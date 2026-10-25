#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# Relay rule on the mail module: <local>@<INBOUND_DOMAIN> goes to our Postfix
#

import os
import sys
import agent


def set_smtp_endpoint(rdb):
    """Publish our Postfix on the cluster VPN, so the mail module reaches it from any node"""
    node_id = os.environ['NODE_ID']
    agent.set_env("SMTP_BIND_ADDRESS", rdb.hget(f'node/{node_id}/vpn', 'ip_address'))
    agent.set_env("SMTP_PORT", os.environ["TCP_PORTS"].split(",")[1])


def _mail_module_id(rdb, mail_uuid):
    providers = agent.list_service_providers(rdb, 'imap', 'tcp', {'module_uuid': mail_uuid})
    return providers[0]['module_id'] if providers else None


def _run(module_id, action, data):
    return agent.tasks.run(f"module/{module_id}", action=action, data=data)


def _find_rule(module_id, subject):
    result = _run(module_id, 'list-relay-rules', {})
    agent.assert_exp(result['exit_code'] == 0, f"list-relay-rules failed on {module_id}")
    for rule in result['output'].get('rules', []):
        if rule['rule_subject'].lower() == subject.lower():
            return rule
    return None


def ensure_relay_rule(mail_uuid):
    """Create the rule, or move it to our current address and port"""
    rdb = agent.redis_connect(use_replica=True)
    module_id = _mail_module_id(rdb, mail_uuid)
    agent.assert_exp(module_id is not None, f"Mail server {mail_uuid} not found")
    subject = os.environ["INBOUND_DOMAIN"]
    other = inbound_domain_owner(rdb, subject)
    agent.assert_exp(other is None, f"Inbound domain {subject} is used by {other}: its relay rule is not changed")
    host = os.environ["SMTP_BIND_ADDRESS"]
    port = int(os.environ["SMTP_PORT"])

    rule = _find_rule(module_id, subject)
    if rule and rule['rule_type'] == 'recipient' and rule['host'] == host \
            and int(rule['port']) == port and rule['enabled']:
        return

    rule_data = {
        "rule_type": "recipient",
        "rule_subject": subject,
        "host": host,
        "port": port,
        "mandatory_tls": False,
        "username": "",
        "password": "",
        "enabled": True,
    }
    # After a restore or a move the rule still points to the old node: update
    # it in place, so list mail always has a route
    action = 'alter-relay-rule' if rule else 'add-relay-rule'
    result = _run(module_id, action, rule_data)
    agent.assert_exp(result['exit_code'] == 0, f"{action} failed on {module_id}")
    print(f"Relay rule {subject} -> {host}:{port} set on {module_id}", file=sys.stderr)


def remove_relay_rule(mail_uuid):
    """Remove the rule only if it still points to this instance"""
    rdb = agent.redis_connect(use_replica=True)
    module_id = _mail_module_id(rdb, mail_uuid)
    if module_id is None:
        print(agent.SD_WARNING + f"Mail server {mail_uuid} not found, relay rule not removed", file=sys.stderr)
        return
    subject = os.environ.get("INBOUND_DOMAIN", "")
    rule = _find_rule(module_id, subject) if subject else None
    # A move installs the new instance first: never remove a rule it already took over
    if not rule or rule['host'] != os.environ.get("SMTP_BIND_ADDRESS") \
            or str(rule['port']) != os.environ.get("SMTP_PORT"):
        return
    result = _run(module_id, 'remove-relay-rule', {'rule_subject': subject})
    if result['exit_code'] != 0:
        print(agent.SD_WARNING + f"remove-relay-rule failed on {module_id}", file=sys.stderr)


#
# Mail addresses of Sympa. The mail module does not let us create them: the
# UI declares them with the token of the logged admin.
#

# Robot addresses of the EPEL package, before the instance prefix
LEGACY_ROBOT_LOCAL_PARTS = ["sympa", "sympa-request", "sympa-owner", "listmaster", "bounce", "abuse-feedback-report"]
ROBOT_SUFFIXES = ["", "-request", "-owner", "-listmaster", "-bounce", "-abuse-feedback-report"]
# Addresses of one list, from Sympa default/list_aliases.tt2
LIST_SUFFIXES = ["", "-request", "-editor", "-unsubscribe", "-owner"]


def robot_prefix():
    return os.environ["INBOUND_DOMAIN"].removesuffix(".invalid")


def robot_local_parts():
    """sympa1, sympa1-request, ... set in sympa.conf by the entrypoint"""
    return [robot_prefix() + suffix for suffix in ROBOT_SUFFIXES]


def list_local_parts(name):
    return [name + suffix for suffix in LIST_SUFFIXES]


def inbound_domain_owner(rdb, inbound):
    """Module ID of another Sympa instance with this inbound domain, or None.

    Two instances with the same inbound domain would share one relay rule,
    and the mail of one would go to the other. The source of a move has our
    UUID and is not another instance.
    """
    for module_id in rdb.hkeys('cluster/module_node'):
        if module_id == os.environ['MODULE_ID']:
            continue
        other, uuid = rdb.hmget(f'module/{module_id}/environment', 'INBOUND_DOMAIN', 'MODULE_UUID')
        if other and other.lower() == inbound.lower() and uuid != os.environ['MODULE_UUID']:
            return module_id
    return None


def free_inbound_domain(rdb):
    """A new inbound domain from our module ID, not used by another instance"""
    candidate = os.environ["MODULE_ID"] + ".invalid"
    if inbound_domain_owner(rdb, candidate):
        candidate = os.environ["MODULE_ID"] + "-" + os.environ["MODULE_UUID"][:8] + ".invalid"
    return candidate


def list_domains_in_use(rdb):
    """List domains of the other Sympa instances: {domain: module_id}.

    Sympa runs one robot per domain, and the robot addresses (sympa@,
    listmaster@...) exist once per domain in the mail module.
    """
    in_use = {}
    for module_id in rdb.hkeys('cluster/module_node'):
        if module_id == os.environ['MODULE_ID']:
            continue
        domain, inbound, uuid = rdb.hmget(f'module/{module_id}/environment', 'LIST_DOMAIN', 'INBOUND_DOMAIN', 'MODULE_UUID')
        # INBOUND_DOMAIN marks a Sympa instance. The source of a move has our UUID.
        if domain and inbound and uuid != os.environ['MODULE_UUID']:
            in_use[domain.lower()] = module_id
    return in_use

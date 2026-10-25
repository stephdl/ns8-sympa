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
    host = os.environ["SMTP_BIND_ADDRESS"]
    port = int(os.environ["SMTP_PORT"])

    rule = _find_rule(module_id, subject)
    if rule and rule['rule_type'] == 'recipient' and rule['host'] == host \
            and int(rule['port']) == port and rule['enabled']:
        return
    if rule:
        # After a restore or a move, the rule still points to the old node
        result = _run(module_id, 'remove-relay-rule', {'rule_subject': subject})
        agent.assert_exp(result['exit_code'] == 0, f"remove-relay-rule failed on {module_id}")

    result = _run(module_id, 'add-relay-rule', {
        "rule_type": "recipient",
        "rule_subject": subject,
        "host": host,
        "port": port,
        "mandatory_tls": False,
        "username": "",
        "password": "",
        "enabled": True,
    })
    agent.assert_exp(result['exit_code'] == 0, f"add-relay-rule failed on {module_id}")
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

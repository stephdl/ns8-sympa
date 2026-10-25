# ns8-sympa

[Sympa](https://www.sympa.community/) mailing list manager for
[NethServer 8](https://github.com/NethServer/ns8-core).

The module runs Sympa 6.2.80 from the Rocky Linux 9 EPEL package. It does
not receive mail from the Internet by itself: the NS8 Mail application
receives the list mail and forwards it to Sympa. Sympa sends mail through
the cluster smarthost.

## Requirements

- A Mail application instance in the cluster. It can run on another node.
- The cluster smarthost, configured in Settings > Smarthost. Without it,
  outgoing mail stays in the queue.
- Optional: a user domain, for LDAP login to the web interface.

## Install

    add-module ghcr.io/stephdl/sympa:latest 1

The output contains the instance name, for example `sympa1`.

## Configure

Configure the instance from the UI, or with:

    api-cli run module/sympa1/configure-module --data - <<EOF
    {
      "host": "sympa.example.org",
      "lets_encrypt": false,
      "list_domain": "example.org",
      "listmasters": ["admin@example.org"],
      "mail_server": "<mail module UUID>",
      "user_domain": "example.org",
      "default_lang": "en-US"
    }
    EOF

- `host`: host name of the web interface, served at
  `https://<host>/sympa`. HTTP is always redirected to HTTPS.
- `list_domain`: mail domain of the lists, like `mylist@example.org`. The UI
  lists the domains of the selected mail server. It
  can be a domain that already holds mailboxes. It must be a domain of the
  Mail application, and it cannot be the internal LDAP domain of the mail
  server or one of its subdomains: the Mail application rejects them.
- `listmasters`: email addresses of the Sympa administrators.
- `mail_server`: UUID of the Mail application instance. `get-configuration`
  lists the available ones in `mail_servers`.
- `user_domain`: user domain for the web login. An empty string disables
  LDAP login, Sympa accounts keep working.
- `default_lang`: default language of Sympa.

`configure-module` validates the input first: the host must not be used by
another application, the mail server and the user domain must exist.

## How mail flows

```
Internet -> Mail application :25 (antispam)
         -> address mylist@example.org forwards to mylist@sympa1.invalid
         -> relay rule sympa1.invalid -> smtp:[<node VPN IP>]:<module SMTP port>
         -> module Postfix -> Sympa queue
Sympa -> module Postfix -> cluster smarthost -> Internet
```

Each instance has an inbound domain, `<module_id>.invalid`, saved in the
`INBOUND_DOMAIN` variable. The `.invalid` top level domain never resolves,
so this mail cannot leave the cluster by mistake.

When the instance is configured, it creates a `recipient` relay rule on
the selected Mail application: `<INBOUND_DOMAIN>` goes to the module
Postfix, published on the node VPN address. The rule appears in the Mail
application relay rules. When the instance is removed, it removes the rule,
only if the rule still points to this instance.

The module Postfix rewrites `<local>@<INBOUND_DOMAIN>` to
`<local>@<list_domain>` and hands the message to Sympa:

- `bounce` and `abuse-feedback-report` go to the bounce queue;
- `<list>-owner` goes to the bounce queue of the list;
- `sympa-request` and `sympa-owner` go to the listmaster;
- every other address goes to the Sympa queue.

VERP bounce addresses like `bounce+...@example.org` work with the single
`bounce` address: the Mail application keeps the `+` extension when it
forwards the message.

### Addresses to declare in the Mail application

The module cannot create addresses in the Mail application: its
`mailadm` role allows relay rules, not addresses. The administrator
declares them, once for Sympa and once for each list. Each address
forwards to an external destination: the same local part at the inbound
domain.

Sympa addresses, once:

    sympa  sympa-request  sympa-owner  listmaster  bounce  abuse-feedback-report

Addresses of each list, for example `mylist`:

    mylist  mylist-request  mylist-editor  mylist-unsubscribe  mylist-owner

The Settings page of the module shows the ready-to-use commands. Example:

    api-cli run module/mail1/add-address --data '{"atype":"domain","domain":"example.org","local":"mylist","destinations":[{"dtype":"external","name":"mylist@sympa1.invalid"}]}'

Before you create an address, check that no user or group has the same
name. An address of the Mail application takes priority over users and
groups, so their mail would go to Sympa without any error.

When a list is closed, remove its five addresses with `remove-address`.

An address that is not declared is rejected during the SMTP session.

## Web interface and login

nginx serves `wwsympa.fcgi` on `https://<host>/sympa`, behind Traefik.

With a user domain, users log in with their LDAP user name or email
address and password. Sympa identifies them by the LDAP `mail` attribute:
a user without `mail` cannot log in. Hidden users of the user domain are
excluded. Other people, for example external subscribers, use a Sympa
account with a password.

When the user domain is not available, the module starts with LDAP login
disabled and logs a warning.

## Containers and data

The rootless pod `sympa` runs:

| Service | Role |
|---|---|
| `postgresql-app.service` | PostgreSQL 18 database |
| `sympa-app.service` | `sympa_msg`, `bulk`, `bounced`, `archived` and `task_manager` |
| `postfix-app.service` | inbound SMTP from the Mail application, relay to the smarthost |
| `wwsympa-app.service` | nginx and the wwsympa FastCGI backend |

The three Sympa containers use the same image, `ghcr.io/stephdl/sympa-app`.
The `sympa-app` container creates or upgrades the database schema when it
starts. If one Sympa daemon exits, the container stops and systemd
restarts it.

Volumes:

- `sympa-etc`: `/etc/sympa`, generated configuration and list templates;
- `sympa-data`: `/var/lib/sympa`, list configurations and web archives. It
  can be placed on an additional disk;
- `sympa-spool`: `/var/spool/sympa`;
- `postfix-queue`: the module Postfix queue;
- `postgres-data`: the database.

Before the pod starts, `bin/sympa-config` writes the files read by the
containers:

- `state/sympa.env`: domain, listmasters, web URL, language;
- `state/secrets/ldap.env`: user domain connection, mode 0600;
- `state/secrets/smarthost.env`: smarthost settings, mode 0600.

`create-module` generates the database password and the Sympa cookie
secret in `state/secrets/`, mode 0600. No secret is stored in the module
environment.

## Events

- `smarthost-changed`: restart the pod, so Postfix uses the new settings.
- `user-domain-changed`: restart the pod when the configured user domain
  changed.

## Backup, restore, clone and move

The backup contains a dump of the database, the secrets and the
`sympa-etc`, `sympa-data` and `sympa-spool` volumes.

- Restore: the database is restored, then `configure-module` runs with
  the saved settings. The inbound domain is kept, so the addresses in the
  Mail application stay valid, and the relay rule is updated with the new
  node address and port. A user domain that does not exist on the cluster
  is dropped with a warning. If the host name is used by another
  application, the instance is not configured: set a new host name in
  Settings.
- Clone: the copy gets its own inbound domain and port, no web route and
  no relay rule. The source keeps working. Set a new host name in
  Settings to use the copy.
- Move: the new instance takes over the web route, the inbound domain and
  the relay rule of the source.

## Uninstall

    remove-module --no-preserve sympa1

The relay rule is removed from the Mail application. The addresses
declared by the administrator are not removed.

## Logs

    journalctl _UID=$(id -u sympa1)

Inside the pod, every service writes to the journal with the service name
as identifier, for example `postfix-app` or `sympa-app`.

## Testing

Test the module using the `test-module.sh` script:

    ./test-module.sh <NODE_ADDR> ghcr.io/stephdl/sympa:latest

The tests are made using [Robot Framework](https://robotframework.org/).

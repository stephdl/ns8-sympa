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
  lists the domains of the selected mail server. It can be a domain that
  already holds mailboxes. It must be a domain of the Mail application, and
  it cannot be the internal LDAP domain of the mail server or one of its
  subdomains: the Mail application rejects them. One domain is served by
  one Sympa instance only: Sympa runs one robot per domain. The UI marks
  the domains used by another instance.
- `listmasters`: email addresses of the Sympa administrators.
- `mail_server`: UUID of the Mail application instance. `get-configuration`
  lists the available ones in `mail_servers`.
- `user_domain`: user domain for the web login. An empty string disables
  LDAP login, Sympa accounts keep working.
- `default_lang`: default language of Sympa.

`configure-module` validates the input first: the host must not be used by
another application, the mail server and the user domain must exist, and
the list domain must be a domain of the mail server not used by another
Sympa instance.

## How mail flows

```
Internet -> Mail application :25 (antispam)
         -> address mylist@example.org forwards to mylist@sympa1.invalid
         -> relay rule sympa1.invalid -> smtp:[<node VPN IP>]:<module SMTP port>
         -> module Postfix -> Sympa queue
Sympa -> module Postfix -> cluster smarthost -> Internet
```

The module Postfix accepts mail only for the inbound domain: it cannot be
used as an open relay.

Each instance has an inbound domain, `<module_id>.invalid`, saved in the
`INBOUND_DOMAIN` variable. The `.invalid` top level domain never resolves,
so this mail cannot leave the cluster by mistake.

When the instance is configured, it creates a `recipient` relay rule on
the selected Mail application: `<INBOUND_DOMAIN>` goes to the module
Postfix, published on the node VPN address. The rule appears in the Mail
application relay rules. When the rule already exists, for example after a
restore or a move, the module updates it in place with `alter-relay-rule`. When the mail server
changes, the rule is removed from the previous one. When the instance is
removed, it removes the rule, only if the rule still points to this
instance.

The module Postfix rewrites `<local>@<INBOUND_DOMAIN>` to
`<local>@<list_domain>` and hands the message to Sympa:

- `bounce` and `abuse-feedback-report` go to the bounce queue;
- `<list>-owner` goes to the bounce queue of the list;
- `sympa-request` and `sympa-owner` go to the listmaster;
- every other address goes to the Sympa queue.

VERP bounce addresses like `bounce+...@example.org` work with the single
`bounce` address: the Mail application keeps the `+` extension when it
forwards the message.

### Mail addresses of Sympa and of the lists

Each address of the list domain used by Sympa forwards to an external
destination: the same local part at the inbound domain.

Sympa addresses, once per instance. They start with a prefix taken from
the inbound domain, for example `sympa1` for `sympa1.invalid`, so they
never collide with a user and survive restore and move:

    sympa1  sympa1-request  sympa1-owner  sympa1-listmaster  sympa1-bounce  sympa1-abuse-feedback-report

`sympa1@` receives the mail commands, like `subscribe` or `help`, and
`sympa1-bounce@` the bounces with VERP. Lists keep plain addresses, for
example `mylist`:

    mylist  mylist-request  mylist-editor  mylist-unsubscribe  mylist-owner

An address that is not declared is rejected during the SMTP session.

The `mailadm` role of the module does not allow creating addresses. The
module UI creates and removes them instead, with the actions of the Mail
application and the token of the logged administrator. The administrator
needs the right to run `add-address` and `remove-address` on the mail
server. Before creating an address, the UI checks that no user, group or
other address has the same name, and creates the five addresses of a list
or none. It removes only the addresses that forward to this instance.

Nothing is automatic outside the UI:

- `create-list` and `destroy-list` called with `api-cli` do not change
  the addresses;
- a list created or closed in the Sympa web interface has no addresses, or
  keeps them. The Lists page flags missing and unused addresses, with a
  button to create or remove them;
- when the mail server or the list domain changes in Settings, the UI
  moves the addresses to the new one after saving;
- when the instance is removed, its addresses stay in the Mail application.
  Settings has a "Before removing the instance" section to remove them
  first.

## Lists

The Lists page shows the lists of the instance with their subject, status,
number of subscribers and the state of their mail addresses, read from the
mail server selected in Settings. Actions:

- `list-lists`: lists, subscribers and missing addresses.
- `create-list`: name, subject, type (a Sympa list template), owners and
  description. The name accepts lowercase letters, digits, dot, dash and
  underscore. Names of Sympa addresses and names ending with a list suffix,
  like `-owner`, are refused. The UI declares the addresses first: if one
  is refused, the list is not created.
- `destroy-list`: purge the list, its subscribers and its archives. The UI
  asks to type the list name, then removes the addresses.

Subscribers, moderation and archives are managed in the Sympa web
interface.

## Web interface and login

nginx serves `wwsympa.fcgi` on `https://<host>/sympa`, behind Traefik.

With a user domain, users log in with their LDAP user name or email
address and password. Sympa identifies them by the LDAP `mail` attribute:
a user without `mail` cannot log in. Hidden users of the user domain are
excluded. Other people, for example external subscribers, use a Sympa
account with a password.

When the user domain does not exist, the module starts with LDAP login
disabled and logs a warning. When Redis or the user domain cannot be read,
for example at boot, the pod starts with the previous LDAP and smarthost
settings.

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
  Mail application stay valid, and the relay rule is updated in place with
  the new node address and port. Let's Encrypt is disabled: enable it again
  in Settings. A user domain that does not exist on the cluster is dropped
  with a warning. If another instance of the cluster already uses the
  inbound domain, the restored instance takes a new one with a warning,
  and its addresses must be declared again from the Lists page.
- Restore that cannot be configured: when the host name is used by another
  application, when the mail server of the backup does not exist on the
  cluster, or when it lacks the list domain, the instance starts without
  web route and without relay rule, and logs a warning. Complete the
  configuration in Settings.
- Clone: the copy gets its own inbound domain and port, no web route and
  no relay rule. Its Sympa addresses must be created from the Lists page. The source keeps working. Set a new host name in
  Settings to use the copy.
- Move: the new instance takes over the web route with its Let's Encrypt
  setting, the inbound domain and the relay rule of the source.

## Uninstall

    remove-module --no-preserve sympa1

The relay rule is removed from the Mail application. The mail addresses
stay: remove them first with the "Before removing the instance" section of
Settings.

## Logs

    journalctl _UID=$(id -u sympa1)

Inside the pod, every service writes to the journal with the service name
as identifier, for example `postfix-app` or `sympa-app`.

## Testing

Test the module using the `test-module.sh` script:

    ./test-module.sh <NODE_ADDR> ghcr.io/stephdl/sympa:latest

The tests are made using [Robot Framework](https://robotframework.org/).

The suite installs an OpenLDAP user domain and a Mail application, then
configures Sympa, creates a list and subscribes to it by mail. It
checks list delivery to a mailbox, LDAP login on the web interface, the
`smarthost-changed` and `user-domain-changed` events, reconfiguration
and invalid input. The test changes the cluster smarthost and restores
it at the end. Set
`SCENARIO` to `update` to install the release published in the stephdl
repository, `https://forge.de-labrusse.fr/ns8/updates/`, and update it to
the image under test. The test adds this repository to the cluster. On a
node that already has a Mail application, set `MAIL_MODULE` to its module
ID and the suite reuses it.

# ns8-sympa

[Sympa](https://www.sympa.community/) mailing list manager for
[NethServer 8](https://github.com/NethServer/ns8-core).

The module runs Sympa 6.2.80 from the Rocky Linux 9 EPEL package. It does
not receive mail from the Internet by itself: the NS8 Mail application
receives the list mail and forwards it to Sympa. Sympa sends mail through
the cluster smarthost.

One instance serves the lists of one mail domain only, like
`mylist@example.org`. For lists on another domain, install another
instance of the module. Two instances cannot share a domain. Once the
first list is created, the list domain and the mail server cannot change
anymore.

## Mail addresses

Sympa needs addresses in the Mail application. Without them, the Mail
application rejects the list mail during the SMTP session. Each address
is an address of the list domain with an external destination: the same
name at the inbound domain of the instance, for example
`mylist@sympa1.invalid`. This is how the mail reaches the module.

An instance needs 6 addresses for Sympa itself, plus 5 per list. With 3
lists, that makes 21 addresses.

The Sympa addresses start with the instance name, `sympa1` in these
examples, so they never collide with a user:

| Address | Purpose |
|---|---|
| `sympa1@example.org` | mail commands, like `subscribe` or `help` |
| `sympa1-request@example.org` | goes to the listmasters |
| `sympa1-owner@example.org` | goes to the listmasters |
| `sympa1-listmaster@example.org` | goes to the listmasters |
| `sympa1-bounce@example.org` | bounces, with VERP |
| `sympa1-abuse-feedback-report@example.org` | abuse reports, handled as bounces |

Each list, for example `mylist`, has 5 addresses:

| Address | Purpose |
|---|---|
| `mylist@example.org` | posts to the list |
| `mylist-request@example.org` | the list owners |
| `mylist-editor@example.org` | the list moderators |
| `mylist-unsubscribe@example.org` | unsubscribe by mail |
| `mylist-owner@example.org` | bounces of the list |

### The UI manages them

The Lists page of the module creates and removes the addresses. It uses
the token of the logged administrator, who needs the right to run
`add-address` and `remove-address` on the mail server. The module itself
cannot create them.

- Creating a list creates its 5 addresses, or none if one is refused. The
  UI checks first that no user, group or other address has the same name.
- Destroying a list removes its addresses.
- When the Sympa addresses are missing, a banner shows them with a
  "Create Sympa addresses" button.
- When the addresses of a list are missing, the list shows a red
  "Missing" tag and a "Create addresses" button. Click it to create them
  again, for example after someone removed them in the Mail application.
- Addresses that forward to the instance but match no list are shown with
  a "Remove unused addresses" button.
- When the mail server or the list domain changes in Settings, the UI
  moves the Sympa addresses after saving. This is possible only before
  the first list is created.

The UI removes only the addresses that forward to this instance.

Nothing is automatic outside the UI. `create-list` and `destroy-list`
called with `api-cli` do not touch the addresses. A list created or closed
in the Sympa web interface has no addresses, or keeps them: use the
buttons of the Lists page.

### Remove them before uninstalling

> **Warning**
> Removing the module does not remove its addresses from the Mail
> application. Remove them first, or you must remove them by hand.

1. Open Settings of the instance, section "Before removing the
   instance", and click "Remove all mail addresses".
2. Then remove the module, see [Uninstall](#uninstall).

If the module is already removed, open the Mail application, page
Addresses, and delete each address of the list domain whose destination
ends with `@sympa1.invalid`:

- `sympa1`, `sympa1-request`, `sympa1-owner`, `sympa1-listmaster`,
  `sympa1-bounce`, `sympa1-abuse-feedback-report`;
- for each list: `<list>`, `<list>-request`, `<list>-editor`,
  `<list>-unsubscribe`, `<list>-owner`.

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
- `lets_encrypt`: request a Let's Encrypt certificate for `host`.
- `list_domain`: mail domain of the lists, like `mylist@example.org`. The UI
  lists the domains of the selected mail server. It can be a domain that
  already holds mailboxes. It must be a domain of the Mail application, and
  it cannot be the internal LDAP domain of the mail server or one of its
  subdomains: the Mail application rejects them. An instance serves one
  domain, and a domain is served by one instance only: Sympa runs one
  robot per domain. The UI marks the domains used by another instance.
- `listmasters`: email addresses of the Sympa administrators.
- `mail_server`: UUID of the Mail application instance. Find it in
  `mail_servers` of `api-cli run module/sympa1/get-configuration`.
- `user_domain`: user domain for the web login. An empty string disables
  LDAP login, Sympa accounts keep working.
- `default_lang`: default language of Sympa.

`configure-module` validates the input first: the host must not be used by
another application, the mail server and the user domain must exist, and
the list domain must be a domain of the mail server not used by another
Sympa instance.

Then open the Lists page: it creates the Sympa addresses, and the lists
with their addresses. See [Mail addresses](#mail-addresses).

Once the instance has lists, the list domain and the mail server cannot
change. Sympa stores the lists and their subscribers under the list
domain: with another domain they would disappear. To serve another
domain, install another instance.

## Lists

The Lists page shows the lists of the instance with their subject, status,
number of subscribers and the state of their mail addresses, read from the
mail server selected in Settings. Actions:

- `list-lists`: lists, subscribers and missing addresses.
- `create-list`: name, subject, type (a Sympa list template), owners and
  description. The name accepts lowercase letters, digits, dot, dash and
  underscore. Names of Sympa addresses and names ending with a list suffix,
  like `-owner`, are refused.
- `destroy-list`: purge the list, its subscribers and its archives. The UI
  asks to type the list name.

Subscribers, moderation and archives are managed in the Sympa web
interface.

## Web interface and login

nginx serves `wwsympa.fcgi` on `https://<host>/sympa`, behind Traefik.

With a user domain, users log in with their LDAP user name or email
address and password. Sympa identifies them by the LDAP `mail` attribute:
a user without `mail` cannot log in. Hidden users of the user domain are
excluded. Other people, for example external subscribers, use a Sympa
account with a password.

### First login of a listmaster

A listmaster is an address of the `listmasters` setting. Sympa gives the
admin rights to whoever logs in with that address.

- With a user domain, the listmaster address must be the `mail`
  attribute of an LDAP user. Log in with the LDAP user name and password.
- Without a user domain, or for an address outside LDAP, click "First
  login?" or "Lost password?" on the login page and enter the address.
  Sympa sends a link by mail to set the password, so the smarthost must
  work first.

When the user domain does not exist, the module starts with LDAP login
disabled and logs a warning. When Redis or the user domain cannot be read,
for example at boot, the pod starts with the previous LDAP and smarthost
settings.

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
  cluster, when it lacks the list domain, or when another Sympa instance
  already uses the list domain, the instance starts without
  web route and without relay rule, and logs a warning. Complete the
  configuration in Settings.
- Clone: the copy gets its own inbound domain and port, no web route and
  no relay rule. The source keeps working.
- Move: the new instance takes over the web route, the inbound domain and
  the relay rule of the source. Let's Encrypt is disabled, because the new
  node may not answer on ports 80 and 443 yet: enable it again in Settings.

A copy, made by a clone or by a restore next to the original instance,
keeps the host name and the list domain of the original. It can be used
only once the original is gone:

1. In the original instance, open Settings and click "Remove all mail
   addresses".
2. Remove the original instance.
3. In the copy, open Settings and save.
4. In the copy, open the Lists page and create the missing addresses.

## Uninstall

Remove the mail addresses first, see
[Remove them before uninstalling](#remove-them-before-uninstalling). Then:

    remove-module --no-preserve sympa1

The relay rule is removed from the Mail application.

## Logs

    journalctl _UID=$(id -u sympa1)

Inside the pod, every service writes to the journal with the service name
as identifier, for example `postfix-app` or `sympa-app`.

## Troubleshooting

A message sent to a list does not reach the subscribers. Check each step
of the path, in this order:

1. The addresses exist. The Lists page shows no red "Missing" tag and no
   "Sympa addresses are missing" banner. If the Mail application rejects
   the message, the sender gets a bounce for an unknown user.
2. The relay rule exists. The Mail application relay rules show a
   `recipient` rule for `sympa1.invalid`. Saving Settings again creates it.
   From the command line:

       api-cli run module/mail1/list-relay-rules

3. The message reached the module:

       journalctl _UID=$(id -u sympa1) SYSLOG_IDENTIFIER=postfix-app

4. Outgoing mail is not stuck in the module queue. A full queue usually
   means the cluster smarthost is missing or refuses the login:

       runagent -m sympa1 podman exec postfix-app postqueue -p

5. Sympa processed the message:

       journalctl _UID=$(id -u sympa1) SYSLOG_IDENTIFIER=sympa-app

A message held for moderation, or a sender who is not a subscriber of a
private list, is normal Sympa behavior: check the list settings in the
Sympa web interface.

## Internals

### How mail flows

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
so this mail cannot leave the cluster by mistake. The Sympa addresses take
their prefix from it, so they survive restore and move.

When the instance is configured, it creates a `recipient` relay rule on
the selected Mail application: `<INBOUND_DOMAIN>` goes to the module
Postfix, published on the node VPN address. The rule appears in the Mail
application relay rules. When the rule already exists, for example after a
restore or a move, the module updates it in place with
`alter-relay-rule`. When the mail server changes, the rule is removed from
the previous one. When the instance is removed, it removes the rule, only
if the rule still points to this instance.

The `mailadm` role of the module does not allow creating addresses: this
is why the UI creates them with the administrator token.

The module Postfix rewrites `<local>@<INBOUND_DOMAIN>` to
`<local>@<list_domain>` and hands the message to Sympa:

- `sympa1-bounce` and `sympa1-abuse-feedback-report` go to the bounce
  queue;
- `<list>-owner` goes to the bounce queue of the list;
- `sympa1-request` and `sympa1-owner` go to the listmaster;
- every other address goes to the Sympa queue.

VERP bounce addresses like `sympa1-bounce+...@example.org` work with the
single bounce address: the Mail application keeps the `+` extension when
it forwards the message.

### Containers and data

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

### Events

- `smarthost-changed`: restart the pod, so Postfix uses the new settings.
- `user-domain-changed`: restart the pod when the configured user domain
  changed.

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

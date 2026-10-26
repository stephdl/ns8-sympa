//
// Copyright (C) 2026 Nethesis S.r.l.
// SPDX-License-Identifier: GPL-3.0-or-later
//

// The Sympa module cannot create addresses in the mail module. These
// methods call the mail module actions with the token of the logged admin.
// An address belongs to Sympa when its only destination is
// <local>@<inbound domain>: only those are ever removed.

export class AddressConflict extends Error {
  constructor(local, reason) {
    super(reason);
    this.local = local;
    this.reason = reason;
  }
}

export default {
  methods: {
    // Run an action of any module and resolve with its output
    moduleTask(moduleId, action, data = {}, title = "") {
      return new Promise((resolve, reject) => {
        const eventId = this.getUuid();
        const handlers = {
          completed: (ctx, result) => resolve(result.output),
          aborted: () => reject(new Error(this.$t("error.generic_error"))),
          "validation-failed": (errors) =>
            reject(
              Object.assign(new Error(action), { action, validation: errors })
            ),
        };
        // Only one event fires: drop the other listeners with it
        const off = () => {
          for (const [name, handler] of Object.entries(handlers)) {
            this.core.$root.$off(`${action}-${name}-${eventId}`, handler);
          }
        };
        for (const [name, handler] of Object.entries(handlers)) {
          handlers[name] = (...args) => {
            off();
            handler(...args);
          };
          this.core.$root.$on(`${action}-${name}-${eventId}`, handlers[name]);
        }
        this.createModuleTaskForApp(moduleId, {
          action,
          data,
          extra: {
            title: title || this.$t("action." + action),
            isNotificationHidden: !title,
            eventId,
          },
        }).catch((err) => {
          off();
          reject(new Error(this.getErrorMessage(err)));
        });
      });
    },
    // Addresses of a domain as the mail module sees them
    async readMailState(mailModule, domain) {
      const [addresses, domains] = await Promise.all([
        this.moduleTask(mailModule, "list-addresses"),
        this.moduleTask(mailModule, "list-domains"),
      ]);
      const domainInfo = domains.find((d) => d.domain === domain) || {};
      const state = { destinations: {}, taken: {} };
      for (const addr of addresses.addresses) {
        const local = addr.local.toLowerCase();
        if (addr.atype === "wildcard") {
          state.taken[local] = "address_reserved";
        } else if (addr.atype === "adduser" && domainInfo.addusers) {
          state.taken[local] = "address_is_user";
        } else if (addr.atype === "addgroup" && domainInfo.addgroups) {
          state.taken[local] = "address_is_group";
        } else if (
          addr.atype === "addalias" &&
          addr.domain.toLowerCase() === domain
        ) {
          // Postfix reads the address table first: a list would steal the mail
          state.taken[local] = "address_is_alias";
        } else if (
          addr.atype === "domain" &&
          addr.domain.toLowerCase() === domain
        ) {
          state.destinations[local] = addr.destinations;
        }
      }
      return state;
    },
    forwardsTo(state, local, inbound) {
      const dests = state ? state.destinations[local.toLowerCase()] : null;
      return (
        !!dests &&
        dests.length === 1 &&
        dests[0].dtype === "external" &&
        dests[0].name.toLowerCase() === `${local}@${inbound}`.toLowerCase()
      );
    },
    // Local parts of the domain that forward to this Sympa instance
    sympaAddresses(state, inbound) {
      return Object.keys(state.destinations).filter((local) =>
        this.forwardsTo(state, local, inbound)
      );
    },
    // Declare the addresses: all of them, or none
    async declareAddresses(mailModule, domain, inbound, locals) {
      const state = await this.readMailState(mailModule, domain);
      const missing = [];
      for (const local of locals) {
        if (this.forwardsTo(state, local, inbound)) {
          continue;
        }
        if (state.taken[local]) {
          throw new AddressConflict(local, state.taken[local]);
        }
        if (state.destinations[local]) {
          throw new AddressConflict(local, "address_already_exists");
        }
        missing.push(local);
      }
      const created = [];
      try {
        for (const local of missing) {
          await this.moduleTask(
            mailModule,
            "add-address",
            {
              atype: "domain",
              domain,
              local,
              destinations: [
                { dtype: "external", name: `${local}@${inbound}` },
              ],
            },
            this.$t("lists.adding_address", { address: `${local}@${domain}` })
          );
          created.push(local);
        }
      } catch (err) {
        await this.dropAddresses(mailModule, domain, created).catch(() => {});
        throw err;
      }
      return created;
    },
    // Remove addresses known to forward to this instance, without checking
    async dropAddresses(mailModule, domain, locals) {
      const failed = [];
      for (const local of locals) {
        try {
          await this.moduleTask(
            mailModule,
            "remove-address",
            { atype: "domain", domain, local },
            this.$t("lists.removing_address", { address: `${local}@${domain}` })
          );
        } catch (err) {
          console.error(`cannot remove ${local}@${domain}`, err);
          failed.push(`${local}@${domain}`);
        }
      }
      if (failed.length) {
        throw new Error(
          this.$t("lists.addresses_not_removed", {
            addresses: failed.join(", "),
          })
        );
      }
    },
    // Remove only the given addresses that still forward to this instance
    async withdrawAddresses(mailModule, domain, inbound, locals) {
      const state = await this.readMailState(mailModule, domain);
      const ours = locals.filter((local) =>
        this.forwardsTo(state, local, inbound)
      );
      await this.dropAddresses(mailModule, domain, ours);
      return ours;
    },
    addressErrorMessage(err, domain) {
      if (err instanceof AddressConflict) {
        return this.$t("lists.list_" + err.reason, {
          value: `${err.local}@${domain}`,
        });
      }
      if (err.validation) {
        return err.validation
          .map((e) =>
            this.$te("lists.list_" + e.error)
              ? this.$t("lists.list_" + e.error, { value: e.value })
              : `${e.error}: ${e.value}`
          )
          .join(" ");
      }
      return err.message;
    },
  },
};

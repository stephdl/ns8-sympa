<!--
  Copyright (C) 2026 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("lists.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.listLists">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.list-lists')"
          :description="error.listLists"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="loaded && mode === 'unconfigured'">
      <cv-column>
        <NsInlineNotification
          kind="info"
          :title="$t('lists.not_configured')"
          :description="$t('lists.not_configured_description')"
          :actionLabel="$t('status.configure')"
          @action="goToAppPage(instanceName, 'settings')"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="loaded && uiManaged">
      <cv-column>
        <NsInlineNotification
          kind="info"
          :title="$t('lists.ui_mode')"
          :description="$t('lists.ui_mode_description', { mail: mailModule })"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="error.mail">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('lists.mail_not_readable', { mail: mailModule })"
          :description="error.mail"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="stateReady && !robotOk">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('lists.robot_addresses_missing')"
          :description="
            uiManaged
              ? $t('lists.robot_addresses_missing_ui', {
                  addresses: robotAddresses.join(', '),
                })
              : $t('lists.robot_addresses_missing_description')
          "
          :actionLabel="
            uiManaged
              ? $t('lists.create_robot_addresses')
              : $t('status.configure')
          "
          @action="
            uiManaged
              ? createRobotAddresses()
              : goToAppPage(instanceName, 'settings')
          "
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="error.action">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="error.actionTitle"
          :description="error.action"
          @close="error.action = ''"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="mode !== 'unconfigured'">
      <cv-column>
        <NsButton
          kind="secondary"
          :icon="Add20"
          :disabled="!stateReady || !!busy"
          @click="showCreateModal"
          class="mg-bottom"
          >{{ $t("lists.create_list") }}</NsButton
        >
      </cv-column>
    </cv-row>
    <cv-row v-if="mode !== 'unconfigured'">
      <cv-column>
        <cv-tile light>
          <NsEmptyState
            v-if="loaded && !lists.length"
            :title="$t('lists.no_lists')"
          >
            <template #description>{{
              $t("lists.no_lists_description")
            }}</template>
          </NsEmptyState>
          <NsDataTable
            v-else
            :allRows="rows"
            :columns="i18nColumns"
            :rawColumns="columns"
            :sortable="true"
            :pageSizes="[10, 25, 50, 100]"
            :overflow-menu="true"
            isSearchable
            :searchPlaceholder="$t('lists.search_lists')"
            :searchClearLabel="core.$t('common.clear_search')"
            :noSearchResultsLabel="core.$t('common.no_search_results')"
            :noSearchResultsDescription="
              core.$t('common.no_search_results_description')
            "
            :isLoading="loading.listLists"
            :skeletonRows="3"
            :isErrorShown="false"
            :itemsPerPageLabel="core.$t('pagination.items_per_page')"
            :rangeOfTotalItemsLabel="core.$t('pagination.range_of_total_items')"
            :ofTotalPagesLabel="core.$t('pagination.of_total_pages')"
            :backwardText="core.$t('pagination.previous_page')"
            :forwardText="core.$t('pagination.next_page')"
            :pageNumberLabel="core.$t('pagination.page_number')"
            @updatePage="tablePage = $event"
          >
            <template slot="data">
              <cv-data-table-row
                v-for="row in tablePage"
                :key="row.name"
                :value="row.name"
              >
                <cv-data-table-cell>
                  <cv-link :href="listUrl(row)" target="_blank">{{
                    listAddress(row)
                  }}</cv-link>
                </cv-data-table-cell>
                <cv-data-table-cell>{{ row.subject }}</cv-data-table-cell>
                <cv-data-table-cell>
                  <cv-tag
                    :kind="row.status === 'open' ? 'green' : 'gray'"
                    :label="statusLabel(row.status)"
                  />
                </cv-data-table-cell>
                <cv-data-table-cell>{{ row.subscribers }}</cv-data-table-cell>
                <cv-data-table-cell>
                  <cv-tag
                    v-if="row.addresses_ok"
                    kind="green"
                    :label="$t('lists.addresses_ok')"
                  />
                  <template v-else-if="stateReady">
                    <cv-tag kind="red" :label="$t('lists.addresses_missing')" />
                    <NsButton
                      kind="ghost"
                      size="small"
                      :loading="busy === row.name"
                      :disabled="!!busy"
                      @click="createListAddresses(row)"
                      >{{ $t("lists.create_addresses") }}</NsButton
                    >
                  </template>
                </cv-data-table-cell>
                <cv-data-table-cell class="table-overflow-menu-cell">
                  <cv-overflow-menu flip-menu class="table-overflow-menu">
                    <cv-overflow-menu-item @click="openList(row)">
                      <NsMenuItem
                        :icon="Launch20"
                        :label="$t('lists.open_in_sympa')"
                      />
                    </cv-overflow-menu-item>
                    <NsMenuDivider />
                    <cv-overflow-menu-item
                      danger
                      :disabled="!!busy"
                      @click="showDestroy(row)"
                    >
                      <NsMenuItem
                        :icon="TrashCan20"
                        :label="$t('lists.destroy_list')"
                      />
                    </cv-overflow-menu-item>
                  </cv-overflow-menu>
                </cv-data-table-cell>
              </cv-data-table-row>
            </template>
          </NsDataTable>
        </cv-tile>
      </cv-column>
    </cv-row>

    <!-- create list -->
    <NsModal
      size="default"
      :visible="isCreateShown"
      :isLoading="loading.createList"
      :primaryButtonDisabled="loading.createList"
      @modal-hidden="isCreateShown = false"
      @primary-click="createList"
    >
      <template slot="title">{{ $t("lists.create_list") }}</template>
      <template slot="content">
        <cv-form @submit.prevent="createList">
          <NsTextInput
            :label="$t('lists.name')"
            v-model.trim="form.name"
            placeholder="news"
            :helper-text="
              $t('lists.name_helper', { domain: listDomain || 'example.org' })
            "
            :invalid-message="$t(error.name, { value: errorValue })"
            :disabled="loading.createList"
            ref="name"
          />
          <NsTextInput
            :label="$t('lists.subject')"
            v-model.trim="form.subject"
            :invalid-message="$t(error.subject)"
            :disabled="loading.createList"
            ref="subject"
          />
          <NsComboBox
            :key="'type-' + typeKey"
            v-model="form.type"
            :title="$t('lists.type')"
            :label="$t('lists.choose_type')"
            :options="typeOptions"
            :autoFilter="true"
            :autoHighlight="true"
            :invalid-message="$t(error.type)"
            :disabled="loading.createList"
            ref="type"
          />
          <cv-text-area
            :label="$t('lists.owners')"
            v-model="form.owners"
            :helper-text="$t('lists.owners_helper')"
            :invalid-message="$t(error.owners, { email: errorValue })"
            :disabled="loading.createList"
            ref="owners"
          />
          <cv-text-area
            :label="$t('lists.description')"
            v-model="form.description"
            :disabled="loading.createList"
          />
          <NsInlineNotification
            v-if="error.createList"
            kind="error"
            :title="$t('action.create-list')"
            :description="error.createList"
            :showCloseButton="false"
          />
        </cv-form>
      </template>
      <template slot="secondary-button">{{
        core.$t("common.cancel")
      }}</template>
      <template slot="primary-button">{{ $t("lists.create") }}</template>
    </NsModal>

    <!-- destroy list -->
    <NsDangerDeleteModal
      :isShown="isDestroyShown"
      :name="selected ? selected.name : ''"
      :title="$t('lists.destroy_list')"
      :warning="core.$t('common.please_read_carefully')"
      :description="
        $t('lists.destroy_description', {
          list: selected ? listAddress(selected) : '',
        })
      "
      :typeToConfirm="
        core.$t('common.type_to_confirm', {
          name: selected ? selected.name : '',
        })
      "
      :isErrorShown="!!error.destroyList"
      :errorTitle="$t('action.destroy-list')"
      :errorDescription="error.destroyList"
      :loading="loading.destroyList"
      @hide="isDestroyShown = false"
      @confirmDelete="destroyList"
    />
  </cv-grid>
</template>

<script>
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

// Raised when an address cannot be declared in the mail module
class AddressConflict extends Error {
  constructor(local, reason) {
    super(reason);
    this.local = local;
    this.reason = reason;
  }
}

export default {
  name: "Lists",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("lists.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "lists",
      },
      urlCheckInterval: null,
      loaded: false,
      mode: "auto",
      lists: [],
      listTypes: [],
      backendRobotOk: true,
      robotAddresses: [],
      listSuffixes: [],
      listDomain: "",
      host: "",
      inboundDomain: "",
      mailModule: "",
      listmasters: [],
      // Addresses of the list domain as the mail module sees them (UI mode)
      mailState: null,
      tablePage: [],
      columns: ["name", "subject", "status", "subscribers", "addresses"],
      isCreateShown: false,
      isDestroyShown: false,
      selected: null,
      typeKey: 0,
      errorValue: "",
      busy: "",
      form: {
        name: "",
        subject: "",
        type: "",
        owners: "",
        description: "",
      },
      loading: {
        listLists: false,
        createList: false,
        destroyList: false,
      },
      error: {
        listLists: "",
        destroyList: "",
        createList: "",
        mail: "",
        action: "",
        actionTitle: "",
        name: "",
        subject: "",
        type: "",
        owners: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    // Without the mailaddressadm role, this page declares the addresses
    uiManaged() {
      return this.mode === "manual";
    },
    stateReady() {
      return this.loaded && (!this.uiManaged || !!this.mailState);
    },
    robotOk() {
      if (!this.uiManaged) {
        return this.backendRobotOk;
      }
      return this.robotAddresses.every((local) => this.isOurs(local));
    },
    rows() {
      if (!this.uiManaged) {
        return this.lists;
      }
      return this.lists.map((item) => ({
        ...item,
        addresses_ok:
          !!this.mailState &&
          this.listLocalParts(item.name).every((local) => this.isOurs(local)),
      }));
    },
    i18nColumns() {
      return this.columns.map((column) => this.$t("lists.column_" + column));
    },
    typeOptions() {
      return this.listTypes.map((type) => ({
        name: type,
        label: this.$t("lists.type_" + type.replace(/-/g, "_")),
        value: type,
      }));
    },
  },
  created() {
    this.refresh();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    listAddress(row) {
      return `${row.name}@${this.listDomain}`;
    },
    listUrl(row) {
      return `https://${this.host}/sympa/info/${row.name}`;
    },
    openList(row) {
      window.open(this.listUrl(row), "_blank");
    },
    statusLabel(status) {
      const known = [
        "open",
        "closed",
        "pending",
        "error_config",
        "family_closed",
      ];
      return known.includes(status)
        ? this.$t("lists.status_" + status)
        : status;
    },
    listLocalParts(name) {
      return this.listSuffixes.map((suffix) => name + suffix);
    },
    // Run an action of any module with the token of the logged admin
    task(moduleId, action, data = {}, title = "") {
      return new Promise((resolve, reject) => {
        const eventId = this.getUuid();
        this.core.$root.$once(`${action}-completed-${eventId}`, (ctx, result) =>
          resolve(result.output)
        );
        this.core.$root.$once(`${action}-aborted-${eventId}`, () =>
          reject(new Error(this.$t("error.generic_error")))
        );
        this.core.$root.$once(
          `${action}-validation-failed-${eventId}`,
          (errors) =>
            reject(Object.assign(new Error(action), { validation: errors }))
        );
        this.createModuleTaskForApp(moduleId, {
          action,
          data,
          extra: {
            title: title || this.$t("action." + action),
            isNotificationHidden: !title,
            eventId,
          },
        }).catch((err) => reject(new Error(this.getErrorMessage(err))));
      });
    },
    async refresh() {
      this.loading.listLists = true;
      this.error.listLists = "";
      try {
        const [config, output] = await Promise.all([
          this.task(this.instanceName, "get-configuration"),
          this.task(this.instanceName, "list-lists"),
        ]);
        this.listDomain = config.list_domain;
        this.host = config.host;
        this.inboundDomain = config.inbound_domain;
        this.listmasters = config.listmasters;
        const server = config.mail_servers.find(
          (s) => s.uuid === config.mail_server
        );
        this.mailModule = server ? server.module_id : "";
        this.mode = output.mode;
        this.lists = output.lists;
        this.listTypes = output.list_types;
        this.backendRobotOk = output.robot_addresses_ok;
        this.robotAddresses = output.robot_addresses;
        this.listSuffixes = output.list_suffixes;
        this.loaded = true;
      } catch (err) {
        this.error.listLists = err.message;
      }
      this.loading.listLists = false;
      if (this.uiManaged && this.mailModule) {
        await this.loadMailState();
      }
    },
    // Read the addresses of the mail module, to check names before using them
    async loadMailState() {
      this.error.mail = "";
      try {
        const [addresses, domains] = await Promise.all([
          this.task(this.mailModule, "list-addresses"),
          this.task(this.mailModule, "list-domains"),
        ]);
        const domain = domains.find((d) => d.domain === this.listDomain) || {};
        const state = { destinations: {}, taken: {} };
        for (const addr of addresses.addresses) {
          const local = addr.local.toLowerCase();
          if (addr.atype === "wildcard") {
            state.taken[local] = "address_reserved";
          } else if (addr.atype === "adduser" && domain.addusers) {
            state.taken[local] = "address_is_user";
          } else if (addr.atype === "addgroup" && domain.addgroups) {
            state.taken[local] = "address_is_group";
          } else if (
            addr.atype === "domain" &&
            addr.domain.toLowerCase() === this.listDomain
          ) {
            state.destinations[local] = addr.destinations;
          }
        }
        this.mailState = state;
      } catch (err) {
        this.mailState = null;
        this.error.mail = err.message;
      }
    },
    // An address is ours when its only destination is <local>@<inbound domain>
    isOurs(local) {
      const dests = this.mailState
        ? this.mailState.destinations[local.toLowerCase()]
        : null;
      return (
        !!dests &&
        dests.length === 1 &&
        dests[0].dtype === "external" &&
        dests[0].name.toLowerCase() ===
          `${local}@${this.inboundDomain}`.toLowerCase()
      );
    },
    // Declare the addresses in the mail module. All of them, or none.
    async addAddresses(locals) {
      await this.loadMailState();
      if (!this.mailState) {
        throw new Error(this.error.mail);
      }
      const missing = [];
      for (const local of locals) {
        if (this.isOurs(local)) {
          continue;
        }
        if (this.mailState.taken[local]) {
          throw new AddressConflict(local, this.mailState.taken[local]);
        }
        if (this.mailState.destinations[local]) {
          throw new AddressConflict(local, "address_already_exists");
        }
        missing.push(local);
      }
      const created = [];
      try {
        for (const local of missing) {
          await this.task(this.mailModule, "add-address", {
            atype: "domain",
            domain: this.listDomain,
            local,
            destinations: [
              { dtype: "external", name: `${local}@${this.inboundDomain}` },
            ],
          });
          created.push(local);
        }
      } catch (err) {
        await this.removeAddresses(created, false);
        throw err;
      }
      return created;
    },
    // Remove only addresses that still forward to this instance
    async removeAddresses(locals, check = true) {
      if (check) {
        await this.loadMailState();
        if (!this.mailState) {
          return;
        }
      }
      for (const local of locals) {
        if (check && !this.isOurs(local)) {
          continue;
        }
        try {
          await this.task(this.mailModule, "remove-address", {
            atype: "domain",
            domain: this.listDomain,
            local,
          });
        } catch (err) {
          console.error(`cannot remove ${local}@${this.listDomain}`, err);
        }
      }
    },
    conflictMessage(err) {
      if (err instanceof AddressConflict) {
        return this.$t("lists.list_" + err.reason, {
          value: `${err.local}@${this.listDomain}`,
        });
      }
      return err.message;
    },
    async createRobotAddresses() {
      this.busy = "robot";
      this.error.action = "";
      try {
        await this.addAddresses(this.robotAddresses);
      } catch (err) {
        this.error.actionTitle = this.$t("lists.create_robot_addresses");
        this.error.action = this.conflictMessage(err);
      }
      this.busy = "";
      await this.loadMailState();
    },
    async createListAddresses(row) {
      this.busy = row.name;
      this.error.action = "";
      try {
        if (this.uiManaged) {
          await this.addAddresses(this.listLocalParts(row.name));
        } else {
          await this.task(
            this.instanceName,
            "create-list-addresses",
            { name: row.name },
            this.$t("lists.creating_addresses", { list: row.name })
          );
        }
      } catch (err) {
        this.error.actionTitle = this.$t("action.create-list-addresses");
        this.error.action = err.validation
          ? err.validation
              .map((e) => this.$t("lists." + e.error, { value: e.value }))
              .join(" ")
          : this.conflictMessage(err);
      }
      this.busy = "";
      await this.refresh();
    },
    showDestroy(row) {
      this.selected = row;
      this.error.destroyList = "";
      this.isDestroyShown = true;
    },
    showCreateModal() {
      this.clearErrors(this);
      this.form = {
        name: "",
        subject: "",
        type: "",
        owners: this.listmasters.length ? this.listmasters[0] : "",
        description: "",
      };
      this.typeKey++;
      this.$nextTick(() => {
        this.form.type = "discussion_list";
      });
      this.isCreateShown = true;
      this.$nextTick(() => this.focusElement("name"));
    },
    owners() {
      return this.form.owners
        .split(/[\s,;]+/)
        .map((addr) => addr.trim().toLowerCase())
        .filter((addr) => addr);
    },
    validateCreate() {
      this.clearErrors(this);
      let ok = true;
      const focus = (field) => {
        if (ok) {
          this.focusElement(field);
        }
        ok = false;
      };
      if (!this.form.name) {
        this.error.name = "common.required";
        focus("name");
      } else if (!/^[a-z0-9][a-z0-9._-]*$/.test(this.form.name)) {
        this.error.name = "lists.invalid_name";
        focus("name");
      }
      if (!this.form.subject) {
        this.error.subject = "common.required";
        focus("subject");
      }
      if (!this.form.type) {
        this.error.type = "common.required";
        focus("type");
      }
      const owners = this.owners();
      const badEmail = owners.find(
        (addr) => !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(addr)
      );
      if (!owners.length) {
        this.error.owners = "common.required";
        focus("owners");
      } else if (badEmail) {
        this.error.owners = "settings.invalid_email";
        this.errorValue = badEmail;
        focus("owners");
      }
      return ok;
    },
    async createList() {
      if (!this.validateCreate()) {
        return;
      }
      this.loading.createList = true;
      const name = this.form.name;
      let created = [];
      try {
        if (this.uiManaged) {
          // Addresses first: a refused name leaves nothing behind in Sympa
          created = await this.addAddresses(this.listLocalParts(name));
        }
        await this.task(
          this.instanceName,
          "create-list",
          {
            name,
            subject: this.form.subject,
            type: this.form.type,
            owners: this.owners(),
            description: this.form.description,
          },
          this.$t("lists.creating_list", { list: name })
        );
        this.isCreateShown = false;
      } catch (err) {
        if (created.length) {
          await this.removeAddresses(created, false);
        }
        if (err instanceof AddressConflict) {
          this.error.name = "lists.list_" + err.reason;
          this.errorValue = `${err.local}@${this.listDomain}`;
          this.focusElement("name");
        } else if (err.validation) {
          for (const e of err.validation) {
            this.error[e.parameter] = "lists." + e.error;
            this.errorValue = e.value;
            this.focusElement(e.parameter);
          }
        } else {
          this.error.createList = err.message;
        }
      }
      this.loading.createList = false;
      await this.refresh();
    },
    async destroyList() {
      this.loading.destroyList = true;
      this.error.destroyList = "";
      const name = this.selected.name;
      try {
        await this.task(
          this.instanceName,
          "destroy-list",
          { name },
          this.$t("lists.destroying_list", { list: name })
        );
        if (this.uiManaged) {
          await this.removeAddresses(this.listLocalParts(name));
        }
        this.isDestroyShown = false;
      } catch (err) {
        this.error.destroyList = err.message;
      }
      this.loading.destroyList = false;
      await this.refresh();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}
</style>

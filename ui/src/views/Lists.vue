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
    <cv-row v-if="loaded && !configured">
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
    <cv-row v-if="loaded && configured">
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
    <cv-row v-if="stateReady && missingRobot.length">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('lists.robot_addresses_missing')"
          :description="
            $t('lists.robot_addresses_missing_ui', {
              addresses: missingRobot.join(', '),
            })
          "
          :actionLabel="$t('lists.create_robot_addresses')"
          @action="createRobotAddresses"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="stateReady && orphans.length">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('lists.orphan_addresses')"
          :description="
            $t('lists.orphan_addresses_description', {
              addresses: orphans.join(', '),
            })
          "
          :actionLabel="$t('lists.remove_orphan_addresses')"
          @action="removeOrphans"
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
    <cv-row v-if="configured">
      <cv-column>
        <NsButton
          kind="secondary"
          :icon="Add20"
          :disabled="!stateReady || !!busy"
          @click="showCreateModal"
          class="mg-bottom"
          >{{ $t("lists.create_list") }}</NsButton
        >
        <NsButton
          kind="tertiary"
          :icon="Restart20"
          :disabled="loading.listLists || !!busy"
          :loading="loading.listLists"
          @click="refresh"
          class="mg-bottom mg-left"
          >{{ $t("lists.refresh") }}</NsButton
        >
      </cv-column>
    </cv-row>
    <cv-row v-if="configured">
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
import MailAddresses, { AddressConflict } from "@/mixins/mailAddresses";

export default {
  name: "Lists",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
    MailAddresses,
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
      configured: false,
      lists: [],
      listTypes: [],
      robotAddresses: [],
      listSuffixes: [],
      listDomain: "",
      host: "",
      inboundDomain: "",
      mailModule: "",
      listmasters: [],
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
    stateReady() {
      return this.loaded && this.configured && !!this.mailState;
    },
    missingRobot() {
      return this.robotAddresses.filter((local) => !this.isOurs(local));
    },
    // Addresses forwarding to this instance that no list or robot uses
    orphans() {
      if (!this.mailState) {
        return [];
      }
      const used = new Set(this.robotAddresses);
      for (const item of this.lists) {
        this.listLocalParts(item.name).forEach((local) => used.add(local));
      }
      return this.sympaAddresses(this.mailState, this.inboundDomain)
        .filter((local) => !used.has(local))
        .sort();
    },
    rows() {
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
    this.load();
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
    isOurs(local) {
      return this.forwardsTo(this.mailState, local, this.inboundDomain);
    },
    async load() {
      this.loading.listLists = true;
      this.error.listLists = "";
      try {
        const [config, output] = await Promise.all([
          this.moduleTask(this.instanceName, "get-configuration"),
          this.moduleTask(this.instanceName, "list-lists"),
        ]);
        this.listDomain = config.list_domain;
        this.host = config.host;
        this.inboundDomain = config.inbound_domain;
        this.listmasters = config.listmasters;
        const server = config.mail_servers.find(
          (s) => s.uuid === config.mail_server
        );
        this.mailModule = server ? server.module_id : "";
        this.setLists(output);
        this.loaded = true;
      } catch (err) {
        this.error.listLists = err.message;
      }
      this.loading.listLists = false;
      if (this.configured) {
        await this.loadMailState();
      }
    },
    setLists(output) {
      this.configured = output.configured && !!this.mailModule;
      this.lists = output.lists;
      this.listTypes = output.list_types;
      this.robotAddresses = output.robot_addresses;
      this.listSuffixes = output.list_suffixes;
    },
    // The configuration does not change on this page: read the lists only
    async refresh() {
      this.loading.listLists = true;
      this.error.listLists = "";
      const [output] = await Promise.all([
        this.moduleTask(this.instanceName, "list-lists").catch((err) => {
          this.error.listLists = err.message;
        }),
        this.configured ? this.loadMailState() : null,
      ]);
      if (output) {
        this.setLists(output);
      }
      this.loading.listLists = false;
    },
    async loadMailState() {
      this.error.mail = "";
      try {
        this.mailState = await this.readMailState(
          this.mailModule,
          this.listDomain
        );
      } catch (err) {
        this.mailState = null;
        this.error.mail = err.message;
      }
    },
    async runAddressAction(key, title, action) {
      this.busy = key;
      this.error.action = "";
      try {
        await action();
      } catch (err) {
        this.error.actionTitle = title;
        this.error.action = this.addressErrorMessage(err, this.listDomain);
      }
      this.busy = "";
      await this.loadMailState();
    },
    createRobotAddresses() {
      return this.runAddressAction(
        "robot",
        this.$t("lists.create_robot_addresses"),
        () =>
          this.declareAddresses(
            this.mailModule,
            this.listDomain,
            this.inboundDomain,
            this.robotAddresses
          )
      );
    },
    removeOrphans() {
      return this.runAddressAction(
        "orphans",
        this.$t("lists.remove_orphan_addresses"),
        () =>
          this.withdrawAddresses(
            this.mailModule,
            this.listDomain,
            this.inboundDomain,
            this.orphans
          )
      );
    },
    createListAddresses(row) {
      return this.runAddressAction(
        row.name,
        this.$t("lists.create_addresses"),
        () =>
          this.declareAddresses(
            this.mailModule,
            this.listDomain,
            this.inboundDomain,
            this.listLocalParts(row.name)
          )
      );
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
        owners: this.listmasters.join("\n"),
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
        // Addresses first: a refused name leaves nothing behind in Sympa
        created = await this.declareAddresses(
          this.mailModule,
          this.listDomain,
          this.inboundDomain,
          this.listLocalParts(name)
        );
        await this.moduleTask(
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
        let message = this.addressErrorMessage(err, this.listDomain);
        try {
          await this.dropAddresses(this.mailModule, this.listDomain, created);
        } catch (dropErr) {
          message += " " + dropErr.message;
        }
        if (err instanceof AddressConflict) {
          this.error.name = "lists.list_" + err.reason;
          this.errorValue = `${err.local}@${this.listDomain}`;
          this.focusElement("name");
        } else if (err.validation && err.action === "create-list") {
          for (const e of err.validation) {
            this.error[e.parameter] = "lists." + e.error;
            this.errorValue = e.value;
            this.focusElement(e.parameter);
          }
        } else {
          // The mail module errors have no field in this form
          this.error.createList = message;
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
        await this.moduleTask(
          this.instanceName,
          "destroy-list",
          { name },
          this.$t("lists.destroying_list", { list: name })
        );
        await this.withdrawAddresses(
          this.mailModule,
          this.listDomain,
          this.inboundDomain,
          this.listLocalParts(name)
        );
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
.mg-left {
  margin-left: $spacing-03;
}
</style>

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
    <cv-row v-if="loaded && mode === 'manual'">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('lists.manual_mode')"
          :description="$t('lists.manual_mode_description')"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="loaded && mode === 'auto' && !robotAddressesOk">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('lists.robot_addresses_missing')"
          :description="$t('lists.robot_addresses_missing_description')"
          :actionLabel="$t('status.configure')"
          @action="goToAppPage(instanceName, 'settings')"
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
          :disabled="loading.listLists"
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
            :allRows="lists"
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
                  <template v-else-if="mode === 'auto'">
                    <cv-tag kind="red" :label="$t('lists.addresses_missing')" />
                    <NsButton
                      kind="ghost"
                      size="small"
                      :loading="loading.addresses === row.name"
                      :disabled="!!loading.addresses"
                      @click="createListAddresses(row)"
                      >{{ $t("lists.create_addresses") }}</NsButton
                    >
                  </template>
                  <NsButton
                    v-else
                    kind="ghost"
                    size="small"
                    @click="showCommands(row)"
                    >{{ $t("lists.show_commands") }}</NsButton
                  >
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
                    <cv-overflow-menu-item danger @click="showDestroy(row)">
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
            v-if="mode === 'manual'"
            kind="info"
            :title="$t('lists.manual_create_note')"
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

    <!-- manual mode: addresses to declare -->
    <NsModal
      size="large"
      :visible="!!commandsFor"
      @modal-hidden="commandsFor = null"
    >
      <template slot="title">{{
        $t("lists.addresses_of", { list: commandsFor ? commandsFor.name : "" })
      }}</template>
      <template slot="content">
        <p class="mg-bottom">{{ $t("lists.commands_description") }}</p>
        <NsCodeSnippet
          :copyTooltip="core.$t('common.copy_to_clipboard')"
          :copyFeedback="core.$t('common.copied_to_clipboard')"
          :moreText="core.$t('common.show_more')"
          :lessText="core.$t('common.show_less')"
          light
          >{{ commandsText }}</NsCodeSnippet
        >
      </template>
      <template slot="secondary-button">{{ core.$t("common.close") }}</template>
    </NsModal>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

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
      robotAddressesOk: true,
      listDomain: "",
      host: "",
      inboundDomain: "",
      mailModule: "",
      tablePage: [],
      columns: ["name", "subject", "status", "subscribers", "addresses"],
      isCreateShown: false,
      isDestroyShown: false,
      selected: null,
      commandsFor: null,
      typeKey: 0,
      listmasters: [],
      errorValue: "",
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
        addresses: "",
      },
      error: {
        listLists: "",
        destroyList: "",
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
    commandsText() {
      if (!this.commandsFor) {
        return "";
      }
      return this.commandsFor.missing_addresses
        .map((local) => {
          const data = {
            atype: "domain",
            domain: this.listDomain,
            local,
            destinations: [
              { dtype: "external", name: `${local}@${this.inboundDomain}` },
            ],
          };
          return `api-cli run module/${
            this.mailModule
          }/add-address --data '${JSON.stringify(data)}'`;
        })
        .join("\n");
    },
  },
  created() {
    this.getConfiguration();
    this.listLists();
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
    showCommands(row) {
      this.commandsFor = row;
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
    // Run a module action and call back with its output
    runTask(taskAction, data, handlers) {
      const eventId = this.getUuid();
      this.core.$root.$once(`${taskAction}-aborted-${eventId}`, (result) =>
        handlers.aborted(result)
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        (ctx, result) => handlers.completed(result.output)
      );
      if (handlers.validationFailed) {
        this.core.$root.$once(
          `${taskAction}-validation-failed-${eventId}`,
          (errors) => handlers.validationFailed(errors)
        );
      }
      return to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data,
          extra: {
            title: handlers.title || this.$t("action." + taskAction),
            isNotificationHidden: !handlers.title,
            eventId,
          },
        })
      ).then(([err]) => {
        if (err) {
          console.error(`error creating task ${taskAction}`, err);
          handlers.aborted(null, this.getErrorMessage(err));
        }
      });
    },
    getConfiguration() {
      this.runTask(
        "get-configuration",
        {},
        {
          aborted: () => {},
          completed: (config) => {
            this.listDomain = config.list_domain;
            this.host = config.host;
            this.inboundDomain = config.inbound_domain;
            this.listmasters = config.listmasters;
            const server = config.mail_servers.find(
              (s) => s.uuid === config.mail_server
            );
            this.mailModule = server ? server.module_id : "mail1";
          },
        }
      );
    },
    listLists() {
      this.loading.listLists = true;
      this.error.listLists = "";
      this.runTask(
        "list-lists",
        {},
        {
          aborted: (result, message) => {
            this.error.listLists = message || this.$t("error.generic_error");
            this.loading.listLists = false;
          },
          completed: (output) => {
            this.mode = output.mode;
            this.lists = output.lists;
            this.listTypes = output.list_types;
            this.robotAddressesOk = output.robot_addresses_ok;
            this.loaded = true;
            this.loading.listLists = false;
          },
        }
      );
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
    createList() {
      if (!this.validateCreate()) {
        return;
      }
      this.loading.createList = true;
      this.runTask(
        "create-list",
        {
          name: this.form.name,
          subject: this.form.subject,
          type: this.form.type,
          owners: this.owners(),
          description: this.form.description,
        },
        {
          title: this.$t("lists.creating_list", { list: this.form.name }),
          aborted: (result, message) => {
            this.loading.createList = false;
            this.isCreateShown = false;
            this.error.actionTitle = this.$t("action.create-list");
            this.error.action = message || this.$t("error.generic_error");
          },
          validationFailed: (errors) => {
            this.loading.createList = false;
            for (const err of errors) {
              this.error[err.parameter] = "lists." + err.error;
              this.errorValue = err.value;
              this.focusElement(err.parameter);
            }
          },
          completed: () => {
            this.loading.createList = false;
            this.isCreateShown = false;
            this.listLists();
          },
        }
      );
    },
    destroyList() {
      this.loading.destroyList = true;
      this.error.destroyList = "";
      const name = this.selected.name;
      this.runTask(
        "destroy-list",
        { name },
        {
          title: this.$t("lists.destroying_list", { list: name }),
          aborted: (result, message) => {
            this.loading.destroyList = false;
            this.error.destroyList = message || this.$t("error.generic_error");
          },
          completed: () => {
            this.loading.destroyList = false;
            this.isDestroyShown = false;
            this.listLists();
          },
        }
      );
    },
    createListAddresses(row) {
      this.loading.addresses = row.name;
      this.error.action = "";
      this.runTask(
        "create-list-addresses",
        { name: row.name },
        {
          title: this.$t("lists.creating_addresses", { list: row.name }),
          aborted: (result, message) => {
            this.loading.addresses = "";
            this.error.actionTitle = this.$t("action.create-list-addresses");
            this.error.action = message || this.$t("error.generic_error");
          },
          validationFailed: (errors) => {
            this.loading.addresses = "";
            this.error.actionTitle = this.$t("action.create-list-addresses");
            this.error.action = errors
              .map((err) => this.$t("lists." + err.error, { value: err.value }))
              .join(" ");
          },
          completed: () => {
            this.loading.addresses = "";
            this.listLists();
          },
        }
      );
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

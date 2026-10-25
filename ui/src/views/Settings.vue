<!--
  Copyright (C) 2026 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="configLoaded && !smarthostEnabled">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('settings.smarthost_missing')"
          :description="$t('settings.smarthost_missing_description')"
          :actionLabel="$t('settings.go_to_smarthost')"
          @action="goTo('/settings/smarthost')"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="configLoaded && !mailServers.length">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('settings.mail_missing')"
          :description="$t('settings.mail_missing_description')"
          :actionLabel="$t('settings.go_to_software_center')"
          @action="goTo('/software-center')"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="savedHost && !hasRoute">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('settings.no_route')"
          :description="$t('settings.no_route_description')"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <NsTextInput
              :label="$t('settings.host')"
              placeholder="sympa.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="$t(error.host)"
              :helper-text="$t('settings.host_helper')"
              :disabled="stillLoading"
              ref="host"
            />
            <NsToggle
              value="letsEncrypt"
              :label="core.$t('apps_lets_encrypt.request_https_certificate')"
              v-model="isLetsEncryptEnabled"
              :disabled="stillLoading"
              class="mg-bottom"
            >
              <template #tooltip>
                <div class="mg-bottom-sm">
                  {{ core.$t("apps_lets_encrypt.lets_encrypt_tips") }}
                </div>
                <div class="mg-bottom-sm">
                  <cv-link @click="goTo('/settings/tls-certificates')">
                    {{ core.$t("apps_lets_encrypt.go_to_tls_certificates") }}
                  </cv-link>
                </div>
              </template>
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </NsToggle>
            <cv-row
              v-if="isLetsEncryptCurrentlyEnabled && !isLetsEncryptEnabled"
            >
              <cv-column>
                <NsInlineNotification
                  kind="warning"
                  :title="
                    core.$t('apps_lets_encrypt.lets_encrypt_disabled_warning')
                  "
                  :description="
                    core.$t(
                      'apps_lets_encrypt.lets_encrypt_disabled_warning_description',
                      {
                        node: status.node_ui_name
                          ? status.node_ui_name
                          : status.node,
                      }
                    )
                  "
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsComboBox
              :key="'mail-' + optionsKey"
              v-model="mailServer"
              :title="$t('settings.mail_server')"
              :label="$t('settings.choose_mail_server')"
              :options="mailServerOptions"
              :autoFilter="true"
              :autoHighlight="true"
              :invalid-message="$t(error.mail_server)"
              :helper-text="$t('settings.mail_server_helper')"
              :disabled="stillLoading"
              class="mg-bottom maxwidth"
              ref="mail_server"
            />
            <NsComboBox
              :key="'list-domain-' + optionsKey + '-' + mailServer"
              v-model="listDomain"
              :title="$t('settings.list_domain')"
              :label="$t('settings.choose_list_domain')"
              :options="listDomainOptions"
              :autoFilter="true"
              :autoHighlight="true"
              :invalid-message="$t(error.list_domain)"
              :helper-text="$t('settings.list_domain_helper')"
              :disabled="stillLoading || !mailServer"
              class="mg-bottom maxwidth"
              ref="list_domain"
            />
            <cv-row v-if="listDomainUsedBy">
              <cv-column>
                <NsInlineNotification
                  kind="warning"
                  :title="$t('settings.list_domain_already_used')"
                  :description="
                    $t('settings.list_domain_already_used_description', {
                      domain: listDomain,
                      instance: listDomainUsedBy,
                    })
                  "
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <cv-text-area
              :label="$t('settings.listmasters')"
              v-model="listmastersText"
              :placeholder="$t('settings.listmasters_placeholder')"
              :helper-text="$t('settings.listmasters_helper')"
              :invalid-message="$t(error.listmasters, { email: invalidEmail })"
              :disabled="stillLoading"
              class="mg-bottom maxwidth"
              ref="listmasters"
            />
            <NsComboBox
              :key="'domain-' + optionsKey"
              v-model="userDomain"
              :title="$t('settings.user_domain')"
              :label="$t('settings.choose_user_domain')"
              :options="userDomainOptions"
              :autoFilter="true"
              :autoHighlight="true"
              :invalid-message="$t(error.user_domain)"
              :helper-text="$t('settings.user_domain_helper')"
              :disabled="stillLoading"
              class="mg-bottom maxwidth"
              ref="user_domain"
            />
            <cv-row v-if="configLoaded && !userDomains.length">
              <cv-column>
                <NsInlineNotification
                  kind="info"
                  :title="$t('settings.no_user_domain')"
                  :description="$t('settings.no_user_domain_description')"
                  :actionLabel="$t('settings.go_to_domains')"
                  @action="goTo('/domains')"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsComboBox
              :key="'lang-' + optionsKey"
              v-model="defaultLang"
              :title="$t('settings.default_lang')"
              :label="$t('settings.choose_language')"
              :options="langOptions"
              :autoFilter="true"
              :autoHighlight="true"
              :invalid-message="$t(error.default_lang)"
              :disabled="stillLoading"
              class="mg-bottom maxwidth"
              ref="default_lang"
            />
            <cv-row v-if="moveError">
              <cv-column>
                <NsInlineNotification
                  kind="warning"
                  :title="$t('settings.addresses_not_moved')"
                  :description="moveError"
                  :actionLabel="$t('settings.go_to_lists')"
                  @action="goToAppPage(instanceName, 'lists')"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <cv-row v-if="validationErrorDetails.length">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="
                    core.$t('apps_lets_encrypt.cannot_obtain_certificate')
                  "
                  :showCloseButton="false"
                >
                  <template #description>
                    <div class="flex flex-col gap-2">
                      <div
                        v-for="(detail, index) in validationErrorDetails"
                        :key="index"
                      >
                        {{ detail }}
                      </div>
                    </div>
                  </template>
                </NsInlineNotification>
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="stillLoading"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
    <cv-row v-if="saved.mailModule && saved.listDomain">
      <cv-column>
        <cv-accordion class="mg-bottom">
          <cv-accordion-item>
            <template slot="title">{{
              $t("settings.before_removing")
            }}</template>
            <template slot="content">
              <p class="mg-bottom">
                {{
                  $t("settings.before_removing_description", {
                    mail: saved.mailModule,
                  })
                }}
              </p>
              <NsInlineNotification
                v-if="cleanupDone"
                kind="success"
                :title="$t('settings.addresses_removed')"
                :description="
                  $t('settings.addresses_removed_description', {
                    count: cleanupDone,
                    mail: saved.mailModule,
                  })
                "
                @close="cleanupDone = 0"
              />
              <NsInlineNotification
                v-if="cleanupError"
                kind="error"
                :title="$t('settings.remove_all_addresses')"
                :description="cleanupError"
                :showCloseButton="false"
              />
              <NsButton
                kind="danger"
                :icon="TrashCan20"
                :disabled="stillLoading || !cleanupAddresses.length"
                @click="showCleanup"
                >{{ $t("settings.remove_all_addresses") }}</NsButton
              <p
                v-if="cleanupLoaded && !cleanupAddresses.length"
                class="mg-top"
              >
                {{ $t("settings.no_address_to_remove") }}
              </p>
              >
            </template>
          </cv-accordion-item>
        </cv-accordion>
      </cv-column>
    </cv-row>
    <NsDangerDeleteModal
      :isShown="isCleanupShown"
      :name="instanceName"
      :title="$t('settings.remove_all_addresses')"
      :warning="core.$t('common.please_read_carefully')"
      :description="
        $t('settings.remove_all_addresses_description', {
          count: cleanupAddresses.length,
          mail: saved.mailModule,
          addresses: cleanupAddresses.join(', '),
        })
      "
      :typeToConfirm="core.$t('common.type_to_confirm', { name: instanceName })"
      :loading="loading.cleanup"
      @hide="isCleanupShown = false"
      @confirmDelete="removeAllAddresses"
    />
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
import MailAddresses from "@/mixins/mailAddresses";

// Languages shipped with Sympa 6.2
const LANGS = {
  "en-US": "English",
  fr: "Français",
  it: "Italiano",
  de: "Deutsch",
  es: "Español",
  pt: "Português",
  "pt-BR": "Português (Brasil)",
  eu: "Euskara",
};

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
    MailAddresses,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      status: {},
      validationErrorDetails: [],
      urlCheckInterval: null,
      configLoaded: false,
      host: "",
      savedHost: "",
      hasRoute: true,
      isLetsEncryptEnabled: false,
      isLetsEncryptCurrentlyEnabled: false,
      listDomain: "",
      listmastersText: "",
      // Empty until the configuration loads, or the combo box shows the raw value
      mailServer: "",
      userDomain: "",
      defaultLang: "",
      mailServers: [],
      userDomains: [],
      smarthostEnabled: true,
      domainsInUse: {},
      // Saved mail server and list domain, to move the addresses after a change
      saved: { mailModule: "", listDomain: "", inbound: "" },
      moveError: "",
      isCleanupShown: false,
      cleanupAddresses: [],
      cleanupError: "",
      cleanupDone: 0,
      cleanupLoaded: false,
      optionsKey: 0,
      invalidEmail: "",
      loading: {
        getConfiguration: false,
        configureModule: false,
        getStatus: false,
        cleanup: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        getStatus: "",
        host: "",
        lets_encrypt: "",
        list_domain: "",
        listmasters: "",
        mail_server: "",
        user_domain: "",
        default_lang: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    stillLoading() {
      return (
        this.loading.getConfiguration ||
        this.loading.configureModule ||
        this.loading.getStatus
      );
    },
    mailServerOptions() {
      return this.mailServers.map((server) => ({
        name: server.uuid,
        label: server.ui_name
          ? `${server.ui_name} (${server.module_id})`
          : server.module_id,
        value: server.uuid,
      }));
    },
    userDomainOptions() {
      return [
        { name: "-", label: this.$t("settings.no_ldap_login"), value: "-" },
      ].concat(
        this.userDomains.map((domain) => ({
          name: domain,
          label: domain,
          value: domain,
        }))
      );
    },
    listDomainOptions() {
      const server = this.mailServers.find((s) => s.uuid === this.mailServer);
      // Like ns8-piler: the label tells which domains another instance serves
      return (server ? server.domains : []).map((domain) => {
        const label = this.domainsInUse[domain]
          ? this.$t("settings.domain_used_by", {
              domain,
              instance: this.domainsInUse[domain],
            })
          : domain;
        return { name: domain, label, value: domain };
      });
    },
    listDomainUsedBy() {
      return this.domainsInUse[this.listDomain] || "";
    },
    langOptions() {
      return Object.entries(LANGS).map(([value, label]) => ({
        name: value,
        label,
        value,
      }));
    },
  },
  watch: {
    mailServer() {
      // A domain of another mail server cannot be kept
      if (
        this.listDomain &&
        !this.listDomainOptions.some((opt) => opt.value === this.listDomain)
      ) {
        this.listDomain = "";
      }
    },
  },
  created() {
    this.getConfiguration();
    this.getStatus();
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
    goTo(path) {
      this.core.$router.push(path);
    },
    async getStatus() {
      this.loading.getStatus = true;
      this.error.getStatus = "";
      const taskAction = "get-status";
      const eventId = this.getUuid();
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getStatusAborted
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getStatusCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getStatus = this.getErrorMessage(err);
        this.loading.getStatus = false;
      }
    },
    getStatusAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getStatus = this.$t("error.generic_error");
      this.loading.getStatus = false;
    },
    getStatusCompleted(taskContext, taskResult) {
      this.status = taskResult.output;
      this.loading.getStatus = false;
    },
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.mailServers = config.mail_servers;
      this.userDomains = config.user_domains;
      this.smarthostEnabled = config.smarthost_enabled;
      this.domainsInUse = config.domains_in_use || {};
      const savedServer = config.mail_servers.find(
        (s) => s.uuid === config.mail_server
      );
      this.saved = {
        mailModule: savedServer ? savedServer.module_id : "",
        listDomain: config.list_domain,
        inbound: config.inbound_domain,
      };
      this.loadCleanupAddresses();
      this.host = config.host;
      this.savedHost = config.host;
      this.hasRoute = config.has_route;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isLetsEncryptCurrentlyEnabled = config.lets_encrypt;
      this.listmastersText = config.listmasters.join("\n");
      // A combo box shows the raw value if it is created with one: clear it, recreate, then set
      this.mailServer = "";
      this.listDomain = "";
      this.userDomain = "";
      this.defaultLang = "";
      this.optionsKey++;
      this.$nextTick(() => {
        this.mailServer =
          config.mail_server ||
          (this.mailServers.length === 1 ? this.mailServers[0].uuid : "");
        // Set after the mail server, or its watcher clears the domain
        this.$nextTick(() => {
          this.listDomain = config.list_domain;
        });
        this.userDomain = config.host ? config.user_domain || "-" : "";
        this.defaultLang = config.default_lang || "en-US";
      });
      this.configLoaded = true;
      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    listmasters() {
      return this.listmastersText
        .split(/[\s,;]+/)
        .map((addr) => addr.trim().toLowerCase())
        .filter((addr) => addr);
    },
    validateConfigureModule() {
      this.clearErrors(this);
      this.validationErrorDetails = [];
      const required = [
        ["host", this.host],
        ["mail_server", this.mailServer],
        ["list_domain", this.listDomain],
        ["listmasters", this.listmasters().length],
      ];
      let isValidationOk = true;
      for (const [field, value] of required) {
        if (!value) {
          this.error[field] = "common.required";
          if (isValidationOk) {
            this.focusElement(field);
          }
          isValidationOk = false;
        }
      }
      if (this.listDomainUsedBy) {
        this.error.list_domain =
          "settings.list_domain_used_by_another_instance";
        if (isValidationOk) {
          this.focusElement("list_domain");
        }
        isValidationOk = false;
      }
      const emailRe = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
      const badEmail = this.listmasters().find((addr) => !emailRe.test(addr));
      if (badEmail) {
        this.error.listmasters = "settings.invalid_email";
        this.invalidEmail = badEmail;
        if (isValidationOk) {
          this.focusElement("listmasters");
        }
        isValidationOk = false;
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;
      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        if (validationError.details) {
          this.validationErrorDetails = validationError.details
            .split("\n")
            .filter((detail) => detail.trim() !== "");
        } else {
          this.error[param] = "settings." + validationError.error;
          if (!focusAlreadySet) {
            this.focusElement(param);
            focusAlreadySet = true;
          }
        }
      }
    },
    async configureModule() {
      if (!this.validateConfigureModule()) {
        return;
      }
      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            list_domain: this.listDomain,
            listmasters: this.listmasters(),
            mail_server: this.mailServer,
            user_domain: this.userDomain === "-" ? "" : this.userDomain,
            default_lang: this.defaultLang || "en-US",
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    async configureModuleCompleted() {
      const before = this.saved;
      const server = this.mailServers.find((s) => s.uuid === this.mailServer);
      const after = {
        mailModule: server ? server.module_id : "",
        listDomain: this.listDomain,
      };
      if (
        before.mailModule &&
        before.listDomain &&
        (before.mailModule !== after.mailModule ||
          before.listDomain !== after.listDomain)
      ) {
        await this.moveAddresses(before, after);
      }
      this.loading.configureModule = false;
      this.getConfiguration();
    },
    // The module cannot remove its addresses when the instance is removed
    async loadCleanupAddresses() {
      this.cleanupLoaded = false;
      if (!this.saved.mailModule || !this.saved.listDomain) {
        this.cleanupAddresses = [];
        return;
      }
      try {
        const state = await this.readMailState(
          this.saved.mailModule,
          this.saved.listDomain
        );
        this.cleanupAddresses = this.sympaAddresses(
          state,
          this.saved.inbound
        ).sort();
        this.cleanupLoaded = true;
      } catch (err) {
        this.cleanupAddresses = [];
        this.cleanupError = err.message;
      }
    },
    async showCleanup() {
      this.cleanupError = "";
      this.cleanupDone = 0;
      // Read again: the Lists page may have changed the addresses
      await this.loadCleanupAddresses();
      if (this.cleanupAddresses.length) {
        this.isCleanupShown = true;
      }
    },
    async removeAllAddresses() {
      this.loading.cleanup = true;
      try {
        await this.withdrawAddresses(
          this.saved.mailModule,
          this.saved.listDomain,
          this.saved.inbound,
          this.cleanupAddresses
        );
        this.cleanupDone = this.cleanupAddresses.length;
        this.isCleanupShown = false;
        await this.loadCleanupAddresses();
      } catch (err) {
        this.cleanupError = err.message;
      }
      this.loading.cleanup = false;
    },
    // The module cannot move its addresses: copy them, then remove the old ones
    async moveAddresses(before, after) {
      this.moveError = "";
      try {
        const state = await this.readMailState(
          before.mailModule,
          before.listDomain
        );
        const locals = this.sympaAddresses(state, before.inbound);
        await this.declareAddresses(
          after.mailModule,
          after.listDomain,
          before.inbound,
          locals
        );
        await this.dropAddresses(before.mailModule, before.listDomain, locals);
      } catch (err) {
        this.moveError = this.addressErrorMessage(err, after.listDomain);
      }
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.mg-top {
  margin-top: $spacing-05;
}

.maxwidth {
  max-width: 38rem;
}
</style>

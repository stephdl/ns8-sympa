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
            <NsTextInput
              :label="$t('settings.list_domain')"
              placeholder="example.org"
              v-model.trim="listDomain"
              class="mg-bottom"
              :invalid-message="$t(error.list_domain)"
              :helper-text="$t('settings.list_domain_helper')"
              :disabled="stillLoading"
              ref="list_domain"
            />
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
    <cv-row v-if="savedListDomain && inboundDomain">
      <cv-column>
        <cv-tile light>
          <h4 class="mg-bottom-md">{{ $t("settings.addresses_title") }}</h4>
          <NsInlineNotification
            kind="info"
            :title="$t('settings.addresses_info')"
            :description="
              $t('settings.addresses_description', {
                domain: savedListDomain,
                inbound: inboundDomain,
              })
            "
            :showCloseButton="false"
          />
          <h6 class="mg-bottom-sm">{{ $t("settings.robot_addresses") }}</h6>
          <NsCodeSnippet
            class="mg-bottom"
            :copyTooltip="core.$t('common.copy_to_clipboard')"
            :copyFeedback="core.$t('common.copied_to_clipboard')"
            :moreText="core.$t('common.show_more')"
            :lessText="core.$t('common.show_less')"
            light
            >{{ addressCommands(robotLocalParts) }}</NsCodeSnippet
          >
          <NsTextInput
            :label="$t('settings.list_name')"
            placeholder="mylist"
            v-model.trim="listName"
            :helper-text="$t('settings.list_name_helper')"
            class="mg-bottom maxwidth"
          />
          <template v-if="validListName">
            <h6 class="mg-bottom-sm">
              {{ $t("settings.list_addresses", { list: listName }) }}
            </h6>
            <NsCodeSnippet
              :copyTooltip="core.$t('common.copy_to_clipboard')"
              :copyFeedback="core.$t('common.copied_to_clipboard')"
              :moreText="core.$t('common.show_more')"
              :lessText="core.$t('common.show_less')"
              light
              >{{ addressCommands(listLocalParts) }}</NsCodeSnippet
            >
          </template>
        </cv-tile>
      </cv-column>
    </cv-row>
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

// Robot addresses, from /etc/sympa/aliases.sympa.postfix of the EPEL package
const ROBOT_LOCAL_PARTS = [
  "sympa",
  "sympa-request",
  "sympa-owner",
  "listmaster",
  "bounce",
  "abuse-feedback-report",
];

// Addresses of one list, from Sympa default/list_aliases.tt2
const LIST_SUFFIXES = ["", "-request", "-editor", "-unsubscribe", "-owner"];

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
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
      savedListDomain: "",
      listmastersText: "",
      // Empty until the configuration loads, or the combo box shows the raw value
      mailServer: "",
      userDomain: "",
      defaultLang: "",
      inboundDomain: "",
      mailServers: [],
      userDomains: [],
      smarthostEnabled: true,
      optionsKey: 0,
      listName: "",
      invalidEmail: "",
      loading: {
        getConfiguration: false,
        configureModule: false,
        getStatus: false,
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
    langOptions() {
      return Object.entries(LANGS).map(([value, label]) => ({
        name: value,
        label,
        value,
      }));
    },
    selectedMailModule() {
      const server = this.mailServers.find((s) => s.uuid === this.mailServer);
      return server ? server.module_id : "mail1";
    },
    validListName() {
      return /^[a-z0-9][a-z0-9._-]*$/.test(this.listName);
    },
    robotLocalParts() {
      return ROBOT_LOCAL_PARTS;
    },
    listLocalParts() {
      return LIST_SUFFIXES.map((suffix) => this.listName + suffix);
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
    addressCommands(localParts) {
      return localParts
        .map((local) => {
          const data = {
            atype: "domain",
            domain: this.savedListDomain,
            local,
            destinations: [
              { dtype: "external", name: `${local}@${this.inboundDomain}` },
            ],
          };
          return `api-cli run module/${
            this.selectedMailModule
          }/add-address --data '${JSON.stringify(data)}'`;
        })
        .join("\n");
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
      this.host = config.host;
      this.savedHost = config.host;
      this.hasRoute = config.has_route;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isLetsEncryptCurrentlyEnabled = config.lets_encrypt;
      this.listDomain = config.list_domain;
      this.savedListDomain = config.list_domain;
      this.listmastersText = config.listmasters.join("\n");
      this.inboundDomain = config.inbound_domain;
      // New options need a fresh combo box, then the value is set
      this.optionsKey++;
      this.$nextTick(() => {
        this.mailServer =
          config.mail_server ||
          (this.mailServers.length === 1 ? this.mailServers[0].uuid : "");
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
    configureModuleCompleted() {
      this.loading.configureModule = false;
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.maxwidth {
  max-width: 38rem;
}
</style>

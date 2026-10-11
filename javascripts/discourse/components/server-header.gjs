import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { CHANNELS_PANEL, DMS_PANEL } from "../lib/constants";

// Discourse AI's panel, which it shows on its conversation pages.
const AI_PANEL = "ai-conversations";
import { serverMenuItems } from "../lib/server-menu";
import ActionMenu from "./action-menu";

// The bar above Discord's channel list: the server's name, opening the
// site-wide pages core's header used to link to, the switch to the user's DMs
// (Discord's Home), and where you make channels that don't belong to a
// section.
export default class ServerHeader extends Component {
  @service currentUser;
  @service menu;
  @service siteSettings;
  @service sidebarState;

  // What's waiting in the review queue, which the server menu leads to.
  get reviewCount() {
    return this.currentUser?.can_review ? this.currentUser.reviewable_count : 0;
  }

  // Discourse AI's own header button is out of sight in this layout, so this
  // stands in for it, under the same conditions.
  get showAiConversations() {
    const models = this.currentUser?.ai_available_llm_models;
    if (
      !settings.ai_conversations_link ||
      !this.siteSettings.ai_bot_enabled ||
      !models
    ) {
      return false;
    }

    return (this.currentUser.ai_enabled_agents || []).some(
      (agent) =>
        agent.allow_personal_messages &&
        (agent.has_default_llm || models.length)
    );
  }

  get aiConversationsActive() {
    return this.sidebarState.currentPanelKey === AI_PANEL;
  }

  // A toggle, like the DM button: out of the conversations goes back to the
  // last forum page, as Discourse AI's own button does.
  get aiConversationsHref() {
    if (this.aiConversationsActive) {
      return (
        getOwner(this).lookup("service:ai-conversations-sidebar-manager")
          ?.lastKnownAppURL || "/"
      );
    }
    return "/discourse-ai/ai-bot/conversations";
  }

  get show() {
    return (
      this.args.always ||
      [CHANNELS_PANEL, DMS_PANEL, AI_PANEL].includes(
        this.sidebarState.currentPanelKey
      )
    );
  }

  @action
  toggleDirectMessages() {
    this.args.directMessages.toggle();
  }

  @action
  openMenu(event) {
    this.menu.show(event.currentTarget, {
      identifier: "discord-server-menu",
      component: ActionMenu,
      data: { items: serverMenuItems(getOwner(this)) },
      placement: "bottom-start",
      modalForMobile: true,
    });
  }

  <template>
    {{#if this.show}}
      <div class="discord-server-header">
        <button
          class="discord-server-header__name btn-transparent"
          type="button"
          {{on "click" this.openMenu}}
        >
          <span class="discord-server-header__title">
            {{this.siteSettings.title}}
          </span>
          {{#if this.reviewCount}}
            <span
              class="discord-server-header__review-badge"
              title={{i18n "review.title"}}
            >{{this.reviewCount}}</span>
          {{/if}}
          {{dIcon "angle-down"}}
        </button>

        {{#if this.showAiConversations}}
          <DButton
            @href={{this.aiConversationsHref}}
            @icon="far-discobot"
            @translatedTitle={{i18n (themePrefix "ai_conversations")}}
            aria-pressed={{if this.aiConversationsActive "true" "false"}}
            class={{dConcatClass
              "btn-flat discord-server-header__ai"
              (if this.aiConversationsActive "--active")
            }}
          />
        {{/if}}

        {{#if @directMessages.available}}
          <DButton
            @action={{this.toggleDirectMessages}}
            @icon="far-comments"
            @translatedTitle={{i18n (themePrefix "direct_messages.title")}}
            aria-pressed={{if @directMessages.active "true" "false"}}
            class={{dConcatClass
              "btn-flat discord-server-header__dms"
              (if @directMessages.active "--active")
            }}
          >
            {{#if @directMessages.unreadCount}}
              <span
                class="discord-server-header__dms-badge"
              >{{@directMessages.unreadCount}}</span>
            {{/if}}
          </DButton>
        {{/if}}

        {{#if @canCreate}}
          <DButton
            @action={{fn @onCreate null}}
            @icon="plus"
            @title={{themePrefix "create_channel.action"}}
            class="btn-flat discord-server-header__create"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}

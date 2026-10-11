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

  get show() {
    return (
      this.args.always ||
      [CHANNELS_PANEL, DMS_PANEL].includes(this.sidebarState.currentPanelKey)
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

        {{#if @directMessages.available}}
          <DButton
            @action={{this.toggleDirectMessages}}
            @icon="comments"
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

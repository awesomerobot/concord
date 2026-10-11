import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { CHANNELS_PANEL } from "../lib/constants";
import { serverMenuItems } from "../lib/server-menu";
import ActionMenu from "./action-menu";

// The bar above Discord's channel list: the server's name, opening the
// site-wide pages core's header used to link to, and where you make channels
// that don't belong to a section.
export default class ServerHeader extends Component {
  @service menu;
  @service siteSettings;
  @service sidebarState;

  get show() {
    return (
      this.args.always || this.sidebarState.currentPanelKey === CHANNELS_PANEL
    );
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
          {{dIcon "angle-down"}}
        </button>

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

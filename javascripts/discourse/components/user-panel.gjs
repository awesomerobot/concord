import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import Notifications from "discourse/components/header/user-dropdown/notifications";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import UserMenuPopover from "./user-menu-popover";

// Discord's panel at the foot of the channel list: who you are, with your
// notifications behind the avatar.
export default class UserPanel extends Component {
  @service currentUser;
  @service menu;
  @service siteSettings;

  get name() {
    return this.siteSettings.prioritize_full_name_in_ux
      ? this.currentUser.name || this.currentUser.username
      : this.currentUser.username;
  }

  get subtitle() {
    return this.currentUser.status?.description || this.currentUser.username;
  }

  @action
  openUserMenu(event) {
    this.menu.show(event.currentTarget, {
      identifier: "discord-user-menu",
      component: UserMenuPopover,
      placement: "top-start",
      modalForMobile: true,
    });
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  @action
  showSignup() {
    getOwner(this).lookup("route:application").send("showCreateAccount");
  }

  <template>
    <div class="discord-user-panel">
      {{#if this.currentUser}}
        <button
          class="discord-user-panel__me btn-transparent"
          title={{i18n "user.avatar.header_title"}}
          type="button"
          {{on "click" this.openUserMenu}}
        >
          <span class="discord-user-panel__avatar">
            <Notifications />
          </span>
          <span class="discord-user-panel__names">
            <span class="discord-user-panel__name">{{this.name}}</span>
            <span class="discord-user-panel__subtitle">{{this.subtitle}}</span>
          </span>
        </button>
        <DButton
          @href="/my/preferences"
          @icon="gear"
          @title="user.preferences.title"
          class="btn-flat discord-user-panel__settings"
        />
      {{else}}
        <DButton
          @action={{this.showLogin}}
          @label="log_in"
          class="btn-primary discord-user-panel__login"
        />
        <DButton
          @action={{this.showSignup}}
          @label="sign_up"
          class="btn-default discord-user-panel__signup"
        />
      {{/if}}
    </div>
  </template>
}

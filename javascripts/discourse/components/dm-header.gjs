import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// Laid out like Discourse AI's conversations sidebar: a way back, then a
// button to start something new.
export default class DmHeader extends Component {
  @service router;

  @action
  back() {
    this.args.directMessages.show(false);
  }

  @action
  newMessage() {
    this.router.transitionTo("chat.new-message");
  }

  <template>
    {{#if @directMessages.active}}
      <div class="discord-dm-header">
        <button
          type="button"
          class="sidebar-sections__back-to-forum discord-dm-header__back"
          {{on "click" this.back}}
        >
          {{dIcon "arrow-left"}}
          <span>{{i18n (themePrefix "back_to_channels")}}</span>
        </button>
        <DButton
          @action={{this.newMessage}}
          @icon="plus"
          @translatedLabel={{i18n (themePrefix "direct_messages.new")}}
          @translatedTitle={{i18n "sidebar.start_new_dm.title"}}
          class="btn-default discord-dm-header__new"
        />
      </div>
    {{/if}}
  </template>
}

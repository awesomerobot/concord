import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { CHANNELS_PANEL } from "../lib/constants";

// The bar above Discord's channel list: the server's name, and where you make
// channels that don't belong to a section.
export default class ServerHeader extends Component {
  @service siteSettings;
  @service sidebarState;

  get show() {
    return (
      this.args.always || this.sidebarState.currentPanelKey === CHANNELS_PANEL
    );
  }

  <template>
    {{#if this.show}}
      <div class="discord-server-header">
        <span class="discord-server-header__name">
          {{this.siteSettings.title}}
        </span>

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

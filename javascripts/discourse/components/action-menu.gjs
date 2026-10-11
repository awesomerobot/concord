import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

// Renders the items from ChannelActions. Closes before running the item, since
// most open a modal or dialog of their own. An item with `items` swaps the
// menu for those, with a way back, rather than opening a second menu beside
// it, which phones (where the menu is a sheet) have no room for.
export default class ActionMenu extends Component {
  @tracked submenu = null;

  get items() {
    return this.submenu?.items || this.args.data.items;
  }

  @action
  run(item) {
    if (item.items) {
      this.submenu = item;
      return;
    }

    this.args.close();
    item.action();
  }

  @action
  back() {
    this.submenu = null;
  }

  <template>
    <DDropdownMenu class="discord-action-menu" as |dropdown|>
      {{#if this.submenu}}
        <dropdown.item>
          <DButton
            @action={{this.back}}
            @icon="angle-left"
            @translatedLabel={{this.submenu.label}}
            class="btn-transparent discord-action-menu__back"
          />
        </dropdown.item>
        <dropdown.divider />
      {{/if}}

      {{#each this.items as |item|}}
        {{#if item.heading}}
          <dropdown.divider />
          <dropdown.subheader>{{item.heading}}</dropdown.subheader>
        {{else if item.divider}}
          <dropdown.divider />
        {{else}}
          <dropdown.item>
            <DButton
              @action={{fn this.run item}}
              @icon={{if item.checked "check" item.icon}}
              @translatedLabel={{item.label}}
              class={{dConcatClass
                "btn-transparent"
                (if item.danger "--danger")
                (if item.checked "--checked")
                (unless (or item.icon item.checked) "--no-icon")
              }}
              data-item-id={{item.id}}
            >
              {{#if item.badge}}
                <span class="discord-action-menu__badge">{{item.badge}}</span>
              {{/if}}
              {{#if item.items}}
                <span class="discord-action-menu__more">
                  {{dIcon "angle-right"}}
                </span>
              {{/if}}
            </DButton>
          </dropdown.item>
        {{/if}}
      {{/each}}
    </DDropdownMenu>
  </template>
}

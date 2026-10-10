import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

// Renders the items from ChannelActions. Closes before running the item, since
// most open a modal or dialog of their own.
export default class ActionMenu extends Component {
  @action
  run(item) {
    this.args.close();
    item.action();
  }

  <template>
    <DDropdownMenu class="discord-action-menu" as |dropdown|>
      {{#each @data.items as |item|}}
        {{#if item.heading}}
          <dropdown.divider />
          <dropdown.subheader>{{item.heading}}</dropdown.subheader>
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
            />
          </dropdown.item>
        {{/if}}
      {{/each}}
    </DDropdownMenu>
  </template>
}

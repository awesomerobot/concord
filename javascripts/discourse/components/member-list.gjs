import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { not } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { CHANNELS_PANEL, DMS_PANEL } from "../lib/constants";

// Discord's member list, down the right of the page, or sliding in from the
// right on small screens.
export default class MemberList extends Component {
  @service sidebarState;
  @service siteSettings;

  get show() {
    return (
      this.args.memberList.active &&
      [CHANNELS_PANEL, DMS_PANEL].includes(this.sidebarState.currentPanelKey)
    );
  }

  @action
  close() {
    this.args.memberList.slideOpen = false;
  }

  get onlineIds() {
    return new Set(this.args.memberList.onlineUsers.map((user) => user.id));
  }

  sectionTitle = (section) =>
    ["online", "offline"].includes(section.title)
      ? i18n(themePrefix(`member_list.${section.title}`))
      : section.title;

  displayName = (user) =>
    (this.siteSettings.prioritize_full_name_in_ux && user.name) ||
    user.username;

  isOnline = (user) => this.onlineIds.has(user.id);

  <template>
    {{! Always there, so core's user cards can listen for clicks on it. }}
    <div class="discord-member-list-host">
      {{#if this.show}}
        {{#if @memberList.compact}}
          <div
            class="discord-member-list__cloak"
            role="presentation"
            {{on "click" this.close}}
          ></div>
        {{else}}
          {{bodyClass "discord-member-list-open"}}
        {{/if}}
        <aside
          aria-label={{i18n (themePrefix "member_list.title")}}
          class={{dConcatClass
            "discord-member-list"
            (if @memberList.compact "--slide-in")
          }}
        >
          <DLoadMore
            @action={{@memberList.pager.loadMore}}
            @enabled={{not @memberList.pager.done}}
            @isLoading={{@memberList.pager.loading}}
          >
            {{#each @memberList.sections key="id" as |listSection|}}
              <section
                class="discord-member-list__section"
                data-section-id={{listSection.id}}
              >
                <h2 class="discord-member-list__heading">
                  {{#if listSection.icon}}{{dIcon listSection.icon}}{{/if}}
                  {{this.sectionTitle listSection}}
                  —
                  {{listSection.users.length}}
                </h2>

                {{#each listSection.users key="id" as |user|}}
                  <div
                    class={{dConcatClass
                      "discord-member-list__member"
                      (unless (this.isOnline user) "--offline")
                    }}
                    data-username={{user.username}}
                  >
                    <span class="discord-member-list__avatar">
                      <DUserAvatar @size="small" @user={{user}} />
                      {{#if (this.isOnline user)}}
                        <span class="discord-member-list__presence"></span>
                      {{/if}}
                    </span>
                    <a
                      class="discord-member-list__name"
                      data-user-card={{user.username}}
                      href="/u/{{user.username}}"
                    >{{this.displayName user}}</a>
                  </div>
                {{/each}}
              </section>
            {{/each}}
          </DLoadMore>
        </aside>
      {{/if}}
    </div>
  </template>
}

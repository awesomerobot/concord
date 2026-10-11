import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Notifications from "discourse/components/header/user-dropdown/notifications";
import bodyClass from "discourse/helpers/body-class";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import SearchPopover from "./search-popover";
import ServerHeader from "./server-header";

const t = (key) => i18n(themePrefix(`channel_header.${key}`));

/**
 * Discord's top row: the server's name over the channel list, then the
 * current channel's name, description and actions. Rendered inside core's
 * header so everything that sizes itself to the header keeps working.
 */
export default class ChannelHeader extends Component {
  @service appEvents;
  @service currentUser;
  @service menu;
  @service router;
  @service search;
  @service site;

  // Core's header owns the slide-in channel list and everything around it
  // (animation, scroll lock, closing on a tap outside), so ask it to toggle.
  @action
  toggleChannelList() {
    this.appEvents.trigger("header:keyboard-trigger", { type: "hamburger" });
  }

  // On small screens, core's user menu slides in from the right, as it does
  // from core's own header.
  @action
  toggleUserMenu() {
    this.appEvents.trigger("header:keyboard-trigger", { type: "user" });
  }

  // In a text channel this is chat's message search, which chat keeps behind
  // its own (hidden) bar's button; that button is missing when chat search is
  // off, and then it's site search like anywhere else.
  @action
  openSearch(event) {
    const chatFilter = document.querySelector(
      ".c-routes.--channel .c-navbar__filter"
    );
    if (this.args.currentChannel.value?.type === "text" && chatFilter) {
      chatFilter.click();
      return;
    }

    // Phones get core's full page search, as from core's own header.
    if (this.site.mobileView) {
      if (this.router.currentRouteName === "full-page-search") {
        document.querySelector(".full-page-search")?.focus();
        return;
      }

      const context = this.search.searchContext;
      DiscourseURL.routeTo(
        context
          ? `/search?context=${context.type}&context_id=${context.id}&skip_context=true`
          : "/search"
      );
      return;
    }

    this.menu.show(event.currentTarget, {
      identifier: "discord-search",
      component: SearchPopover,
      placement: "bottom-end",
      // The panel's own width rules; the menu's default cap is narrower.
      maxWidth: "none",
      modalForMobile: true,
    });
  }

  get channel() {
    const current = this.args.currentChannel.value;
    let channel;

    switch (current?.type) {
      case "text":
        channel = this.#textChannel(current.channel);
        break;
      case "topic":
        channel = this.#topic(current.topic);
        break;
      case "voice":
        channel = this.#voiceRoom(current.room);
        break;
      case "forum":
        channel = this.#forum(current.category);
        break;
      case "tag":
        channel = { icon: "tag", name: current.tag.name };
        break;
      case "page":
        channel = current;
        break;
    }

    return { actions: [], ...channel };
  }

  get memberListAction() {
    return {
      id: "member-list",
      icon: "users",
      title: t("member_list"),
      active: this.args.memberList.active,
      action: () => this.args.memberList.toggle(),
    };
  }

  #textChannel(channel) {
    if (!channel) {
      return;
    }

    const models = channel.routeModels;
    const go = (route) => () => this.router.transitionTo(route, ...models);

    return {
      icon: "hashtag",
      name: channel.title,
      description: channel.description,
      actions: [
        channel.threadingEnabled && {
          id: "threads",
          icon: "discourse-threads",
          title: t("threads"),
          action: go("chat.channel.threads"),
        },
        {
          id: "pins",
          icon: "thumbtack",
          title: t("pins"),
          action: go("chat.channel.pins"),
        },
        {
          id: "settings",
          icon: "gear",
          title: t("settings"),
          action: go("chat.channel.info.settings"),
        },
      ].filter(Boolean),
    };
  }

  // The topic list's own controls already offer a new topic. Settings sit
  // here like a text channel's, rather than in the list's controls.
  #forum(category) {
    return {
      icon: "fab-discourse",
      name: category.displayName,
      description: category.description_text,
      actions: [
        category.can_edit && {
          id: "settings",
          icon: "gear",
          title: t("settings"),
          action: () =>
            DiscourseURL.routeTo(`/c/${Category.slugFor(category)}/edit`),
        },
      ].filter(Boolean),
    };
  }

  // A topic is a post in a forum channel: its title leads, with the
  // category it's in underneath.
  #topic(topic) {
    if (!topic) {
      return;
    }

    return {
      icon: "fab-discourse",
      name: topic.title,
      description: topic.category?.displayName,
    };
  }

  #voiceRoom(room) {
    if (!room) {
      return;
    }

    return {
      icon: "volume-high",
      name: room.name,
      description: room.description_excerpt,
    };
  }

  <template>
    {{! Core's header contents make way while this is shown. }}
    {{bodyClass "discord-header"}}
    <div class="discord-channel-header">
      <ServerHeader
        @always={{true}}
        @canCreate={{@canCreate}}
        @onCreate={{@onCreate}}
      />

      <div class="discord-channel-header__channel">
        {{! "hamburger-dropdown" makes core's close-on-click-outside leave
            this button to toggle the panel itself. }}
        <DButton
          @action={{this.toggleChannelList}}
          @icon="bars"
          @title="sidebar.title"
          class="btn-flat discord-channel-header__menu hamburger-dropdown"
        />
        {{#if this.channel.name}}
          <span class="discord-channel-header__icon">
            {{dIcon this.channel.icon}}
          </span>
          <h1 class="discord-channel-header__name">{{this.channel.name}}</h1>
          {{#if this.channel.description}}
            <span class="discord-channel-header__description">
              {{this.channel.description}}
            </span>
          {{/if}}
        {{/if}}

        <div class="discord-channel-header__actions">
          {{#each this.channel.actions as |action|}}
            <DButton
              @action={{action.action}}
              @icon={{action.icon}}
              @translatedTitle={{action.title}}
              class="btn-flat"
              data-action-id={{action.id}}
            />
          {{/each}}
          <DButton
            @action={{this.memberListAction.action}}
            @icon={{this.memberListAction.icon}}
            @translatedTitle={{this.memberListAction.title}}
            aria-pressed={{if this.memberListAction.active "true" "false"}}
            class={{dConcatClass
              "btn-flat"
              (if this.memberListAction.active "--active")
            }}
            data-action-id={{this.memberListAction.id}}
          />

          <DButton
            @icon="magnifying-glass"
            @title="search.title"
            class="btn-flat discord-channel-header__search"
            {{on "click" this.openSearch}}
          />

          {{#if this.currentUser}}
            {{! "user-menu-panel" makes core's close-on-click-outside leave
                this button to toggle the menu itself. }}
            <button
              class="btn-transparent discord-channel-header__user user-menu-panel"
              title={{i18n "user.avatar.header_title"}}
              type="button"
              {{on "click" this.toggleUserMenu}}
            >
              <Notifications />
            </button>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}

import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import SearchMenu from "discourse/components/search-menu";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ServerHeader from "./server-header";

const t = (key) => i18n(themePrefix(`channel_header.${key}`));

/**
 * Discord's top row: the server's name over the channel list, then the
 * current channel's name, description and actions. Rendered inside core's
 * header so everything that sizes itself to the header keeps working.
 */
export default class ChannelHeader extends Component {
  @service discovery;
  @service router;

  get chat() {
    return getOwner(this).lookup("service:chat");
  }

  get voiceRooms() {
    return getOwner(this).lookup("service:voice-rooms");
  }

  get routeName() {
    return this.router.currentRouteName || "";
  }

  get channel() {
    const name = this.routeName;

    if (name.startsWith("chat.channel")) {
      return this.#textChannel(this.chat?.activeChannel);
    }

    if (name.startsWith("topic.")) {
      return this.#topic(this.#routeAttributes("topic"));
    }

    if (name === "voice-room") {
      const slug = this.router.currentRoute.params.slug;
      return this.#voiceRoom(this.voiceRooms?.roomBySlug(slug));
    }

    if (this.discovery.category) {
      return this.#forum(this.discovery.category);
    }

    if (this.discovery.tag) {
      return { icon: "tag", name: this.discovery.tag.name };
    }
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
          id: "members",
          icon: "users",
          title: t("members"),
          action: go("chat.channel.info.members"),
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

  // The topic list's own controls already offer a new topic.
  #forum(category) {
    return {
      icon: "far-comments",
      name: category.displayName,
      description: category.description_text,
    };
  }

  // A topic is a post in a forum channel: its title leads, with the
  // category it's in underneath.
  #topic(topic) {
    if (!topic) {
      return;
    }

    return {
      icon: "far-comments",
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

  #routeAttributes(routeName) {
    let route = this.router.currentRoute;

    while (route) {
      if (route.name === routeName) {
        return route.attributes;
      }
      route = route.parent;
    }
  }

  <template>
    <div class="discord-channel-header">
      <ServerHeader
        @always={{true}}
        @canCreate={{@canCreate}}
        @onCreate={{@onCreate}}
      />

      <div class="discord-channel-header__channel">
        {{#if this.channel}}
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

          <div class="discord-channel-header__search search-menu">
            <SearchMenu
              @location="header"
              @searchInputId="discord-search-input"
            />
          </div>
        </div>
      </div>
    </div>
  </template>
}

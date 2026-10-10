import { setOwner } from "@ember/owner";
import { service } from "@ember/service";

/**
 * Works out which channel the current page belongs to, for everything that
 * changes with it (the header row, the member list).
 *
 * @returns {{ type: "text", channel } | { type: "voice", room } |
 *   { type: "forum", category } | { type: "topic", topic } |
 *   { type: "tag", tag } | undefined}
 */
export default class CurrentChannel {
  @service discovery;
  @service router;

  constructor(owner) {
    setOwner(this, owner);
    this.chat = owner.lookup("service:chat");
    this.voiceRooms = owner.lookup("service:voice-rooms");
  }

  get value() {
    const name = this.router.currentRouteName || "";

    if (name.startsWith("chat.channel")) {
      const channel = this.chat?.activeChannel;
      return channel && { type: "text", channel };
    }

    if (name.startsWith("topic.")) {
      const topic = this.#routeAttributes("topic");
      return topic && { type: "topic", topic };
    }

    if (name === "voice-room") {
      const room = this.voiceRooms?.roomBySlug(
        this.router.currentRoute.params.slug
      );
      return room && { type: "voice", room };
    }

    if (this.discovery.category) {
      return { type: "forum", category: this.discovery.category };
    }

    if (this.discovery.tag) {
      return { type: "tag", tag: this.discovery.tag };
    }
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
}

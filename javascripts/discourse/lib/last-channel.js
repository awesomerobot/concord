import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";

const STORAGE_KEY = "discord-last-channel";

/**
 * Reopens the channel someone was last in when they come back to the site's
 * address, as Discord does. Only a fresh load of the homepage itself is
 * redirected: a link to any other page goes where it says, and the home link
 * inside the app still goes home.
 *
 * Kept per user in local storage, so people sharing a browser don't get each
 * other's channels. A topic counts as being in its category's channel.
 */
export default class LastChannel {
  constructor(owner, currentChannel, user) {
    this.router = owner.lookup("service:router");
    this.chatApi = owner.lookup("service:chat-api");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.currentChannel = currentChannel;
    this.key = `${STORAGE_KEY}:${user.id}`;
  }

  install() {
    let first = true;

    this.router.on("routeWillChange", (transition) => {
      if (first) {
        first = false;
        this.#reopen(transition);
      }
    });
    this.router.on("routeDidChange", () => this.#remember());
  }

  async #reopen(transition) {
    if (transition.from || !isHomepageAddress()) {
      return;
    }

    const saved = this.#read();
    if (!saved?.url) {
      return;
    }

    // Held while a chat channel is checked, so one that's gone doesn't end
    // up on chat's "not found" error instead of the homepage.
    const held = saved.type === "text";
    if (held) {
      transition.abort();
    }

    if (!(await this.#exists(saved))) {
      this.#forget();
      if (held) {
        transition.retry();
      }
      return;
    }

    // Starting another transition aborts the homepage's, so it's never drawn
    // or left in the history.
    this.router.replaceWith(saved.url);
  }

  async #exists({ type, id }) {
    if (type === "forum") {
      return !!Category.findById(id);
    }

    if (type === "text") {
      try {
        const { channel } = await this.chatApi.channel(id);
        this.chatChannelsManager.store(channel);
      } catch {
        return false;
      }
    }

    return true;
  }

  #remember() {
    const saved = this.#channel();
    if (saved) {
      try {
        localStorage.setItem(this.key, JSON.stringify(saved));
      } catch {
        // Storage is unavailable, so there's nothing to come back to.
      }
    }
  }

  #channel() {
    const current = this.currentChannel.value;
    const path = (this.router.currentURL || "").split(/[?#]/)[0];

    switch (current?.type) {
      case "text": {
        const { channel } = current;
        return {
          type: "text",
          id: channel.id,
          url: `/chat/c/${channel.slugifiedTitle}/${channel.id}`,
        };
      }
      case "forum":
        return categoryChannel(current.category);
      case "topic":
        return (
          !current.topic.isPrivateMessage &&
          categoryChannel(current.topic.category)
        );
      case "tag":
      case "voice":
        return { type: current.type, url: path };
    }
  }

  #read() {
    try {
      return JSON.parse(localStorage.getItem(this.key));
    } catch {
      return null;
    }
  }

  #forget() {
    try {
      localStorage.removeItem(this.key);
    } catch {
      // Nothing was stored.
    }
  }
}

function categoryChannel(category) {
  return category && { type: "forum", id: category.id, url: category.path };
}

function isHomepageAddress() {
  const trim = (path) => path.replace(/\/+$/, "");
  return (
    trim(window.location.pathname) === trim(getURL("/")) &&
    !window.location.search
  );
}

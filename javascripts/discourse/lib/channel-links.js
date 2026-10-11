import { trustHTML } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import CategorySectionLink from "discourse/lib/sidebar/user/categories-section/category-section-link";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";
import { channelKey } from "./sidebar-sections";

// Every link is prefixed by its kind, since a category, a tag and a chat
// channel can share a slug and section links are keyed by name.

function channelClasses(kind, unread) {
  const classes = ["discord-channel", `discord-channel--${kind}`];

  if (unread) {
    classes.push("discord-channel--unread");
  }

  return classes.join(" ");
}

// A category is a forum channel. Counts and routing come from core's link, only
// the prefix changes, so it reads as a channel type rather than a category.
export class ForumChannelLink extends CategorySectionLink {
  keywords = { navigation: [] };

  get channelKey() {
    return channelKey("forum", this.category.id);
  }

  get name() {
    return `forum-${super.name}`;
  }

  get classNames() {
    return channelClasses("forum", !!this.activeCountable);
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return "far-comments";
  }

  get prefixColor() {
    return null;
  }
}

export class TagChannelLink extends TagSectionLink {
  keywords = { navigation: [] };

  get channelKey() {
    return channelKey("tag", this.tag.id);
  }

  get name() {
    return `tag-${super.name}`;
  }

  get classNames() {
    return channelClasses("tag", this.totalUnread > 0 || this.totalNew > 0);
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return "tag";
  }

  get prefixColor() {
    return null;
  }
}

// A chat channel is a text channel. Chat's own sidebar link lives inside its
// initializer and can't be imported, so this is a lean version of it.
export class TextChannelLink {
  route = "chat.channel";
  prefixType = "icon";
  prefixValue = "hashtag";
  suffixType = "icon";
  suffixCSSClass = "unread";
  keywords = { navigation: [] };

  constructor({ channel }) {
    this.channel = channel;
  }

  get channelKey() {
    return channelKey("text", this.channel.id);
  }

  get name() {
    return `text-${this.channel.slugifiedTitle}`;
  }

  get classNames() {
    const { tracking } = this.channel;
    const classes = [
      channelClasses(
        "text",
        tracking.unreadCount > 0 || tracking.watchedThreadsUnreadCount > 0
      ),
      `channel-${this.channel.id}`,
    ];

    if (this.channel.currentUserMembership?.muted) {
      classes.push("sidebar-section-link--muted");
    }

    return classes.join(" ");
  }

  get models() {
    return this.channel.routeModels;
  }

  get text() {
    return trustHTML(emojiUnescape(this.channel.escapedTitle));
  }

  get title() {
    return this.channel.escapedDescription
      ? trustHTML(this.channel.escapedDescription)
      : this.channel.escapedTitle;
  }

  get prefixBadge() {
    return this.channel.chatable?.read_restricted ? "lock" : null;
  }

  // Mentions get a count, like Discord's red pill; anything else unread just
  // gets the dot.
  get badgeText() {
    const mentions = this.channel.tracking.mentionCount;
    return mentions > 0 ? mentions.toString() : null;
  }

  get suffixValue() {
    const { tracking } = this.channel;

    if (tracking.mentionCount > 0) {
      return;
    }

    if (tracking.unreadCount > 0 || tracking.watchedThreadsUnreadCount > 0) {
      return "circle";
    }
  }
}

// A voice room is a voice channel. Named the way the voice plugin names its
// own sidebar links, so its document-level click handler joins the room.
export class VoiceChannelLink {
  href = "#";
  prefixType = "icon";
  prefixValue = "volume-high";
  keywords = { navigation: [] };

  constructor({ room, voiceWebrtc }) {
    this.room = room;
    this.voiceWebrtc = voiceWebrtc;
  }

  get channelKey() {
    return channelKey("voice", this.room.id);
  }

  get name() {
    return `voice-room-${this.room.id}`;
  }

  get text() {
    return this.room.name;
  }

  get title() {
    return this.room.description_excerpt || this.room.name;
  }

  get classNames() {
    const classes = ["discord-channel", "discord-channel--voice"];
    const state = this.voiceWebrtc?.connectionStateFor(this.room.id);

    if (state === "connected") {
      classes.push("sidebar-section-link--active");
    } else if (state === "connecting") {
      classes.push("discord-channel--connecting");
    }

    return classes.join(" ");
  }

  get prefixBadge() {
    return this.room.public ? null : "lock";
  }

  // Who's in the room, until the list shows their avatars underneath.
  get badgeText() {
    const count = this.room.active_participants?.length;
    return count > 0 ? count.toString() : null;
  }
}

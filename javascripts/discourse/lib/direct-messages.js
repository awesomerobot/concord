import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { DirectMessageLink } from "./channel-links";
import { DMS_PANEL } from "./constants";
import dmMode from "./dm-mode";

// Where the page belongs to the server rather than to someone's DMs.
const SERVER_CHANNEL_TYPES = ["text", "forum", "topic", "voice", "tag"];
const DM_ROUTES = ["chat.new-message", "chat.direct-messages"];

/**
 * Discord's Home: the user's direct messages, shown in the sidebar instead of
 * the server's channels. Opening a DM switches to it, and going to any of the
 * server's channels switches back; the DM button beside the server name
 * switches by hand.
 */
export default class DirectMessages {
  @service router;
  @service sidebarState;

  #links = new Map();

  constructor(owner, currentChannel, channelActions) {
    setOwner(this, owner);
    this.currentChannel = currentChannel;
    this.channelActions = channelActions;
    this.chat = owner.lookup("service:chat");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.router.on("routeDidChange", this.follow);
  }

  /** Whether the DM panel exists, which is whenever chat can hold DMs. */
  get supported() {
    return !!this.chat && !!this.chat.currentUser;
  }

  /** Whether to offer the DM list: the user can DM, or has been DMed. */
  get available() {
    return this.supported && !!this.chat.userCanAccessDirectMessages;
  }

  // Only while the DMs are what's showing: another panel, like Discourse AI's
  // conversations, can stand in for them without ending DM mode.
  get active() {
    return dmMode.active && this.sidebarState.currentPanelKey === DMS_PANEL;
  }

  get channels() {
    return this.chatChannelsManager?.directMessageChannels || [];
  }

  linkNamed(name) {
    return this.links.find((link) => link.name === name);
  }

  get links() {
    return this.channels.map((channel) => {
      if (!this.#links.has(channel.id)) {
        this.#links.set(
          channel.id,
          this.channelActions.decorate(new DirectMessageLink({ channel }))
        );
      }
      return this.#links.get(channel.id);
    });
  }

  get unreadCount() {
    return this.channels.reduce(
      (count, channel) => count + channel.tracking.unreadCount,
      0
    );
  }

  toggle() {
    this.show(!this.active);
  }

  show(active) {
    dmMode.active = active;
    this.sidebarState.setPanel(dmMode.panel);
  }

  @bind
  follow() {
    if (!this.available) {
      return;
    }

    const name = this.router.currentRouteName || "";
    let active;

    if (DM_ROUTES.includes(name)) {
      active = true;
    } else if (name.startsWith("chat.channel") && this.chat?.activeChannel) {
      active = this.chat.activeChannel.isDirectMessageChannel;
    } else if (SERVER_CHANNEL_TYPES.includes(this.currentChannel.value?.type)) {
      active = false;
    }

    if (active !== undefined && active !== dmMode.active) {
      this.show(active);
    }
  }
}

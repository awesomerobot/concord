import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { channelKey } from "./sidebar-groups";

// Members fetched per group for a private voice channel. Voice rooms only know
// individual members, and each one is a request.
const VOICE_MEMBER_LIMIT = 200;

/**
 * Creates each kind of channel through the endpoint that backs it, and knows
 * what each kind needs to be private.
 *
 * - Forum: a category, restricted to the groups.
 * - Text: a chat channel. Chat channels take their access from a category, so
 *   each one gets its own backing category, kept under one container category.
 * - Voice: a voice room. Rooms have members rather than groups, so the groups'
 *   current members are added.
 */
export default class ChannelCreator {
  @service currentUser;
  @service site;
  @service siteSettings;

  constructor(owner) {
    setOwner(this, owner);

    this.chat = owner.lookup("service:chat");
    this.chatApi = owner.lookup("service:chat-api");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.voiceRooms = owner.lookup("service:voice-rooms");
  }

  get canCreateForum() {
    return !!this.currentUser?.can_create_category;
  }

  get canCreateText() {
    return (
      !!this.chatApi &&
      this.currentUser?.staff &&
      this.chat?.userCanChat &&
      this.siteSettings.enable_public_channels &&
      this.canCreateForum
    );
  }

  get canCreateVoice() {
    return (
      !!this.voiceRooms &&
      this.siteSettings.voice_enabled &&
      this.voiceRooms.canCreateRoom
    );
  }

  get types() {
    return [
      this.canCreateText && "text",
      this.canCreateVoice && "voice",
      this.canCreateForum && "forum",
    ].filter(Boolean);
  }

  get groups() {
    return this.site.groups.filter((group) => group.id !== 0);
  }

  /**
   * @param {object} data
   * @param {"text"|"voice"|"forum"} data.type
   * @param {string} data.name
   * @param {boolean} data.isPrivate
   * @param {number[]} data.groupIds
   * @returns {Promise<{ key: string, route: string, models: Array, notice?: string }>}
   *   The new channel's key, and where to go once it's made.
   */
  async create({ type, name, isPrivate, groupIds }) {
    const groups = isPrivate ? groupIds : [];

    switch (type) {
      case "forum":
        return this.#createForum(name, groups);
      case "text":
        return this.#createText(name, groups);
      case "voice":
        return this.#createVoice(name, isPrivate, groups);
    }
  }

  async #createForum(name, groupIds) {
    const category = await this.#createCategory({
      name,
      permissions: this.#permissions(groupIds),
    });

    return {
      key: channelKey("forum", category.id),
      route: "discovery.category",
      models: [`${Category.slugFor(category)}/${category.id}`],
    };
  }

  async #createText(name, groupIds) {
    const container = await this.#chatContainer();
    const category = await this.#createCategory({
      name,
      parent_category_id: container.id,
      permissions: this.#permissions(groupIds),
    });

    // Auto-join puts the channel in everyone's list who can see it, the way
    // every Discord member sees every channel they have access to.
    const channel = await this.chatApi.createChannel({
      name,
      chatable_id: category.id,
      auto_join_users: true,
    });
    this.chatChannelsManager.follow(channel);

    return {
      key: channelKey("text", channel.id),
      route: "chat.channel",
      models: channel.routeModels,
    };
  }

  async #createVoice(name, isPrivate, groupIds) {
    const { room } = await ajax("/voice/rooms", {
      type: "POST",
      data: { room: { name, public: !isPrivate } },
    });

    let notice;

    if (isPrivate) {
      const { userIds, capped } = await this.#groupMemberIds(groupIds);

      for (const userId of userIds) {
        if (userId !== this.currentUser.id) {
          await ajax(`/voice/rooms/${room.id}/memberships`, {
            type: "POST",
            data: { user_id: userId },
          });
        }
      }

      if (capped) {
        notice = i18n(themePrefix("create_channel.voice_members_capped"), {
          count: VOICE_MEMBER_LIMIT,
        });
      }
    }

    this.voiceRooms.handleDirectoryEvent({ type: "created", room });

    return {
      key: channelKey("voice", room.id),
      route: "voice-room",
      models: [room.slug],
      notice,
    };
  }

  async #createCategory(attributes) {
    const color = this.#randomColor();
    const result = await ajax("/categories", {
      type: "POST",
      data: { color, text_color: "FFFFFF", ...attributes },
    });

    return this.site.updateCategory(result.category);
  }

  // Found by slug so the theme needn't store anything. It stays open to
  // everyone: a parent restricted to some groups would refuse children for
  // any other group.
  async #chatContainer() {
    const slug = settings.chat_container_category;
    const existing = Category.findSingleBySlug(slug);

    if (existing) {
      return existing;
    }

    return this.#createCategory({
      name: i18n(themePrefix("create_channel.container_name")),
      slug,
    });
  }

  // Category permissions are keyed by group name; 1 is full access.
  #permissions(groupIds) {
    if (!groupIds.length) {
      return undefined;
    }

    const permissions = {};

    for (const group of this.site.groups) {
      if (groupIds.includes(group.id)) {
        permissions[group.name] = 1;
      }
    }

    return permissions;
  }

  async #groupMemberIds(groupIds) {
    const userIds = new Set();
    let capped = false;

    for (const group of this.site.groups) {
      if (!groupIds.includes(group.id)) {
        continue;
      }

      const { members, meta } = await ajax(
        `/groups/${group.name}/members.json`,
        { data: { limit: VOICE_MEMBER_LIMIT } }
      );

      members.forEach((member) => userIds.add(member.id));
      capped ||= meta.total > members.length;
    }

    if (userIds.size > VOICE_MEMBER_LIMIT) {
      capped = true;
    }

    return {
      userIds: [...userIds].slice(0, VOICE_MEMBER_LIMIT),
      capped,
    };
  }

  #randomColor() {
    const colors = this.siteSettings.category_colors?.split("|") || [];
    return colors[Math.floor(Math.random() * colors.length)] || "0088CC";
  }
}

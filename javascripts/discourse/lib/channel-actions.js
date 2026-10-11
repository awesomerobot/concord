import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import ActionMenu from "../components/action-menu";
import RenameModal from "../components/modal/rename";

const CATEGORY_LEVELS = { muted: 0, regular: 1, watching: 3 };

const t = (key, opts) => i18n(themePrefix(`channel_menu.${key}`), opts);

/**
 * What the inline menus on headings and channels offer. Each kind of channel
 * is backed by something different, so most items differ by kind, and each
 * shows only when the user may do it.
 *
 * An item is `{ label, icon, action, checked?, danger? }`, `{ heading }` to
 * label the items after it, or `{ divider: true }`.
 */
export default class ChannelActions {
  @service currentUser;
  @service dialog;
  @service menu;
  @service modal;
  @service router;
  @service toasts;

  constructor(owner, sidebarSections) {
    setOwner(this, owner);
    this.sidebarSections = sidebarSections;
    this.chatApi = owner.lookup("service:chat-api");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.voiceRooms = owner.lookup("service:voice-rooms");
  }

  /** Puts the `…` button on a channel row. */
  decorate(link) {
    if (!this.currentUser) {
      return link;
    }

    link.hoverType = "icon";
    link.hoverValue = "ellipsis";
    link.hoverTitle = t("title");
    link.hoverAction = (event, onClose) => {
      event.preventDefault();
      event.stopPropagation();
      this.#show(event, this.channelItems(link), onClose);
    };

    return link;
  }

  /** The `…` button on a section heading. */
  sectionAction(index) {
    if (!this.sidebarSections.canEdit) {
      return;
    }

    return {
      id: "sectionMenu",
      icon: "ellipsis",
      title: t("section_title"),
      action: (event) => this.#show(event, this.sectionItems(index)),
    };
  }

  sectionItems(index) {
    const sections = this.sidebarSections;
    const section = sections.sections[index];

    return [
      {
        label: t("rename_section"),
        icon: "pencil",
        action: () =>
          this.#rename(t("rename_section"), section.name, (name) =>
            sections.renameSection(index, name)
          ),
      },
      index > 0 && {
        label: t("move_up"),
        icon: "arrow-up",
        action: () => this.#run(() => sections.moveSection(index, -1)),
      },
      index < sections.sections.length - 1 && {
        label: t("move_down"),
        icon: "arrow-down",
        action: () => this.#run(() => sections.moveSection(index, 1)),
      },
      {
        label: t("delete_section"),
        icon: "trash-can",
        danger: true,
        action: () =>
          this.dialog.deleteConfirm({
            message: t("delete_section_confirm", { name: section.name }),
            didConfirm: () => this.#run(() => sections.deleteSection(index)),
          }),
      },
    ].filter(Boolean);
  }

  // Everyday actions first, then notifications, the section, and deleting last
  // on its own.
  channelItems(link) {
    const [type] = link.channelKey.split(":");
    const sections =
      {
        forum: () => this.#forumItems(link.category),
        text: () => this.#textItems(link.channel),
        voice: () => this.#voiceItems(link.room),
      }[type]?.() || {};

    return [
      sections.markRead,
      sections.rename,
      {
        label: t("copy_link"),
        icon: "link",
        action: () => this.#copyLink(link),
      },
      ...(sections.notifications || []),
      ...this.#moveItems(link.channelKey),
      sections.delete && { divider: true },
      sections.delete,
    ].filter(Boolean);
  }

  #forumItems(category) {
    const level = category.notification_level;
    const items = {
      markRead: {
        label: t("mark_read"),
        icon: "eye",
        action: () => this.#run(() => this.#dismissCategory(category)),
      },
      notifications: [
        { heading: t("notifications") },
        ...[
          ["watching", "all_posts"],
          ["regular", "default"],
          ["muted", "mute"],
        ].map(([name, label]) => ({
          label: t(label),
          checked: level === CATEGORY_LEVELS[name],
          action: () =>
            this.#run(() => category.setNotification(CATEGORY_LEVELS[name])),
        })),
      ],
    };

    if (category.can_edit) {
      items.rename = {
        label: t("rename"),
        icon: "pencil",
        action: () =>
          this.#rename(t("rename"), category.name, (name) =>
            ajax(`/categories/${category.id}`, {
              type: "PUT",
              data: { name },
            }).then(() => category.set("name", name))
          ),
      };
      items.delete = {
        label: t("delete"),
        icon: "trash-can",
        danger: true,
        action: () =>
          this.#confirmDelete(category.name, async () => {
            await ajax(`/categories/${category.id}`, { type: "DELETE" });
            await this.sidebarSections.removeChannel(`forum:${category.id}`);
            this.#goHomeIfOn(category.url);
          }),
      };
    }

    return items;
  }

  #textItems(channel) {
    const membership = channel.currentUserMembership;
    const items = {
      markRead: {
        label: t("mark_read"),
        icon: "eye",
        action: () =>
          this.#run(() => this.chatApi.markChannelAsRead(channel.id)),
      },
      notifications: [
        { heading: t("notifications") },
        ...[
          ["always", "all_messages"],
          ["mention", "mentions_only"],
          ["never", "nothing"],
        ].map(([level, label]) => ({
          label: t(label),
          checked:
            !membership?.muted && membership?.notificationLevel === level,
          action: () =>
            this.#updateChatSettings(channel, {
              muted: false,
              notification_level: level,
            }),
        })),
        {
          label: t("mute"),
          checked: !!membership?.muted,
          action: () =>
            this.#updateChatSettings(channel, { muted: !membership?.muted }),
        },
      ],
    };

    if (this.currentUser.staff) {
      items.rename = {
        label: t("rename"),
        icon: "pencil",
        action: () =>
          this.#rename(t("rename"), channel.title, (name) =>
            this.chatApi
              .updateChannel(channel.id, { name })
              .then(() => (channel.title = name))
          ),
      };
      items.delete = {
        label: t("delete"),
        icon: "trash-can",
        danger: true,
        action: () =>
          this.#confirmDelete(channel.title, async () => {
            await this.chatApi.destroyChannel(channel.id);
            this.chatChannelsManager.remove(channel);
            await this.sidebarSections.removeChannel(`text:${channel.id}`);
            this.router.transitionTo("discovery.latest");
          }),
      };
    }

    return items;
  }

  #voiceItems(room) {
    if (!room.can_manage) {
      return {};
    }

    return {
      rename: {
        label: t("rename"),
        icon: "pencil",
        action: () =>
          this.#rename(t("rename"), room.name, (name) =>
            ajax(`/voice/rooms/${room.id}`, {
              type: "PUT",
              data: { room: { name } },
            }).then((result) => this.voiceRooms.upsertRoom(result.room))
          ),
      },
      delete: {
        label: t("delete"),
        icon: "trash-can",
        danger: true,
        action: () =>
          this.#confirmDelete(room.name, async () => {
            await ajax(`/voice/rooms/${room.id}`, { type: "DELETE" });
            this.voiceRooms.handleDirectoryEvent({ type: "destroyed", room });
            await this.sidebarSections.removeChannel(`voice:${room.id}`);
          }),
      },
    };
  }

  #moveItems(key) {
    const sections = this.sidebarSections;

    if (!sections.canEdit) {
      return [];
    }

    const current = sections.sectionIndexOf(key);

    return [
      { heading: t("move_to_section") },
      ...sections.sections.map((section, index) => ({
        label: section.name,
        checked: index === current,
        action: () =>
          this.#run(() => sections.moveChannel(key, section.name)),
      })),
      {
        label: t("no_section"),
        checked: current === -1,
        action: () => this.#run(() => sections.moveChannel(key, null)),
      },
      // Moving into a section that doesn't exist yet creates it.
      {
        label: t("new_section"),
        icon: "plus",
        action: () =>
          this.#rename(
            t("new_section"),
            "",
            (name) => sections.moveChannel(key, name),
            t("create_section")
          ),
      },
    ];
  }

  #show(event, items, onClose) {
    this.menu.show(event.target.closest("a, button") || event.target, {
      identifier: "discord-channel-menu",
      component: ActionMenu,
      data: { items },
      placement: "right-start",
      modalForMobile: true,
      onClose,
    });
  }

  #copyLink(link) {
    const href = link.href && link.href !== "#" ? link.href : null;
    const url =
      href ||
      (link.route === "voice-room" || link.room
        ? this.router.urlFor("voice-room", link.room.slug)
        : this.router.urlFor(
            link.route,
            ...(link.models || (link.model ? [link.model] : []))
          ));

    clipboardCopy(new URL(url, window.location.origin).href);
    this.toasts.success({
      duration: "short",
      data: { message: t("link_copied") },
    });
  }

  // New topics and unread posts both, whichever "new" the user has set up.
  async #dismissCategory(category) {
    await ajax("/topics/reset-new", {
      type: "PUT",
      data: {
        category_id: category.id,
        dismiss_topics: true,
        dismiss_posts: true,
      },
    });
    await ajax("/topics/bulk", {
      type: "PUT",
      data: {
        filter: "unread",
        category_id: category.id,
        operation: { type: "dismiss_posts" },
      },
    });
  }

  #updateChatSettings(channel, settings) {
    return this.#run(async () => {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          channel.id,
          settings
        );
      const membership = channel.currentUserMembership;
      membership.muted = result.membership.muted;
      membership.notificationLevel = result.membership.notification_level;
    });
  }

  #rename(title, value, save, submitLabel) {
    this.modal.show(RenameModal, {
      model: { title, value, save, submitLabel },
    });
  }

  #confirmDelete(name, destroy) {
    this.dialog.deleteConfirm({
      message: t("delete_confirm", { name }),
      didConfirm: () => this.#run(destroy),
    });
  }

  #goHomeIfOn(url) {
    if (this.router.currentURL?.startsWith(url)) {
      this.router.transitionTo("discovery.latest");
    }
  }

  async #run(fn) {
    try {
      await fn();
    } catch (error) {
      popupAjaxError(error);
    }
  }
}

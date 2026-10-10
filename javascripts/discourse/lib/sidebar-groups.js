import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

// Theme code isn't told its own id, but its translation prefix carries it.
const THEME_ID = themePrefix("").split(".")[1];

export function channelKey(type, id) {
  return `${type}:${id}`;
}

/**
 * The headings the channel list is grouped under, like Discord's channel
 * categories, and which channels sit under each.
 *
 * They're stored in the `sidebar_groups` theme setting. Theme settings aren't
 * reactive, so this keeps its own tracked copy and writes back through the
 * admin endpoint, which means only admins can change them. Other people pick
 * up changes on their next page load.
 */
export default class SidebarGroups {
  @tracked groups;

  /** Called after the groups are saved. */
  onChange = () => {};

  constructor(currentUser) {
    this.currentUser = currentUser;
    this.groups = settings.sidebar_groups || [];
  }

  get canEdit() {
    return !!this.currentUser?.admin;
  }

  get names() {
    return [...new Set(this.groups.map((group) => group.name))];
  }

  /**
   * Adds a channel to the group with this name, creating the group at the end
   * of the list if there isn't one.
   *
   * @param {string} groupName
   * @param {string} key A channel key, from `channelKey`.
   */
  async addChannel(groupName, key) {
    await this.#save(this.#with(this.groups, groupName, key));
  }

  /** @returns {number} The index of the group holding this channel, or -1. */
  groupIndexOf(key) {
    return this.groups.findIndex((group) =>
      (group.channels || []).some((c) => channelKey(c.type, c.id) === key)
    );
  }

  async renameGroup(index, name) {
    await this.#save(
      this.groups.map((group, i) => (i === index ? { ...group, name } : group))
    );
  }

  async moveGroup(index, offset) {
    const groups = [...this.groups];
    const [group] = groups.splice(index, 1);
    groups.splice(index + offset, 0, group);
    await this.#save(groups);
  }

  // Its channels aren't touched; they go back to the top of the list.
  async deleteGroup(index) {
    await this.#save(this.groups.filter((_, i) => i !== index));
  }

  /**
   * Moves a channel into the named group, or out of every group if null.
   */
  async moveChannel(key, groupName) {
    const groups = this.#without(key);
    await this.#save(
      groupName === null ? groups : this.#with(groups, groupName, key)
    );
  }

  async removeChannel(key) {
    if (this.groupIndexOf(key) !== -1) {
      await this.#save(this.#without(key));
    }
  }

  #with(groups, groupName, key) {
    const [type, id] = key.split(":");
    const channel = { type, id: Number(id) };
    const index = groups.findIndex((group) => group.name === groupName);

    if (index === -1) {
      return [...groups, { name: groupName, channels: [channel] }];
    }

    return groups.map((group, i) =>
      i === index
        ? { ...group, channels: [...(group.channels || []), channel] }
        : group
    );
  }

  #without(key) {
    return this.groups.map((group) => ({
      ...group,
      channels: (group.channels || []).filter(
        (c) => channelKey(c.type, c.id) !== key
      ),
    }));
  }

  async #save(groups) {
    await ajax(`/admin/themes/${THEME_ID}/setting`, {
      type: "PUT",
      data: { name: "sidebar_groups", value: JSON.stringify(groups) },
    });

    settings.sidebar_groups = groups;
    this.groups = groups;
    this.onChange();
  }
}

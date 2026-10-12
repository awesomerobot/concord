import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

// Theme code isn't told its own id, but its translation prefix carries it.
const THEME_ID = themePrefix("").split(".")[1];

export function channelKey(type, id) {
  return `${type}:${id}`;
}

/**
 * The headed sections the channel list is split into, like Discord's channel
 * categories, and which channels sit in each.
 *
 * They're stored in the `sidebar_sections` theme setting. Theme settings
 * aren't reactive, so this keeps its own tracked copy and writes back through
 * the admin endpoint, which means only admins can change them. Other people
 * pick up changes on their next page load.
 */
export default class SidebarSections {
  @tracked sections;

  onChange = () => {};

  constructor(currentUser) {
    this.currentUser = currentUser;
    this.sections = settings.sidebar_sections || [];
  }

  get canEdit() {
    return !!this.currentUser?.admin;
  }

  get names() {
    return [...new Set(this.sections.map((section) => section.name))];
  }

  /**
   * Adds a channel to the section with this name, creating the section at the
   * end of the list if there isn't one.
   *
   * @param {string} sectionName
   * @param {string} key A channel key, from `channelKey`.
   */
  async addChannel(sectionName, key) {
    await this.#save(this.#with(this.sections, sectionName, key));
  }

  sectionIndexOf(key) {
    return this.sections.findIndex((section) =>
      (section.channels || []).some((c) => channelKey(c.type, c.id) === key)
    );
  }

  async renameSection(index, name) {
    await this.#save(
      this.sections.map((section, i) =>
        i === index ? { ...section, name } : section
      )
    );
  }

  async moveSection(index, offset) {
    const sections = [...this.sections];
    const [section] = sections.splice(index, 1);
    sections.splice(index + offset, 0, section);
    await this.#save(sections);
  }

  // Its channels aren't touched; they go back to the top of the list.
  async deleteSection(index) {
    await this.#save(this.sections.filter((_, i) => i !== index));
  }

  /**
   * Moves a channel into the named section, or out of every section if null.
   */
  async moveChannel(key, sectionName) {
    const sections = this.#without(key);
    await this.#save(
      sectionName === null ? sections : this.#with(sections, sectionName, key)
    );
  }

  async removeChannel(key) {
    if (this.sectionIndexOf(key) !== -1) {
      await this.#save(this.#without(key));
    }
  }

  #with(sections, sectionName, key) {
    const [type, id] = key.split(":");
    const channel = { type, id: Number(id) };
    const index = sections.findIndex((section) => section.name === sectionName);

    if (index === -1) {
      return [...sections, { name: sectionName, channels: [channel] }];
    }

    return sections.map((section, i) =>
      i === index
        ? { ...section, channels: [...(section.channels || []), channel] }
        : section
    );
  }

  #without(key) {
    return this.sections.map((section) => ({
      ...section,
      channels: (section.channels || []).filter(
        (c) => channelKey(c.type, c.id) !== key
      ),
    }));
  }

  async #save(sections) {
    await ajax(`/admin/themes/${THEME_ID}/setting`, {
      type: "PUT",
      data: { name: "sidebar_sections", value: JSON.stringify(sections) },
    });

    settings.sidebar_sections = sections;
    this.sections = sections;
    this.onChange();
  }
}

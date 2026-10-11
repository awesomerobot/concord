import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { extractError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const t = (key, options) =>
  i18n(themePrefix(`channel_privacy.${key}`), options);

/**
 * Who can see a channel, after it's made: the create modal's private switch
 * and groups, filled in from the channel as it is now.
 */
export default class ChannelPrivacyModal extends Component {
  @service toasts;

  @tracked flash;
  @tracked formData;
  @tracked loaded;

  constructor() {
    super(...arguments);

    if (this.privacy.kind !== "shared") {
      this.#load();
    }
  }

  get privacy() {
    return this.args.model.privacy;
  }

  get loading() {
    return !this.formData && !this.flash;
  }

  // The groups a subcategory's access requires are added on save, so they
  // aren't offered; nor are groups the parent category doesn't allow.
  get groupOptions() {
    const required = new Set((this.loaded?.required || []).map((g) => g.id));
    const allowed = this.loaded?.allowedGroupIds;

    return this.args.model.groups.filter(
      (group) => !required.has(group.id) && (!allowed || allowed.has(group.id))
    );
  }

  // Its parent decides as much as it does, so say which way and why.
  get privateDescription() {
    const { publicSubcategory, privateParent } = this.loaded || {};

    if (publicSubcategory) {
      return t("public_subcategory", { name: publicSubcategory });
    }
    if (privateParent) {
      return t("private_parent", { name: privateParent.name });
    }
    return i18n(themePrefix("create_channel.private_description"));
  }

  get privacyLocked() {
    return !!(this.loaded?.publicSubcategory || this.loaded?.privateParent);
  }

  get groupsDescription() {
    const { required = [], privateParent } = this.loaded || {};
    const notes = [];

    if (privateParent) {
      notes.push(
        t("parent_groups", {
          name: privateParent.name,
          groups: privateParent.groupNames.join(", "),
        })
      );
    }
    if (required.length) {
      notes.push(
        t("required_groups", {
          groups: required.map((group) => group.name).join(", "),
        })
      );
    }
    if (this.privacy.kind === "voice") {
      notes.push(t("voice_note"));
    }

    return notes.join(" ") || null;
  }

  get sharedCategoryName() {
    return this.privacy.category?.displayName;
  }

  async #load() {
    try {
      this.loaded = await this.privacy.load();
      this.formData = {
        isPrivate: this.loaded.isPrivate,
        groupIds: this.loaded.groupIds,
      };
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  @action
  validate(data, { addError }) {
    if (
      this.privacy.requiresGroups &&
      data.isPrivate &&
      !data.groupIds?.length &&
      !this.loaded?.required?.length
    ) {
      addError("groupIds", {
        title: i18n(themePrefix("create_channel.groups")),
        message: i18n(themePrefix("create_channel.groups_required")),
      });
    }
  }

  @action
  async save(data) {
    this.flash = null;

    try {
      const notice = await this.privacy.save(data, this.loaded);
      this.args.closeModal();

      if (notice) {
        this.toasts.warning({ data: { message: notice } });
      }
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  @action
  openCategorySecurity() {
    this.args.closeModal();
    DiscourseURL.routeTo(
      `/c/${Category.slugFor(this.privacy.category)}/edit/security`
    );
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @title={{t "title" name=@model.name}}
      class="discord-create-channel-modal discord-channel-privacy-modal"
    >
      <:body>
        {{#if (eq this.privacy.kind "shared")}}
          <p class="discord-channel-privacy-modal__shared">
            {{t "shared" category=this.sharedCategoryName}}
          </p>
          <DButton
            @action={{this.openCategorySecurity}}
            @translatedLabel={{t "open_category"}}
            class="btn-default"
          />
        {{else}}
          <DConditionalLoadingSpinner @condition={{this.loading}}>
            {{#if this.formData}}
              <Form
                @data={{this.formData}}
                @onSubmit={{this.save}}
                @validate={{this.validate}}
                as |form data|
              >
                <form.Field
                  @description={{this.privateDescription}}
                  @disabled={{this.privacyLocked}}
                  @format="full"
                  @name="isPrivate"
                  @title={{i18n (themePrefix "create_channel.private")}}
                  @type="toggle"
                  as |field|
                >
                  <field.Control />
                </form.Field>

                {{#if data.isPrivate}}
                  <form.Field
                    @description={{this.groupsDescription}}
                    @format="full"
                    @name="groupIds"
                    @title={{if
                      (eq this.privacy.kind "voice")
                      (t "voice_groups")
                      (i18n (themePrefix "create_channel.groups"))
                    }}
                    @type="custom"
                    as |field|
                  >
                    <field.Control>
                      <GroupChooser
                        @content={{this.groupOptions}}
                        @labelProperty="name"
                        @onChange={{field.set}}
                        @value={{field.value}}
                      />
                    </field.Control>
                  </form.Field>
                {{/if}}

                <form.Actions>
                  <form.Submit @label="save" class="btn-primary" />
                  <form.Button
                    @action={{@closeModal}}
                    @label="cancel"
                    class="btn-transparent"
                  />
                </form.Actions>
              </Form>
            {{/if}}
          </DConditionalLoadingSpinner>
        {{/if}}
      </:body>
    </DModal>
  </template>
}

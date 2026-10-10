import { withPluginApi } from "discourse/lib/plugin-api";

// Discord opens a channel in the main area, never a floating panel, so chat
// always runs full page. Everything that would switch to the drawer goes
// through `prefersDrawer`, and the chat routes only open the drawer when it's
// preferred.
export default {
  name: "discord-chat-full-page",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "service:chat-state-manager",
        (Superclass) =>
          class extends Superclass {
            get isFullPagePreferred() {
              return true;
            }

            get isDrawerPreferred() {
              return false;
            }

            prefersDrawer() {
              this.prefersFullPage();
            }
          }
      );
    });
  },
};

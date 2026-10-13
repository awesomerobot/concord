import { next } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";

// Chat's own idea of active: interacted with in the last five minutes, and
// not in a background tab for longer.
const ONLINE_OPTIONS = {
  userUnseenTime: 300000,
  browserHiddenTime: 300000,
};

export default {
  name: "concord-chat-presence",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      // Chat counts someone online only while chat is open. Here chat is one
      // kind of channel among many, so being anywhere on the site counts;
      // hiding one's presence still does.
      api.modifyClass(
        "service:chat",
        (Superclass) =>
          class extends Superclass {
            updatePresence() {
              next(() => {
                if (this.isDestroying || !this.currentUser) {
                  return;
                }

                if (this.currentUser.user_option?.hide_presence) {
                  this.presenceChannel?.leave();
                } else {
                  this.presenceChannel?.enter({
                    activeOptions: ONLINE_OPTIONS,
                  });
                }
              });
            }
          }
      );
    });
  },
};

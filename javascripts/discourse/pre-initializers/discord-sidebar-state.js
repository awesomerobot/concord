import { withPluginApi } from "discourse/lib/plugin-api";
import { MAIN_PANEL, SEPARATED_MODE } from "discourse/lib/sidebar/panels";
import { CHANNELS_PANEL } from "../lib/constants";

// The panels our channel list stands in for. Chat's panel is listed by key so
// this works whether or not the chat plugin is installed.
const REPLACED_PANELS = [MAIN_PANEL, "chat"];

// Core and chat both move the sidebar between the forum and chat panels, on
// route changes and when the chat drawer opens or closes. Rather than chase
// each of those, the sidebar state redirects them to our panel. The service is
// looked up early in boot, so this patches it from a pre-initializer.
export default {
  name: "discord-sidebar-state",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "service:sidebar-state",
        (Superclass) =>
          class extends Superclass {
            setPanel(name) {
              super.setPanel(
                REPLACED_PANELS.includes(name) ? CHANNELS_PANEL : name
              );
            }

            // Combined mode would flatten every panel's sections together, and
            // also forces the main panel, so it becomes ours in separated mode.
            setCombinedMode() {
              super.setCombinedMode();
              this.mode = SEPARATED_MODE;
              this.currentPanelKey = CHANNELS_PANEL;
            }

            // There's nothing to switch to from the channel list.
            showSwitchPanelButtons() {
              if (this.currentPanelKey === CHANNELS_PANEL) {
                this.hideSwitchPanelButtons();
              } else {
                super.showSwitchPanelButtons();
              }
            }
          }
      );
    });
  },
};

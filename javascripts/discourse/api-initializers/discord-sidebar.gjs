import { apiInitializer } from "discourse/lib/api";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import { i18n } from "discourse-i18n";
import CreateChannelModal from "../components/modal/create-channel";
import ChannelActions from "../lib/channel-actions";
import ChannelCreator from "../lib/channel-creator";
import CurrentChannel from "../lib/current-channel";
import MemberListData from "../lib/member-list";
import ChannelDirectory from "../lib/channel-directory";
import {
  CHANNELS_PANEL,
  GROUP_SECTION_PREFIX,
  UNGROUPED_SECTION,
} from "../lib/constants";
import SidebarGroups from "../lib/sidebar-groups";
import ChannelHeader from "../components/channel-header";
import MemberList from "../components/member-list";
import ServerHeader from "../components/server-header";
import UserPanel from "../components/user-panel";

export default apiInitializer((api) => {
  const owner = getOwnerWithFallback(api);
  const sidebarGroups = new SidebarGroups(api.getCurrentUser());
  const channelActions = new ChannelActions(owner, sidebarGroups);
  const directory = new ChannelDirectory(owner, sidebarGroups, channelActions);
  const creator = new ChannelCreator(owner);
  const modal = owner.lookup("service:modal");
  const currentChannel = new CurrentChannel(owner);
  const memberList = new MemberListData(owner, currentChannel);
  const sidebarState = owner.lookup("service:sidebar-state");

  const openCreateChannel = (groupIndex = null) =>
    modal.show(CreateChannelModal, {
      model: { creator, sidebarGroups, groupIndex },
    });

  const createAction = (groupIndex) => {
    if (!creator.types.length) {
      return;
    }

    return [
      {
        id: "createChannel",
        icon: "plus",
        title: i18n(themePrefix("create_channel.action")),
        action: () => openCreateChannel(groupIndex),
      },
    ];
  };

  // Channels in no group sit at the top with no heading, as in Discord. A
  // section without a header never collapses.
  class UngroupedSection extends BaseCustomSidebarSection {
    name = UNGROUPED_SECTION;
    text = "";
    hideSectionHeader = true;

    get links() {
      return directory.sections.ungrouped;
    }

    get displaySection() {
      return this.links.length > 0;
    }
  }

  const groupSection = (index, name) =>
    class extends BaseCustomSidebarSection {
      name = name;
      actionsInline = true;

      get text() {
        return sidebarGroups.groups[index]?.name;
      }

      get links() {
        return directory.sections.grouped[index]?.links || [];
      }

      get actions() {
        return [
          ...(createAction(index) || []),
          channelActions.groupAction(index),
        ].filter(Boolean);
      }
    };

  api.addSidebarPanel(
    (BaseCustomSidebarPanel) =>
      class extends BaseCustomSidebarPanel {
        key = CHANNELS_PANEL;
        hidden = true;
        expandActiveSection = true;
        scrollActiveLinkIntoView = true;
      }
  );

  // A section per group. Named after the group, since that's what keeps a
  // section collapsed across page loads, with the position added where two
  // groups share a name. Rebuilt whenever the groups change.
  const panel = sidebarState.panels.find((p) => p.key === CHANNELS_PANEL);
  const syncSections = () => {
    const seen = new Set();

    panel.sections = [
      UngroupedSection,
      ...sidebarGroups.groups.map((group, index) => {
        let name = `${GROUP_SECTION_PREFIX}${group.name
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, "-")}`;
        if (seen.has(name)) {
          name = `${name}-${index}`;
        }
        seen.add(name);
        return groupSection(index, name);
      }),
    ];
  };

  syncSections();
  sidebarGroups.onChange = syncSections;

  api.renderInOutlet(
    "before-sidebar-sections",
    <template>
      <ServerHeader
        @canCreate={{creator.types.length}}
        @onCreate={{openCreateChannel}}
      />
    </template>
  );

  // On wide screens core's header contents are hidden and this row takes
  // their place, so the header keeps its height and the layout built on it.
  api.renderInOutlet(
    "after-header",
    <template>
      <ChannelHeader
        @canCreate={{creator.types.length}}
        @currentChannel={{currentChannel}}
        @memberList={{memberList}}
        @onCreate={{openCreateChannel}}
      />
    </template>
  );

  api.renderInOutlet("after-sidebar-sections", UserPanel);

  // A third column of the main grid, after the page itself.
  api.renderInOutlet(
    "after-main-outlet",
    <template><MemberList @memberList={{memberList}} /></template>
  );

  // The state patch redirects these to the channel panel.
  api.setSidebarPanel("main");
  api.setSeparatedSidebarMode();
});

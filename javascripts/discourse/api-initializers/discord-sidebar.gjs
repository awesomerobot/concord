import { apiInitializer } from "discourse/lib/api";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CreateChannelModal from "../components/modal/create-channel";
import ChannelActions from "../lib/channel-actions";
import ChannelCreator from "../lib/channel-creator";
import CurrentChannel from "../lib/current-channel";
import MemberListData from "../lib/member-list";
import ChannelDirectory from "../lib/channel-directory";
import {
  CHANNELS_PANEL,
  DMS_PANEL,
  DMS_SECTION,
  SECTION_PREFIX,
  TOP_SECTION,
} from "../lib/constants";
import DirectMessages from "../lib/direct-messages";
import installLongPress from "../lib/long-press";
import SidebarSections from "../lib/sidebar-sections";
import ChannelHeader from "../components/channel-header";
import MemberList from "../components/member-list";
import ServerHeader from "../components/server-header";
import TopicLayout from "../components/topic-layout";
import UserPanel from "../components/user-panel";

export default apiInitializer((api) => {
  const owner = getOwnerWithFallback(api);
  const sidebarSections = new SidebarSections(api.getCurrentUser());
  const channelActions = new ChannelActions(owner, sidebarSections);
  const directory = new ChannelDirectory(owner, sidebarSections, channelActions);
  const creator = new ChannelCreator(owner);
  const modal = owner.lookup("service:modal");
  const currentChannel = new CurrentChannel(owner);
  const memberList = new MemberListData(owner, currentChannel);
  const directMessages = new DirectMessages(owner, currentChannel);
  const sidebarState = owner.lookup("service:sidebar-state");

  const openCreateChannel = (sectionIndex = null) =>
    modal.show(CreateChannelModal, {
      model: { creator, sidebarSections, sectionIndex },
    });

  const createAction = (sectionIndex) => {
    if (!creator.types.length) {
      return;
    }

    return [
      {
        id: "createChannel",
        icon: "plus",
        title: i18n(themePrefix("create_channel.action")),
        action: () => openCreateChannel(sectionIndex),
      },
    ];
  };

  // Channels in no section sit at the top with no heading, as in Discord. A
  // section without a header never collapses.
  class TopSection extends BaseCustomSidebarSection {
    name = TOP_SECTION;
    text = "";
    hideSectionHeader = true;

    get links() {
      return directory.layout.top;
    }

    get displaySection() {
      return this.links.length > 0;
    }
  }

  const headedSection = (index, name) =>
    class extends BaseCustomSidebarSection {
      name = name;
      actionsInline = true;

      get text() {
        return sidebarSections.sections[index]?.name;
      }

      get links() {
        return directory.layout.sections[index]?.links || [];
      }

      get actions() {
        return [
          ...(createAction(index) || []),
          channelActions.sectionAction(index),
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

  // A sidebar section per section. Named after it, since that's what keeps a
  // section collapsed across page loads, with the position added where two
  // share a name. Rebuilt whenever the sections change.
  const panel = sidebarState.panels.find((p) => p.key === CHANNELS_PANEL);
  const syncSections = () => {
    const seen = new Set();

    panel.sections = [
      TopSection,
      ...sidebarSections.sections.map((section, index) => {
        let name = `${SECTION_PREFIX}${section.name
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, "-")}`;
        if (seen.has(name)) {
          name = `${name}-${index}`;
        }
        seen.add(name);
        return headedSection(index, name);
      }),
    ];
  };

  syncSections();
  sidebarSections.onChange = syncSections;

  // Discord's Home: the user's DMs, swapped in for the channels by the DM
  // button beside the server name, or by opening a DM.
  const newDirectMessageLink = {
    name: "new-dm",
    route: "chat.new-message",
    text: i18n(themePrefix("direct_messages.new")),
    title: i18n("sidebar.start_new_dm.title"),
    prefixType: "icon",
    prefixValue: "plus",
    classNames: "discord-channel discord-channel--new-dm",
  };

  if (directMessages.available) {
    api.addSidebarPanel(
      (BaseCustomSidebarPanel) =>
        class extends BaseCustomSidebarPanel {
          key = DMS_PANEL;
          hidden = true;
          scrollActiveLinkIntoView = true;
        }
    );

    api.addSidebarSection(
      (BaseSection) =>
        class extends BaseSection {
          name = DMS_SECTION;
          text = "";
          hideSectionHeader = true;

          // Starting a conversation leads the list, as in Discord's Home.
          get links() {
            return [newDirectMessageLink, ...directMessages.links];
          }
        },
      DMS_PANEL
    );
  }

  api.renderInOutlet(
    "before-sidebar-sections",
    <template>
      <ServerHeader
        @canCreate={{creator.types.length}}
        @directMessages={{directMessages}}
        @onCreate={{openCreateChannel}}
      />
    </template>
  );

  // On wide screens core's header contents are hidden and this row takes
  // their place, so the header keeps its height and the layout built on it.
  api.renderInOutlet(
    "after-header",
    <template>
      {{#unless currentChannel.isAuthPage}}
        <ChannelHeader
          @canCreate={{creator.types.length}}
          @currentChannel={{currentChannel}}
          @directMessages={{directMessages}}
          @memberList={{memberList}}
          @onCreate={{openCreateChannel}}
        />
      {{/unless}}
    </template>
  );

  api.renderInOutlet("after-sidebar-sections", UserPanel);

  // Touch screens have no hover for the rows' `…` button, so a long press
  // opens the channel's menu, as in Discord.
  if (api.getCurrentUser()) {
    installLongPress(
      `.sidebar-section[data-section-name^="discord-"] .sidebar-section-link`,
      (row) => {
        const link = directory.linkNamed(row.dataset.linkName);
        if (link?.channelKey) {
          channelActions.showChannelMenu(row, link);
        }
      }
    );
  }

  // Names in the member list open user cards, as they do on the page.
  api.addCardClickListenerSelector(".discord-member-list-host");

  // A third column of the main grid, after the page itself.
  api.renderInOutlet(
    "after-main-outlet",
    <template>
      {{#unless currentChannel.isAuthPage}}
        <MemberList @memberList={{memberList}} />
      {{/unless}}
    </template>
  );

  api.renderInOutlet(
    "after-main-outlet",
    <template>
      {{#if (eq currentChannel.value.type "topic")}}
        <TopicLayout />
      {{/if}}
    </template>
  );

  // The state patch redirects these to the channel panel.
  api.setSidebarPanel("main");
  api.setSeparatedSidebarMode();
});

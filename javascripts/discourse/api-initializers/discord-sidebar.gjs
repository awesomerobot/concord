import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { apiInitializer } from "discourse/lib/api";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import ChannelHeader from "../components/channel-header";
import MemberList from "../components/member-list";
import CreateChannelModal from "../components/modal/create-channel";
import ServerHeader from "../components/server-header";
import TopicLayout from "../components/topic-layout";
import UserPanel from "../components/user-panel";
import ChannelActions from "../lib/channel-actions";
import ChannelCreator from "../lib/channel-creator";
import ChannelDirectory from "../lib/channel-directory";
import ChannelPrivacy from "../lib/channel-privacy";
import {
  CHANNELS_PANEL,
  DMS_PANEL,
  DMS_SECTION,
  SECTION_PREFIX,
  TOP_SECTION,
} from "../lib/constants";
import CurrentChannel from "../lib/current-channel";
import DirectMessages from "../lib/direct-messages";
import LastChannel from "../lib/last-channel";
import installLongPress from "../lib/long-press";
import MemberListData from "../lib/member-list";
import replaySlideIn from "../lib/replay-slide-in";
import scrollToActive from "../lib/scroll-to-active";
import SidebarSections from "../lib/sidebar-sections";

export default apiInitializer((api) => {
  const owner = getOwnerWithFallback(api);
  const sidebarSections = new SidebarSections(api.getCurrentUser());
  const creator = new ChannelCreator(owner);
  const channelActions = new ChannelActions(
    owner,
    sidebarSections,
    new ChannelPrivacy(owner, creator),
    creator
  );
  const directory = new ChannelDirectory(
    owner,
    sidebarSections,
    channelActions
  );
  const modal = owner.lookup("service:modal");
  const currentChannel = new CurrentChannel(owner);
  const memberList = new MemberListData(owner, currentChannel);
  const directMessages = new DirectMessages(
    owner,
    currentChannel,
    channelActions
  );
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

  // Registered even before the user can DM, since a first DM from someone
  // else makes the list available without a page load.
  if (directMessages.supported) {
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

  // Rendered afresh each time the slide-in list opens. Core scrolls the
  // current channel's row into view (the panels ask it to), but then focuses
  // the slide-in's first link, which scrolls it back to the top; so scroll
  // again a frame later, still before the list is first drawn.
  const onListInserted = (element) => {
    const list = element.closest(".sidebar-hamburger-dropdown");
    if (list) {
      requestAnimationFrame(() => scrollToActive(list));
    }
    replaySlideIn(element);
  };

  api.renderInOutlet(
    "before-sidebar-sections",
    <template>
      <ServerHeader
        @canCreate={{creator.types.length}}
        @directMessages={{directMessages}}
        @onCreate={{openCreateChannel}}
      />
      <span hidden {{didInsert onListInserted}}></span>
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

  // Discord opens a channel in the main area, never a floating panel, so chat
  // runs full page. That's chat's own per-browser preference, so it's set at
  // boot, and again ahead of every route change: chat's drawer shortcut (-)
  // switches it to the drawer just before navigating, and chat's routes read
  // it once the transition is under way.
  // (Reading the preference first would touch the mobile view too early in
  // boot, and setting it is one small local storage write.)
  const chatStateManager = owner.lookup("service:chat-state-manager");
  if (chatStateManager) {
    const preferFullPage = () => chatStateManager.prefersFullPage();

    preferFullPage();
    owner.lookup("service:router").on("routeWillChange", preferFullPage);
  }

  // Core closes the slide-in channel list when one of its sidebar links is
  // tapped, but not when the server menu or a channel's menu navigates from
  // inside it, so close it on any navigation. Through core's header, so it
  // slides out and the page scrolls again.
  const header = owner.lookup("service:header");
  owner.lookup("service:router").on("routeDidChange", () => {
    if (header.hamburgerVisible) {
      owner
        .lookup("service:app-events")
        .trigger("header:keyboard-trigger", { type: "hamburger" });
    }
  });

  if (settings.remember_last_channel && api.getCurrentUser()) {
    new LastChannel(owner, currentChannel, api.getCurrentUser()).install();
  }

  // Chat only updates presence on its own routes, so a visit that starts on a
  // forum page wouldn't count as online until chat was opened.
  owner.lookup("service:chat")?.updatePresence?.();

  // Touch screens have no hover for the rows' `…` button, so a long press
  // opens the channel's menu, as in Discord.
  if (api.getCurrentUser()) {
    installLongPress(
      `.sidebar-section[data-section-name^="discord-"] .sidebar-section-link`,
      (row) => {
        const name = row.dataset.linkName;
        const link =
          directory.linkNamed(name) || directMessages.linkNamed(name);
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

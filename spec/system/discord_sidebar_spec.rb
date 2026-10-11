# frozen_string_literal: true

RSpec.describe "Discord sidebar" do
  fab!(:admin)
  fab!(:group)
  fab!(:category) { Fabricate(:category, name: "Lounge") }
  fab!(:chat_channel) { Fabricate(:category_channel, chatable: category, name: "hangout") }
  fab!(:voice_room) { Fabricate(:voice_room, name: "Campfire", public: true, creator: admin) }

  let!(:theme) { upload_theme_component }
  let(:sidebar) { find(".sidebar-wrapper") }
  let(:modal) { PageObjects::Modals::Base.new }
  let(:form) { PageObjects::Components::FormKit.new(".discord-create-channel-modal form") }

  before do
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.voice_create_room_allowed_groups = Group::AUTO_GROUPS[:admins]
    chat_system_bootstrap(admin, [chat_channel])
    group.add(admin)
    sign_in(admin)
  end

  def screenshot(name)
    dir = ENV["DCCK_SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  def channel_link(name)
    sidebar.find(".sidebar-section-link[data-link-name='#{name}']")
  end

  def open_create_modal
    find(".discord-server-header__create").click
    expect(modal).to be_open
  end

  def group_chooser
    PageObjects::Components::SelectKit.new(
      ".form-kit__field[data-name='groupIds'] .select-kit",
    )
  end

  def section_chooser
    PageObjects::Components::SelectKit.new(
      ".form-kit__field[data-name='section'] .select-kit",
    )
  end

  it "replaces the sidebar with one list of channels, on forum and chat pages" do
    visit("/latest")

    expect(page).to have_css(".discord-server-header")
    expect(channel_link("forum-#{category.slug}")).to be_present
    expect(channel_link("text-hangout")).to be_present
    expect(channel_link("voice-room-#{voice_room.id}")).to be_present
    expect(sidebar).to have_no_css(".sidebar-section[data-section-name='community']")
    expect(sidebar).to have_no_css(".sidebar-section[data-section-name='categories']")

    channel_link("text-hangout").click
    expect(page).to have_current_path(%r{/chat/c/hangout/#{chat_channel.id}})
    expect(page).to have_no_css(".chat-drawer.is-expanded")
    expect(channel_link("forum-#{category.slug}")).to be_present
    expect(sidebar).to have_no_css(".sidebar-section[data-section-name='chat-channels']")
  end

  it "keeps channels with long names to the same width" do
    Fabricate(:category, name: "A really quite remarkably long channel name")
    visit("/latest")

    widths = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".discord-channel")].map((link) => link.getBoundingClientRect().width)
    JS
    expect(widths.uniq.size).to eq(1)
  end

  it "creates a private forum channel limited to the chosen groups" do
    visit("/latest")
    open_create_modal

    form.field("type").select("forum")
    form.field("name").fill_in("secret-plans")
    form.field("isPrivate").toggle
    group_chooser.expand
    group_chooser.search(group.name)
    group_chooser.select_row_by_name(group.name)
    group_chooser.collapse
    screenshot("create-modal")
    form.submit

    expect(page).to have_current_path(%r{/c/secret-plans/\d+})
    created = Category.find_by(name: "secret-plans")
    expect(created.read_restricted).to eq(true)
    expect(created.category_groups.pluck(:group_id)).to contain_exactly(group.id)
    expect(channel_link("forum-secret-plans")).to be_present
  end

  it "creates a text channel in a new section typed into the section picker" do
    visit("/latest")
    open_create_modal

    form.field("type").select("text")
    section_chooser.expand
    section_chooser.search("Gaming")
    section_chooser.select_row_by_value("Gaming")
    screenshot("new-section-picked")
    expect(page).to have_css(
      ".form-kit__field[data-name='section'] .select-kit-header .name",
      text: "Gaming",
    )
    form.field("name").fill_in("lfg")
    form.submit

    expect(page).to have_current_path(%r{/chat/c/lfg/\d+})
    created = Chat::Channel.find_by(name: "lfg")
    expect(created.chatable.parent_category.slug).to eq("chat-channels")

    sections = theme.reload.settings[:sidebar_sections].value
    expect(sections).to eq(
      [{ "name" => "Gaming", "channels" => [{ "type" => "text", "id" => created.id }] }],
    )

    gaming = sidebar.find(".sidebar-section[data-section-name='discord-section-gaming']")
    expect(gaming).to have_css(".sidebar-section-link[data-link-name='text-lfg']")
    expect(sidebar).to have_no_css(
      ".sidebar-section-link[data-link-name='forum-#{created.chatable.slug}']",
    )
  end

  it "opens chat full page even when the drawer was preferred" do
    visit("/latest")
    page.execute_script(
      "localStorage.setItem('discourse_chat_preferred_mode', JSON.stringify('DRAWER_CHAT'))",
    )
    visit("/latest")

    channel_link("text-hangout").click
    expect(page).to have_current_path(%r{/chat/c/hangout/#{chat_channel.id}})
    expect(page).to have_no_css(".chat-drawer.is-expanded")
    expect(page).to have_no_css(".c-navbar__open-drawer-button", visible: :visible)
  end

  it "creates a public voice channel" do
    visit("/latest")
    open_create_modal

    form.field("type").select("voice")
    form.field("name").fill_in("Late night")
    form.submit

    room = Voice::Room.find_by(name: "Late night")
    expect(room.public).to eq(true)
    expect(channel_link("voice-room-#{room.id}")).to be_present
  end

  it "mutes a text channel and moves it to a section from its menu" do
    theme.update_setting(
      :sidebar_sections,
      [{ "name" => "Hangouts", "channels" => [] }].to_json,
    )
    theme.save!

    visit("/latest")

    link = channel_link("text-hangout")
    link.hover
    link.find(".sidebar-section-hover-button").click
    labels = all(".discord-action-menu .btn").map(&:text)
    expect(labels.first(3)).to eq(["Mark as read", "Rename", "Copy link"])
    expect(labels.last).to eq("Delete")
    expect(labels).not_to include("Hangouts")
    screenshot("channel-menu")
    find(".discord-action-menu .btn", text: "Mute").click

    expect(sidebar).to have_css(
      ".sidebar-section-link--muted[data-link-name='text-hangout']",
    )
    expect(chat_channel.membership_for(admin).reload.muted).to eq(true)

    link = channel_link("text-hangout")
    link.hover
    link.find(".sidebar-section-hover-button").click
    find(".discord-action-menu [data-item-id='move-to-section']").click
    # Beside the channel's menu, which stays open.
    expect(page).to have_css(".discord-action-menu", count: 2)
    screenshot("channel-submenu")
    find(".discord-action-menu .btn", text: "Hangouts").click
    expect(page).to have_no_css(".discord-action-menu")

    hangouts = sidebar.find(".sidebar-section[data-section-name='discord-section-hangouts']")
    expect(hangouts).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
  end

  it "moves a channel into a new section from its menu" do
    visit("/latest")

    link = channel_link("text-hangout")
    link.hover
    link.find(".sidebar-section-hover-button").click
    find(".discord-action-menu [data-item-id='move-to-section']").click
    find(".discord-action-menu .btn", text: "New section…").click

    name_form = PageObjects::Components::FormKit.new(".discord-rename-modal form")
    name_form.field("name").fill_in("Hangouts")
    name_form.submit

    hangouts = sidebar.find(".sidebar-section[data-section-name='discord-section-hangouts']")
    expect(hangouts).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
    expect(theme.reload.settings[:sidebar_sections].value).to eq(
      [{ "name" => "Hangouts", "channels" => [{ "type" => "text", "id" => chat_channel.id }] }],
    )
  end

  it "renames a section from its heading menu" do
    theme.update_setting(:sidebar_sections, [{ "name" => "Old", "channels" => [] }].to_json)
    theme.save!

    visit("/latest")

    heading = sidebar.find(".sidebar-section[data-section-name='discord-section-old']")
    heading.find(".sidebar-section-header-wrapper").hover
    heading.find("[data-sidebar-action-id='sectionMenu']").click
    find(".discord-action-menu .btn", text: "Rename section").click

    rename_form = PageObjects::Components::FormKit.new(".discord-rename-modal form")
    rename_form.field("name").fill_in("New")
    rename_form.submit

    expect(sidebar).to have_css(".sidebar-section[data-section-name='discord-section-new']")
    expect(theme.reload.settings[:sidebar_sections].value.first["name"]).to eq("New")
  end

  it "centres section carets over the channel icons" do
    theme.update_setting(
      :sidebar_sections,
      [{ "name" => "Hangouts", "channels" => [{ "type" => "forum", "id" => category.id }] }].to_json,
    )
    theme.save!

    visit("/latest")

    section = "[data-section-name='discord-section-hangouts']"
    expect(sidebar).to have_css("#{section} .sidebar-section-link-prefix")
    screenshot("section")

    centres = page.evaluate_script(<<~JS)
      (() => {
        const centre = (selector) => {
          const rect = document.querySelector(selector).getBoundingClientRect();
          return rect.left + rect.width / 2;
        };
        return [
          centre("#{section} .sidebar-section-header-caret"),
          centre("#{section} .sidebar-section-link-prefix .prefix-icon"),
        ];
      })()
    JS
    expect(centres.first).to be_within(1).of(centres.last)
  end

  describe "direct messages" do
    fab!(:friend) { Fabricate(:user, username: "campmate") }
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [admin, friend]) }

    let(:dms_button) { find(".discord-channel-header .discord-server-header__dms") }

    it "swaps the channel list for DMs from beside the server name" do
      Fabricate(:chat_message, chat_channel: dm_channel, user: friend, message: "hi there")
      visit("/latest")

      expect(dms_button).to have_css(".discord-server-header__dms-badge", text: "1")
      dms_button.click

      dms = sidebar.find(".sidebar-section[data-section-name='discord-dms']")
      expect(dms).to have_no_css(".sidebar-section-header")
      expect(dms.all(".sidebar-section-link").first["data-link-name"]).to eq("new-dm")
      expect(dms).to have_css(".sidebar-section-link[data-link-name='dm-#{dm_channel.id}']")
      expect(sidebar).to have_no_css(".sidebar-section-link[data-link-name='text-hangout']")
      screenshot("dms")

      dms.find(".sidebar-section-link[data-link-name='dm-#{dm_channel.id}']").click
      expect(page).to have_current_path(%r{/chat/c/.+/#{dm_channel.id}})
      expect(sidebar).to have_css("[data-section-name='discord-dms']")
      screenshot("dm-channel")

      new_dm = sidebar.find(".sidebar-section-link[data-link-name='new-dm']")
      expect(new_dm).to have_text("New DM or group chat")
      new_dm.click
      expect(page).to have_css(".chat-modal-new-message")
      send_keys(:escape)

      find(".discord-channel-header .discord-server-header__dms").click
      expect(sidebar).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
      expect(sidebar).to have_no_css("[data-section-name='discord-dms']")
    end

    it "follows the page between DMs and the server's channels" do
      visit("/chat/c/-/#{dm_channel.id}")
      expect(sidebar).to have_css(".sidebar-section-link[data-link-name='dm-#{dm_channel.id}']")
      expect(dms_button["aria-pressed"]).to eq("true")

      visit("/c/#{category.slug}/#{category.id}")
      expect(sidebar).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
      expect(sidebar).to have_no_css("[data-section-name='discord-dms']")
    end
  end

  describe "header" do
    let(:header) { find(".discord-channel-header") }

    it "opens the site's pages from the server name" do
      Fabricate(:reviewable)
      visit("/latest")

      header.find(".discord-server-header__name").click
      menu = find(".discord-action-menu")
      expect(menu).to have_css("[data-item-id='admin']")
      expect(menu).to have_css("[data-item-id='review'] .discord-action-menu__badge")
      expect(menu).to have_css("[data-item-id='keyboard-shortcuts']")
      screenshot("server-menu")

      menu.find("[data-item-id='about']").click
      expect(page).to have_current_path("/about")
    end

    it "titles the server menu's pages" do
      SiteSetting.enable_badges = true
      SiteSetting.enable_group_directory = true
      badge = Badge.find(Badge::FirstLike)

      {
        "/about" => "About",
        "/g" => "Groups",
        "/g/#{group.name}" => group.name,
        "/u" => "Users",
        "/badges" => "Badges",
        "/badges/#{badge.id}/#{badge.slug}" => badge.display_name,
        "/review" => "Review",
        "/admin" => "Admin",
      }.each do |path, title|
        visit(path)
        expect(header).to have_css(".discord-channel-header__name", exact_text: title)
        expect(page).to have_no_css(
          ".badges > h1, .show-badge > h1, .group-info-names .group-info-details",
          visible: :visible,
        )
        screenshot("page#{path.tr("/", "-")}")
      end
    end

    it "replaces core's header and chat's channel bar with the channel's own" do
      visit("/chat/c/hangout/#{chat_channel.id}")

      expect(page).to have_no_css(".d-header > .wrap", visible: :visible)
      expect(header).to have_css(".discord-channel-header__name", text: "hangout")
      expect(page).to have_css(".c-routes.--channel")
      expect(page).to have_no_css(".c-routes.--channel > .c-navbar-container", visible: :visible)

      gap = page.evaluate_script(<<~JS)
        window.innerHeight - document.querySelector(".chat-channel").getBoundingClientRect().bottom
      JS
      expect(gap).to be_within(2).of(0)
      screenshot("chat")

      header.find("[data-action-id='pins']").click
      expect(page).to have_current_path(%r{/chat/c/hangout/#{chat_channel.id}/pins})
    end

    it "searches from a dropdown without widening the page" do
      visit("/latest")

      overflow = page.evaluate_script(
        "document.documentElement.scrollWidth - document.documentElement.clientWidth",
      )
      expect(overflow).to eq(0)

      header.find(".discord-channel-header__search").click
      expect(page).to have_css(".discord-search-panel #discord-search-input:focus")
      expect(page.evaluate_script(<<~JS)).to eq(550)
        document.querySelector(".discord-search-panel").getBoundingClientRect().width
      JS
      screenshot("search")

      send_keys(:escape)
      expect(page).to have_no_css(".discord-search-panel")
    end

    it "searches the channel's messages from a chat channel" do
      chat_channel.add(admin)
      Fabricate(:chat_message, chat_channel: chat_channel, user: admin, message: "hello there")
      visit("/chat/c/-/#{chat_channel.id}")

      header.find(".discord-channel-header__search").click
      text_left, input_text_left = page.evaluate_script(<<~JS)
        (() => {
          const input = document.querySelector(".chat-channel__filter-bar input");
          return [
            document.querySelector(".chat-message-text").getBoundingClientRect().left,
            input.getBoundingClientRect().left + parseFloat(getComputedStyle(input).paddingLeft),
          ];
        })()
      JS
      expect(input_text_left).to be_within(1).of(text_left)
      expect(page).to have_css(".chat-channel__filter-bar input:focus")
      expect(page.evaluate_script(<<~JS)).to eq("solid")
        getComputedStyle(document.querySelector(".chat-channel__filter-bar .filter-input-container")).outlineStyle
      JS
      expect(page).to have_no_css(".discord-search-panel")
      screenshot("chat-search")

      header.find(".discord-channel-header__search").click
      expect(page).to have_no_css(".chat-channel__filter-bar")
    end

    it "shows the category" do
      category.update!(description: "Sit by the fire")
      visit("/c/#{category.slug}/#{category.id}")

      expect(page).to have_css(".list-controls")
      expect(page).to have_no_css(".list-controls .category-breadcrumb", visible: :visible)
      expect(page).to have_no_css(
        ".list-controls .notifications-tracking-trigger-btn",
        visible: :visible,
      )

      expect(header).to have_css(".discord-channel-header__name", text: "Lounge")
      expect(header).to have_css(".discord-channel-header__description", text: "Sit by the fire")
      expect(page).to have_no_css(".list-controls .edit-category", visible: :visible)
      screenshot("forum")

      header.find("[data-action-id='settings']").click
      expect(page).to have_current_path(%r{/c/#{category.slug}/edit})
    end

    it "centres a topic in the space beside the channel list" do
      topic = Fabricate(:topic, category:, title: "Best campfire songs")
      20.times { Fabricate(:post, topic:) }

      resize_window(width: 1920) do
        visit(topic.relative_url)
        expect(page).to have_css(".timeline-container")

        outlet, posts = page.evaluate_script(<<~JS)
          ["#main-outlet", ".container.posts"].map((s) => {
            const r = document.querySelector(s).getBoundingClientRect();
            return { left: r.left, right: r.right };
          })
        JS
        expect(posts["left"] - outlet["left"]).to be > 100
        expect(posts["left"] - outlet["left"]).to be_within(1).of(outlet["right"] - posts["right"])
        screenshot("topic-centred")

        find(".topic-footer-main-buttons .create").click
        expect(page).to have_css("#reply-control.open")
        find("#reply-control .toggle-preview").click if page.has_no_css?("#reply-control.hide-preview", wait: 0)
        expect(page).to have_css("#reply-control.hide-preview")
        composer_left = page.evaluate_script(
          "document.querySelector('#reply-control').getBoundingClientRect().left",
        )
        expect(composer_left).to be_within(1).of(posts["left"])
        screenshot("topic-centred-composer")
      end
    end

    it "goes back to the forum channel from a topic" do
      topic = Fabricate(:post, topic: Fabricate(:topic, category:, title: "Best campfire songs")).topic
      visit(topic.relative_url)

      header.find(".discord-channel-header__back").click
      expect(page).to have_current_path(%r{/c/#{category.slug}/#{category.id}})
      expect(header).to have_css(".discord-channel-header__name", text: "Lounge")
    end

    it "shows a topic's title over its category" do
      topic = Fabricate(:post, topic: Fabricate(:topic, category:, title: "Best campfire songs")).topic
      visit(topic.relative_url)

      expect(header).to have_css(
        ".discord-channel-header__name a[href='#{topic.relative_url}/1']",
        text: "Best campfire songs",
      )
      expect(header).to have_css(
        ".discord-channel-header__description a[href='#{category.url}']",
        text: "Lounge",
      )
      expect(header).to have_css(
        ".discord-channel-header__back[href='#{category.url}'][title='Back to Lounge']",
      )
      screenshot("topic")

      expect(page).to have_css(
        ".topic-footer-main-buttons + * .notifications-tracking-trigger-btn, #topic-footer-buttons .notifications-tracking-trigger-btn",
      )

      find(".topic-footer-main-buttons .create").click
      expect(page).to have_css("#reply-control.open")
      screenshot("composer")
    end

    it "fills the window, with the sidebar under the server name" do
      visit("/latest")

      widths = page.evaluate_script(<<~JS)
        (() => {
          const rect = (s) => document.querySelector(s).getBoundingClientRect();
          return {
            window: window.innerWidth,
            outlet: rect("#main-outlet-wrapper").width,
            sidebar: rect(".sidebar-wrapper").left,
            server: rect(".discord-channel-header .discord-server-header").right,
            sidebarRight: rect(".sidebar-wrapper").right,
            content: rect("#main-outlet").left,
            channel:
              rect(".discord-channel-header__channel").left +
              parseFloat(getComputedStyle(document.querySelector(".discord-channel-header__channel")).paddingLeft),
          };
        })()
      JS

      expect(widths["outlet"]).to be_within(20).of(widths["window"])
      expect(widths["sidebar"]).to eq(0)
      expect(widths["sidebarRight"]).to be_within(1).of(widths["server"])
      expect(widths["content"]).to be_within(1).of(widths["channel"])
    end
  end

  describe "user panel" do
    it "opens the notifications menu from the bell" do
      Fabricate(:notification, user: admin)
      visit("/latest")

      panel = find(".discord-user-panel")
      expect(panel).to have_css(".discord-user-panel__name", text: admin.username)
      expect(panel).to have_css(".discord-user-panel__notifications .badge-notification", text: "1")
      expect(panel).to have_no_css(".discord-user-panel__avatar .badge-notification", visible: :visible)
      screenshot("user-panel")

      panel.find(".discord-user-panel__notifications").click
      expect(page).to have_css(".discord-user-menu .user-menu .quick-access-panel")
      tabs_left, panel_left = page.evaluate_script(<<~JS)
        [".discord-user-menu .menu-tabs-container", ".discord-user-menu .quick-access-panel"]
          .map((s) => document.querySelector(s).getBoundingClientRect().left)
      JS
      expect(tabs_left).to be < panel_left
      expect(page).to have_no_css(".discord-user-menu #user-menu-button-profile", visible: :visible)
      screenshot("user-menu")
    end

    it "opens the profile menu from the user's name" do
      visit("/latest")

      find(".discord-user-panel__me").click
      menu = find(".discord-profile-menu #quick-access-profile")
      expect(menu).to have_css("li.preferences")
      expect(menu).to have_css("li.logout")
      expect(page.evaluate_script(<<~JS)).to eq("400")
        getComputedStyle(document.querySelector(".discord-profile-menu li.summary .item-label")).fontWeight
      JS
      screenshot("profile-menu")

      menu.find("li.preferences a").click
      expect(page).to have_current_path(%r{/u/#{admin.username}/preferences})
      expect(page).to have_no_css(".discord-profile-menu")
    end

    it "offers log in and sign up when signed out" do
      Capybara.reset_sessions!
      visit("/latest")

      expect(page).to have_css(".discord-user-panel .discord-user-panel__login")
      expect(page).to have_css(".discord-user-panel .discord-user-panel__signup")
    end

    it "leaves the log in and sign up pages to core" do
      Capybara.reset_sessions!

      %w[/login /signup].each do |path|
        visit(path)
        expect(page).to have_css(".d-header .home-logo-wrapper-outlet", visible: :visible)
        expect(page).to have_no_css(".discord-channel-header, .discord-member-list")
        expect(page).to have_no_css("body.discord-member-list-open")
        screenshot("auth#{path.tr("/", "-")}")
      end
    end
  end

  describe "member list" do
    fab!(:member) { Fabricate(:user, username: "camper") }
    fab!(:outsider) { Fabricate(:user, username: "stranger") }

    let(:list) { find(".discord-member-list") }

    before do
      chat_channel.add(member)
      DirectoryItem.refresh!
    end

    def section(id)
      list.find(".discord-member-list__section[data-section-id='#{id}']")
    end

    it "lists a chat channel's members, with online admins under their role" do
      visit("/chat/c/hangout/#{chat_channel.id}")

      expect(section("role-admins")).to have_css("[data-username='#{admin.username}']")
      expect(section("offline")).to have_css("[data-username='camper']")
      expect(list).to have_no_css("[data-username='stranger']")
      screenshot("member-list")
      expect(page.evaluate_script(<<~JS)).to eq("0px")
        getComputedStyle(document.querySelector(".full-page-chat")).borderRightWidth
      JS
    end

    it "opens user cards from the list" do
      visit("/chat/c/hangout/#{chat_channel.id}")

      list.find("[data-username='camper'] .discord-member-list__name").click
      expect(page).to have_css(".user-card .user-profile-link", text: "camper")
      expect(page).to have_current_path(%r{/chat/c/hangout/})
      screenshot("member-card")
    end

    it "lists everyone on forum pages" do
      visit("/c/#{category.slug}/#{category.id}")

      expect(list).to have_css("[data-username='camper']")
      expect(list).to have_css("[data-username='stranger']")
    end

    it "hides and remembers being hidden" do
      visit("/latest")
      expect(page).to have_css(".discord-member-list")

      find(".discord-channel-header [data-action-id='member-list']").click
      expect(page).to have_no_css(".discord-member-list")

      visit("/latest")
      expect(page).to have_css(".discord-channel-header [data-action-id='member-list']")
      expect(page).to have_no_css(".discord-member-list")
    end
  end

  describe "small screens" do
    def opens_channel_list_from_header
      visit("/chat/c/hangout/#{chat_channel.id}")

      header = find(".discord-channel-header")
      expect(header).to have_css(".discord-channel-header__name", text: "hangout")
      expect(page).to have_no_css(".d-header .home-logo-wrapper-outlet", visible: :visible)
      expect(page).to have_no_css(".c-routes.--channel > .c-navbar-container", visible: :visible)

      screenshot("#{yield}-closed")

      header.find(".discord-channel-header__menu").click
      panel = find(".hamburger-panel")
      expect(panel).to have_css(".sidebar-section-link[data-link-name='forum-#{category.slug}']")
      expect(panel).to have_css(".discord-server-header")
      expect(panel).to have_no_css(".discord-user-panel", visible: :visible)
      # Let the slide-in finish before the screenshot.
      expect(page).to have_css(".hamburger-panel .discord-server-header__name", visible: :visible)
      sleep 0.5 if ENV["DCCK_SCREENSHOTS"]
      screenshot(yield)

      panel.find(".sidebar-section-link[data-link-name='forum-#{category.slug}']").click
      expect(page).to have_current_path(%r{/c/#{category.slug}/#{category.id}})
      expect(page).to have_no_css(".hamburger-panel")

      header.find(".discord-channel-header__user").click
      menu = find(".user-menu-dropdown-wrapper .user-menu", visible: :visible)
      expect(menu).to have_css("#user-menu-button-profile")
      sleep 0.5 if ENV["DCCK_SCREENSHOTS"]
      screenshot("#{yield}-user-menu")

      # It covers the header, so it closes from the shade beside it.
      find(".header-cloak").click(x: 10, y: 300)
      expect(page).to have_no_css(".user-menu-dropdown-wrapper")
    end

    it "keeps the header's buttons on screen with a long title", mobile: true do
      topic =
        Fabricate(
          :post,
          topic:
            Fabricate(
              :topic,
              category:,
              title: "What are the very best campfire songs everyone should know",
            ),
        ).topic
      visit(topic.relative_url)

      header = find(".discord-channel-header")
      expect(header).to have_css(".discord-channel-header__user")
      right = page.evaluate_script(<<~JS)
        document.querySelector(".discord-channel-header__user").getBoundingClientRect().right
      JS
      expect(right).to be <= page.evaluate_script("window.innerWidth")
      screenshot("mobile-long-title")
    end

    it "slides the member list in from the right on phones", mobile: true do
      visit("/chat/c/hangout/#{chat_channel.id}")

      expect(page).to have_no_css(".discord-member-list")
      find(".discord-channel-header [data-action-id='member-list']").click
      list = find(".discord-member-list.--slide-in")
      expect(list).to have_css(".discord-member-list__member[data-username='#{admin.username}']")
      expect(page).to have_no_css("body.discord-member-list-open")
      sleep 0.5 if ENV["DCCK_SCREENSHOTS"]
      screenshot("mobile-member-list")

      list.find("[data-username='#{admin.username}'] .discord-member-list__name").click
      expect(page).to have_css(".user-card")
      expect(page).to have_no_css(".discord-member-list")
    end

    it "searches from the full search page on phones", mobile: true do
      visit("/latest")

      find(".discord-channel-header__search").click
      expect(page).to have_current_path(%r{^/search})
      expect(page).to have_css(".full-page-search")
      expect(page).to have_no_css(".discord-search-panel")
    end

    it "opens the channel list from the header on phones", mobile: true do
      opens_channel_list_from_header { "mobile" }
    end

    it "opens the channel list from the header in a narrow window" do
      resize_window(width: 700) { opens_channel_list_from_header { "narrow" } }
    end
  end
end

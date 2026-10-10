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

  def sidebar_group_chooser
    PageObjects::Components::SelectKit.new(
      ".form-kit__field[data-name='sidebarGroup'] .select-kit",
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
    form.submit

    expect(page).to have_current_path(%r{/c/secret-plans/\d+})
    created = Category.find_by(name: "secret-plans")
    expect(created.read_restricted).to eq(true)
    expect(created.category_groups.pluck(:group_id)).to contain_exactly(group.id)
    expect(channel_link("forum-secret-plans")).to be_present
  end

  it "creates a text channel in a new group typed into the group picker" do
    visit("/latest")
    open_create_modal

    form.field("type").select("text")
    sidebar_group_chooser.expand
    sidebar_group_chooser.search("Gaming")
    sidebar_group_chooser.select_row_by_value("Gaming")
    form.field("name").fill_in("lfg")
    form.submit

    expect(page).to have_current_path(%r{/chat/c/lfg/\d+})
    created = Chat::Channel.find_by(name: "lfg")
    expect(created.chatable.parent_category.slug).to eq("chat-channels")

    groups = theme.reload.settings[:sidebar_groups].value
    expect(groups).to eq(
      [{ "name" => "Gaming", "channels" => [{ "type" => "text", "id" => created.id }] }],
    )

    gaming = sidebar.find(".sidebar-section[data-section-name='discord-group-gaming']")
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

  it "mutes a text channel and moves it to a group from its menu" do
    theme.update_setting(
      :sidebar_groups,
      [{ "name" => "Hangouts", "channels" => [] }].to_json,
    )
    theme.save!

    visit("/latest")

    link = channel_link("text-hangout")
    link.hover
    link.find(".sidebar-section-hover-button").click
    find(".discord-action-menu .btn", text: "Mute").click

    expect(sidebar).to have_css(
      ".sidebar-section-link--muted[data-link-name='text-hangout']",
    )
    expect(chat_channel.membership_for(admin).reload.muted).to eq(true)

    link = channel_link("text-hangout")
    link.hover
    link.find(".sidebar-section-hover-button").click
    find(".discord-action-menu .btn", text: "Hangouts").click

    hangouts = sidebar.find(".sidebar-section[data-section-name='discord-group-hangouts']")
    expect(hangouts).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
  end

  it "renames a group from its heading menu" do
    theme.update_setting(:sidebar_groups, [{ "name" => "Old", "channels" => [] }].to_json)
    theme.save!

    visit("/latest")

    heading = sidebar.find(".sidebar-section[data-section-name='discord-group-old']")
    heading.find(".sidebar-section-header-wrapper").hover
    heading.find("[data-sidebar-action-id='groupMenu']").click
    find(".discord-action-menu .btn", text: "Rename group").click

    rename_form = PageObjects::Components::FormKit.new(".discord-rename-modal form")
    rename_form.field("name").fill_in("New")
    rename_form.submit

    expect(sidebar).to have_css(".sidebar-section[data-section-name='discord-group-new']")
    expect(theme.reload.settings[:sidebar_groups].value.first["name"]).to eq("New")
  end

  describe "header" do
    let(:header) { find(".discord-channel-header") }

    it "replaces core's header and chat's channel bar with the channel's own" do
      visit("/chat/c/hangout/#{chat_channel.id}")

      expect(page).to have_no_css(".d-header > .wrap", visible: :visible)
      expect(header).to have_css(".discord-channel-header__name", text: "hangout")
      expect(page).to have_css(".c-routes.--channel")
      expect(page).to have_no_css(".c-routes.--channel > .c-navbar-container", visible: :visible)
      screenshot("chat")

      header.find("[data-action-id='pins']").click
      expect(page).to have_current_path(%r{/chat/c/hangout/#{chat_channel.id}/pins})
    end

    it "shows the category" do
      category.update!(description: "Sit by the fire")
      visit("/c/#{category.slug}/#{category.id}")

      expect(header).to have_css(".discord-channel-header__name", text: "Lounge")
      expect(header).to have_css(".discord-channel-header__description", text: "Sit by the fire")
      screenshot("forum")
    end

    it "shows a topic's title over its category" do
      topic = Fabricate(:post, topic: Fabricate(:topic, category:, title: "Best campfire songs")).topic
      visit(topic.relative_url)

      expect(header).to have_css(".discord-channel-header__name", text: "Best campfire songs")
      expect(header).to have_css(".discord-channel-header__description", text: "Lounge")
      screenshot("topic")

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
          };
        })()
      JS

      expect(widths["outlet"]).to be_within(20).of(widths["window"])
      expect(widths["sidebar"]).to eq(0)
      expect(widths["sidebarRight"]).to be_within(1).of(widths["server"])
    end
  end

  describe "user panel" do
    it "opens the user menu from the foot of the sidebar" do
      visit("/latest")

      panel = find(".discord-user-panel")
      expect(panel).to have_css(".discord-user-panel__name", text: admin.username)

      panel.find(".discord-user-panel__me").click
      expect(page).to have_css(".discord-user-menu .user-menu .quick-access-panel")
      screenshot("user-menu")
    end

    it "offers log in and sign up when signed out" do
      Capybara.reset_sessions!
      visit("/latest")

      expect(page).to have_css(".discord-user-panel .discord-user-panel__login")
      expect(page).to have_css(".discord-user-panel .discord-user-panel__signup")
    end
  end
end

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

    find(".chat-header-icon").click
    expect(page).to have_current_path(%r{/chat})
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
end

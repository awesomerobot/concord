# Complete Discord Cancellation Kit

A theme component that makes Discourse feel like Discord.

It replaces the sidebar with one section where everything is a channel:

- **Categories** are forum channels: every category the user can see
- **Chat channels** are text channels, grouped under their category by default
- **Voice rooms** (voice plugin) are voice channels; clicking one joins it
- **Tags** are tag channels

Channels can be sorted into collapsible sections, kept in the
`sidebar_sections` setting. Anything not in a section is listed at the top with
no heading, like Discord. Each section heading has its own `+`, which opens the
modal with that section picked; admins can also pick the section in the modal.
Sections are saved through the admin theme-setting endpoint, so only admins can
change them, and others see changes on their next page load. (The setting used
to be `sidebar_groups`; a settings migration carries it over.)

The `+` next to the site name at the top opens a create-channel modal. It offers the
channel types the user is allowed to create, and a private toggle that limits
the channel to selected groups:

- Forum: a category whose permissions are set to the groups
- Text: a chat channel. Chat takes its access from a category, so each one
  gets its own backing category under the `chat_container_category` category
  (created if missing, and hidden from the list). Its members are auto-joined.
- Voice: a private room with the groups' current members added (up to 200).
  Later group members don't get access, since rooms have no group access.

The default panels (forum, chat) are both redirected to this one, so moving
between topics and chat doesn't swap the sidebar out. The admin and user
panels are left alone.

Not yet covered: a chat home page (DMs, friends list). That's coming to core.

## Menus

Every channel row has a `…` button on hover, and every section heading has one
next to its `+`. Items depend on the channel's kind and what the user may do:

- Forum: mark as read, notifications (all posts / default / mute), rename and
  delete for category editors
- Text: mark as read, notifications (all messages / only mentions / nothing),
  mute, rename and delete for staff
- Voice: rename and delete for the room's managers
- All: copy link, and for admins, move to section (including a new one,
  named on the spot)
- Section headings (admins): rename, move up, move down, delete

A channel's menu leads with mark as read, rename and copy link, then
notifications and move to section (a submenu of the sections, so it doesn't
lengthen the menu), with delete on its own at the end.

Core hides the row button on narrow touch screens, so phones don't get these
yet.

## Layout

Core's header contents are hidden at every width, and a Discord-style row
takes their place inside the same header: the server name over the channel
list, then the current channel's icon, name, description, actions and a search
button that opens core's search panel as a dropdown. Living inside core's
header keeps every height calculation built on it (chat, composer, sticky
elements) working. Chat's own channel bar is hidden; its threads, pins and
settings are in the row. A forum channel's settings (core's wrench) are there
too, for people who can edit the category. In a text channel the search
button opens chat's own message search for that channel instead of site search.
On phones it goes to core's full page search instead of the dropdown, as core's
own header does.

Below the `md` breakpoint (phones, and narrow desktop windows) the row starts
with a hamburger button that opens the channel list as core's slide-in panel,
with the server name and user panel in it. The button asks core's header to
toggle the panel, so its animation, scroll lock and close-on-tap-outside are
core's own. The row ends with the user's avatar (with its unread badge), which
opens core's user menu as a slide-in from the right, as core's mobile header
does; the user panel at the foot of the channel list is then only for signing
in.

The foot of the sidebar shows the current user; clicking opens the user
menu's profile tab on its own (status, presence, summary, activity,
preferences, log out). The bell beside it, carrying the unread badge, opens
core's user menu (notifications, messages, bookmarks) without that tab.
Signed-out visitors get log in and sign up buttons there. Core's sidebar
footer is hidden.

The main column fills the window beside the channel list. Topics are the
exception: the posts stay at core's reading width, with the timeline beside
them, and are centred in the space. The composer (when its preview is hidden)
starts where the topic does.

## Server menu

The site name at the top of the channel list opens a menu of the site-wide
pages core's header and sidebar used to link to: invite, admin, review (with
its pending count), about, FAQ or guidelines, groups, users, badges, and
keyboard shortcuts. The links are core's own community section links, so who
sees each one follows core's rules. Those pages (and each group and badge)
get their title in the header row, and the badges pages' own headings and the
group page's name are hidden so it isn't said twice.

## Member list

A panel down the right of the page, toggled by the people icon in the header
row (the choice is remembered per browser). Below the `md` breakpoint the same
icon slides it in from the right over the page instead; it starts closed and
closes on navigation or a tap beside it. It shows:

- on a voice channel, who's in the call first
- online members of each group in `member_list_roles` (admins and moderators
  by default), a section per role
- everyone else online, then offline

On a chat channel it covers the channel's members; elsewhere, everyone in the
user directory. "Online" means active in the last few minutes, from chat's
presence channel plus the who's-online plugin when installed. Members load 50
at a time as you scroll; a chat channel's first 250 load up front so its online
members can be found.

# Complete Discord Cancellation Kit

A theme component that makes Discourse feel like Discord.

It replaces the sidebar with one section where everything is a channel:

- **Categories** are forum channels: every category the user can see
- **Chat channels** are text channels, grouped under their category by default
- **Voice rooms** (voice plugin) are voice channels; clicking one joins it
- **Tags** are tag channels

Channels can be sorted under collapsible headings, kept in the
`sidebar_groups` setting. Anything not in a group is listed at the top with no
heading, like Discord. Each heading has its own `+`, which opens the modal with that group
picked; admins can also pick the group in the modal. Groups are saved through
the admin theme-setting endpoint, so only admins can change them, and others
see changes on their next page load.

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

Every channel row has a `…` button on hover, and every group heading has one
next to its `+`. Items depend on the channel's kind and what the user may do:

- Forum: mark as read, notifications (all posts / default / mute), rename and
  delete for category editors
- Text: mark as read, notifications (all messages / only mentions / nothing),
  mute, rename and delete for staff
- Voice: rename and delete for the room's managers
- All: copy link, and for admins, move to group
- Group headings (admins): rename, move up, move down, delete

Core hides the row button on narrow touch screens, so phones don't get these
yet.

## Layout

On wide screens, core's header contents are hidden and a Discord-style row
takes their place inside the same header: the server name over the channel
list, then the current channel's icon, name, description, actions and a search
button that opens core's search panel as a dropdown. Living inside core's header keeps every height calculation built on it
(chat, composer, sticky elements) working. Chat's own channel bar is hidden;
its threads, pins, members and settings are in the row. Below the `md`
breakpoint core's header stays, since it holds the button that opens the
sidebar.

The foot of the sidebar shows the current user; clicking opens core's user
menu (notifications, messages, bookmarks, profile). Signed-out visitors get
log in and sign up buttons there. Core's sidebar footer is hidden.

## Member list

A panel down the right of the page, toggled by the people icon in the header
row (the choice is remembered per browser). It shows:

- on a voice channel, who's in the call first
- online members of each group in `member_list_roles` (admins and moderators
  by default), a section per role
- everyone else online, then offline

On a chat channel it covers the channel's members; elsewhere, everyone in the
user directory. "Online" means active in the last few minutes, from chat's
presence channel plus the who's-online plugin when installed. Members load 50
at a time as you scroll; a chat channel's first 250 load up front so its online
members can be found.

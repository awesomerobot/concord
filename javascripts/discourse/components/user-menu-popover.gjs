import UserMenu from "discourse/components/user-menu/menu";

// Core's user menu (notifications, messages, bookmarks, profile), opened from
// the user panel instead of the header.
const UserMenuPopover = <template>
  <div class="discord-user-menu">
    <UserMenu @closeUserMenu={{@close}} />
  </div>
</template>;

export default UserMenuPopover;

import UserMenu from "discourse/components/user-menu/menu";

// Core's user menu (notifications, messages, bookmarks), opened from the user
// panel instead of the header. Its profile tab is behind the gear instead.
const UserMenuPopover = <template>
  <div class="discord-user-menu">
    <UserMenu @closeUserMenu={{@close}} />
  </div>
</template>;

export default UserMenuPopover;

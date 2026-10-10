import SearchMenu from "discourse/components/search-menu";

// Core's header search panel, opened from the header row's search button.
const SearchPopover = <template>
  <div aria-live="polite" class="search-menu glimmer-search-menu">
    <div class="menu-panel drop-down search-menu-panel discord-search-panel">
      <SearchMenu
        @autofocusInput={{true}}
        @inlineResults={{true}}
        @location="header"
        @onClose={{@close}}
        @searchInputId="discord-search-input"
      />
    </div>
  </div>
</template>;

export default SearchPopover;

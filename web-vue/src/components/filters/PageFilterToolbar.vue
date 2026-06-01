<!--
  PageFilterToolbar.vue — shared filter toolbar used across teacher
  pages (Jadwal, Presensi, Buku Nilai, etc.).

  Layout:
    ┌─────────────────────────────────────────────────────────────┐
    │ [chip] [chip] [chip]   │  [segmented]   ───   [🔎 search]   │
    └─────────────────────────────────────────────────────────────┘

  Slots:
    - #chips       — AppFilterChip row (required usage)
    - #segmented   — optional SegmentedControl block (with a left divider)
    - #search      — optional custom search; otherwise the built-in
                     search input is rendered when `searchPlaceholder`
                     is set (or v-model:search is bound).

  All children sit inside a white rounded card with a thin slate border,
  matching the Schedule/Presensi look.
-->
<script setup lang="ts">
import { computed, useSlots } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    /** Two-way bound search value (use `v-model:search`). */
    search?: string;
    /** Placeholder for the built-in search input. */
    searchPlaceholder?: string;
    /**
     * Hide the search input even if a placeholder is provided.
     * Useful when the parent wants to compose a fully custom search
     * via the `#search` slot.
     */
    hideDefaultSearch?: boolean;
    /** Minimum width of the built-in search input (px). */
    searchMinWidth?: number;
  }>(),
  {
    search: '',
    searchPlaceholder: '',
    hideDefaultSearch: false,
    searchMinWidth: 200,
  },
);

const emit = defineEmits<{ 'update:search': [string] }>();

const slots = useSlots();
const hasSegmented = computed(() => !!slots.segmented);
const hasSearchSlot = computed(() => !!slots.search);

/**
 * Show the built-in search input when:
 *   - no custom #search slot was passed
 *   - hideDefaultSearch is false
 *   - and either a placeholder or a v-model is supplied
 */
const showBuiltinSearch = computed(
  () =>
    !hasSearchSlot.value &&
    !props.hideDefaultSearch &&
    (!!props.searchPlaceholder || props.search !== undefined),
);

function onSearchInput(e: Event) {
  emit('update:search', (e.target as HTMLInputElement).value);
}
</script>

<template>
  <section class="bg-white border border-slate-200 rounded-2xl p-3">
    <div class="flex items-center gap-2 flex-wrap">
      <!-- Filter chips slot (AppFilterChip / custom chips). -->
      <slot name="chips" />

      <!-- Optional segmented control with a divider in front of it. -->
      <template v-if="hasSegmented">
        <span class="hidden sm:block w-px h-7 bg-slate-200"></span>
        <slot name="segmented" />
      </template>

      <span class="flex-1"></span>

      <!-- Custom search (slot) takes precedence over the built-in one. -->
      <slot name="search" />

      <div
        v-if="showBuiltinSearch"
        class="inline-flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5"
        :style="{ minWidth: `${searchMinWidth}px` }"
      >
        <NavIcon name="search" :size="13" class="text-slate-400" />
        <input
          :value="search"
          type="search"
          :placeholder="searchPlaceholder"
          class="bg-transparent border-0 outline-none flex-1 text-[12px] font-medium text-slate-900 placeholder:text-slate-400"
          @input="onSearchInput"
        />
      </div>
    </div>
  </section>
</template>

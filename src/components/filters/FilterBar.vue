<!--
  FilterBar.vue — flexible filter-bar shell for report/list views.

  The repeated "row of dropdowns / status+periode filters + a search box"
  seen in AdminAttendanceReportView, AdminFinanceBillsView and
  AdminGradeRecapView. Deliberately a *styled container with slots* — not
  an opinionated control set — so each view drops in whatever filter
  controls (SegmentedControl, native <select>, AppFilterChip, etc.) it
  needs.

  Layout:
    ┌────────────────────────────────────────────────────────────┐
    │  [ default slot: filter controls ]      │  [🔎 search ]     │
    └────────────────────────────────────────────────────────────┘
  White rounded card with a thin slate border — matches the KPI-strip /
  PageFilterToolbar look already used across the admin views.

  Slots:
    - default — filter controls (dropdowns, chips, segmented, …)

  Search:
    - Bind `v-model:search` to render the built-in search input on the
      right. Omit the binding (and `searchPlaceholder`) to hide it.
    - For a fully custom search, put it in the default slot and leave the
      built-in one off.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    /** Two-way bound search value (use `v-model:search`). */
    search?: string;
    /** Placeholder for the built-in search input. */
    searchPlaceholder?: string;
    /** Hide the built-in search input even if a value/placeholder is set. */
    hideSearch?: boolean;
    /** Minimum width of the built-in search input (px). */
    searchMinWidth?: number;
  }>(),
  {
    search: '',
    searchPlaceholder: '',
    hideSearch: false,
    searchMinWidth: 180,
  },
);

const emit = defineEmits<{ 'update:search': [string] }>();

// Render the built-in search when not explicitly hidden and the parent
// opted in (either a placeholder or a bound value).
const showSearch = computed(
  () =>
    !props.hideSearch &&
    (!!props.searchPlaceholder || props.search.length > 0),
);
</script>

<template>
  <div
    class="bg-white border border-slate-200 rounded-2xl shadow-sm px-3 py-2.5 flex items-center gap-3 flex-wrap"
  >
    <div class="flex items-center gap-2 flex-wrap flex-1 min-w-0">
      <slot />
    </div>

    <label
      v-if="showSearch"
      class="flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5"
      :style="{ minWidth: `${searchMinWidth}px` }"
    >
      <NavIcon name="search" :size="14" class="text-slate-400 flex-shrink-0" />
      <input
        :value="search"
        type="text"
        :placeholder="searchPlaceholder"
        class="flex-1 min-w-0 text-[13px] text-slate-900 outline-none placeholder-slate-400 bg-transparent"
        @input="emit('update:search', ($event.target as HTMLInputElement).value)"
      />
    </label>
  </div>
</template>

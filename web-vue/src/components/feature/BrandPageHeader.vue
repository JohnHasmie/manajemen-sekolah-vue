<!--
  BrandPageHeader.vue — gradient header for admin CRUD screens.
  Port of `lib/core/widgets/brand_page_header.dart` /
  `lib/core/widgets/teacher_page_header.dart`.

  Layout:
    ┌────────────────────────────────────────────────┐
    │ Title                                          │
    │ Subtitle (count)                               │
    │                                                │
    │ ┌──────────────────────┐  ┌──┐                 │
    │ │ Search…              │  │⨯│                 │
    │ └──────────────────────┘  └──┘                 │
    │ [chip] [chip] [chip] [Hapus semua]             │
    └────────────────────────────────────────────────┘

  Themed by `primaryColor` (role color). The card sits on top of the
  AppShell topbar, so this is a content header, not a chrome bar.
-->
<script setup lang="ts">
import { computed } from 'vue';
import SearchBar from '@/components/filters/SearchBar.vue';
import ActiveFilterChips, {
  type FilterChip,
} from '@/components/filters/ActiveFilterChips.vue';

const props = withDefaults(
  defineProps<{
    title: string;
    subtitle?: string;
    primaryColor: string;
    searchValue?: string;
    searchPlaceholder?: string;
    activeFilters?: FilterChip[];
    hasActiveFilter?: boolean;
  }>(),
  {
    subtitle: '',
    searchValue: '',
    searchPlaceholder: 'Cari…',
    activeFilters: () => [],
    hasActiveFilter: false,
  },
);

defineEmits<{
  'update:searchValue': [string];
  search: [string];
  filterClick: [];
  removeFilter: [key: string];
  clearAllFilters: [];
}>();

const gradient = computed(() => ({
  backgroundImage: `linear-gradient(135deg, ${props.primaryColor} 0%, ${props.primaryColor}dd 100%)`,
}));
</script>

<template>
  <section
    class="rounded-card text-white shadow-card p-lg space-y-md"
    :style="gradient"
  >
    <div>
      <h1 class="text-xl sm:text-2xl font-bold">{{ title }}</h1>
      <p v-if="subtitle" class="text-sm opacity-90 mt-0.5">{{ subtitle }}</p>
    </div>

    <div class="flex items-center gap-2">
      <div class="flex-1 [&_input]:!bg-white/95 [&_input]:!border-transparent [&_input]:!text-slate-900">
        <SearchBar
          :model-value="searchValue"
          :placeholder="searchPlaceholder"
          @update:model-value="$emit('update:searchValue', $event)"
          @search="$emit('search', $event)"
        />
      </div>
      <button
        type="button"
        class="relative inline-flex items-center justify-center w-10 h-10 rounded-xl bg-white/15 hover:bg-white/25 text-white flex-shrink-0"
        aria-label="Filter"
        @click="$emit('filterClick')"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="w-4 h-4"
        >
          <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3" />
        </svg>
        <span
          v-if="hasActiveFilter"
          class="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-status-warning"
        />
      </button>
    </div>

    <div
      v-if="activeFilters.length"
      class="bg-white/10 rounded-xl p-2 [&_button]:!bg-white/95 [&_span]:!bg-white/95 [&_span]:!text-slate-700"
    >
      <ActiveFilterChips
        :chips="activeFilters"
        @remove="$emit('removeFilter', $event)"
        @clear-all="$emit('clearAllFilters')"
      />
    </div>
  </section>
</template>

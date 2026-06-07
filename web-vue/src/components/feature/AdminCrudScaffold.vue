<!--
  AdminCrudScaffold.vue — shared admin manajemen-data shell.

  Mirrors the chrome of the new admin hubs (Jadwal / Keuangan / Rapor):
    1. BrandPageHeader (role-admin gradient banner with kicker + title + meta)
    2. KpiStripCards (4-up tinted icon-square cards) — optional
    3. PageFilterToolbar with per-facet AppFilterChip buttons (passed via slot)
    4. AsyncView body (loading / error / empty / content)
    5. Sticky bulk-action bar at bottom-center when items are selected
    6. Floating + FAB anchored bottom-right

  Slots:
    header-actions  — right of the gradient banner (AdminDataMenu, etc.)
    filter-chips    — AppFilterChip buttons inside PageFilterToolbar #chips
    bulk-actions    — buttons inside the sticky bulk-action bar
    default         — the list/grid body

  Replaces the older title-bar/search-row scaffold so the 4 Manajemen
  Data pages (Siswa / Guru / Kelas / Mapel) match the design pattern
  of the rest of the admin app.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    title: string;
    kicker?: string;
    meta?: string;
    /** Optional KPI strip data (4-up). Omit to hide. */
    kpiCards?: KpiCard[];
    searchPlaceholder?: string;
    state: AsyncState<unknown>;
    emptyTitle?: string;
    emptyDescription?: string;
    selectedCount?: number;
    /** Hide the floating + FAB entirely (AY read-only, etc.). */
    hideAddFab?: boolean;
    fabLabel?: string;
    /** Number of active filters — shown on the "Bersihkan" button. */
    activeFilterCount?: number;
  }>(),
  {
    kicker: '',
    meta: '',
    kpiCards: () => [],
    emptyDescription: '',
    selectedCount: 0,
    hideAddFab: false,
    activeFilterCount: 0,
  },
);

const { t } = useI18n();
// Translated default placeholders — only kick in when the host page
// doesn't pass an explicit value.
const searchPlaceholderText = computed(() =>
  props.searchPlaceholder?.trim() ? props.searchPlaceholder : `${t('common.search')}…`,
);
const emptyTitleText = computed(() =>
  props.emptyTitle?.trim() ? props.emptyTitle : t('common.emptyTitle'),
);
const fabLabelText = computed(() =>
  props.fabLabel?.trim() ? props.fabLabel : t('common.add'),
);

const emit = defineEmits<{
  search: [string];
  addClick: [];
  bulkClear: [];
  clearAllFilters: [];
  retry: [];
  'update:search': [string];
}>();

// PageFilterToolbar uses v-model:search; we bridge with @search for back-compat.
const searchValue = ref('');
watch(searchValue, (v) => {
  emit('search', v);
  emit('update:search', v);
});
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- Gradient banner (admin) -->
    <BrandPageHeader
      role="admin"
      :kicker="kicker"
      :title="title"
      :meta="meta"
    >
      <slot name="header-actions" />
    </BrandPageHeader>

    <!-- KPI strip (optional) -->
    <KpiStripCards v-if="kpiCards.length > 0" :cards="kpiCards" />

    <!-- Toolbar — per-facet chips on the left, search on the right -->
    <PageFilterToolbar
      v-model:search="searchValue"
      :search-placeholder="searchPlaceholderText"
      :search-min-width="240"
    >
      <template #chips>
        <slot name="filter-chips" />
        <button
          v-if="activeFilterCount > 0"
          type="button"
          class="text-[11px] font-bold text-slate-500 hover:text-role-admin px-2"
          @click="emit('clearAllFilters')"
        >
          {{ t('common.reset') }} ({{ activeFilterCount }})
        </button>
      </template>
    </PageFilterToolbar>

    <!-- Body -->
    <AsyncView
      :state="state"
      :empty-title="emptyTitleText"
      :empty-description="emptyDescription"
      min-height="20rem"
      @retry="emit('retry')"
    >
      <template #default>
        <slot />
      </template>
    </AsyncView>

    <!-- Sticky bulk action bar -->
    <section
      v-if="selectedCount > 0"
      class="fixed bottom-4 left-1/2 -translate-x-1/2 z-30 bg-white border border-slate-200 rounded-2xl shadow-lg p-3 flex items-center gap-2 max-w-2xl w-[calc(100%-2rem)]"
    >
      <p class="text-[11px] font-bold text-slate-700 flex-1">
        {{ t('common.selected', { count: selectedCount }) }}
      </p>
      <Button variant="secondary" size="sm" @click="emit('bulkClear')">
        {{ t('common.cancel') }}
      </Button>
      <slot name="bulk-actions" />
    </section>

    <!-- Floating + FAB (bottom-right) -->
    <Button
      v-if="!hideAddFab"
      variant="primary"
      class="fixed bottom-6 right-6 z-30 shadow-lg shadow-role-admin/30"
      @click="emit('addClick')"
    >
      <NavIcon name="plus" :size="14" />
      {{ fabLabelText }}
    </Button>
  </div>
</template>

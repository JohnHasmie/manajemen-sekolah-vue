<!--
  AdminTutoring2KelompokView.vue — greenfield "Kelompok Belajar" list.

  Mirrors AdminTutoring2ProgramsView.vue shape 1:1:
  BrandPageHeader → KpiStripCards → PageFilterToolbar + AppFilterChip
  → AsyncView → table → floating "+ Kelompok baru" CTA.

  Data path: `useDataRefresh(loader)` → `{ state, reload }`.
  Filters + academic-year change trigger reload.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const search = ref('');
const programFilter = ref<string>(''); // '' = Semua
const termFilter = ref<string>(''); // '' = Semua
const tutorFilter = ref<string>(''); // '' = Semua

const { t } = useI18n();

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listGroups({
    per_page: 50,
    status: undefined,
    program_id: programFilter.value || undefined,
    term_id: termFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
  });
  // Client-side search — listGroups has no `search` param yet.
  const q = debouncedSearch.value.trim().toLowerCase();
  return q ? items.filter((g) => g.name.toLowerCase().includes(q)) : items;
});

watch([debouncedSearch, programFilter, termFilter, tutorFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelLearningGroup[];
  const privateCount = items.filter((g) => g.kind === 'private').length;
  const totalUtil = items.reduce((sum, g) => {
    if (!g.capacity || g.capacity <= 0) return sum;
    return sum + ((g.seated_count ?? 0) / g.capacity);
  }, 0);
  const withCapacity = items.filter((g) => g.capacity && g.capacity > 0).length;
  const avgUtil = withCapacity > 0 ? Math.round((totalUtil / withCapacity) * 100) : 0;
  const fullCount = items.filter((g) => (g.seated_count ?? 0) >= (g.capacity ?? 0) && (g.capacity ?? 0) > 0).length;
  return [
    { icon: 'users', label: t('tutoring2.admin.groups.kpiGroups'), value: String(items.length) },
    { icon: 'user', label: t('tutoring2.admin.groups.kpiPrivates'), value: String(privateCount) },
    { icon: 'chart-bar', label: t('tutoring2.admin.groups.kpiAvgUtilization'), value: `${avgUtil}%` },
    { icon: 'circle-check', label: t('tutoring2.admin.groups.kpiFull'), value: String(fullCount), tone: fullCount > 0 ? 'amber' : undefined },
  ];
});

function statusPillTone(status: BimbelLearningGroup['status']): StatusBadgeTone {
  switch (status) {
    case 'active': return 'success';
    case 'draft': return 'neutral';
    case 'closed': return 'neutral';
  }
}

function statusLabel(status: BimbelLearningGroup['status']): string {
  return t(`tutoring2.status.${status}`);
}

function shortId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.length > 8 ? id.slice(0, 8) : id;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.groups.title')"
      :meta="state.status === 'content'
        ? `${(state.data as BimbelLearningGroup[]).length} ${t('tutoring2.common.group').toLowerCase()} · ${(state.data as BimbelLearningGroup[]).filter((g) => g.kind === 'private').length} ${t('tutoring2.admin.groups.kpiPrivates').toLowerCase()}`
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.groups.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.program')"
          :value="programFilter ? shortId(programFilter) : t('tutoring2.common.all')"
          icon-name="book"
          :active="!!programFilter"
          @click="programFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.term')"
          :value="termFilter ? shortId(termFilter) : t('tutoring2.common.all')"
          icon-name="calendar"
          :active="!!termFilter"
          @click="termFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.tutor')"
          :value="tutorFilter ? shortId(tutorFilter) : t('tutoring2.common.all')"
          icon-name="user"
          :active="!!tutorFilter"
          @click="tutorFilter = ''"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.groups.emptyTitle')"
      :empty-description="t('tutoring2.admin.groups.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.group') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.classLabel') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.capacity') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.tutor') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="g in (data as BimbelLearningGroup[])"
                :key="g.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ g.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ g.kind_label ?? (g.kind === 'private' ? t('tutoring2.admin.groups.kindPrivate') : t('tutoring2.admin.groups.kindGroup')) }}</td>
                <td class="px-4 py-3 font-mono text-2xs text-slate-500">{{ shortId(g.program_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ g.seated_count ?? 0 }} / {{ g.capacity }}</td>
                <td class="px-4 py-3 font-mono text-2xs text-slate-500">{{ shortId(g.tutor_id) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="g.status_label ?? statusLabel(g.status)" :tone="statusPillTone(g.status)" uppercase />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.groups.newCta') }}
    </button>
  </div>
</template>

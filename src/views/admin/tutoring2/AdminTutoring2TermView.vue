<!--
  AdminTutoring2TermView.vue — greenfield "Term / Batch" list.

  Mirrors AdminTutoring2ProgramsView.vue shape 1:1. Backend hasn't
  exposed /tutoring-v2/terms yet (BE-1 pending), so this MVP derives
  the term list from unique `term_id` values on learning groups. When
  BE ships the endpoint we swap the loader and drop the derivation.
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
import type { StatusBadgeTone } from '@/types/status-badge';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();

// Local derived shape until BE-1 ships /tutoring-v2/terms.
interface BimbelTermRow {
  id: string;
  name: string;
  start_date: string | null;
  end_date: string | null;
  status: 'draft' | 'active' | 'closed';
  status_label: string;
  groups_count: number;
}

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'draft' | 'active' | 'closed'
const yearFilter = ref<string>(''); // '' = Semua

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

// TODO WEB-3+ add TutoringBimbelService.listTerms once BE-1 exposes /tutoring-v2/terms
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listGroups({ per_page: 50 });
  const byTerm = new Map<string, BimbelLearningGroup[]>();
  for (const g of items) {
    if (!g.term_id) continue;
    const arr = byTerm.get(g.term_id) ?? [];
    arr.push(g);
    byTerm.set(g.term_id, arr);
  }
  const terms: BimbelTermRow[] = Array.from(byTerm.entries()).map(([id, groups]) => ({
    id,
    name: `Term ${id.length > 8 ? id.slice(0, 8) : id}`,
    start_date: null,
    end_date: null,
    status: 'draft',
    status_label: t('tutoring2.status.draft'),
    groups_count: groups.length,
  }));
  const q = debouncedSearch.value.trim().toLowerCase();
  let rows = q ? terms.filter((row) => row.name.toLowerCase().includes(q)) : terms;
  if (statusFilter.value) {
    rows = rows.filter((row) => row.status === statusFilter.value);
  }
  return rows;
});

watch([debouncedSearch, statusFilter, yearFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelTermRow[];
  const active = items.filter((row) => row.status === 'active').length;
  const closed = items.filter((row) => row.status === 'closed').length;
  const draft = items.filter((row) => row.status === 'draft').length;
  const groupsTotal = items.reduce((sum, row) => sum + (row.groups_count ?? 0), 0);
  return [
    { icon: 'circle-check', label: t('tutoring2.admin.term.kpiActive'), value: String(active) },
    { icon: 'flag', label: t('tutoring2.admin.term.kpiClosed'), value: String(closed) },
    { icon: 'file-pencil', label: t('tutoring2.admin.term.kpiDraft'), value: String(draft), tone: draft > 0 ? 'amber' : undefined },
    { icon: 'users', label: t('tutoring2.admin.term.kpiGroupsTotal'), value: String(groupsTotal) },
  ];
});

function statusPillTone(status: BimbelTermRow['status']): StatusBadgeTone {
  switch (status) {
    case 'active': return 'success';
    case 'draft': return 'neutral';
    case 'closed': return 'neutral';
  }
}

function formatDate(d: string | null): string {
  return d ?? '—';
}

const termCount = computed(() =>
  state.value.status === 'content' ? (state.value.data as BimbelTermRow[]).length : 0,
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.term.title')"
      :meta="state.status === 'content' ? t('tutoring2.common.metaTermsDetected', { count: termCount }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.term.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'active'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.year')"
          :value="yearFilter || t('tutoring2.common.all')"
          icon-name="calendar"
          :active="!!yearFilter"
          @click="yearFilter = yearFilter ? '' : String(new Date().getFullYear())"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.term.emptyTitle')"
      empty-description="Klik + untuk membuat term baru — rombongan kelompok belajar per periode."
      @retry="reload"
    >
      <!-- TODO i18n key: term empty-description -->
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.term') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.startDate') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.endDate') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.group') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in (data as BimbelTermRow[])"
                :key="row.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ row.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatDate(row.start_date) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatDate(row.end_date) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="row.status_label" :tone="statusPillTone(row.status)" uppercase />
                </td>
                <td class="px-4 py-3 text-slate-600">{{ row.groups_count }} {{ t('tutoring2.common.group').toLowerCase() }}</td>
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
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.term.newCta') }}
    </button>
  </div>
</template>

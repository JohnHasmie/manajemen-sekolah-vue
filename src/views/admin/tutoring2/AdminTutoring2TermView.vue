<!--
  AdminTutoring2TermView.vue — greenfield "Term / Batch" list.

  Mirrors AdminTutoring2ProgramsView.vue shape 1:1. Backend hasn't
  exposed /tutoring-v2/terms yet (BE-1 pending), so this MVP derives
  the term list from unique `term_id` values on learning groups. When
  BE ships the endpoint we swap the loader and drop the derivation.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
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
    status_label: 'Draft',
    groups_count: groups.length,
  }));
  const q = debouncedSearch.value.trim().toLowerCase();
  let rows = q ? terms.filter((t) => t.name.toLowerCase().includes(q)) : terms;
  if (statusFilter.value) {
    rows = rows.filter((t) => t.status === statusFilter.value);
  }
  return rows;
});

watch([debouncedSearch, statusFilter, yearFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelTermRow[];
  const active = items.filter((t) => t.status === 'active').length;
  const closed = items.filter((t) => t.status === 'closed').length;
  const draft = items.filter((t) => t.status === 'draft').length;
  const groupsTotal = items.reduce((sum, t) => sum + (t.groups_count ?? 0), 0);
  return [
    { icon: 'circle-check', label: 'Term aktif', value: String(active) },
    { icon: 'flag', label: 'Selesai', value: String(closed) },
    { icon: 'file-pencil', label: 'Draft', value: String(draft), tone: draft > 0 ? 'amber' : undefined },
    { icon: 'users', label: 'Total kelompok', value: String(groupsTotal) },
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
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      kicker="Admin Bimbel"
      title="Term & Batch"
      :meta="state.status === 'content' ? `${(state.data as BimbelTermRow[]).length} term terdeteksi` : 'Memuat…'"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" search-placeholder="Cari term…">
      <template #chips>
        <AppFilterChip
          label="Status"
          :value="statusFilter || 'Semua'"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'active'"
        />
        <AppFilterChip
          label="Tahun"
          :value="yearFilter || 'Semua'"
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
      empty-title="Belum ada term"
      empty-description="Klik + untuk membuat term baru — rombongan kelompok belajar per periode."
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">Term</th>
                <th class="px-4 py-3 font-bold">Mulai</th>
                <th class="px-4 py-3 font-bold">Selesai</th>
                <th class="px-4 py-3 font-bold">Status</th>
                <th class="px-4 py-3 font-bold">Kelompok</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="t in (data as BimbelTermRow[])"
                :key="t.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ t.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatDate(t.start_date) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatDate(t.end_date) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="t.status_label" :tone="statusPillTone(t.status)" uppercase />
                </td>
                <td class="px-4 py-3 text-slate-600">{{ t.groups_count }} kelompok</td>
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
      <span aria-hidden="true">+</span> Term baru
    </button>
  </div>
</template>

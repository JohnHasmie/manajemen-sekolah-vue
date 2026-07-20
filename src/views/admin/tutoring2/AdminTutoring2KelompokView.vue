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
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
} from '@/services/tutoring-bimbel.service';

const search = ref('');
const programFilter = ref<string>(''); // '' = Semua
const termFilter = ref<string>(''); // '' = Semua
const tutorFilter = ref<string>(''); // '' = Semua

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
    { icon: 'users', label: 'Kelompok', value: String(items.length) },
    { icon: 'user', label: '1-on-1', value: String(privateCount) },
    { icon: 'chart-bar', label: 'Rata utilisasi', value: `${avgUtil}%` },
    { icon: 'circle-check', label: 'Penuh', value: String(fullCount), tone: fullCount > 0 ? 'amber' : undefined },
  ];
});

function statusChipTone(status: BimbelLearningGroup['status']): string {
  switch (status) {
    case 'active': return 'bg-success-soft text-success';
    case 'draft': return 'bg-slate-100 text-slate-500';
    case 'closed': return 'bg-slate-100 text-slate-400 line-through';
  }
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
      kicker="Admin Bimbel"
      title="Kelompok Belajar"
      :meta="state.status === 'content'
        ? `${(state.data as BimbelLearningGroup[]).length} kelompok · ${(state.data as BimbelLearningGroup[]).filter((g) => g.kind === 'private').length} privat`
        : 'Memuat…'"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" search-placeholder="Cari kelompok…">
      <template #chips>
        <AppFilterChip
          label="Program"
          :value="programFilter ? shortId(programFilter) : 'Semua'"
          icon-name="book"
          :active="!!programFilter"
          @click="programFilter = ''"
        />
        <AppFilterChip
          label="Term"
          :value="termFilter ? shortId(termFilter) : 'Semua'"
          icon-name="calendar"
          :active="!!termFilter"
          @click="termFilter = ''"
        />
        <AppFilterChip
          label="Tutor"
          :value="tutorFilter ? shortId(tutorFilter) : 'Semua'"
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
      empty-title="Belum ada kelompok"
      empty-description="Klik + untuk membuat kelompok belajar baru."
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">Kelompok</th>
                <th class="px-4 py-3 font-bold">Kelas</th>
                <th class="px-4 py-3 font-bold">Program</th>
                <th class="px-4 py-3 font-bold">Kapasitas</th>
                <th class="px-4 py-3 font-bold">Tutor</th>
                <th class="px-4 py-3 font-bold">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="g in (data as BimbelLearningGroup[])"
                :key="g.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ g.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ g.kind_label ?? (g.kind === 'private' ? '1-on-1' : 'Grup') }}</td>
                <td class="px-4 py-3 font-mono text-2xs text-slate-500">{{ shortId(g.program_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ g.seated_count ?? 0 }} / {{ g.capacity }}</td>
                <td class="px-4 py-3 font-mono text-2xs text-slate-500">{{ shortId(g.tutor_id) }}</td>
                <td class="px-4 py-3">
                  <span class="inline-block rounded-full px-2 py-0.5 text-2xs font-bold uppercase tracking-wide" :class="statusChipTone(g.status)">
                    {{ g.status_label ?? g.status }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      type="button"
      class="fixed bottom-6 right-6 z-30 flex items-center gap-2 rounded-full bg-brand-cobalt px-5 py-3 text-sm font-bold text-white shadow-lg transition hover:brightness-110"
    >
      <span aria-hidden="true">+</span> Kelompok baru
    </button>
  </div>
</template>

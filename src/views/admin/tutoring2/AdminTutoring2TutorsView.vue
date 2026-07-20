<!--
  AdminTutoring2TutorView.vue — greenfield "Tutor & Staf" list.

  BE-2..7 doesn't ship a dedicated tutor endpoint (a tutor is just a
  `teachers` row assigned to a learning group). For WEB-3 MVP we
  derive the tutor set from `listGroups({})`, taking the unique
  non-null `tutor_id` values and showing a placeholder-oriented
  table until BE-later gives us `/tutoring-v2/tutors`.

  Mirrors AdminTutoring2ProgramsView shape:
    1. `BrandPageHeader`
    2. `KpiStripCards` — 4 tiles
    3. `PageFilterToolbar` + `AppFilterChip`s
    4. `AsyncView` → white rounded-3xl table card
    5. Floating "+ Tambah tutor" CTA.
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

// TODO WEB-3+ add /tutoring-v2/tutors endpoint (BE exposes school teachers filtered to those assigned to bimbel groups); MVP derives from group.tutor_id

const search = ref('');
const peranFilter = ref<string>(''); // '' | 'active' | 'staf'
const spesialisasiFilter = ref<string>(''); // nominal for MVP

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listGroups({});
  return items;
});

watch([debouncedSearch, peranFilter, spesialisasiFilter], () => reload());
useAcademicYearWatcher(reload);

// Derived: one row per unique non-null tutor_id, plus a count of the
// groups they lead. Placeholder columns (spesialisasi/tarif/kehadiran)
// wait on the future /tutoring-v2/tutors endpoint.
interface TutorRow {
  tutor_id: string;
  group_count: number;
}

const tutorRows = computed<TutorRow[]>(() => {
  const groups = (state.value.status === 'content' ? state.value.data : []) as BimbelLearningGroup[];
  const counts = new Map<string, number>();
  for (const g of groups) {
    if (!g.tutor_id) continue;
    counts.set(g.tutor_id, (counts.get(g.tutor_id) ?? 0) + 1);
  }
  const rows: TutorRow[] = Array.from(counts.entries()).map(([tutor_id, group_count]) => ({
    tutor_id,
    group_count,
  }));
  const needle = debouncedSearch.value.trim().toLowerCase();
  if (!needle) return rows;
  return rows.filter((r) => r.tutor_id.toLowerCase().includes(needle));
});

const uniqueTutorCount = computed(() => {
  const groups = (state.value.status === 'content' ? state.value.data : []) as BimbelLearningGroup[];
  const set = new Set<string>();
  for (const g of groups) {
    if (g.tutor_id) set.add(g.tutor_id);
  }
  return set.size;
});

const kpiCards = computed<KpiCard[]>(() => {
  return [
    { icon: 'user', label: 'Total tutor', value: String(uniqueTutorCount.value) },
    { icon: 'briefcase', label: 'Staf', value: '0' },
    { icon: 'circle-check', label: 'Hadir hari ini', value: '0' },
    { icon: 'coffee', label: 'Cuti/izin', value: '0' },
  ];
});

function shortId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      kicker="Admin Bimbel"
      title="Tutor & Staf"
      :meta="state.status === 'content' ? `${uniqueTutorCount} tutor` : 'Memuat…'"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" search-placeholder="Cari tutor…">
      <template #chips>
        <AppFilterChip
          label="Peran"
          :value="peranFilter || 'Semua'"
          icon-name="user"
          :active="!!peranFilter"
          @click="peranFilter = peranFilter ? '' : 'active'"
        />
        <AppFilterChip
          label="Spesialisasi"
          :value="spesialisasiFilter || 'Semua'"
          icon-name="tag"
          :active="!!spesialisasiFilter"
          @click="spesialisasiFilter = ''"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      empty-title="Belum ada tutor"
      empty-description="Klik + untuk menambah tutor baru."
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">Nama</th>
                <th class="px-4 py-3 font-bold">Spesialisasi</th>
                <th class="px-4 py-3 font-bold">Kelompok</th>
                <th class="px-4 py-3 font-bold">Tarif</th>
                <th class="px-4 py-3 font-bold">Kehadiran</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in tutorRows"
                :key="r.tutor_id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <!-- TODO WEB-3+ join with teachers.name once /tutoring-v2/tutors exposes it -->
                <td class="px-4 py-3 font-bold text-slate-900">{{ shortId(r.tutor_id) }}</td>
                <td class="px-4 py-3 text-slate-400">—</td>
                <td class="px-4 py-3 text-slate-600">{{ r.group_count }} kelompok</td>
                <td class="px-4 py-3 text-slate-400">—</td>
                <td class="px-4 py-3 text-slate-400">—</td>
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
      <span aria-hidden="true">+</span> Tambah tutor
    </button>
  </div>
</template>

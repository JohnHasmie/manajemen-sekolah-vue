<!--
  AdminTutoring2ProgramsView.vue — greenfield "Program & Paket" list.

  Reference implementation for the WEB-3 admin screens (agent fan-out
  spawns 10 more against this shape). Composition contract, top → bottom:

    1. `BrandPageHeader` — role="admin", gradient tier header.
    2. `KpiStripCards` — 4 tiles, always 4.
    3. `PageFilterToolbar` — search + `AppFilterChip`s.
    4. `AsyncView` — state machine, feeds `SkeletonList` / `EmptyState`
       / `ErrorState` from the shared data/ folder. Default slot
       renders the loaded list.
    5. Floating "+ Program baru" CTA.

  Data path: `useDataRefresh(loader)` → `{ state, reload }`. Filters +
  academic-year change trigger reload via `useAcademicYearWatcher` +
  local `watch`. Search debounces at 300ms (`useDebounceFn` from
  VueUse — the codebase's established pattern).
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
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'draft' | 'active' | 'archived'
const gradeLevelFilter = ref<string>(''); // '' | 'SD' | 'SMP' | 'SMA' | 'Umum'

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listPrograms({
    per_page: 50,
    search: debouncedSearch.value || undefined,
    status: statusFilter.value || undefined,
    grade_level: gradeLevelFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, statusFilter, gradeLevelFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelProgram[];
  const draft = items.filter((p) => p.status === 'draft').length;
  const packages = items.reduce((sum, p) => sum + (p.packages_count ?? 0), 0);
  const minPrice = items.reduce<number | null>((min, p) => {
    if (p.min_price == null) return min;
    return min == null || p.min_price < min ? p.min_price : min;
  }, null);
  return [
    { icon: 'book', label: 'Program', value: String(items.length) },
    { icon: 'package', label: 'Paket aktif', value: String(packages) },
    { icon: 'tag', label: 'Termahal (mulai)', value: minPrice != null ? `Rp ${minPrice.toLocaleString('id-ID')}` : '—' },
    { icon: 'file-pencil', label: 'Draft', value: String(draft), tone: draft > 0 ? 'amber' : undefined },
  ];
});

function statusChipTone(status: BimbelProgram['status']): string {
  switch (status) {
    case 'active': return 'bg-success-soft text-success';
    case 'draft': return 'bg-slate-100 text-slate-500';
    case 'archived': return 'bg-slate-100 text-slate-400 line-through';
  }
}

function formatRupiah(n: number | null | undefined): string {
  return n != null ? `Rp ${n.toLocaleString('id-ID')}` : '—';
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      kicker="Admin Bimbel"
      title="Program & Paket"
      :meta="state.status === 'content' ? `${(state.data as BimbelProgram[]).length} program aktif` : 'Memuat…'"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" search-placeholder="Cari program…">
      <template #chips>
        <AppFilterChip
          label="Status"
          :value="statusFilter || 'Semua'"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'active'"
        />
        <AppFilterChip
          label="Jenjang"
          :value="gradeLevelFilter || 'Semua'"
          icon-name="stairs"
          :active="!!gradeLevelFilter"
          @click="gradeLevelFilter = gradeLevelFilter ? '' : 'SMA'"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      empty-title="Belum ada program"
      empty-description="Klik + untuk menambah program baru."
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">Program</th>
                <th class="px-4 py-3 font-bold">Jenjang</th>
                <th class="px-4 py-3 font-bold">Paket</th>
                <th class="px-4 py-3 font-bold">Harga mulai</th>
                <th class="px-4 py-3 font-bold">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="p in (data as BimbelProgram[])"
                :key="p.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ p.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ p.grade_level ?? '—' }}</td>
                <td class="px-4 py-3 text-slate-600">{{ p.packages_count ?? 0 }} paket</td>
                <td class="px-4 py-3 text-slate-600">{{ formatRupiah(p.min_price) }}</td>
                <td class="px-4 py-3">
                  <span class="inline-block rounded-full px-2 py-0.5 text-2xs font-bold uppercase tracking-wide" :class="statusChipTone(p.status)">
                    {{ p.status_label ?? p.status }}
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
      <span aria-hidden="true">+</span> Program baru
    </button>
  </div>
</template>

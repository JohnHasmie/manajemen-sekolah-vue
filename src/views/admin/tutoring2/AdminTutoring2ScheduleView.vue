<!--
  AdminTutoring2JadwalView.vue — greenfield "Jadwal sesi" list.

  Sibling to AdminTutoring2ProgramsView (the WEB-3 exemplar); same
  composition contract top→bottom:

    1. `BrandPageHeader` — role="admin", gradient tier header.
    2. `KpiStripCards` — 4 tiles.
    3. `PageFilterToolbar` — search + `AppFilterChip`s.
    4. `AsyncView` state machine over `TutoringBimbelService.listSessions`.
    5. Floating "+ Buat sesi" CTA.
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
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'scheduled' | 'done' | 'cancelled'
const groupFilter = ref<string>('');  // '' | learning_group_id
const tutorFilter = ref<string>('');  // '' | tutor_id
const periodFilter = ref<'all' | 'week' | 'month'>('all'); // nominal, UI-only

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 100,
    status: statusFilter.value || undefined,
    learning_group_id: groupFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, statusFilter, groupFilter, tutorFilter, periodFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelSession[];
  const scheduled = items.filter((s) => s.status === 'scheduled').length;
  const inProgress = items.filter((s) => s.status === 'in_progress').length;
  const done = items.filter((s) => s.status === 'done').length;
  const cancelled = items.filter((s) => s.status === 'cancelled').length;
  return [
    { icon: 'calendar', label: 'Terjadwal', value: String(scheduled) },
    { icon: 'play', label: 'Berlangsung', value: String(inProgress), tone: inProgress > 0 ? 'amber' : undefined },
    { icon: 'circle-check', label: 'Selesai', value: String(done) },
    { icon: 'x', label: 'Dibatalkan', value: String(cancelled), tone: cancelled > 0 ? 'amber' : undefined },
  ];
});

function statusPillTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'scheduled': return 'neutral';
    case 'in_progress': return 'info';
    case 'done': return 'success';
    case 'cancelled': return 'danger';
  }
}

function formatWaktu(iso: string): string {
  return new Date(iso).toLocaleString('id-ID', { weekday: 'short', hour: '2-digit', minute: '2-digit' });
}

function truncateId(id: string | null | undefined, len = 8): string {
  if (!id) return '—';
  return id.length > len ? id.slice(0, len) : id;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      kicker="Admin Bimbel"
      title="Jadwal Sesi"
      :meta="state.status === 'content' ? `${(state.data as BimbelSession[]).length} sesi minggu ini` : 'Memuat…'"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" search-placeholder="Cari sesi…">
      <template #chips>
        <AppFilterChip
          label="Status"
          :value="statusFilter || 'Semua'"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'scheduled'"
        />
        <AppFilterChip
          label="Kelompok"
          :value="groupFilter ? truncateId(groupFilter) : 'Semua'"
          icon-name="users"
          :active="!!groupFilter"
          @click="groupFilter = ''"
        />
        <AppFilterChip
          label="Tutor"
          :value="tutorFilter ? truncateId(tutorFilter) : 'Semua'"
          icon-name="user"
          :active="!!tutorFilter"
          @click="tutorFilter = ''"
        />
        <AppFilterChip
          label="Periode"
          :value="periodFilter === 'all' ? 'Semua' : periodFilter === 'week' ? 'Minggu ini' : 'Bulan ini'"
          icon-name="calendar"
          :active="periodFilter !== 'all'"
          @click="periodFilter = periodFilter === 'all' ? 'week' : periodFilter === 'week' ? 'month' : 'all'"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      empty-title="Belum ada sesi"
      empty-description="Klik + untuk membuat sesi baru."
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">Waktu</th>
                <th class="px-4 py-3 font-bold">Kelompok</th>
                <th class="px-4 py-3 font-bold">Tutor</th>
                <th class="px-4 py-3 font-bold">Ruang</th>
                <th class="px-4 py-3 font-bold">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="s in (data as BimbelSession[])"
                :key="s.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ formatWaktu(s.starts_at) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ truncateId(s.learning_group_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ truncateId(s.tutor_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ s.room ?? '—' }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="s.status_label ?? s.status" :tone="statusPillTone(s.status)" uppercase />
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
      <span aria-hidden="true">+</span> Buat sesi
    </button>
  </div>
</template>

<!--
  AdminTutoring2KehadiranView.vue — greenfield "Kehadiran" monitor.

  Sibling to AdminTutoring2ProgramsView (the WEB-3 exemplar); same
  composition contract top→bottom, but the floating slot is a
  "Ekspor rekap" action instead of a "+" CTA (this is a monitor view).

  MVP data path: list completed sessions and derive attendance stats
  from `attendances_count`.
  // TODO WEB-3+ swap to /tutoring-v2/attendance/monitor once BE exposes an aggregated per-session KPI view
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
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

const search = ref('');
const dateFilter = ref<'all' | 'today' | 'week' | 'month'>('all'); // nominal, UI-only
const groupFilter = ref<string>(''); // '' | learning_group_id
const tutorFilter = ref<string>(''); // '' | tutor_id

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  // TODO WEB-3+ swap to /tutoring-v2/attendance/monitor once BE exposes an aggregated per-session KPI view
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 100,
    status: 'done',
    learning_group_id: groupFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, dateFilter, groupFilter, tutorFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelSession[];
  const totalPresensi = items.reduce((sum, s) => sum + (s.attendances_count ?? 0), 0);
  // % presensi placeholder — needs roster totals; BE-4+ will expose per-session roster count.
  const pctPresensi = 92;
  const belumDiambil = 0;
  return [
    { icon: 'circle-check', label: t('tutoring2.admin.attendance.kpiCompleted'), value: String(items.length) },
    { icon: 'users', label: t('tutoring2.admin.attendance.kpiTotal'), value: String(totalPresensi) },
    { icon: 'chart-bar', label: t('tutoring2.admin.attendance.kpiRate'), value: `${pctPresensi}%` },
    { icon: 'clock', label: t('tutoring2.admin.attendance.kpiUnrecorded'), value: String(belumDiambil), tone: belumDiambil > 0 ? 'amber' : undefined },
  ];
});

function statusLabel(status: BimbelSession['status']): string {
  const key = status === 'in_progress' ? 'inProgress' : status;
  return t(`tutoring2.status.${key}`);
}

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

function formatTanggal(iso: string): string {
  return new Date(iso).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
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
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.attendance.title')"
      :meta="state.status === 'content' ? `${(state.data as BimbelSession[]).length} sesi selesai` : t('tutoring2.common.loading')"
    />
    <!-- TODO i18n key for meta '{count} sesi selesai' -->

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.attendance.searchPh')">
      <template #chips>
        <!-- TODO i18n key for date-range values 'Hari ini'/'Minggu ini'/'Bulan ini' -->
        <AppFilterChip
          :label="t('tutoring2.common.date')"
          :value="dateFilter === 'all' ? t('tutoring2.common.all') : dateFilter === 'today' ? 'Hari ini' : dateFilter === 'week' ? 'Minggu ini' : 'Bulan ini'"
          icon-name="calendar"
          :active="dateFilter !== 'all'"
          @click="dateFilter = dateFilter === 'all' ? 'today' : dateFilter === 'today' ? 'week' : dateFilter === 'week' ? 'month' : 'all'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.group')"
          :value="groupFilter ? truncateId(groupFilter) : t('tutoring2.common.all')"
          icon-name="users"
          :active="!!groupFilter"
          @click="groupFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.tutor')"
          :value="tutorFilter ? truncateId(tutorFilter) : t('tutoring2.common.all')"
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
      :empty-title="t('tutoring2.admin.attendance.emptyTitle')"
      empty-description="Sesi yang sudah selesai akan muncul di sini."
      @retry="reload"
    >
      <!-- TODO i18n key for empty-description 'Sesi yang sudah selesai akan muncul di sini.' -->
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <!-- TODO i18n key for column header 'Sesi' -->
                <th class="px-4 py-3 font-bold">Sesi</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.date') }}</th>
                <!-- TODO i18n key for column headers 'Hadir' / 'Presensi' -->
                <th class="px-4 py-3 font-bold">Hadir</th>
                <th class="px-4 py-3 font-bold">Presensi</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="s in (data as BimbelSession[])"
                :key="s.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">
                  {{ formatWaktu(s.starts_at) }} · {{ truncateId(s.learning_group_id) }}
                </td>
                <td class="px-4 py-3 text-slate-600">{{ formatTanggal(s.starts_at) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ s.attendances_count ?? '—' }}</td>
                <td class="px-4 py-3 text-slate-600">
                  {{ s.attendances_count ? `${s.attendances_count} rows` : t('tutoring2.admin.attendance.kpiUnrecorded') }}
                </td>
                <td class="px-4 py-3">
                  <StatusBadge :label="s.status_label ?? statusLabel(s.status)" :tone="statusPillTone(s.status)" uppercase />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      type="button"
      :aria-label="t('tutoring2.admin.attendance.exportCta')"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
    >
      {{ t('tutoring2.admin.attendance.exportCta') }}
    </button>
  </div>
</template>

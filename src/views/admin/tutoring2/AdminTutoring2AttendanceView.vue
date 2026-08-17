<!--
  AdminTutoring2KehadiranView.vue — greenfield "Kehadiran" monitor.

  Sibling to AdminTutoring2ProgramsView (the WEB-3 exemplar); same
  composition contract top→bottom, but the floating slot is a
  "Ekspor rekap" action instead of a "+" CTA (this is a monitor view).

  ── What this replaces ──

  Three of the four tiles were wrong, two of them literals:

      Sesi selesai   real
      Total presensi ALWAYS 0   — `index` never counted attendances, so
                                  `attendances_count` was absent from
                                  every row and `?? 0` swallowed it
      % Presensi     `const pctPresensi = 92`
      Belum diambil  `const belumDiambil = 0`

  So an admin whose whole reason for opening this screen is to see
  whether registers are being taken was told 92% and "nothing
  outstanding", permanently, on top of a total that could not move off
  zero.

  BE !786 makes `index` count attendances and, separately, how many
  were `hadir`. Both KPIs now come from exactly the sessions in the
  list — filters included. The tempting alternative,
  `/admin/reports/attendance`, aggregates by enrollment over a date
  range with no group or tutor filter, so its percentage would
  contradict the table beneath it as soon as an admin filtered.

  ── Absent is not zero ──

  Both counts are optional on the wire. A row that carries neither is
  "not counted", which is why the rate renders "—" rather than 0%
  when nothing countable came back, and why "Belum diambil" only
  counts rows that actually reported a zero.
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
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 100,
    status: 'done',
    learning_group_id: groupFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, dateFilter, groupFilter, tutorFilter], () => reload());

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelSession[];

  // Only rows that actually reported a count take part. A row without
  // one is unknown, and unknown must not be averaged in as zero.
  const counted = items.filter((s) => typeof s.attendances_count === 'number');
  const totalMarks = counted.reduce((sum, s) => sum + (s.attendances_count ?? 0), 0);
  const totalPresent = counted.reduce(
    (sum, s) => sum + (s.attendances_present_count ?? 0),
    0,
  );

  // Hadir over every mark recorded across these sessions. Null when
  // nothing countable came back — "—", never 0%, because no register
  // taken is not the same as nobody attending.
  const rate =
    counted.length === 0 || totalMarks === 0
      ? null
      : Math.round((totalPresent / totalMarks) * 100);

  // A DONE session with zero attendance rows is a register nobody
  // took. Rows that reported no count at all are excluded: we cannot
  // tell an untaken register from an uncounted one.
  const belumDiambil = counted.filter((s) => (s.attendances_count ?? 0) === 0).length;

  return [
    {
      icon: 'circle-check',
      label: t('tutoring2.admin.attendance.kpiCompleted'),
      value: String(items.length),
    },
    {
      icon: 'users',
      label: t('tutoring2.admin.attendance.kpiTotal'),
      value: counted.length === 0 ? '—' : String(totalMarks),
    },
    {
      icon: 'chart-bar',
      label: t('tutoring2.admin.attendance.kpiRate'),
      value: rate == null ? '—' : `${rate}%`,
    },
    {
      icon: 'clock',
      label: t('tutoring2.admin.attendance.kpiUnrecorded'),
      value: counted.length === 0 ? '—' : String(belumDiambil),
      tone: belumDiambil > 0 ? 'amber' : undefined,
    },
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
      :meta="state.status === 'content' ? t('tutoring2.common.metaSessionsDone', { count: (state.data as BimbelSession[]).length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.attendance.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.date')"
          :value="dateFilter === 'all' ? t('tutoring2.common.all') : dateFilter === 'today' ? t('tutoring2.common.today') : dateFilter === 'week' ? t('tutoring2.common.thisWeek') : t('tutoring2.common.thisMonth')"
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
      :empty-description="t('tutoring2.admin.attendance.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.session') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.date') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.attended') }}</th>
                <!-- TODO i18n key for column header 'Presensi' -->
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

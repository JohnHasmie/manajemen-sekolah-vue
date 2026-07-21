<!--
  ParentTutoring2AttendanceView.vue — Wali attendance history for one child (WEB-5).

  Composition:
    1. BrandPageHeader (role="parent") — with meta line.
    2. KpiStripCards          — Hadir / Izin / Sakit / Alpa.
    3. AsyncView              — rounded-3xl surface with divide-y rows.

  MVP: TutoringBimbelService.listSessionAttendance requires a session_id
  we don't have per-student aggregated. Until BE ships a proper endpoint
  we fetch the last N sessions and render them as placeholder attendance
  rows — session status mocks presence status.

  // TODO WEB-5+ swap to /tutoring2/parent/attendance/:studentId when
  //             the BE aggregates it.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const route = useRoute();
// Wired in per the tutoring2 view contract; used by the future save flow
// when we swap to /tutoring2/parent/attendance/:studentId.
useToast();

// Route params (studentId reserved for the future per-child endpoint).
const studentId = String(route.params.studentId ?? '');
void studentId;

// ── Data ──────────────────────────────────────────────────────────
// TODO WEB-5+ swap to /tutoring2/parent/attendance/:studentId when the
//             BE aggregates it. For MVP we fetch recent sessions and
//             show the last 10 as placeholder attendance rows.
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({ per_page: 100 });
  return items;
});
useAcademicYearWatcher(reload);

const allSessions = computed<BimbelSession[]>(() => {
  return state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as BimbelSession[] | undefined) ?? [])
    : [];
});

// Only the last 10 sessions (already-happened / in-progress) — placeholder
// filter until the parent-scoped attendance endpoint ships.
const rows = computed<BimbelSession[]>(() => {
  return [...allSessions.value]
    .sort((a, b) => b.starts_at.localeCompare(a.starts_at))
    .slice(0, 10);
});

// ── KPIs ─────────────────────────────────────────────────────────
// MVP: derived from session status counts as placeholder buckets.
const kpiCards = computed<KpiCard[]>(() => {
  const list = allSessions.value;
  const present = list.filter((s) => s.status === 'done').length;
  const permitted = list.filter((s) => s.status === 'cancelled').length;
  const sick = 0;
  const absent = list.filter((s) => s.status === 'scheduled').length;
  return [
    { icon: 'user-check', label: t('tutoring2.parent.attendance.kpiPresent'), value: String(present), tone: 'green' },
    { icon: 'clock', label: t('tutoring2.parent.attendance.kpiPermitted'), value: String(permitted), tone: 'amber' },
    { icon: 'heart', label: t('tutoring2.parent.attendance.kpiSick'), value: String(sick), tone: 'brand' },
    { icon: 'x-circle', label: t('tutoring2.parent.attendance.kpiAbsent'), value: String(absent), tone: 'red' },
  ];
});

const metaLabel = computed(() =>
  state.value.status === 'loading'
    ? t('tutoring2.common.loading')
    : t('tutoring2.parent.attendance.meta', { count: rows.value.length }),
);

// ── Helpers ──────────────────────────────────────────────────────
function formatShortDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

// Session-status → placeholder presence mapping (MVP).
function presenceLabel(status: BimbelSession['status']): string {
  switch (status) {
    case 'done':
      return t('tutoring2.parent.attendance.kpiPresent');
    case 'cancelled':
      return t('tutoring2.parent.attendance.kpiPermitted');
    case 'in_progress':
      return t('tutoring2.parent.attendance.kpiSick');
    case 'scheduled':
    default:
      return t('tutoring2.parent.attendance.kpiAbsent');
  }
}

function presenceTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'done':
      return 'success';
    case 'cancelled':
      return 'warning';
    case 'in_progress':
      return 'info';
    case 'scheduled':
    default:
      return 'danger';
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.attendance.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.parent.attendance.emptyTitle')"
      @retry="reload"
    >
      <!-- TODO i18n key: tutoring2.parent.attendance.emptyDesc -->
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="s in rows"
              :key="s.id"
              class="flex items-center gap-3 px-4 py-3"
            >
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ formatShortDate(s.starts_at) }}
                  <span class="mx-1 text-slate-300">·</span>
                  {{ t('tutoring2.common.group') }} {{ s.learning_group_id.slice(0, 8) }}
                </p>
                <p class="truncate text-2xs text-slate-500">
                  {{ formatTime(s.starts_at) }}
                  <span class="mx-1 text-slate-300">·</span>
                  {{ s.room ?? t('tutoring2.common.noRoom') }}
                </p>
              </div>
              <StatusBadge
                :label="presenceLabel(s.status)"
                :tone="presenceTone(s.status)"
                uppercase
              />
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

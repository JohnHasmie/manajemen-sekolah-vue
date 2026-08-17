<!--
  ParentTutoring2AttendanceView.vue — Wali attendance history for one child.

  Composition:
    1. BrandPageHeader (role="parent") — with meta line.
    2. KpiStripCards          — Hadir / Izin / Sakit / Alpa.
    3. AsyncView              — rounded-3xl surface with divide-y rows.

  ── What this replaces ──

  The screen ignored `studentId` entirely (`void studentId`) and fetched
  the last 100 SESSIONS, rendering the ten most recent as "attendance
  rows". Every number a wali read here was about the centre's timetable,
  not about their child:

      Hadir  = sessions the centre had marked `done`
      Izin   = sessions the centre had `cancelled`
      Sakit  = 0, hardcoded
      Alpa   = sessions still `scheduled`  ← FUTURE classes

  The last one is the worst of them: a parent was shown lessons that
  have not happened yet as their child's absences. A cancelled session
  was shown as an excused absence nobody applied for, and a session the
  child skipped still counted as attendance because the centre held it.

  `GET /tutoring-v2/students/{id}/attendance` has existed since BE-24
  and is scoped for exactly this caller: a wali reads their own child
  through the `tutoring.attendance.view_own` branch, which resolves
  ownership by `students.user_id` OR `students.guardian_email`.

  ── The summary comes from the server ──

  Rows are paginated; the summary is computed over the whole range. A
  client-side tally of `rows` would report one page of attendance as the
  entire term's. `attendance_rate` is null when nothing has been marked
  and is rendered as "—", never as 0% — a register not yet taken is not
  a child who attended nothing.
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
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type {
  StudentAttendanceResult,
  StudentAttendanceRow,
  StudentAttendanceSummary,
} from '@/types/tutoring2/attendance';

const { t } = useI18n();
const route = useRoute();

const studentId = String(route.params.studentId ?? '');

// ── Data ──────────────────────────────────────────────────────────
const { state, reload } = useDataRefresh<StudentAttendanceResult>(async () => {
  // An empty id would read as "every student" to a careless endpoint;
  // refuse locally rather than send it.
  if (!studentId) {
    throw new Error('studentId is required');
  }
  return TutoringStudentsService.getAttendance(studentId, { per_page: 50 });
});

const result = computed<StudentAttendanceResult | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value as { data?: StudentAttendanceResult }).data ?? null)
    : null,
);

const rows = computed<StudentAttendanceRow[]>(() => result.value?.rows ?? []);

const summary = computed<StudentAttendanceSummary | null>(
  () => result.value?.summary ?? null,
);

// ── KPIs ─────────────────────────────────────────────────────────
// Straight from the server's summary. Not derived from `rows`, which is
// one page, and not derived from session status, which is the centre's
// calendar rather than the child's record.
const kpiCards = computed<KpiCard[]>(() => {
  const s = summary.value;
  const v = (n: number | undefined) => (s == null ? '—' : String(n ?? 0));
  return [
    {
      icon: 'user-check',
      label: t('tutoring2.parent.attendance.kpiPresent'),
      value: v(s?.hadir),
      tone: 'green',
    },
    {
      icon: 'clock',
      label: t('tutoring2.parent.attendance.kpiPermitted'),
      value: v(s?.izin),
      tone: 'amber',
    },
    {
      icon: 'heart',
      label: t('tutoring2.parent.attendance.kpiSick'),
      value: v(s?.sakit),
      tone: 'brand',
    },
    {
      icon: 'x-circle',
      label: t('tutoring2.parent.attendance.kpiAbsent'),
      value: v(s?.alpa),
      tone: 'red',
    },
  ];
});

/** "92,5%" — or "—" when no register has been taken yet. */
const attendanceRateLabel = computed<string>(() => {
  const rate = summary.value?.attendance_rate;
  if (rate == null) return '—';
  return `${rate.toString().replace('.', ',')}%`;
});

const metaLabel = computed(() =>
  state.value.status === 'loading'
    ? t('tutoring2.common.loading')
    : t('tutoring2.parent.attendance.meta', {
        count: summary.value?.total ?? rows.value.length,
      }),
);

// ── Helpers ──────────────────────────────────────────────────────
function formatShortDate(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

function formatTime(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
}

/**
 * The row's own attendance status. Prefers the server's label so a
 * status added on the backend renders as itself.
 */
function presenceLabel(row: StudentAttendanceRow): string {
  if (row.status_label) return row.status_label;
  switch (row.status) {
    case 'hadir':
      return t('tutoring2.parent.attendance.kpiPresent');
    case 'izin':
      return t('tutoring2.parent.attendance.kpiPermitted');
    case 'sakit':
      return t('tutoring2.parent.attendance.kpiSick');
    case 'alpa':
      return t('tutoring2.parent.attendance.kpiAbsent');
    default:
      return row.status;
  }
}

function presenceTone(row: StudentAttendanceRow): StatusBadgeTone {
  switch (row.status) {
    case 'hadir':
      return 'success';
    case 'izin':
      return 'warning';
    case 'sakit':
      return 'info';
    case 'alpa':
      return 'danger';
    // An unrecognised status renders neutrally rather than borrowing
    // the tone of one it is not.
    default:
      return 'neutral';
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

    <div
      v-if="summary"
      class="rounded-3xl border border-slate-100 bg-white px-4 py-3 shadow-sm"
    >
      <p class="text-2xs uppercase tracking-wide text-slate-400">
        {{ t('tutoring2.parent.attendance.kpiPresent') }}
      </p>
      <p class="text-lg font-bold text-slate-900 tabular-nums">
        {{ attendanceRateLabel }}
      </p>
    </div>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.parent.attendance.emptyTitle')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="row in rows"
              :key="row.id"
              class="flex items-center gap-3 px-4 py-3"
            >
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ formatShortDate(row.starts_at) }}
                  <template v-if="row.learning_group_name">
                    <span class="mx-1 text-slate-300">·</span>
                    {{ row.learning_group_name }}
                  </template>
                </p>
                <p class="truncate text-2xs text-slate-500">
                  {{ formatTime(row.starts_at) }}
                  <template v-if="row.program_name">
                    <span class="mx-1 text-slate-300">·</span>
                    {{ row.program_name }}
                  </template>
                </p>
              </div>
              <StatusBadge
                :label="presenceLabel(row)"
                :tone="presenceTone(row)"
                uppercase
              />
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

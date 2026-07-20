<!--
  AdminAttendanceOverviewCard.vue — unified attendance snapshot for the
  admin dashboard (SS3 Opsi A, replaces the old placeholder heatmap).

  Reads three new fields from the admin `/dashboard/stats` payload
  (MR!523 in edu_core):

    attendance_per_class:      null | Array<{class_id,class_name,present_pct,total,present}>
    teacher_attendance_today:  null | {present_pct,total,present}
    staff_attendance_today:    null | {present_pct,total,present}

  Gating (already enforced server-side, we just don't render the panel):
    - attendance_per_class   → attendance.student.view
    - teacher/staff summary  → attendance.staff.report.view
    - `null`  = the ability was rejected on the server
    - `[]` or `{total:0}` = ability granted but no data recorded today

  Layout (mirrors the artifact SS3 Opsi A recommendation):
    - dcard header (icon + "Hari ini · <date>" eyebrow + title + Detail
      link that jumps to /admin/student-attendance)
    - Ring row: up to 3 KPI rings (Siswa emerald / Guru cobalt / Staf
      amber). Each ring is only rendered when its source field is not
      null; when the field is a zero-total object the ring greys out and
      shows "belum ada".
    - Per-kelas bar list: shown when attendance_per_class is a non-empty
      array. Empty-array case shows a soft "no records today" line.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMeStore } from '@/stores/me';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatDateLong } from '@/lib/format';

interface PerClassRow {
  class_id: string;
  class_name: string;
  present_pct: number;
  total: number;
  present: number;
}

interface AttendanceSummaryToday {
  present_pct: number;
  total: number;
  present: number;
}

/**
 * Loose stats shape — the admin dashboard payload is `Record<string, any>`
 * (see DashboardService.getStats), so we defensively narrow only the
 * three fields we care about here.
 */
interface StatsShape {
  attendance_rate_today?: number | string | null;
  attendance_per_class?: PerClassRow[] | null;
  teacher_attendance_today?: AttendanceSummaryToday | null;
  staff_attendance_today?: AttendanceSummaryToday | null;
  [key: string]: unknown;
}

const props = defineProps<{
  stats: StatsShape;
}>();

const { t } = useI18n();
const router = useRouter();
const me = useMeStore();

// --- Gating -----------------------------------------------------------
// The BE already stripped fields the caller can't see; we still hide the
// whole panel when the admin has NO attendance ability at all so we
// don't render an empty shell.
const canStudent = computed(() =>
  me.canAny(['attendance.student.view', 'attendance.student.export']),
);
const canStaff = computed(() => me.can('attendance.staff.report.view'));
const hasAnyPanel = computed(() => canStudent.value || canStaff.value);

// --- Ring inputs ------------------------------------------------------
function toInt(v: unknown): number {
  if (typeof v === 'number' && Number.isFinite(v)) return Math.round(v);
  if (typeof v === 'string') {
    const n = Number.parseFloat(v);
    return Number.isFinite(n) ? Math.round(n) : 0;
  }
  return 0;
}

const perClass = computed<PerClassRow[] | null>(() => {
  const raw = props.stats?.attendance_per_class;
  if (raw == null) return null;
  if (!Array.isArray(raw)) return null;
  return raw;
});

// Student ring pct: prefer the top-level `attendance_rate_today` field
// (already in the payload before MR!523), fall back to the average of
// the per-class rows so we never show a blank ring when only per-class
// data landed.
const studentPct = computed<number>(() => {
  const top = props.stats?.attendance_rate_today;
  if (top != null) return Math.max(0, Math.min(100, toInt(top)));
  const rows = perClass.value;
  if (rows && rows.length > 0) {
    const sum = rows.reduce((acc, r) => acc + toInt(r.present_pct), 0);
    return Math.round(sum / rows.length);
  }
  return 0;
});
const studentPresent = computed<number>(() => {
  const rows = perClass.value ?? [];
  return rows.reduce((acc, r) => acc + toInt(r.present), 0);
});
const studentTotal = computed<number>(() => {
  const rows = perClass.value ?? [];
  return rows.reduce((acc, r) => acc + toInt(r.total), 0);
});
// Student ring is "present" (renders a value) when the admin has the
// student ability AND the payload actually carried a rate today.
const showStudentRing = computed(() => canStudent.value);

const teacherSummary = computed<AttendanceSummaryToday | null>(() => {
  const raw = props.stats?.teacher_attendance_today;
  if (raw == null || typeof raw !== 'object') return null;
  return raw as AttendanceSummaryToday;
});
const staffSummary = computed<AttendanceSummaryToday | null>(() => {
  const raw = props.stats?.staff_attendance_today;
  if (raw == null || typeof raw !== 'object') return null;
  return raw as AttendanceSummaryToday;
});
const showTeacherRing = computed(() => teacherSummary.value != null);
const showStaffRing = computed(() => staffSummary.value != null);

// --- Bar list state ---------------------------------------------------
const hasPerClass = computed(() => perClass.value != null);
const perClassRows = computed(() => perClass.value ?? []);
// Header date — WIB-local, spelled long so the eyebrow reads
// "Hari ini · Selasa, 21 Juli 2026".
const todayLabel = computed(() => formatDateLong(new Date()));

// --- Colour helpers ---------------------------------------------------
function barColorClass(pct: number): string {
  if (pct >= 90) return 'bg-emerald-500';
  if (pct >= 75) return 'bg-amber-500';
  return 'bg-rose-500';
}

// Small conic-gradient ring — 46px, matches artifact `.ring-kpi`.
// We inline the gradient because Tailwind can't emit an arbitrary
// conic-gradient with a runtime percentage.
interface RingSpec {
  color: string;
  softBg: string;
  labelClass: string;
}
const RING_STUDENT: RingSpec = {
  color: '#10B981', // emerald-500
  softBg: '#ECFDF5',
  labelClass: 'text-emerald-700',
};
const RING_TEACHER: RingSpec = {
  color: '#1B6FB8', // brand cobalt
  softBg: '#E6F7FD',
  labelClass: 'text-role-teacher',
};
const RING_STAFF: RingSpec = {
  color: '#B45309', // amber
  softBg: '#FEF3C7',
  labelClass: 'text-role-staff',
};

function ringStyle(pct: number, spec: RingSpec, isEmpty: boolean): string {
  const clamped = Math.max(0, Math.min(100, Math.round(pct)));
  if (isEmpty) {
    return 'background: conic-gradient(#CBD5E1 0deg, #E2E8F0 0deg);';
  }
  const deg = (clamped / 100) * 360;
  return `background: conic-gradient(${spec.color} ${deg}deg, #E2E8F0 ${deg}deg);`;
}

function gotoDetail() {
  router.push('/admin/student-attendance');
}
</script>

<template>
  <section
    v-if="hasAnyPanel"
    class="bg-white border border-slate-200 rounded-2xl p-4"
  >
    <!-- Header — same dcard pattern as the finance card next door -->
    <header class="flex items-center justify-between mb-3 px-1">
      <div class="flex items-center gap-2.5 min-w-0">
        <div class="w-8 h-8 rounded-xl bg-emerald-100 text-emerald-700 grid place-items-center flex-shrink-0">
          <NavIcon name="check-circle" :size="16" />
        </div>
        <div class="min-w-0">
          <p class="text-3xs font-bold text-slate-400 tracking-widest uppercase truncate">
            {{ t('admin.attendance.eyebrowToday', { date: todayLabel }) }}
          </p>
          <h3 class="text-sm font-black text-slate-900 leading-none mt-0.5">
            {{ t('admin.attendance.title') }}
          </h3>
        </div>
      </div>
      <button
        v-if="canStudent"
        type="button"
        class="text-2xs font-bold text-role-admin hover:underline flex-shrink-0"
        @click="gotoDetail"
      >
        {{ t('admin.attendance.detail') }}
      </button>
    </header>

    <!-- 3-ring KPI row -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
      <!-- Siswa -->
      <div
        v-if="showStudentRing"
        class="flex items-center gap-3 rounded-xl bg-slate-50 px-3 py-3"
      >
        <div
          class="w-[46px] h-[46px] rounded-full grid place-items-center flex-shrink-0"
          :style="ringStyle(studentPct, RING_STUDENT, studentTotal === 0 && !stats?.attendance_rate_today)"
        >
          <div class="w-[34px] h-[34px] rounded-full bg-white grid place-items-center">
            <span class="text-2xs font-black text-slate-900 tabular-nums">
              {{ studentTotal === 0 && !stats?.attendance_rate_today ? '—' : `${studentPct}%` }}
            </span>
          </div>
        </div>
        <div class="min-w-0">
          <p class="text-3xs font-bold uppercase tracking-widest" :class="RING_STUDENT.labelClass">
            {{ t('admin.attendance.ringStudent') }}
          </p>
          <p class="text-2xs font-bold text-slate-500 mt-0.5 tabular-nums truncate">
            <template v-if="studentTotal > 0">
              {{ t('admin.attendance.presentOf', { present: studentPresent, total: studentTotal }) }}
            </template>
            <template v-else-if="stats?.attendance_rate_today != null">
              {{ t('admin.attendance.rateToday') }}
            </template>
            <template v-else>
              {{ t('admin.attendance.notYet') }}
            </template>
          </p>
        </div>
      </div>

      <!-- Guru -->
      <div
        v-if="showTeacherRing"
        class="flex items-center gap-3 rounded-xl bg-slate-50 px-3 py-3"
      >
        <div
          class="w-[46px] h-[46px] rounded-full grid place-items-center flex-shrink-0"
          :style="ringStyle(teacherSummary?.present_pct ?? 0, RING_TEACHER, (teacherSummary?.total ?? 0) === 0)"
        >
          <div class="w-[34px] h-[34px] rounded-full bg-white grid place-items-center">
            <span class="text-2xs font-black text-slate-900 tabular-nums">
              {{ (teacherSummary?.total ?? 0) === 0 ? '—' : `${Math.round(teacherSummary?.present_pct ?? 0)}%` }}
            </span>
          </div>
        </div>
        <div class="min-w-0">
          <p class="text-3xs font-bold uppercase tracking-widest" :class="RING_TEACHER.labelClass">
            {{ t('admin.attendance.ringTeacher') }}
          </p>
          <p class="text-2xs font-bold text-slate-500 mt-0.5 tabular-nums truncate">
            <template v-if="(teacherSummary?.total ?? 0) > 0">
              {{ t('admin.attendance.presentOf', { present: teacherSummary?.present ?? 0, total: teacherSummary?.total ?? 0 }) }}
            </template>
            <template v-else>
              {{ t('admin.attendance.notYet') }}
            </template>
          </p>
        </div>
      </div>

      <!-- Staf -->
      <div
        v-if="showStaffRing"
        class="flex items-center gap-3 rounded-xl bg-slate-50 px-3 py-3"
      >
        <div
          class="w-[46px] h-[46px] rounded-full grid place-items-center flex-shrink-0"
          :style="ringStyle(staffSummary?.present_pct ?? 0, RING_STAFF, (staffSummary?.total ?? 0) === 0)"
        >
          <div class="w-[34px] h-[34px] rounded-full bg-white grid place-items-center">
            <span class="text-2xs font-black text-slate-900 tabular-nums">
              {{ (staffSummary?.total ?? 0) === 0 ? '—' : `${Math.round(staffSummary?.present_pct ?? 0)}%` }}
            </span>
          </div>
        </div>
        <div class="min-w-0">
          <p class="text-3xs font-bold uppercase tracking-widest" :class="RING_STAFF.labelClass">
            {{ t('admin.attendance.ringStaff') }}
          </p>
          <p class="text-2xs font-bold text-slate-500 mt-0.5 tabular-nums truncate">
            <template v-if="(staffSummary?.total ?? 0) > 0">
              {{ t('admin.attendance.presentOf', { present: staffSummary?.present ?? 0, total: staffSummary?.total ?? 0 }) }}
            </template>
            <template v-else>
              {{ t('admin.attendance.notYet') }}
            </template>
          </p>
        </div>
      </div>
    </div>

    <!-- Per-kelas bar list — only when the ability granted the field.
         Empty array (no sessions yet today) drops into a soft empty
         line instead of leaving a bare section header. -->
    <div v-if="hasPerClass" class="mt-4 pt-3 border-t border-slate-100">
      <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest mb-2 px-1">
        {{ t('admin.attendance.perClass') }}
      </p>
      <ul v-if="perClassRows.length > 0" class="space-y-1.5">
        <li
          v-for="row in perClassRows"
          :key="row.class_id"
          class="grid items-center gap-2 px-1"
          style="grid-template-columns: 38px 1fr 40px;"
        >
          <span class="text-2xs font-black text-role-teacher tabular-nums truncate">
            {{ row.class_name }}
          </span>
          <span class="h-[14px] rounded-full bg-slate-100 overflow-hidden">
            <span
              class="block h-full rounded-full transition-all"
              :class="barColorClass(toInt(row.present_pct))"
              :style="{ width: `${Math.max(0, Math.min(100, toInt(row.present_pct)))}%` }"
            ></span>
          </span>
          <span class="text-2xs font-black text-slate-800 tabular-nums text-right">
            {{ Math.round(toInt(row.present_pct)) }}%
          </span>
        </li>
      </ul>
      <p
        v-else
        class="text-2xs text-slate-500 px-1 py-2 italic"
      >
        {{ t('admin.attendance.noRecordsToday') }}
      </p>
    </div>
  </section>
</template>

<!--
  AdminAttendanceOverviewCard.vue — unified attendance snapshot for the
  admin dashboard (SS3 Opsi A + 7-hari extension).

  Layer 1 (today) — driven by the admin `/dashboard/stats` payload
  (MR!523 in edu_core):

    attendance_per_class:      null | Array<{class_id,class_name,present_pct,total,present}>
    teacher_attendance_today:  null | {present_pct,total,present}
    staff_attendance_today:    null | {present_pct,total,present}
    attendance_rate_today:     null | number

  Layer 2 (this week — 7-day bar chart) fetched here on mount:

    /attendance/student-timeseries        — student per-day totals
    /teacher-attendance/report/timeseries — teacher AND staff (personnel_type)

  Gating (already enforced server-side, we just don't render the panel):
    - attendance_per_class   → attendance.student.view
    - teacher/staff summary  → attendance.staff.report.view
    - `null`  = the ability was rejected on the server
    - `[]` or `{total:0}` = ability granted but no data recorded today

  Layout (Opsi A):
    - dcard header (icon + "Hari ini · <date>" eyebrow + title + Detail
      link that jumps to /admin/student-attendance)
    - Ring row: up to 3 KPI rings (Siswa emerald / Guru cobalt / Staf
      amber). Each ring is only rendered when its source field is not
      null; when the field is a zero-total object the ring greys out and
      shows "belum ada".
    - Tab bar (Siswa/Guru/Staf) — active tab tinted per dimension.
      Switching tabs re-colours the 7-day chart below, but does NOT
      re-fetch data (all three dimensions are fetched in parallel once).
    - "Minggu ini" strip + 7-day bar chart. Weekend/holiday days come
      through the timeseries as `is_workday=false` and render as neutral
      slate-200 stubs with a "libur" pill under the axis. Today gets a
      dashed cobalt vertical marker.
    - Per-kelas bar list: shown only when the active tab is Siswa (and
      when attendance_per_class is not null).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMeStore } from '@/stores/me';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatDateLong } from '@/lib/format';
import { toLocalYmd } from '@/lib/local-date';
import { AttendanceService } from '@/services/attendance.service';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import type {
  StudentAttendanceTimeseries,
  StudentAttendanceTimeseriesDay,
} from '@/types/attendance';
import type {
  TeacherAttendanceTimeseries,
  TeacherAttendanceTimeseriesDay,
} from '@/types/teacher-attendance';

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

const { t, locale } = useI18n();
const router = useRouter();
const me = useMeStore();
const ayStore = useAcademicYearStore();

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

// ─── 7-day chart ────────────────────────────────────────────────────
//
// State shared by all 3 dimensions. We fetch student + teacher + staff
// timeseries in parallel on mount, keep them in local refs, and let the
// active tab pick which array to render. Tab-switching does NOT trigger
// a refetch — the cache lives for the lifetime of the card (invalidated
// only on AY change).

type Dim = 'student' | 'teacher' | 'staff';

/** Normalised per-day cell — all 3 wire shapes fold into this. */
interface ChartDay {
  /** YYYY-MM-DD (local). */
  date: string;
  /** Weekend or holiday. */
  is_workday: boolean;
  /** 0..100. Meaningless on non-workdays (chart draws neutral bar). */
  present_pct: number;
  /** Optional holiday label — falls back to i18n "Akhir pekan"/"Libur". */
  holiday_name: string | null;
  /** Whether the day carried any records at all (workday & rows > 0). */
  has_data: boolean;
}

const activeDim = ref<Dim>('student');

const studentDays = ref<ChartDay[] | null>(null);
const teacherDays = ref<ChartDay[] | null>(null);
const staffDays = ref<ChartDay[] | null>(null);
const weekLoading = ref(true);

/** Locale-independent Monday-start week for the "minggu berjalan" window. */
function mondayOfWeek(base: Date): Date {
  const d = new Date(base.getFullYear(), base.getMonth(), base.getDate());
  // JS: Sun=0, Mon=1, …, Sat=6 — Indonesia treats Mon as start.
  const dow = d.getDay();
  const offset = dow === 0 ? -6 : 1 - dow;
  d.setDate(d.getDate() + offset);
  return d;
}

function addDays(d: Date, n: number): Date {
  const copy = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  copy.setDate(copy.getDate() + n);
  return copy;
}

const weekStart = computed(() => mondayOfWeek(new Date()));
const weekEnd = computed(() => addDays(weekStart.value, 6));
const startYmd = computed(() => toLocalYmd(weekStart.value));
const endYmd = computed(() => toLocalYmd(weekEnd.value));
const todayYmd = computed(() => toLocalYmd(new Date()));

/** Header range label: "14–20 Juli" (both ends localised, month spelled). */
const weekRangeLabel = computed(() => {
  const s = weekStart.value;
  const e = weekEnd.value;
  const sameMonth = s.getMonth() === e.getMonth();
  const monthFmt = new Intl.DateTimeFormat(locale.value, { month: 'long' });
  const dayS = s.getDate();
  const dayE = e.getDate();
  if (sameMonth) {
    return `${dayS}–${dayE} ${monthFmt.format(e)}`;
  }
  return `${dayS} ${monthFmt.format(s)} – ${dayE} ${monthFmt.format(e)}`;
});

/**
 * Build 7 cells spanning `weekStart..weekEnd`. When the timeseries
 * response is short (backend only returned workdays) we still emit an
 * "off" placeholder for the missing days so the bar row is always 7-wide.
 */
function alignToWeek(rows: ChartDay[]): ChartDay[] {
  const byDate = new Map<string, ChartDay>();
  for (const r of rows) byDate.set(r.date, r);
  const out: ChartDay[] = [];
  for (let i = 0; i < 7; i++) {
    const d = addDays(weekStart.value, i);
    const key = toLocalYmd(d);
    const hit = byDate.get(key);
    if (hit) {
      out.push(hit);
      continue;
    }
    // Missing day — best-effort infer: Sat/Sun default to weekend off,
    // weekdays fall into a "no data" bucket so the chart still shows a
    // placeholder.
    const dow = d.getDay();
    const weekend = dow === 0 || dow === 6;
    out.push({
      date: key,
      is_workday: !weekend,
      present_pct: 0,
      holiday_name: null,
      has_data: false,
    });
  }
  return out;
}

function studentToChart(d: StudentAttendanceTimeseriesDay): ChartDay {
  return {
    date: d.date,
    is_workday: d.is_workday,
    present_pct: Math.max(0, Math.min(100, Math.round(d.present_pct))),
    holiday_name: d.holiday_name ?? null,
    has_data: d.is_workday && d.total > 0,
  };
}

function personnelToChart(d: TeacherAttendanceTimeseriesDay): ChartDay {
  // The backend rounds to 1dp — we render integers on the bars.
  const pct = Math.max(0, Math.min(100, Math.round(d.present_pct ?? 0)));
  return {
    date: d.date,
    is_workday: d.is_workday,
    present_pct: pct,
    holiday_name: null,
    has_data:
      d.is_workday && (d.present_count > 0 || d.absent_count > 0),
  };
}

async function loadWeek() {
  weekLoading.value = true;
  const ayId = ayStore.selectedYearId ?? undefined;
  const s = startYmd.value;
  const e = endYmd.value;
  // Fire all three in parallel — failures fold to `[]` inside each
  // service so one broken endpoint doesn't nuke the whole card.
  const [student, teacher, staff] = await Promise.all([
    canStudent.value
      ? AttendanceService.getStudentTimeseries({
          start_date: s,
          end_date: e,
          academic_year_id: ayId,
        })
          .then((r: StudentAttendanceTimeseries) => r.data.map(studentToChart))
          .catch(() => [] as ChartDay[])
      : Promise.resolve([] as ChartDay[]),
    canStaff.value
      ? TeacherAttendanceService.adminTimeseries({
          start_date: s,
          end_date: e,
          personnel_type: 'teacher',
        })
          .then((r: TeacherAttendanceTimeseries) => r.data.map(personnelToChart))
          .catch(() => [] as ChartDay[])
      : Promise.resolve([] as ChartDay[]),
    canStaff.value
      ? TeacherAttendanceService.adminTimeseries({
          start_date: s,
          end_date: e,
          personnel_type: 'staff',
        })
          .then((r: TeacherAttendanceTimeseries) => r.data.map(personnelToChart))
          .catch(() => [] as ChartDay[])
      : Promise.resolve([] as ChartDay[]),
  ]);
  studentDays.value = alignToWeek(student);
  teacherDays.value = alignToWeek(teacher);
  staffDays.value = alignToWeek(staff);
  weekLoading.value = false;
}

onMounted(() => {
  // Default the tab to the first dimension the admin actually has
  // access to — a staff-only admin (no student ability) opens on Guru.
  if (!canStudent.value && canStaff.value) {
    activeDim.value = 'teacher';
  }
  void loadWeek();
});
useAcademicYearWatcher(() => {
  studentDays.value = null;
  teacherDays.value = null;
  staffDays.value = null;
  void loadWeek();
});

// --- Tab bar ---------------------------------------------------------
interface TabSpec {
  key: Dim;
  labelKey: string;
  color: string;
  activeText: string;
  activeDotBg: string;
  pctToday: number | null;
}

const tabs = computed<TabSpec[]>(() => {
  const list: TabSpec[] = [];
  if (canStudent.value) {
    list.push({
      key: 'student',
      labelKey: 'admin.attendance.ringStudent',
      color: RING_STUDENT.color,
      activeText: 'text-emerald-700',
      activeDotBg: 'bg-emerald-500',
      pctToday: props.stats?.attendance_rate_today != null
        ? studentPct.value
        : (studentTotal.value > 0 ? studentPct.value : null),
    });
  }
  if (showTeacherRing.value) {
    list.push({
      key: 'teacher',
      labelKey: 'admin.attendance.ringTeacher',
      color: RING_TEACHER.color,
      activeText: 'text-role-teacher',
      activeDotBg: 'bg-role-teacher',
      pctToday:
        (teacherSummary.value?.total ?? 0) > 0
          ? Math.round(teacherSummary.value?.present_pct ?? 0)
          : null,
    });
  }
  if (showStaffRing.value) {
    list.push({
      key: 'staff',
      labelKey: 'admin.attendance.ringStaff',
      color: RING_STAFF.color,
      activeText: 'text-role-staff',
      activeDotBg: 'bg-role-staff',
      pctToday:
        (staffSummary.value?.total ?? 0) > 0
          ? Math.round(staffSummary.value?.present_pct ?? 0)
          : null,
    });
  }
  return list;
});

// --- Chart derived state ---------------------------------------------

const activeDays = computed<ChartDay[] | null>(() => {
  if (activeDim.value === 'student') return studentDays.value;
  if (activeDim.value === 'teacher') return teacherDays.value;
  return staffDays.value;
});

const activeColor = computed(() => {
  if (activeDim.value === 'student') return RING_STUDENT.color;
  if (activeDim.value === 'teacher') return RING_TEACHER.color;
  return RING_STAFF.color;
});

const activeBarFill = computed(() => activeColor.value);

/** Weekdays that carry real data — averaged for the "rata-rata" cell. */
const workdaysWithData = computed<ChartDay[]>(() => {
  return (activeDays.value ?? []).filter((d) => d.is_workday && d.has_data);
});

const effectiveDayCount = computed<number>(() => {
  return (activeDays.value ?? []).filter((d) => d.is_workday).length;
});

const averagePct = computed<number | null>(() => {
  const rows = workdaysWithData.value;
  if (rows.length === 0) return null;
  const sum = rows.reduce((acc, d) => acc + d.present_pct, 0);
  return Math.round(sum / rows.length);
});

const bestDay = computed<ChartDay | null>(() => {
  const rows = workdaysWithData.value;
  if (rows.length === 0) return null;
  return rows.reduce((a, b) => (b.present_pct > a.present_pct ? b : a));
});

const worstDay = computed<ChartDay | null>(() => {
  const rows = workdaysWithData.value;
  if (rows.length === 0) return null;
  return rows.reduce((a, b) => (b.present_pct < a.present_pct ? b : a));
});

/** Empty-state predicate for the whole chart. */
const noEffectiveDays = computed(() => {
  const rows = activeDays.value ?? [];
  if (rows.length === 0) return true;
  return rows.every((d) => !d.is_workday);
});

// --- SVG chart geometry ---------------------------------------------
// Values are viewBox-space; the outer <svg> stretches width:100% with
// `preserveAspectRatio="none"` so the bars flex with the card while
// the labels stay legible.
const CHART_W = 640;
const CHART_H = 190;
const CHART_TOP = 30;
const CHART_BASE = 150;
const CHART_LEFT_PAD = 30;
const CHART_RIGHT_PAD = 12;
const BAR_WIDTH = 46;

function xForIndex(i: number): number {
  // 7 evenly-spaced slots. Slot width = (usable) / 7. Bar left-aligned
  // inside the slot with a small offset so it visually centres.
  const usable = CHART_W - CHART_LEFT_PAD - CHART_RIGHT_PAD;
  const slot = usable / 7;
  const cx = CHART_LEFT_PAD + slot * (i + 0.5);
  return cx - BAR_WIDTH / 2;
}

function centerXForIndex(i: number): number {
  return xForIndex(i) + BAR_WIDTH / 2;
}

/** Height for a workday bar mapped from a 0..100 percent. */
function heightForPct(pct: number): number {
  const clamped = Math.max(0, Math.min(100, pct));
  const range = CHART_BASE - CHART_TOP;
  return (clamped / 100) * range;
}

/** Off-day / weekend stubs sit at 20% of the plot height (mockup spec). */
const OFF_HEIGHT = (CHART_BASE - CHART_TOP) * 0.2;
const OFF_Y = CHART_BASE - OFF_HEIGHT;

function yForPct(pct: number): number {
  return CHART_BASE - heightForPct(pct);
}

/** Localized day-of-week short name (Sen/Sel/Rab…). */
function shortDow(dateStr: string): string {
  if (!dateStr) return '';
  const d = new Date(`${dateStr}T00:00:00`);
  if (Number.isNaN(d.getTime())) return '';
  const fmt = new Intl.DateTimeFormat(locale.value, { weekday: 'short' });
  // 3-char cap so "Senin"→"Sen", "Monday"→"Mon".
  return fmt.format(d).replace(/\.$/, '').slice(0, 3);
}

function dayNumber(dateStr: string): string {
  if (!dateStr) return '';
  const d = new Date(`${dateStr}T00:00:00`);
  if (Number.isNaN(d.getTime())) return '';
  return String(d.getDate());
}

function isToday(dateStr: string): boolean {
  return dateStr === todayYmd.value;
}

function holidayLabelFor(day: ChartDay): string {
  if (day.holiday_name && day.holiday_name.length > 0) return day.holiday_name;
  const d = new Date(`${day.date}T00:00:00`);
  const dow = d.getDay();
  if (dow === 0 || dow === 6) return t('admin.attendance.weekly.weekend');
  return t('admin.attendance.weekly.holiday');
}

/** Off-day pills row — only lists days that are actually non-workday. */
const holidayPills = computed(() => {
  const rows = activeDays.value ?? [];
  return rows
    .filter((d) => !d.is_workday)
    .map((d) => ({
      key: d.date,
      dow: shortDow(d.date),
      label: holidayLabelFor(d),
    }));
});
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

    <!-- ─── Weekly section ─────────────────────────────────────────
         Tab bar + 7-day chart + summary strip. Only rendered when we
         have at least one tab (guarded by `hasAnyPanel` above, but a
         defensive `v-if` keeps the DOM clean if abilities flip). -->
    <div
      v-if="tabs.length > 0"
      class="mt-4 pt-3 border-t border-slate-100"
    >
      <!-- Section eyebrow: "Minggu ini · 14–20 Juli" -->
      <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest mb-2 px-1">
        {{ t('admin.attendance.weekly.eyebrow', { range: weekRangeLabel }) }}
      </p>

      <!-- Dimension tab bar (segmented control on slate-100 pill). -->
      <div
        role="tablist"
        class="flex gap-1 bg-slate-100 rounded-xl p-1 mb-3"
      >
        <button
          v-for="tab in tabs"
          :key="tab.key"
          type="button"
          role="tab"
          :aria-selected="activeDim === tab.key"
          class="flex-1 flex items-center justify-center gap-1.5 rounded-lg py-1.5 text-2xs font-bold transition"
          :class="
            activeDim === tab.key
              ? `bg-white shadow-sm ${tab.activeText}`
              : 'text-slate-500 hover:text-slate-700'
          "
          @click="activeDim = tab.key"
        >
          <span
            class="w-2 h-2 rounded-full flex-shrink-0"
            :class="activeDim === tab.key ? tab.activeDotBg : 'bg-slate-300'"
          ></span>
          <span class="truncate">
            {{ t(tab.labelKey) }}
            <span v-if="tab.pctToday != null" class="tabular-nums">· {{ tab.pctToday }}%</span>
          </span>
        </button>
      </div>

      <!-- Summary strip (3 KPI cells) — only when the chart has data. -->
      <div
        v-if="!weekLoading && !noEffectiveDays"
        class="grid grid-cols-3 gap-2 mb-3"
      >
        <div class="bg-slate-50 border border-slate-200 rounded-lg px-2.5 py-2">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.attendance.weekly.average') }}
          </p>
          <p class="text-sm font-black text-slate-900 tabular-nums mt-0.5">
            <template v-if="averagePct != null">{{ averagePct }}%</template>
            <template v-else>—</template>
          </p>
        </div>
        <div class="bg-slate-50 border border-slate-200 rounded-lg px-2.5 py-2">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.attendance.weekly.effectiveDays') }}
          </p>
          <p class="text-sm font-black text-slate-900 tabular-nums mt-0.5">
            {{ t('admin.attendance.weekly.daysUnit', { n: effectiveDayCount }) }}
          </p>
        </div>
        <div class="bg-slate-50 border border-slate-200 rounded-lg px-2.5 py-2">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.attendance.weekly.bestWorst') }}
          </p>
          <p class="text-2xs font-black text-slate-900 tabular-nums mt-0.5 truncate">
            <template v-if="bestDay && worstDay">
              {{ shortDow(bestDay.date) }} {{ bestDay.present_pct }}%
              <span class="text-slate-400 font-bold">/</span>
              {{ shortDow(worstDay.date) }} {{ worstDay.present_pct }}%
            </template>
            <template v-else>—</template>
          </p>
        </div>
      </div>

      <!-- Chart wrapper — skeleton while loading, empty-state when the
           whole week is non-workday, otherwise SVG bars. -->
      <div class="relative">
        <div
          v-if="weekLoading"
          class="h-[190px] rounded-lg bg-slate-50 animate-pulse"
        ></div>

        <p
          v-else-if="noEffectiveDays"
          class="h-[110px] flex items-center justify-center text-2xs text-slate-500 italic bg-slate-50 rounded-lg px-4 text-center"
        >
          {{ t('admin.attendance.weekly.emptyEffective') }}
        </p>

        <svg
          v-else
          :viewBox="`0 0 ${CHART_W} ${CHART_H}`"
          preserveAspectRatio="none"
          class="w-full h-[190px] overflow-visible"
          role="img"
          :aria-label="t('admin.attendance.weekly.chartAria')"
        >
          <!-- Gridlines @ 50 / 75 / 100 -->
          <line :x1="CHART_LEFT_PAD" :x2="CHART_W - CHART_RIGHT_PAD" :y1="yForPct(100)" :y2="yForPct(100)"
                stroke="#E2E8F0" stroke-width="1" stroke-dasharray="2 3"/>
          <line :x1="CHART_LEFT_PAD" :x2="CHART_W - CHART_RIGHT_PAD" :y1="yForPct(75)"  :y2="yForPct(75)"
                stroke="#E2E8F0" stroke-width="1" stroke-dasharray="2 3"/>
          <line :x1="CHART_LEFT_PAD" :x2="CHART_W - CHART_RIGHT_PAD" :y1="yForPct(50)"  :y2="yForPct(50)"
                stroke="#E2E8F0" stroke-width="1" stroke-dasharray="2 3"/>
          <text x="6" :y="yForPct(100) + 4" fill="#94A3B8" font-size="9.5"
                font-family="ui-monospace,Menlo,monospace">100</text>
          <text x="14" :y="yForPct(75) + 4" fill="#94A3B8" font-size="9.5"
                font-family="ui-monospace,Menlo,monospace">75</text>
          <text x="14" :y="yForPct(50) + 4" fill="#94A3B8" font-size="9.5"
                font-family="ui-monospace,Menlo,monospace">50</text>

          <!-- Bars -->
          <template v-for="(day, idx) in activeDays ?? []" :key="day.date">
            <!-- Off-day (weekend / holiday) — flat slate stub -->
            <rect
              v-if="!day.is_workday"
              :x="xForIndex(idx)"
              :y="OFF_Y"
              :width="BAR_WIDTH"
              :height="OFF_HEIGHT"
              rx="6"
              fill="#E2E8F0"
            />
            <!-- Empty workday (no records yet) — dashed outline -->
            <rect
              v-else-if="!day.has_data"
              :x="xForIndex(idx)"
              :y="OFF_Y"
              :width="BAR_WIDTH"
              :height="OFF_HEIGHT"
              rx="6"
              fill="transparent"
              stroke="#CBD5E1"
              stroke-dasharray="2 2"
              stroke-width="1"
            />
            <!-- Workday with data — dimension-coloured bar -->
            <rect
              v-else
              :x="xForIndex(idx)"
              :y="yForPct(day.present_pct)"
              :width="BAR_WIDTH"
              :height="heightForPct(day.present_pct)"
              rx="6"
              :fill="activeBarFill"
              opacity="0.86"
            />

            <!-- Value label -->
            <text
              :x="centerXForIndex(idx)"
              y="22"
              text-anchor="middle"
              font-size="10"
              font-weight="800"
              font-family="ui-monospace,Menlo,monospace"
              :fill="day.is_workday && day.has_data ? '#334155' : '#94A3B8'"
            >
              {{ day.is_workday && day.has_data ? `${day.present_pct}%` : '—' }}
            </text>

            <!-- Day label + date number -->
            <text
              :x="centerXForIndex(idx)"
              y="170"
              text-anchor="middle"
              font-size="11"
              font-weight="700"
              :fill="day.is_workday ? '#64748B' : '#94A3B8'"
            >
              {{ shortDow(day.date) }}
            </text>
            <text
              :x="centerXForIndex(idx)"
              y="184"
              text-anchor="middle"
              font-size="9"
              fill="#94A3B8"
              font-family="ui-monospace,Menlo,monospace"
            >
              {{ dayNumber(day.date) }}
            </text>

            <!-- HARI INI marker — dashed cobalt line over today's slot -->
            <template v-if="isToday(day.date)">
              <line
                :x1="centerXForIndex(idx)"
                :x2="centerXForIndex(idx)"
                :y1="CHART_TOP"
                :y2="CHART_BASE"
                stroke="#1B6FB8"
                stroke-width="1.5"
                stroke-dasharray="3 3"
              />
              <text
                :x="centerXForIndex(idx)"
                y="10"
                text-anchor="middle"
                font-size="9"
                font-weight="800"
                fill="#1B6FB8"
                font-family="ui-monospace,Menlo,monospace"
              >
                {{ t('admin.attendance.weekly.today') }}
              </text>
            </template>
          </template>
        </svg>

        <!-- Holiday pill row — sits below the chart, right-aligned. -->
        <div
          v-if="!weekLoading && holidayPills.length > 0"
          class="flex flex-wrap justify-end gap-1.5 mt-1"
        >
          <span
            v-for="pill in holidayPills"
            :key="pill.key"
            class="inline-flex items-center gap-1 bg-slate-100 text-slate-500 text-3xs font-bold px-2 py-0.5 rounded"
          >
            <span aria-hidden="true">◌</span>
            <span>{{ pill.dow }} · {{ pill.label }}</span>
          </span>
        </div>
      </div>
    </div>

    <!-- Per-kelas bar list — only when the ability granted the field
         AND the active tab is Siswa. Empty array (no sessions yet
         today) drops into a soft empty line instead of leaving a bare
         section header. -->
    <div
      v-if="hasPerClass && activeDim === 'student'"
      class="mt-4 pt-3 border-t border-slate-100"
    >
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

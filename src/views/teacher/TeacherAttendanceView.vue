<!--
  TeacherAttendanceView.vue — Presensi (list laporan kehadiran).

  Web port of the Flutter "Kehadiran" redesign — the landing page is
  a list of attendance reports per session, not a one-shot input form.
  Tapping a card routes the teacher to either:
    - /teacher/attendance/detail  (session sudah tercatat → lihat / edit)
    - /teacher/attendance/input   (session belum tercatat → input baru)

  Layout (consistent with TeacherScheduleView):
    1. <BrandPageHeader> + <RoleToggleChipRow> — shared
    2. <KpiStripCards> — shared (Hari ini / Tercatat / Belum / Rerata)
    3. <PageFilterToolbar> — shared (Periode · Kelas · Mapel + search)
    4. AsyncView body — day-grouped <SessionReportCard>s
    5. Floating "+ Tambah presensi session" CTA
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { AttendanceService } from '@/services/attendance.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import type {
  AttendanceKpiSummary,
  SessionReport,
} from '@/types/attendance';
import type { Classroom, Subject } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import RoleToggleChipRow, {
  type RoleOption,
} from '@/components/feature/RoleToggleChipRow.vue';
import Modal from '@/components/ui/Modal.vue';
import { useQuickAction } from '@/composables/useQuickAction';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const auth = useAuthStore();
const router = useRouter();
const { fromQuickAction, queryString } = useQuickAction();
const { t } = useI18n();

// ── Role chip state ──
const selectedRoleId = ref<string>('mengajar');
const roleOptions = computed<RoleOption[]>(() => {
  const out: RoleOption[] = [
    {
      id: 'mengajar',
      shortName: 'Mengajar',
      subLabel: 'Input presensi mapel saya',
      avatarInitials: 'M',
    },
  ];
  for (const hc of auth.homeroomClasses) {
    const name = hc.name || hc.id;
    out.push({
      id: `wali:${hc.id}`,
      shortName: `Wali ${name}`,
      subLabel: 'Kelas perwalian',
      avatarInitials:
        name.length === 0
          ? 'W'
          : name.length <= 2
            ? name.toUpperCase()
            : name.slice(0, 2).toUpperCase(),
    });
  }
  return out;
});
const isWaliMode = computed(() => selectedRoleId.value.startsWith('wali:'));
const activeHomeroomId = computed(() =>
  isWaliMode.value ? selectedRoleId.value.slice(5) : null,
);
const activeHomeroom = computed(() =>
  auth.homeroomClasses.find((h) => h.id === activeHomeroomId.value) ?? null,
);

// ── Filter state ──
type PeriodKey = 'today' | 'week' | 'last7' | 'month' | 'semester' | 'year';
const periodKey = ref<PeriodKey>('week');
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const classId = ref<string>('');
const subjectId = ref<string>('');
const searchQuery = ref<string>('');
const showPeriodPicker = ref(false);
const showClassPicker = ref(false);
const showSubjectPicker = ref(false);

const PERIOD_OPTIONS = computed<{ key: PeriodKey; label: string }[]>(() => [
  { key: 'today', label: t('common.today') },
  { key: 'week', label: t('teacher.attendance.thisWeek') },
  { key: 'last7', label: t('teacher.attendance.last7Days') },
  { key: 'month', label: t('teacher.attendance.thisMonth') },
  { key: 'semester', label: t('teacher.attendance.thisSemester') },
  { key: 'year', label: t('teacher.attendance.thisYear') },
]);
const activePeriod = computed(
  () =>
    PERIOD_OPTIONS.value.find((p) => p.key === periodKey.value) ?? PERIOD_OPTIONS.value[1],
);
const activeClass = computed(
  () => classes.value.find((c) => c.id === classId.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectId.value) ?? null,
);

// ── Data state ──
const reports = ref<SessionReport[]>([]);
const kpi = ref<AttendanceKpiSummary>({
  sessions_today: 0,
  sessions_completed: 0,
  sessions_pending: 0,
});
const isLoading = ref(true);
const error = ref<string | null>(null);

// ── Date helpers ──
function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function isoDaysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function startOfWeekIso(): string {
  const d = new Date();
  const dow = d.getDay();
  // Monday-based week: 0=Sun → -6 days back; 1=Mon → 0; etc.
  const offset = dow === 0 ? -6 : 1 - dow;
  d.setDate(d.getDate() + offset);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function startOfMonthIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}
function startOfYearIso(): string {
  return `${new Date().getFullYear()}-01-01`;
}
function startOfSemesterIso(): string {
  // Odd semester (Ganjil) ≈ Jul–Dec, even (Genap) ≈ Jan–Jun. Pick the
  // current semester's first month based on today's month.
  const d = new Date();
  const startMonth = d.getMonth() + 1 >= 7 ? 7 : 1;
  return `${d.getFullYear()}-${String(startMonth).padStart(2, '0')}-01`;
}
function dateRange(p: PeriodKey): { from: string; to: string } {
  const to = todayIso();
  switch (p) {
    case 'today':
      return { from: to, to };
    case 'week':
      return { from: startOfWeekIso(), to };
    case 'last7':
      return { from: isoDaysAgo(6), to };
    case 'month':
      return { from: startOfMonthIso(), to };
    case 'semester':
      return { from: startOfSemesterIso(), to };
    case 'year':
      return { from: startOfYearIso(), to };
  }
}

// ── Data loaders ──
async function loadReferences() {
  try {
    const [c, s] = await Promise.all([
      ClassroomService.list({ per_page: 100 }),
      SubjectService.list({ per_page: 100 }),
    ]);
    classes.value = c.items;
    subjects.value = s.items;

    if (fromQuickAction.value) {
      classId.value = queryString('class_id') ?? '';
      subjectId.value = queryString('subject_id') ?? '';
    }
  } catch (e) {
    error.value = (e as Error).message;
  }
}

async function loadReports() {
  isLoading.value = true;
  error.value = null;
  const teacherId = auth.teacherId ?? auth.user?.id ?? '';
  const { from, to } = dateRange(periodKey.value);
  try {
    // In parent-kelas mode lock class_id to the homeroom; otherwise honour
    // the filter chip.
    const effectiveClassId =
      activeHomeroomId.value || classId.value || undefined;
    const res = await AttendanceService.listReports({
      teacher_id: teacherId,
      date_start: from,
      date_end: to,
      class_id: effectiveClassId,
      subject_id: subjectId.value || undefined,
      search: searchQuery.value || undefined,
      view: isWaliMode.value ? 'homeroom' : 'session',
      per_page: 100,
    });
    reports.value = res.items;
    kpi.value = res.kpi;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await loadReports();
});

// Refetch on filter change.
watch([periodKey, classId, subjectId, selectedRoleId], () => {
  loadReports();
});

// Debounce-y enough — refetch on search after a small wait.
let searchTimer: ReturnType<typeof setTimeout> | null = null;
watch(searchQuery, () => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => loadReports(), 300);
});

// When the user flips to a parent chip, lock the class filter.
watch(activeHomeroomId, (newId) => {
  if (newId) classId.value = newId;
});

// Refetch when the active academic year changes via the chip.
useAcademicYearWatcher(() => loadReports());

// ── Client-side filter + grouping ──
/** Applied after the server fetch so the search field feels instant. */
const filteredReports = computed<SessionReport[]>(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return reports.value;
  return reports.value.filter(
    (r) =>
      r.subject_name.toLowerCase().includes(q) ||
      r.class_name.toLowerCase().includes(q),
  );
});

const totalSessions = computed(() => filteredReports.value.length);
const tercatatCount = computed(
  () => filteredReports.value.filter((r) => r.filled).length,
);
const belumCount = computed(() => totalSessions.value - tercatatCount.value);
const rerataPct = computed(() => {
  if (filteredReports.value.length === 0) return 0;
  const sum = filteredReports.value.reduce(
    (acc, r) => acc + (r.filled ? r.percentage : 0),
    0,
  );
  const filledCount = filteredReports.value.filter((r) => r.filled).length;
  if (filledCount === 0) return 0;
  return Math.round(sum / filledCount);
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'calendar',
    label: t('common.today'),
    value: kpi.value.sessions_today || sessionsTodayClientCount.value,
    suffix: t('common.sessions'),
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: t('teacher.attendance.recorded'),
    value: kpi.value.sessions_completed || tercatatCount.value,
    suffix: t('common.sessions'),
    tone: 'green',
  },
  {
    icon: 'bell',
    label: t('common.pending'),
    value: kpi.value.sessions_pending || belumCount.value,
    suffix: t('common.pending'),
    tone: 'amber',
  },
  {
    icon: 'bar-chart',
    label: t('teacher.attendance.averagePresent'),
    value: kpi.value.avg_present_pct ?? rerataPct.value,
    suffix: '%',
    tone: 'violet',
  },
]);

// Client-side fallback if KPI bundle is empty.
const sessionsTodayClientCount = computed(
  () => filteredReports.value.filter((r) => r.date === todayIso()).length,
);

/**
 * Reports grouped by date, newest first. Each entry is
 * `{ date, label, items }` ready to render under a section header.
 */
const reportsByDay = computed<
  Array<{ date: string; label: string; isToday: boolean; items: SessionReport[] }>
>(() => {
  const buckets = new Map<string, SessionReport[]>();
  for (const r of filteredReports.value) {
    const list = buckets.get(r.date) ?? [];
    list.push(r);
    buckets.set(r.date, list);
  }
  const dates = Array.from(buckets.keys()).sort((a, b) => b.localeCompare(a));
  return dates.map((date) => {
    const items = (buckets.get(date) ?? []).sort((a, b) =>
      (a.start_time ?? '').localeCompare(b.start_time ?? ''),
    );
    return {
      date,
      label: formatLongDate(date),
      isToday: date === todayIso(),
      items,
    };
  });
});

const state = computed<AsyncState<SessionReport[]>>(() => {
  if (isLoading.value && reports.value.length === 0)
    return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filteredReports.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredReports.value };
});

// ── Helpers ──
function formatLongDate(d: string): string {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  } catch {
    return d;
  }
}

function subjectInitial(name: string): string {
  const part = name.trim().split(/\s+/)[0] || '?';
  return part[0]?.toUpperCase() ?? '?';
}

/** Color tone for the per-session percentage pill. */
function pctTone(r: SessionReport): {
  bg: string;
  text: string;
  border: string;
  label: string;
} {
  if (!r.filled) {
    return {
      bg: 'bg-amber-50',
      text: 'text-amber-700',
      border: 'border-amber-200',
      label: t('common.pending'),
    };
  }
  if (r.percentage >= 90)
    return {
      bg: 'bg-emerald-50',
      text: 'text-emerald-700',
      border: 'border-emerald-200',
      label: `${r.percentage}%`,
    };
  if (r.percentage >= 75)
    return {
      bg: 'bg-amber-50',
      text: 'text-amber-700',
      border: 'border-amber-200',
      label: `${r.percentage}%`,
    };
  return {
    bg: 'bg-red-50',
    text: 'text-red-700',
    border: 'border-red-200',
    label: `${r.percentage}%`,
  };
}

// ── Navigation ──
function gotoReport(r: SessionReport) {
  const target = r.filled
    ? '/teacher/attendance/detail'
    : '/teacher/attendance/input';
  router.push({
    path: target,
    query: {
      class_id: r.class_id,
      subject_id: r.subject_id,
      date: r.date,
      ...(r.lesson_hour_id ? { lesson_hour_id: r.lesson_hour_id } : {}),
    },
  });
}

function gotoNewInput() {
  router.push({
    path: '/teacher/attendance/input',
    query: {
      ...(classId.value ? { class_id: classId.value } : {}),
      ...(subjectId.value ? { subject_id: subjectId.value } : {}),
      date: todayIso(),
    },
  });
}

// ── Picker helpers ──
function pickPeriod(k: PeriodKey) {
  periodKey.value = k;
  showPeriodPicker.value = false;
}
function pickClass(id: string) {
  classId.value = id;
  showClassPicker.value = false;
}
function pickSubject(id: string) {
  subjectId.value = id;
  showSubjectPicker.value = false;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <!-- ── 1. Header ─────────────────────────────────────────── -->
    <BrandPageHeader
      role="guru"
      :kicker="
        isWaliMode
          ? `Presensi · Wali Kelas ${activeHomeroom?.name ?? ''}`
          : 'Akademik · Kehadiran'
      "
      :title="
        isWaliMode
          ? `Laporan Kehadiran ${activeHomeroom?.name ?? ''}`
          : 'Laporan Kehadiran'
      "
      :meta="`${kpi.sessions_today} sesi hari ini · ${tercatatCount} tercatat · ${belumCount} menunggu`"
      :live-dot="!isWaliMode"
    >
      <template #role-toggle>
        <RoleToggleChipRow
          :roles="roleOptions"
          :selected-role-id="selectedRoleId"
          accent-color="#1B6FB8"
          @update:selected-role-id="(v) => (selectedRoleId = v)"
        />
      </template>
    </BrandPageHeader>

    <!-- ── 2. KPI strip ──────────────────────────────────────── -->
    <KpiStripCards :cards="kpiCards" />

    <!-- ── 3. Filter toolbar ─────────────────────────────────── -->
    <PageFilterToolbar
      :search="searchQuery"
      :search-placeholder="t('teacher.attendance.searchPlaceholder')"
      @update:search="(v) => (searchQuery = v)"
    >
      <template #chips>
        <AppFilterChip
          :label="t('common.period')"
          :value="activePeriod.label"
          icon-name="calendar"
          tone="amber"
          @click="showPeriodPicker = true"
        />
        <AppFilterChip
          v-if="!isWaliMode"
          :label="t('common.class')"
          :value="activeClass?.name ?? t('teacher.attendance.allClasses')"
          icon-name="layers"
          tone="violet"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          :label="t('common.subject')"
          :value="activeSubject?.name ?? t('teacher.attendance.allSubjects')"
          icon-name="book"
          tone="brand"
          @click="showSubjectPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- ── 4. Body ───────────────────────────────────────────── -->
    <AsyncView
      :state="state"
      :empty-title="t('teacher.attendance.noReportsYet')"
      :empty-description="t('teacher.attendance.noSessionsHelp')"
      @retry="loadReports"
    >
      <template #default>
        <div class="space-y-md">
          <section
            v-for="day in reportsByDay"
            :key="day.date"
            class="space-y-2"
          >
            <div class="flex items-center gap-2 px-1">
              <span
                class="text-2xs font-bold uppercase tracking-widest"
                :class="day.isToday ? 'text-brand-cobalt' : 'text-slate-500'"
              >
                {{ day.isToday ? `${t('common.today')} · ${day.label}` : day.label }}
              </span>
              <div
                class="flex-1 h-px"
                :class="day.isToday ? 'bg-brand-cobalt/30' : 'bg-slate-200'"
              ></div>
              <span
                class="text-3xs font-bold px-2 py-0.5 rounded-full"
                :class="
                  day.isToday
                    ? 'bg-brand-cobalt/10 text-brand-cobalt'
                    : 'bg-slate-100 text-slate-600'
                "
              >
                {{ day.items.length }} {{ t('common.sessions') }}
              </span>
            </div>

            <button
              v-for="r in day.items"
              :key="r.id"
              type="button"
              class="w-full text-left bg-white border border-slate-200 rounded-2xl p-3.5 transition-all hover:border-brand-cobalt/40 hover:shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
              :class="!r.filled ? 'border-amber-200 bg-amber-50/30' : ''"
              @click="gotoReport(r)"
            >
              <div class="flex items-center gap-3">
                <!-- Subject avatar -->
                <div
                  class="w-12 h-12 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0 text-lg font-black"
                >
                  {{ subjectInitial(r.subject_name) }}
                </div>

                <!-- Title + meta -->
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-1.5 min-w-0">
                    <span class="text-[14px] font-black text-slate-900 truncate">
                      {{ r.subject_name || '—' }}
                    </span>
                    <span class="text-slate-300 text-[12px]">·</span>
                    <span
                      class="bg-brand-cobalt/10 text-brand-cobalt px-1.5 py-0.5 rounded-full text-3xs font-bold flex-shrink-0"
                    >
                      {{ r.class_name }}
                    </span>
                  </div>
                  <div
                    class="flex items-center gap-1.5 mt-1 text-2xs text-slate-500 flex-wrap"
                  >
                    <template v-if="r.start_time">
                      <NavIcon name="calendar" :size="11" />
                      <span>{{ r.start_time }}<span v-if="r.end_time"> – {{ r.end_time }}</span></span>
                    </template>
                    <span
                      v-if="r.hour_number ?? r.jam_ke"
                      class="bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded-full text-3xs font-bold"
                    >
                      {{ t('teacher.attendance.hour') }} ke-{{ r.hour_number ?? r.jam_ke }}
                    </span>
                    <span
                      v-if="r.total > 0"
                      class="bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded-full text-3xs font-bold"
                    >
                      👥 {{ r.total }} {{ t('common.students') }}
                    </span>
                    <span
                      v-if="isWaliMode && r.teacher_name"
                      class="text-[10.5px] text-slate-400 truncate"
                    >
                      · {{ r.teacher_name }}
                    </span>
                  </div>

                  <!-- HSIA mini-chips (only when filled) -->
                  <div
                    v-if="r.filled"
                    class="flex items-center gap-1.5 mt-2 flex-wrap"
                  >
                    <span
                      class="inline-flex items-center gap-1 bg-emerald-50 text-emerald-700 px-2 py-0.5 rounded-full text-3xs font-bold"
                    >
                      H {{ r.hadir }}
                    </span>
                    <span
                      class="inline-flex items-center gap-1 bg-amber-50 text-amber-700 px-2 py-0.5 rounded-full text-3xs font-bold"
                    >
                      S {{ r.sakit }}
                    </span>
                    <span
                      class="inline-flex items-center gap-1 bg-sky-50 text-sky-700 px-2 py-0.5 rounded-full text-3xs font-bold"
                    >
                      I {{ r.izin }}
                    </span>
                    <span
                      class="inline-flex items-center gap-1 bg-red-50 text-red-700 px-2 py-0.5 rounded-full text-3xs font-bold"
                    >
                      A {{ r.alpa }}
                    </span>
                  </div>
                </div>

                <!-- Right side: percentage pill + CTA -->
                <div class="flex flex-col items-end gap-1.5 flex-shrink-0">
                  <span
                    class="inline-flex items-center gap-1 px-3 py-1 rounded-full text-[12px] font-black border"
                    :class="[
                      pctTone(r).bg,
                      pctTone(r).text,
                      pctTone(r).border,
                    ]"
                  >
                    <span>{{ pctTone(r).label }}</span>
                  </span>
                  <span
                    class="text-3xs font-bold uppercase tracking-widest"
                    :class="r.filled ? 'text-slate-500' : 'text-amber-700'"
                  >
                    {{ r.filled ? `${t('common.viewDetails')} ›` : `${t('teacher.attendance.enterNow')} →` }}
                  </span>
                </div>
              </div>
            </button>
          </section>
        </div>
      </template>
    </AsyncView>

    <!-- ── 5. Floating CTA ───────────────────────────────────── -->
    <button
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="gotoNewInput"
    >
      <NavIcon name="plus" :size="16" />
      {{ t('teacher.attendance.addSessionAttendance') }}
    </button>

    <!-- ── Periode picker ────────────────────────────────────── -->
    <Modal
      v-if="showPeriodPicker"
      :title="t('teacher.attendance.selectPeriod')"
      @close="showPeriodPicker = false"
    >
      <ul class="space-y-1 max-h-[360px] overflow-y-auto">
        <li v-for="p in PERIOD_OPTIONS" :key="p.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                p.key === periodKey,
            }"
            @click="pickPeriod(p.key)"
          >
            <span>{{ p.label }}</span>
            <span
              v-if="p.key === periodKey"
              class="text-3xs font-bold uppercase tracking-wider"
              >{{ t('common.active') }}</span
            >
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Class picker ──────────────────────────────────────── -->
    <Modal
      v-if="showClassPicker"
      :title="t('teacher.attendance.selectClass')"
      @close="showClassPicker = false"
    >
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold': classId === '',
            }"
            @click="pickClass('')"
          >
            {{ t('teacher.attendance.allClasses') }}
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold': c.id === classId,
            }"
            @click="pickClass(c.id)"
          >
            <span>{{ c.name }}</span>
            <span v-if="c.student_count" class="text-3xs text-slate-400">
              {{ c.student_count }} {{ t('common.students') }}
            </span>
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Subject picker ────────────────────────────────────── -->
    <Modal
      v-if="showSubjectPicker"
      :title="t('teacher.attendance.selectSubject')"
      @close="showSubjectPicker = false"
    >
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                subjectId === '',
            }"
            @click="pickSubject('')"
          >
            {{ t('teacher.attendance.allSubjects') }}
          </button>
        </li>
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                s.id === subjectId,
            }"
            @click="pickSubject(s.id)"
          >
            <span>{{ s.name }}</span>
            <span v-if="s.code" class="text-3xs text-slate-400">{{
              s.code
            }}</span>
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>

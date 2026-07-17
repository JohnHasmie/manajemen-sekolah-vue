<!--
  TeacherDashboardView.vue - teacher home.
  Mirrors Flutter's `teacher_dashboard_body.dart`:
    - stats.slices[] carousel with _GuruSlice schema
    - HeroStatsCard captions: sessions / attendance / RPP / grades
    - PriorityInbox from stats.priority_inbox + priority_inbox_total
    - stats.todays_schedule[] for the Schedule hari ini strip

  Layout follows the redesign mockup:
    1. Compact greeting row + tahun-pelajaran chip
    2. Inline KPI strip (no overlapping hero)
    3. Schedule hari ini (3-card strip, next session highlighted)
    4. 2-column main:
       - Left (8/12): Perlu Perhatian
       - Right (4/12): Aksi Cepat 2x2 + Modul More
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useLocaleWatcher } from '@/composables/useLocaleWatcher';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { useMeStore } from '@/stores/me';
import { DashboardService, type InboxResponse } from '@/services/dashboard.service';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import type { TeacherAttendanceConfig } from '@/types/teacher-attendance';
import { formatNumber, formatTime } from '@/lib/format';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import DashboardLayout from '@/components/layout/DashboardLayout.vue';
import StatSummaryCard, { type StatTrend } from '@/components/feature/StatSummaryCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import PriorityInbox, { type PriorityItem } from '@/components/feature/PriorityInbox.vue';
import AcademicYearChip from '@/components/feature/AcademicYearChip.vue';
import AcademicYearPickerModal from '@/components/feature/AcademicYearPickerModal.vue';
import TutoringEntryBanner from '@/components/feature/TutoringEntryBanner.vue';
import WelcomeBanner from '@/components/ui/WelcomeBanner.vue';
import GamificationHighlightCard from '@/components/feature/gamification/GamificationHighlightCard.vue';
import {
  TeacherProgressService,
  type HighlightPayload,
} from '@/services/teacher-progress.service';
import { useMe } from '@/composables/useMe';
import PinnedAnnouncementCarousel from '@/components/feature/PinnedAnnouncementCarousel.vue';
import { usePriorityInbox } from '@/composables/usePriorityInbox';

type StatsPayload = Record<string, any>;
type Slice = Record<string, any>;

interface ScheduleEntry {
  id?: string;
  subject_name?: string;
  subject?: string;
  class_name?: string;
  kelas?: string;
  start_time?: string;
  end_time?: string;
  room?: string;
  is_active?: boolean;
}

const auth = useAuthStore();
const me = useMeStore();
const meApi = useMe();
const router = useRouter();
const { t } = useI18n();

const showYearPicker = ref(false);

const stats = ref<StatsPayload>({});
const inbox = ref<InboxResponse>({ items: [], counts: {} });
const state = ref<AsyncState<StatsPayload>>({ status: 'loading' });
const lastSync = ref(new Date());

// Gamification highlight hero — hidden entirely when the school
// hasn't subscribed to teacher_gamification (ability is stripped
// server-side, so `meApi.can` returns false). Fetched lazily and
// silently — a 402/403 leaves `highlight` null and the section is
// skipped by the v-if, so no error surface bleeds into the
// dashboard.
const highlight = ref<HighlightPayload | null>(null);
const canSeePrestasi = computed(() => meApi.can('gamification.view'));

async function loadHighlight() {
  if (!canSeePrestasi.value) return;
  try {
    highlight.value = await TeacherProgressService.getHighlight();
  } catch {
    // Silent — a school losing the sub mid-session should not
    // interrupt the rest of the dashboard.
    highlight.value = null;
  }
}

// Teacher's own daily check-in (PRESENSI GURU) state — powers the
// "Anda belum presensi hari ini" Perlu-Perhatian nudge. Loaded from
// GET /teacher-attendance/config independently of the main stats so a
// 403 (module off / not a teacher) or network error just hides the
// nudge and never blocks the dashboard. `null` = unknown/not loaded.
const attendanceConfig = ref<TeacherAttendanceConfig | null>(null);

// Carousel state
const activeSlice = ref(0);
const sliceProgress = ref(0);
const isPaused = ref(false);
const SLICE_DURATION_MS = 5000;
const STEP_MS = 50;

let progressTimer: ReturnType<typeof setInterval> | null = null;

const slices = computed<Slice[]>(() => {
  const raw = stats.value.slices;
  return Array.isArray(raw) && raw.length > 0 ? (raw as Slice[]) : [synthAggregateSlice()];
});

const sliceCount = computed(() => slices.value.length);
const current = computed<Slice>(() => slices.value[Math.min(activeSlice.value, sliceCount.value - 1)] ?? {});

function synthAggregateSlice(): Slice {
  return {
    key: 'mengajar',
    label: t('teacher.dashboard.teaching'),
    is_aggregate: true,
    sessions_today: asInt(stats.value.classes_today ?? stats.value.sessions_today),
    sessions_today_done: 0,
    attendance_rate_window: 0,
    attendance_delta: 0,
    lesson_plans_approved: asInt(stats.value.rpp_approved),
    lesson_plans_pending: asInt(stats.value.rpp_pending),
    lesson_plans_revision: asInt(stats.value.rpp_rejected),
    grades_pending_sessions: 0,
  };
}

function asInt(v: unknown): number {
  if (typeof v === 'number') return Math.round(v);
  if (typeof v === 'string') return Number.parseInt(v, 10) || 0;
  return 0;
}

function num(key: string): number {
  return asInt(current.value[key]);
}

const sliceLabel = computed<string>(() => String(current.value.label ?? ''));
const sliceLabelMuted = computed<boolean>(() => Boolean(current.value.is_aggregate));

// Carousel timer (Stories style)
function startSlices() {
  stopSlices();
  progressTimer = setInterval(() => {
    if (isPaused.value) return;
    if (sliceCount.value <= 1) return;
    sliceProgress.value += STEP_MS / SLICE_DURATION_MS;
    if (sliceProgress.value >= 1) {
      sliceProgress.value = 0;
      activeSlice.value = (activeSlice.value + 1) % sliceCount.value;
    }
  }, STEP_MS);
}

function stopSlices() {
  if (progressTimer) {
    clearInterval(progressTimer);
    progressTimer = null;
  }
}

function goToSlice(idx: number) {
  activeSlice.value = Math.max(0, Math.min(idx, sliceCount.value - 1));
  sliceProgress.value = 0;
}

function togglePause() {
  isPaused.value = !isPaused.value;
}

// Captions mirror Flutter's _buildGuruSliceCards
const sessionsCaption = computed(() => {
  const total = num('sessions_today');
  const done = num('sessions_today_done');
  if (total > 0) return `${done} ${t('common.completed')} · ${total - done} belum`;
  return t('teacher.dashboard.noSessionsToday');
});

const attendanceTrend = computed<StatTrend | null>(() => {
  const delta = num('attendance_delta');
  if (delta === 0) return null;
  return {
    direction: delta > 0 ? 'up' : 'down',
    label: `${delta > 0 ? '+' : ''}${delta}%`,
  };
});

const rppNeedsAttention = computed(
  () => num('lesson_plans_pending') + num('lesson_plans_revision'),
);

const rppCaption = computed(() => {
  if (rppNeedsAttention.value > 0) {
    return `${num('lesson_plans_pending')} ${t('common.pending')} · ${num('lesson_plans_revision')} ${t('teacher.dashboard.revision')}`;
  }
  return `${num('lesson_plans_approved')} ${t('common.approved')}`;
});

const rppTone = computed<'warning' | 'success'>(() =>
  rppNeedsAttention.value > 0 ? 'warning' : 'success',
);

const gradesCaption = computed(() =>
  num('grades_pending_sessions') > 0 ? t('teacher.dashboard.needsGradeInput') : t('teacher.dashboard.allGradesEntered'),
);

const gradesTone = computed<'brand' | 'success'>(() =>
  num('grades_pending_sessions') > 0 ? 'brand' : 'success',
);

// Priority inbox — parser + tap router come from the shared composable
// so admin + parent + teacher use the same route resolution logic.
const { mapToPriorityItems, handlePriorityTap, priorityCountLabel } =
  usePriorityInbox('teacher');

const backendPriorityItems = computed<PriorityItem[]>(() =>
  mapToPriorityItems(stats.value.priority_inbox),
);

// Workweek gate — bit0=Sunday .. bit6=Saturday (default 62 = Mon–Fri).
// Keeps the nudge off weekends without a second round-trip. Holidays
// aren't captured here (config only exposes is_workday on an existing
// record), so this stays a simple "is today a scheduled workday" check.
function isTodayWorkday(cfg: TeacherAttendanceConfig): boolean {
  const mask = cfg.settings.workweek_days_bitmask ?? 62;
  const dow = new Date().getDay(); // 0=Sun..6=Sat
  return ((mask >> dow) & 1) === 1;
}

// Client-synthesised "Anda belum presensi hari ini" attention item —
// the on-screen companion to the FCM check-in reminder. Shown only when
// the teacher holds the self-attendance ability, today's config has
// loaded, today is a workday, and they have NOT yet checked in. Returns
// null (item hidden) the moment any of those flips — including right
// after a successful check-in, since a reload sets has_checked_in=true.
const selfAttendanceItem = computed<PriorityItem | null>(() => {
  if (!me.can('attendance.self.view_own')) return null;
  const cfg = attendanceConfig.value;
  if (!cfg) return null;
  if (cfg.state.has_checked_in) return null;
  if (!isTodayWorkday(cfg)) return null;
  return {
    id: 'teacher-self-attendance-not-checked-in',
    type: 'teacher_self_attendance',
    severity: 'warning',
    label: t('teacher.dashboard.selfAttendance.notCheckedInTitle'),
    subtitle: t('teacher.dashboard.selfAttendance.notCheckedInSubtitle'),
    count: 1,
    occurred_at: new Date().toISOString(),
    target_route: 'teacher_self_attendance',
    target_params: {},
  };
});

// The synthetic nudge (when present) leads the list so the teacher sees
// it first, followed by the backend aggregator rows.
const priorityItems = computed<PriorityItem[]>(() => {
  const self = selfAttendanceItem.value;
  const backend = backendPriorityItems.value;
  return self ? [self, ...backend] : backend;
});

const priorityTotal = computed(() => {
  const extra = selfAttendanceItem.value ? 1 : 0;
  const total = stats.value.priority_inbox_total;
  if (typeof total === 'number') return total + extra;
  if (typeof total === 'string')
    return (Number.parseInt(total, 10) || backendPriorityItems.value.length) + extra;
  return priorityItems.value.length;
});

const priorityHeaderLabel = computed(() =>
  priorityCountLabel(priorityItems.value.length, priorityTotal.value),
);

// Today's schedule (stats.todays_schedule[] from the Flutter dashboard state transformer)
//
// The backend ships denormalised Indonesian field names (mata_pelajaran_nama,
// kelas_nama, jam_mulai/jam_selesai) plus nested `subject`/`class` relation
// OBJECTS — NOT the English subject_name/class_name/start_time the card reads.
// Without mapping, `s.subject_name` was undefined and the template fell through
// to rendering the raw `subject` object/id ("berupa id schedule"). Mirror the
// normalisation Flutter already does in schedule.dart so names actually show.
const todaysSchedule = computed<ScheduleEntry[]>(() => {
  const raw = stats.value.todays_schedule;
  if (!Array.isArray(raw)) return [];
  const name = (v: unknown): string | undefined => {
    if (typeof v === 'string') return v;
    if (v && typeof v === 'object') {
      const o = v as Record<string, unknown>;
      return (o.name ?? o.nama) as string | undefined;
    }
    return undefined;
  };
  return (raw as Array<Record<string, any>>).map((r) => ({
    id: r.id,
    subject_name:
      r.subject_name ?? r.mata_pelajaran_nama ?? name(r.subject ?? r.mata_pelajaran),
    class_name: r.class_name ?? r.kelas_nama ?? name(r.class ?? r.kelas),
    start_time: r.start_time ?? r.jam_mulai ?? r.lesson_hour?.start_time ?? r.lesson_hour?.jam_mulai,
    end_time: r.end_time ?? r.jam_selesai ?? r.lesson_hour?.end_time ?? r.lesson_hour?.jam_selesai,
    room: r.room ?? r.ruangan ?? undefined,
    is_active: r.is_active,
  }));
});

function fmtTime(t?: string): string {
  if (!t) return '--:--';
  // Accept "HH:mm:ss", "HH:mm" or ISO. Strip seconds.
  const m = t.match(/(\d{1,2}):(\d{2})/);
  return m ? `${m[1].padStart(2, '0')}.${m[2]}` : t;
}

// Greeting based on time of day
const greeting = computed(() => {
  const h = new Date().getHours();
  if (h < 11) return t('teacher.dashboard.greetingMorning');
  if (h < 15) return t('teacher.dashboard.greetingAfternoon');
  if (h < 18) return t('teacher.dashboard.greetingEvening');
  return t('teacher.dashboard.greetingNight');
});

const today = computed(() => {
  return new Date().toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  });
});

// Data load
async function load() {
  state.value = { status: 'loading' };
  try {
    const role = auth.activeRole ?? 'teacher';
    const [statsData, inboxData] = await Promise.all([
      DashboardService.getStats(role),
      DashboardService.teacherPriorityInbox(20),
    ]);
    stats.value = statsData;
    inbox.value = inboxData;
    lastSync.value = new Date();
    state.value = { status: 'content', data: statsData };
    activeSlice.value = 0;
    sliceProgress.value = 0;
  } catch (e) {
    state.value = { status: 'error', error: (e as Error).message };
  }
  // Fire-and-forget: never let the check-in status fetch block or fail
  // the main dashboard render.
  void loadAttendanceStatus();
}

// Teacher self check-in status — fetched independently of the main
// stats so a 403 (module off / not a teacher) or network hiccup just
// hides the "belum presensi" nudge. Gated on the same ability the
// presensi-guru route uses; the router guard has already hydrated `me`
// before this view mounts, so the check is reliable here.
async function loadAttendanceStatus() {
  if (!me.can('attendance.self.view_own')) {
    attendanceConfig.value = null;
    return;
  }
  try {
    attendanceConfig.value = await TeacherAttendanceService.config();
  } catch {
    attendanceConfig.value = null;
  }
}

onMounted(() => {
  load();
  startSlices();
  void loadHighlight();
});

onUnmounted(stopSlices);

// Refetch when the active academic year changes via the chip.
useAcademicYearWatcher(() => load());

// Re-fetch the server-localised priority inbox (+ stats) when the user
// switches app language so "Perlu Perhatian" / "Needs Attention" labels
// follow the new locale without a manual page reload.
useLocaleWatcher(() => load());

interface QuickAction {
  label: string;
  icon: string;
  to: string;
  hint?: string;
}

// Each action carries the same gate the sidebar + router use (see
// `useNavMenu.ts` TEACHER_NAV and `router/index.ts` teacher meta) so
// dashboard tiles and menu items agree on what a tenant sees. `visible`
// undefined = always shown; filter drops tiles whose predicate is false.
type GatedAction = QuickAction & { visible?: () => boolean };

const quickActions = computed<QuickAction[]>(() => {
  const raw: GatedAction[] = [
    {
      label: t('common.schedule'),
      icon: 'calendar',
      to: '/teacher/schedule',
      hint: `${todaysSchedule.value.length} ${t('teacher.dashboard.sessionsToday')}`,
      visible: () => me.can('academic.schedule.view'),
    },
    {
      label: t('common.attendance'),
      icon: 'check-square',
      to: '/teacher/attendance',
      hint:
        num('sessions_today') > 0
          ? `${num('sessions_today') - num('sessions_today_done')} ${t('common.pending')}`
          : t('teacher.dashboard.viewAttendance'),
      visible: () => me.canAny(['attendance.student.submit', 'attendance.student.view']),
    },
    {
      label: t('common.activity'),
      icon: 'activity',
      to: '/teacher/class-activity',
      hint: t('teacher.dashboard.recordActivity'),
      visible: () => me.can('activity.view'),
    },
    {
      label: t('teacher.dashboard.inputGrades'),
      icon: 'edit',
      to: '/teacher/grades',
      hint:
        num('grades_pending_sessions') > 0
          ? `${num('grades_pending_sessions')} ${t('teacher.dashboard.classesReady')}`
          : t('teacher.dashboard.allCompleted'),
      visible: () => me.can('academic.grade.input'),
    },
  ];
  return raw.filter((a) => !a.visible || a.visible());
});

const secondaryActions = computed<{ label: string; icon: string; to: string }[]>(() => {
  const raw: (GatedAction & { hint?: undefined })[] = [
    { label: t('common.materials'), icon: 'book', to: '/teacher/materials',
      visible: () => me.can('academic.material.view') },
    { label: t('teacher.dashboard.draftLessonPlan'), icon: 'file-text', to: '/teacher/lesson-plans',
      visible: () => me.can('academic.lesson_plan.view') },
    { label: t('teacher.dashboard.aiRecommendations'), icon: 'sparkles', to: '/teacher/recommendations',
      visible: () => me.canAny(['communication.recommendation.view', 'communication.recommendation.create']) },
    { label: t('teacher.dashboard.eReportCard'), icon: 'file-plus', to: '/teacher/report-cards',
      visible: () => me.can('academic.report_card.view') },
  ];
  return raw
    .filter((a) => !a.visible || a.visible())
    .map(({ label, icon, to }) => ({ label, icon, to }));
});

// handlePriorityTap supplied by usePriorityInbox('teacher') above.
</script>

<template>
  <div class="space-y-6 pb-12">
    <!-- First-run welcome — dismissible, keyed per-role so a re-designed
         copy revision can invalidate the old sticker by bumping the
         suffix. Renders above the AsyncView so it shows on cold boot
         even before dashboard data has loaded. -->
    <WelcomeBanner
      storage-key="kamiledu.welcome.guru.v1"
      emoji="🎓"
      title="Selamat datang, Bapak/Ibu Guru!"
      message="Presensi harian ada di menu Presensi. RPP dan Kegiatan Kelas ada di Akademik. Nilai siswa bisa Anda input di Buku Nilai. Semoga hari mengajar Anda menyenangkan!"
      cta-label="Mengerti"
    />
    <PinnedAnnouncementCarousel viewer-role="teacher" />
    <AsyncView :state="state" :empty-title="t('common.empty')" @retry="load">
      <template #default>
        <!-- Shared scaffold: fixed vertical rhythm + slot order across
             every role dashboard. Slots: greeting → kpis → hero → main →
             quickActions. `padded` keeps this view's own page padding
             (admin/parent are rendered inside a shell that already pads).
             Content below is unchanged; only the outer wrapper + section
             grouping moved into named slots. -->
        <DashboardLayout padded>

          <!-- #greeting: compact greeting row + bimbel entry banner. -->
          <template #greeting>
          <section class="flex items-center justify-between gap-4">
            <div class="flex items-center gap-4 min-w-0">
              <div class="w-11 h-11 rounded-2xl bg-brand-cobalt/10 grid place-items-center text-brand-cobalt flex-shrink-0">
                <NavIcon name="sparkles" :size="22" />
              </div>
              <div class="min-w-0">
                <p class="text-2xs font-bold text-slate-400 tracking-widest uppercase leading-none">
                  {{ greeting }}
                </p>
                <h1 class="text-xl sm:text-2xl font-black text-slate-900 tracking-tight leading-tight mt-1 truncate">
                  Halo, <span class="text-brand-cobalt">{{ auth.user?.name ?? 'Guru' }}</span>
                </h1>
              </div>
            </div>

            <div class="flex items-center gap-2 flex-shrink-0">
              <span class="hidden md:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 text-3xs font-black uppercase tracking-widest">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                Realtime · {{ formatTime(lastSync) }}
              </span>
              <AcademicYearChip
                variant="light"
                :min-width="140"
                @open="showYearPicker = true"
              />
            </div>
          </section>

          <!-- Bimbel entry — only for tutoring-center tenants. -->
          <TutoringEntryBanner
            :subtitle="t('tutoring.entry.tutorSub')"
            @click="router.push({ name: 'teacher.tutoring.sessions' })"
          />
          </template>

          <!-- #kpis: KPI strip (inline, no hero) with slice carousel.
               These four cards are ALL backed by real data the teacher
               dashboard already loads via DashboardService.getStats(role)
               → stats.slices[] (or the synthesized aggregate slice):
                 • Sessions today   ← slice.sessions_today
                                       (falls back to stats.classes_today /
                                        stats.sessions_today)
                 • Attendance %     ← slice.attendance_rate_window
                                       (+ slice.attendance_delta trend)
                 • Lesson plans     ← slice.lesson_plans_approved /_pending
                                       /_revision (fallback stats.rpp_*)
                 • Grades pending   ← slice.grades_pending_sessions
               No fabricated metrics are added. Additional real signals the
               view already holds (today's schedule count, priority-inbox
               count) are surfaced in the #main sections below, not as fake
               KPI cards.
               TODO: if the stats endpoint later exposes e.g. an unread-
               announcement or assigned-subject count for teachers, add a
               5th real card here — do NOT synthesize one until then. -->
          <template #kpis>
          <section
            class="space-y-3"
            @mouseenter="isPaused = true"
            @mouseleave="isPaused = false"
          >
            <div v-if="sliceCount > 1" class="flex items-center justify-between gap-3 px-1">
              <div class="flex items-center gap-2 flex-wrap">
                <button
                  v-for="(s, idx) in slices"
                  :key="(s.key ?? idx) + ''"
                  type="button"
                  class="px-3 py-1.5 rounded-lg text-3xs font-black uppercase tracking-widest transition-all"
                  :class="
                    idx === activeSlice
                      ? 'bg-brand-cobalt text-white shadow-sm'
                      : 'bg-white text-slate-500 hover:text-slate-900 border border-slate-200'
                  "
                  @click="goToSlice(idx)"
                >
                  {{ s.label || `Slice ${idx + 1}` }}
                </button>
              </div>
              <button
                type="button"
                class="w-8 h-8 rounded-lg bg-white border border-slate-200 hover:border-slate-300 text-slate-500 hover:text-slate-900 grid place-items-center"
                :aria-label="isPaused ? 'Lanjutkan otomatis' : 'Jeda otomatis'"
                @click="togglePause"
              >
                <span class="text-3xs">{{ isPaused ? '▶' : '▮▮' }}</span>
              </button>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
              <StatSummaryCard
                :label="t('teacher.dashboard.sessionsCardLabel')"
                :value="formatNumber(num('sessions_today'))"
                tone="brand"
                icon-name="calendar"
                :sublabel="sessionsCaption"
                :slices="sliceCount"
                :active-slice="activeSlice"
                :slice-progress="sliceProgress"
                :slice-label="sliceLabel"
                :slice-label-muted="sliceLabelMuted"
                @click="router.push('/teacher/schedule')"
              />
              <StatSummaryCard
                :label="t('common.attendance')"
                :value="`${num('attendance_rate_window')}%`"
                tone="success"
                icon-name="check-circle"
                :sublabel="t('teacher.dashboard.periodAverage')"
                :trend="attendanceTrend"
                :slices="sliceCount"
                :active-slice="activeSlice"
                :slice-progress="sliceProgress"
                :slice-label="sliceLabel"
                :slice-label-muted="sliceLabelMuted"
                @click="router.push('/teacher/attendance')"
              />
              <StatSummaryCard
                :label="t('common.lessonPlan')"
                :value="formatNumber(num('lesson_plans_approved'))"
                :tone="rppTone"
                icon-name="clipboard-list"
                :sublabel="rppCaption"
                :slices="sliceCount"
                :active-slice="activeSlice"
                :slice-progress="sliceProgress"
                :slice-label="sliceLabel"
                :slice-label-muted="sliceLabelMuted"
                @click="router.push('/teacher/lesson-plans')"
              />
              <StatSummaryCard
                :label="t('teacher.dashboard.gradesNotYetEntered')"
                :value="formatNumber(num('grades_pending_sessions'))"
                :tone="gradesTone"
                icon-name="edit"
                :sublabel="gradesCaption"
                :slices="sliceCount"
                :active-slice="activeSlice"
                :slice-progress="sliceProgress"
                :slice-label="sliceLabel"
                :slice-label-muted="sliceLabelMuted"
                @click="router.push('/teacher/grades')"
              />
            </div>
          </section>
          </template>

          <!-- #main: today's schedule strip, then the two-column body
               (Perlu Perhatian inbox + Aksi Cepat / Modul). The teacher's
               quick actions live inside this two-column grid's right rail,
               so they stay here rather than in #quickActions. Internal
               24px rhythm preserved via space-y-6. -->
          <template #main>
          <div class="space-y-6">

          <!-- Gamification highlight — first thing the teacher sees when
               they've subscribed to the module. The card picks its
               own state (new_badge, level_up, ...) from the
               endpoint so the highlight rotates day-to-day. Skipped
               entirely when the ability is absent (school off the
               sub) or the fetch failed (silent). -->
          <GamificationHighlightCard
            v-if="canSeePrestasi && highlight"
            :state="highlight.state"
            :eyebrow="highlight.eyebrow"
            :title="highlight.title"
            :sub="highlight.sub"
            :mini-badge="highlight.mini_badge"
            :cta-label="highlight.cta_label"
            :cta-target="highlight.cta_target"
            :meta="highlight.meta"
            @cta="router.push(highlight.cta_target)"
          />

          <!-- 3. Schedule hari ini (real schedule strip) -->
          <section class="bg-white rounded-3xl border border-slate-100 p-5 shadow-sm">
            <header class="flex items-center justify-between mb-4 px-1">
              <div class="flex items-center gap-2.5">
                <div class="w-8 h-8 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center">
                  <NavIcon name="calendar" :size="16" />
                </div>
                <div>
                  <h3 class="text-sm font-black text-slate-900 tracking-tight leading-none">
                    {{ t('teacher.dashboard.todaysSchedule') }}
                  </h3>
                  <p class="text-2xs text-slate-400 font-bold mt-0.5">
                    {{ today }} · {{ todaysSchedule.length }} {{ t('common.sessions') }}
                  </p>
                </div>
              </div>
              <button
                type="button"
                class="text-2xs font-black text-brand-cobalt hover:text-brand-azure uppercase tracking-widest"
                @click="router.push('/teacher/schedule')"
              >
                {{ t('common.viewAll') }} →
              </button>
            </header>

            <div v-if="todaysSchedule.length === 0" class="py-8 text-center text-slate-400">
              <div class="w-14 h-14 mx-auto rounded-2xl bg-slate-50 grid place-items-center mb-3">
                <NavIcon name="activity" :size="28" />
              </div>
              <p class="text-sm font-bold text-slate-600">{{ t('teacher.dashboard.noScheduleToday') }}</p>
              <p class="text-xs text-slate-400 mt-1">{{ t('teacher.dashboard.scheduleCompleteOrNotStarted') }}</p>
            </div>

            <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2.5">
              <div
                v-for="(s, idx) in todaysSchedule.slice(0, 3)"
                :key="s.id ?? idx"
                class="rounded-2xl px-4 py-3.5 border transition-all cursor-pointer hover:-translate-y-0.5"
                :class="
                  s.is_active
                    ? 'bg-brand-cobalt/5 border-brand-cobalt/30 shadow-md shadow-brand-cobalt/10'
                    : 'bg-slate-50 border-slate-100 hover:border-slate-200'
                "
                @click="router.push('/teacher/schedule')"
              >
                <p
                  class="text-3xs font-black uppercase tracking-widest"
                  :class="s.is_active ? 'text-brand-cobalt' : 'text-slate-400'"
                >
                  {{ fmtTime(s.start_time) }} <span v-if="s.end_time">– {{ fmtTime(s.end_time) }}</span>
                </p>
                <p class="text-sm font-black text-slate-900 truncate mt-1">
                  {{ s.subject_name ?? t('common.subject') }}
                </p>
                <p class="text-2xs font-bold text-slate-500 truncate mt-0.5">
                  {{ s.class_name ?? '' }}<span v-if="s.room"> · {{ s.room }}</span>
                </p>
                <span
                  v-if="s.is_active"
                  class="mt-2 inline-flex items-center gap-1 text-4xs font-black uppercase tracking-widest px-2 py-0.5 rounded-md bg-brand-cobalt text-white"
                >
                  <span class="w-1 h-1 rounded-full bg-white animate-pulse"></span>
                  {{ t('teacher.dashboard.inProgress') }}
                </span>
              </div>
            </div>
          </section>

          <!-- 4. Two-column main: Perlu Perhatian (left) + Aksi Cepat & Modul (right) -->
          <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">

            <!-- Left: Perlu Perhatian -->
            <section class="lg:col-span-8">
              <div class="bg-white rounded-3xl border border-slate-100 p-5 shadow-sm">
                <header class="flex items-center justify-between mb-4 px-1">
                  <div class="flex items-center gap-2.5">
                    <div class="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 grid place-items-center">
                      <NavIcon name="bell" :size="16" />
                    </div>
                    <div class="flex items-center gap-2">
                      <h3 class="text-sm font-black text-slate-900 tracking-tight leading-none">
                        {{ t('teacher.dashboard.requiresAttention') }}
                      </h3>
                      <span
                        v-if="priorityItems.length > 0"
                        class="px-2 py-0.5 rounded-full bg-brand-cobalt text-white text-3xs font-black"
                      >
                        {{ priorityHeaderLabel }}
                      </span>
                    </div>
                  </div>
                  <button
                    v-if="priorityItems.length > 0"
                    type="button"
                    class="text-2xs font-black text-brand-cobalt hover:text-brand-azure uppercase tracking-widest"
                    @click="router.push({ name: 'teacher.inbox' })"
                  >
                    {{ t('common.viewAll') }} →
                  </button>
                </header>

                <PriorityInbox
                  :items="priorityItems"
                  :show-header="false"
                  @item-tap="handlePriorityTap"
                />
              </div>
            </section>

            <!-- Right: Aksi Cepat + Modul More -->
            <section class="lg:col-span-4 space-y-6">
              <!-- Aksi Cepat 2x2 -->
              <div class="bg-white rounded-3xl border border-slate-100 p-5 shadow-sm">
                <header class="flex items-center gap-2.5 mb-4 px-1">
                  <div class="w-8 h-8 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center">
                    <NavIcon name="sparkles" :size="16" />
                  </div>
                  <h3 class="text-sm font-black text-slate-900 tracking-tight leading-none">
                    {{ t('teacher.dashboard.quickActions') }}
                  </h3>
                </header>
                <div class="grid grid-cols-2 gap-2.5">
                  <button
                    v-for="a in quickActions"
                    :key="a.label"
                    type="button"
                    class="text-left p-4 rounded-2xl bg-slate-50 hover:bg-brand-cobalt/5 border border-transparent hover:border-brand-cobalt/20 transition-all group"
                    @click="router.push({ path: a.to, query: { from: 'quick-action' } })"
                  >
                    <div class="w-9 h-9 rounded-xl bg-white border border-slate-100 group-hover:bg-brand-cobalt group-hover:border-brand-cobalt grid place-items-center text-brand-cobalt group-hover:text-white transition-colors mb-2.5">
                      <NavIcon :name="a.icon" :size="18" />
                    </div>
                    <p class="text-sm font-black text-slate-900 tracking-tight leading-none">
                      {{ a.label }}
                    </p>
                    <p v-if="a.hint" class="text-3xs font-bold text-slate-400 mt-1.5 truncate">
                      {{ a.hint }}
                    </p>
                  </button>
                </div>
              </div>

              <!-- Modul More - clean list, no gradient -->
              <div class="bg-white rounded-3xl border border-slate-100 p-5 shadow-sm">
                <header class="flex items-center gap-2.5 mb-4 px-1">
                  <div class="w-8 h-8 rounded-xl bg-slate-100 text-slate-500 grid place-items-center">
                    <NavIcon name="book" :size="16" />
                  </div>
                  <div>
                    <h3 class="text-sm font-black text-slate-900 tracking-tight leading-none">
                      {{ t('teacher.dashboard.otherModules') }}
                    </h3>
                    <p class="text-3xs text-slate-400 font-bold mt-0.5">
                      {{ t('teacher.dashboard.accessReportsAndTools') }}
                    </p>
                  </div>
                </header>
                <div class="space-y-1.5">
                  <button
                    v-for="a in secondaryActions"
                    :key="a.label"
                    type="button"
                    class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-slate-50 transition-colors group text-left"
                    @click="router.push(a.to)"
                  >
                    <div class="w-7 h-7 rounded-lg bg-slate-50 text-brand-cobalt group-hover:bg-brand-cobalt group-hover:text-white grid place-items-center transition-colors">
                      <NavIcon :name="a.icon" :size="14" />
                    </div>
                    <span class="flex-1 text-sm font-bold text-slate-700 group-hover:text-slate-900">
                      {{ a.label }}
                    </span>
                    <span class="text-slate-300 group-hover:text-brand-cobalt transition-colors">→</span>
                  </button>
                </div>
              </div>
            </section>
          </div>

          </div>
          </template>

        </DashboardLayout>
      </template>
    </AsyncView>

    <AcademicYearPickerModal
      v-if="showYearPicker"
      role="teacher"
      @close="showYearPicker = false"
    />
  </div>
</template>

<!--
  AdminDashboardView.vue — admin home ("Opsi A — Command Center").

  Layout (top → bottom), mirrors the approved Opsi A mockup + Flutter:
    1. Greeting header       — name + tingkat chips + Tahun Ajaran + REALTIME
    2. Status band           — Pusat Kendali (readiness) LEFT · 2×2 KPI tiles RIGHT
                               (Total Siswa · Total Guru · Total Staf · RPP Menunggu)
    3. Hari ini band         — Kehadiran Sekolah (donuts + weekly chart) LEFT ·
                               [Perlu Perhatian + Keuangan slim] rail RIGHT
    4. Engagement band       — GATED on `canSeePrestasi` (gamification module):
                                 · active  → merged EngagementToggleCard LEFT +
                                             Akses cepat (4 tiles) rail RIGHT
                                 · absent  → full-width Akses cepat (6 tiles) +
                                             tasteful upsell strip
    5. Langganan             — SubscriptionMiniRow, pinned to the BOTTOM

  The old floating KPI strip, the duplicate "Kehadiran Hari Ini" KPI, the
  four separate Prestasi/Engagement cards, and the "Manajemen Sekolah"
  12-tile grid (which duplicated the left nav) are all gone — consolidated
  into the bands above.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { useMeStore } from '@/stores/me';
import { DashboardService } from '@/services/dashboard.service';
import { formatNumber, formatDateLong } from '@/lib/format';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import DashboardLayout from '@/components/layout/DashboardLayout.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import AcademicYearChip from '@/components/feature/AcademicYearChip.vue';
import AcademicYearPickerModal from '@/components/feature/AcademicYearPickerModal.vue';
import TutoringEntryBanner from '@/components/feature/TutoringEntryBanner.vue';
import AdminControlCenterCard from '@/components/feature/AdminControlCenterCard.vue';
import AdminAttendanceOverviewCard from '@/components/feature/AdminAttendanceOverviewCard.vue';
import SubscriptionMiniRow from '@/components/feature/SubscriptionMiniRow.vue';
import AdminTutoringDashboardView from '@/views/admin/tutoring/AdminTutoringDashboardView.vue';
import AttentionPanel, { type AttentionItem } from '@/components/feature/AttentionPanel.vue';
import EngagementToggleCard from '@/components/feature/gamification/EngagementToggleCard.vue';
import {
  TeacherProgressService,
  type AdminHighlightPayload,
  type AdminSummaryPayload,
  type AdminStaffHighlightPayload,
  type AdminStaffSummaryPayload,
} from '@/services/teacher-progress.service';
import { ReadinessService, type ReadinessPayload } from '@/services/readiness.service';
import { useMe } from '@/composables/useMe';
import { useTenant } from '@/composables/useTenant';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useLocaleWatcher } from '@/composables/useLocaleWatcher';
import PinnedAnnouncementCarousel from '@/components/feature/PinnedAnnouncementCarousel.vue';

type StatsPayload = Record<string, any>;
type Slice = Record<string, any>;

const auth = useAuthStore();
const me = useMeStore();
const meApi = useMe();
const router = useRouter();
const { t, locale } = useI18n();

// Prestasi (paid module). `canSeePrestasi` is the SINGLE entitlement flag
// that gates the whole engagement band + the upsell strip — reused exactly
// as before (server ability strip flips it false when the school hasn't
// subscribed to the gamification module).
const canSeePrestasi = computed(() => meApi.can('gamification.admin.view'));
const adminHighlight = ref<AdminHighlightPayload | null>(null);
const adminSummary = ref<AdminSummaryPayload | null>(null);
// Staff-side highlight + summary (BE MR6/7 /admin/staff-engagement/*).
// Both null when the school owns no staff so the merged card degrades to
// guru-only (no toggle) for single-guru bimbel.
const adminStaffHighlight = ref<AdminStaffHighlightPayload | null>(null);
const adminStaffSummary = ref<AdminStaffSummaryPayload | null>(null);

// Readiness teaser — CORE feature, gated only on `readiness.view`.
const canSeeReadiness = computed(() => meApi.can('readiness.view'));
const readinessPayload = ref<ReadinessPayload | null>(null);

async function loadPrestasi() {
  if (!canSeePrestasi.value) return;
  try {
    const [s, r] = await Promise.all([
      TeacherProgressService.getAdminHighlight(),
      TeacherProgressService.getAdminSummary(),
    ]);
    adminHighlight.value = s;
    adminSummary.value = r;
  } catch {
    // Silent — a mid-session sub loss must not disrupt the rest of the
    // dashboard. The v-if drops the band cleanly.
    adminHighlight.value = null;
    adminSummary.value = null;
  }
  // Staff highlight + summary fetched independently. A tenant may have
  // zero staff rows (single-guru bimbel) — the merged card self-hides the
  // Staf toggle when `total_staff === 0`, so we still fetch to know that.
  try {
    const [sh, ss] = await Promise.all([
      TeacherProgressService.getAdminStaffHighlight(),
      TeacherProgressService.getAdminStaffSummary(),
    ]);
    adminStaffHighlight.value = sh;
    adminStaffSummary.value = ss;
  } catch {
    adminStaffHighlight.value = null;
    adminStaffSummary.value = null;
  }
}

async function loadReadiness() {
  if (!canSeeReadiness.value) return;
  try {
    readinessPayload.value = await ReadinessService.get();
  } catch {
    // Silent — card degrades when this stays null.
    readinessPayload.value = null;
  }
}

function gotoReadiness() {
  router.push({ name: 'admin.readiness' });
}

// A tutoring-center admin gets the bimbel dashboard; the school KPIs
// below read zero for a bimbel. Reactive so it swaps in as soon as the
// tenant resolves (the route redirect can race the schools fetch).
const { isTutoringCenter } = useTenant();

const showYearPicker = ref(false);

const stats = ref<StatsPayload>({});
const state = ref<AsyncState<StatsPayload>>({ status: 'loading' });

// Slice (tingkat) carousel
const sliceKey = ref<string>('all');

const slices = computed<Slice[]>(() => {
  const raw = stats.value.slices;
  if (Array.isArray(raw) && raw.length > 0) return raw as Slice[];
  return [
    {
      key: 'all',
      label: t('admin.dashboard.allLevels'),
      is_aggregate: true,
      total_students: asInt(stats.value.total_students),
      total_teachers: asInt(stats.value.total_teachers),
      total_classes: asInt(stats.value.total_classes),
      attendance_rate: asInt(stats.value.attendance_rate_today),
      attendance_delta: 0,
      pending_lesson_plans: asInt(stats.value.pending_lesson_plans),
    },
  ];
});

const sliceOptions = computed(() =>
  slices.value.map((s) => ({
    key: String(s.key ?? s.label),
    label: String(s.label ?? 'Slice'),
  })),
);

const current = computed<Slice>(() => {
  return (
    slices.value.find((s) => String(s.key ?? s.label) === sliceKey.value) ??
    slices.value[0] ??
    {}
  );
});

function asInt(v: unknown): number {
  if (typeof v === 'number') return Math.round(v);
  if (typeof v === 'string') return Number.parseInt(v, 10) || 0;
  return 0;
}

function num(key: string): number {
  return asInt(current.value[key]);
}

function topLevelNum(key: string): number {
  return asInt(stats.value[key]);
}

const greeting = computed(() => {
  const h = new Date().getHours();
  if (h < 11) return t('common.greetingMorning');
  if (h < 15) return t('common.greetingAfternoon');
  if (h < 18) return t('common.greetingEvening');
  return t('common.greetingNight');
});

async function load() {
  state.value = { status: 'loading' };
  try {
    const data = await DashboardService.getStats('admin');
    stats.value = data;
    state.value = { status: 'content', data };
    if (sliceOptions.value.length > 0 && !sliceOptions.value.find((o) => o.key === sliceKey.value)) {
      sliceKey.value = sliceOptions.value[0].key;
    }
  } catch (e) {
    state.value = { status: 'error', error: (e as Error).message };
  }
}

onMounted(() => {
  void load();
  void loadPrestasi();
  void loadReadiness();
});

// Refetch when the active academic year changes via the chip.
useAcademicYearWatcher(() => load());

// Re-fetch the server-localised stats when the user switches app language.
useLocaleWatcher(() => load());

interface QuickAction {
  labelKey: string;
  icon: string;
  to: string;
  /** Gate the action against the tenant's entitlement (undefined = ungated). */
  visible?: () => boolean;
}

// Same mirror as `useNavMenu.ts` — siswa/kelas gate on hasStudentContext
// and mapel on hasAcademicContext. Reports quick-actions gate on the same
// abilities the router uses so nav + dashboard always agree.
const quickActions = computed<QuickAction[]>(() => {
  const raw: QuickAction[] = [
    { labelKey: 'nav.students', icon: 'users', to: '/admin/students',
      visible: () => me.hasStudentContext },
    { labelKey: 'nav.teachers', icon: 'user-check', to: '/admin/teachers' },
    { labelKey: 'nav.classes', icon: 'layers', to: '/admin/classes',
      visible: () => me.hasStudentContext },
    { labelKey: 'nav.subjects', icon: 'book', to: '/admin/subjects',
      visible: () => me.hasAcademicContext },
    { labelKey: 'nav.schedule', icon: 'calendar', to: '/admin/schedule',
      visible: () => me.can('academic.schedule.view') },
    { labelKey: 'nav.attendance', icon: 'check-square', to: '/admin/student-attendance',
      visible: () => me.canAny(['attendance.student.view', 'attendance.student.export']) },
    { labelKey: 'nav.lessonPlans', icon: 'file-text', to: '/admin/lesson-plans',
      visible: () => me.can('academic.lesson_plan.view') },
    { labelKey: 'nav.finance', icon: 'wallet', to: '/admin/finance',
      visible: () => me.can('finance.bill.view') },
    { labelKey: 'nav.grades', icon: 'edit-3', to: '/admin/grades',
      visible: () => me.can('academic.grade.view') },
    { labelKey: 'nav.gradeRecap', icon: 'bar-chart', to: '/admin/grade-recap',
      visible: () => me.can('academic.grade.recap.view') },
    { labelKey: 'nav.reportCards', icon: 'file-plus', to: '/admin/report-cards',
      visible: () => me.can('academic.report_card.view') },
    { labelKey: 'nav.announcements', icon: 'megaphone', to: '/admin/announcements',
      visible: () => me.can('communication.announcement.view') },
  ];
  return raw.filter((a) => !a.visible || a.visible());
});

// ─── Finance ─────────────────────────────────────────────────────────
const financeReceived = computed(() => topLevelNum('finance_received'));
const financeOutstanding = computed(() => topLevelNum('finance_outstanding'));
const financeTotal = computed(() => financeReceived.value + financeOutstanding.value);
const financePct = computed(() =>
  financeTotal.value > 0
    ? Math.round((financeReceived.value / financeTotal.value) * 100)
    : 0,
);
const financeMonthLabel = computed(() =>
  new Intl.DateTimeFormat(locale.value, { month: 'long' }).format(new Date()),
);

// ─── KPI tiles (status band) ─────────────────────────────────────────
// Total Staf uses the new MR!527 `total_staff` field; "—" when absent.
const totalStaffDisplay = computed<string>(() => {
  const v = stats.value.total_staff;
  if (v == null) return '—';
  return formatNumber(asInt(v));
});
const pendingLessonPlans = computed(
  () => num('pending_lesson_plans') || topLevelNum('pending_lesson_plans'),
);

// ─── Header date ─────────────────────────────────────────────────────
const todayLabel = computed(() => formatDateLong(new Date()));

// ─── Perlu Perhatian — client-side, no new endpoint ──────────────────
// Derived purely from data already on the dashboard payloads. Ordered by
// severity (critical → warning → info); AttentionPanel renders the
// "Semua aman" fallback when this is empty.
const attentionItems = computed<AttentionItem[]>(() => {
  const items: AttentionItem[] = [];

  // 1. Staff attendance today < 100% → red.
  const staffAtt = stats.value.staff_attendance_today as
    | { present_pct: number; total: number; present: number }
    | null
    | undefined;
  if (
    staffAtt &&
    typeof staffAtt === 'object' &&
    staffAtt.total > 0 &&
    staffAtt.present_pct < 100
  ) {
    const notYet = Math.max(0, staffAtt.total - staffAtt.present);
    items.push({
      key: 'staff-attendance',
      severity: 'critical',
      icon: 'briefcase',
      title: t('admin.dashboard.attention.staffAttendanceTitle', {
        pct: Math.round(staffAtt.present_pct),
      }),
      subtitle: t('admin.dashboard.attention.staffAttendanceSub', {
        n: notYet,
        total: staffAtt.total,
      }),
      route: '/admin/teacher-attendance/report',
    });
  }

  // 2. Gamification active AND engagement "sepi" (quiet) staff > 0 → amber.
  if (
    canSeePrestasi.value &&
    adminStaffSummary.value &&
    adminStaffSummary.value.needs_attention_count > 0
  ) {
    items.push({
      key: 'staff-quiet',
      severity: 'warning',
      icon: 'flame',
      title: t('admin.dashboard.attention.staffQuietTitle', {
        n: adminStaffSummary.value.needs_attention_count,
      }),
      subtitle: t('admin.dashboard.attention.staffQuietSub'),
      route: '/admin/staff-engagement',
    });
  }

  // 3. Lowest class attendance < 95% → info.
  const perClass = stats.value.attendance_per_class as
    | { class_id: string; class_name: string; present_pct: number }[]
    | null
    | undefined;
  if (Array.isArray(perClass) && perClass.length > 0) {
    const lowest = perClass.reduce((a, b) =>
      b.present_pct < a.present_pct ? b : a,
    );
    if (lowest.present_pct < 95) {
      items.push({
        key: 'low-class',
        severity: 'info',
        icon: 'layers',
        title: t('admin.dashboard.attention.lowClassTitle', {
          name: lowest.class_name,
          pct: Math.round(lowest.present_pct),
        }),
        subtitle: t('admin.dashboard.attention.lowClassSub'),
        route: '/admin/student-attendance',
      });
    }
  }

  const rank: Record<AttentionItem['severity'], number> = {
    critical: 0,
    warning: 1,
    info: 2,
  };
  return items.sort((a, b) => rank[a.severity] - rank[b.severity]);
});

// ─── Akses cepat (curated quick tiles) ───────────────────────────────
interface QuickTile {
  labelKey: string;
  icon: string;
  to: string;
  tone: 'blue' | 'violet' | 'amber' | 'green';
}
const TILE_TONE: Record<string, QuickTile['tone']> = {
  'nav.reportCards': 'blue',
  'nav.gradeRecap': 'violet',
  'nav.grades': 'amber',
  'nav.finance': 'green',
  'nav.announcements': 'amber',
  'nav.schedule': 'blue',
};
const TILE_TINT: Record<QuickTile['tone'], string> = {
  blue: 'bg-blue-50 text-blue-600',
  violet: 'bg-violet-100 text-violet-600',
  amber: 'bg-amber-100 text-amber-600',
  green: 'bg-emerald-100 text-emerald-600',
};
function tileTintClass(tone: QuickTile['tone']): string {
  return TILE_TINT[tone];
}
function pickTiles(keys: string[]): QuickTile[] {
  return keys
    .map((k) => {
      const found = quickActions.value.find((a) => a.labelKey === k);
      if (!found) return null;
      return {
        labelKey: found.labelKey,
        icon: found.icon,
        to: found.to,
        tone: TILE_TONE[k] ?? 'blue',
      } satisfies QuickTile;
    })
    .filter((x): x is QuickTile => x !== null);
}
// With gamification: compact 4-tile rail. Without: full-width 6 tiles.
const quickTilesWithGami = computed(() =>
  pickTiles(['nav.reportCards', 'nav.gradeRecap', 'nav.announcements', 'nav.finance']),
);
const quickTilesNoGami = computed(() =>
  pickTiles([
    'nav.reportCards',
    'nav.gradeRecap',
    'nav.grades',
    'nav.finance',
    'nav.announcements',
    'nav.schedule',
  ]),
);

function gotoModules() {
  router.push('/admin/settings/modules');
}
</script>

<template>
  <AdminTutoringDashboardView v-if="isTutoringCenter" />
  <div v-else class="space-y-md">
    <AsyncView :state="state" :empty-title="t('common.empty')" @retry="load">
      <template #default>
        <DashboardLayout>

          <!-- #greeting: compact greeting + slice tabs + AY chip + REALTIME,
               then the bimbel entry banner (self-hides for schools). -->
          <template #greeting>
            <section class="flex items-center justify-between gap-4 flex-wrap">
              <div class="flex items-center gap-3 min-w-0">
                <div class="w-10 h-10 rounded-2xl bg-role-admin/10 grid place-items-center text-role-admin flex-shrink-0">
                  <NavIcon name="sparkles" :size="20" />
                </div>
                <div class="min-w-0">
                  <p class="text-3xs font-bold text-slate-400 tracking-widest uppercase">{{ greeting }}</p>
                  <h1 class="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                    {{ t('admin.sekolah.dashboard.greeting_prefix') }} <span class="text-role-admin">{{ auth.user?.name }}</span>
                  </h1>
                </div>
              </div>
              <div class="flex items-center gap-2 flex-wrap">
                <SegmentedControl
                  v-if="sliceOptions.length > 1"
                  v-model="sliceKey"
                  :options="sliceOptions"
                  size="sm"
                />
                <AcademicYearChip
                  variant="light"
                  :min-width="140"
                  @open="showYearPicker = true"
                />
                <span class="hidden md:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 text-3xs font-bold uppercase tracking-widest">
                  <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                  {{ t('admin.sekolah.dashboard.realtime') }}
                </span>
              </div>
            </section>

            <!-- Bimbel entry — only for tutoring-center tenants. -->
            <TutoringEntryBanner
              :subtitle="t('admin.sekolah.dashboard.tutoring_banner_subtitle')"
              @click="router.push({ name: 'admin.tutoring.programs' })"
            />
          </template>

          <!-- #main: all bands, in fixed vertical order. -->
          <template #main>
          <div class="space-y-md">

            <!-- Pengumuman disematkan — self-hides when empty. -->
            <PinnedAnnouncementCarousel viewer-role="admin" />

            <!-- ── 1. Status band ─────────────────────────────────── -->
            <div class="space-y-2.5">
              <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest px-1">
                {{ t('admin.dashboard.sectionStatus') }}
              </p>
              <div class="grid grid-cols-1 lg:grid-cols-[1.7fr_1fr] gap-md items-start">
                <!-- LEFT: Pusat Kendali (readiness) -->
                <AdminControlCenterCard
                  :readiness="canSeeReadiness ? readinessPayload : null"
                  :pending-lesson-plans="topLevelNum('pending_lesson_plans')"
                  :draft-announcements="topLevelNum('draft_announcements')"
                  :overdue-bills="topLevelNum('overdue_bills')"
                  :quick-actions="quickActions"
                  :show-enable-cta="
                    canSeeReadiness &&
                    (!readinessPayload || !readinessPayload.supported)
                  "
                  @enable-click="gotoReadiness"
                />

                <!-- RIGHT: 2×2 compact KPI tiles -->
                <div class="grid grid-cols-2 gap-3">
                  <button
                    v-if="me.hasStudentContext"
                    type="button"
                    class="bg-white border border-slate-200 rounded-2xl p-3 text-left hover:border-role-admin hover:shadow-sm transition-all"
                    @click="router.push('/admin/students')"
                  >
                    <span class="w-8 h-8 rounded-xl grid place-items-center bg-brand-cobalt/10 text-brand-cobalt">
                      <NavIcon name="users" :size="16" />
                    </span>
                    <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mt-2">
                      {{ t('admin.dashboard.totalStudents') }}
                    </p>
                    <p class="text-xl font-black text-slate-900 tabular-nums leading-none mt-0.5">
                      {{ formatNumber(num('total_students') || topLevelNum('total_students')) }}
                    </p>
                    <p class="text-3xs text-slate-400 mt-1">
                      {{ num('total_classes') || topLevelNum('total_classes') }} {{ t('admin.dashboard.classCount') }}
                    </p>
                  </button>

                  <button
                    type="button"
                    class="bg-white border border-slate-200 rounded-2xl p-3 text-left hover:border-role-admin hover:shadow-sm transition-all"
                    @click="router.push('/admin/teachers')"
                  >
                    <span class="w-8 h-8 rounded-xl grid place-items-center bg-teal-50 text-teal-600">
                      <NavIcon name="user-check" :size="16" />
                    </span>
                    <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mt-2">
                      {{ t('admin.dashboard.totalTeachers') }}
                    </p>
                    <p class="text-xl font-black text-slate-900 tabular-nums leading-none mt-0.5">
                      {{ formatNumber(num('total_teachers') || topLevelNum('total_teachers')) }}
                    </p>
                    <p class="text-3xs text-slate-400 mt-1">{{ t('admin.dashboard.teacherActive') }}</p>
                  </button>

                  <button
                    type="button"
                    class="bg-white border border-slate-200 rounded-2xl p-3 text-left hover:border-role-admin hover:shadow-sm transition-all"
                    @click="router.push('/admin/staff')"
                  >
                    <span class="w-8 h-8 rounded-xl grid place-items-center bg-violet-100 text-violet-600">
                      <NavIcon name="briefcase" :size="16" />
                    </span>
                    <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mt-2">
                      {{ t('admin.dashboard.totalStaff') }}
                    </p>
                    <p class="text-xl font-black text-slate-900 tabular-nums leading-none mt-0.5">
                      {{ totalStaffDisplay }}
                    </p>
                    <p class="text-3xs text-slate-400 mt-1">{{ t('admin.dashboard.staffLabel') }}</p>
                  </button>

                  <button
                    v-if="me.can('academic.lesson_plan.view')"
                    type="button"
                    class="bg-white border border-slate-200 rounded-2xl p-3 text-left hover:border-role-admin hover:shadow-sm transition-all"
                    @click="router.push('/admin/lesson-plans')"
                  >
                    <span class="w-8 h-8 rounded-xl grid place-items-center bg-amber-100 text-amber-600">
                      <NavIcon name="file-text" :size="16" />
                    </span>
                    <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mt-2">
                      {{ t('admin.dashboard.pendingLessonPlans') }}
                    </p>
                    <p class="text-xl font-black text-slate-900 tabular-nums leading-none mt-0.5">
                      {{ formatNumber(pendingLessonPlans) }}
                    </p>
                    <p class="text-3xs text-slate-400 mt-1">
                      <template v-if="pendingLessonPlans === 0">{{ t('admin.dashboard.inboxClean') }}</template>
                      <template v-else>{{ topLevelNum('rpp_rejected') }} {{ t('admin.dashboard.needRevision') }}</template>
                    </p>
                  </button>
                </div>
              </div>
            </div>

            <!-- ── 2. Hari ini band ──────────────────────────────── -->
            <div class="space-y-2.5">
              <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest px-1">
                {{ t('admin.dashboard.sectionToday') }} · {{ todayLabel }}
              </p>
              <div class="grid grid-cols-1 lg:grid-cols-[1.9fr_1fr] gap-md items-start">
                <!-- LEFT: Kehadiran Sekolah (donuts + weekly chart) -->
                <AdminAttendanceOverviewCard :stats="stats" />

                <!-- RIGHT rail: Perlu Perhatian + Keuangan slim -->
                <div class="flex flex-col gap-md">
                  <AttentionPanel :items="attentionItems" />

                  <button
                    v-if="me.can('finance.bill.view')"
                    type="button"
                    class="bg-white border border-slate-200 rounded-2xl p-3.5 flex items-center gap-3 text-left hover:border-role-admin hover:shadow-sm transition-all"
                    @click="router.push('/admin/finance')"
                  >
                    <span class="w-8 h-8 rounded-xl bg-emerald-100 text-emerald-700 grid place-items-center flex-shrink-0">
                      <NavIcon name="wallet" :size="16" />
                    </span>
                    <span class="min-w-0 flex-1">
                      <span class="block text-xs font-black text-slate-900 leading-tight">
                        {{ t('admin.dashboard.financeSlimTitle', { month: financeMonthLabel }) }}
                      </span>
                      <span class="block text-3xs text-slate-500 leading-tight mt-0.5">
                        <template v-if="financeTotal === 0">{{ t('admin.dashboard.financeNoBills') }}</template>
                        <template v-else>{{ financePct }}% {{ t('admin.dashboard.targetReached') }}</template>
                      </span>
                    </span>
                    <span class="text-2xs font-bold text-role-admin flex-shrink-0">{{ t('admin.dashboard.open') }}</span>
                  </button>
                </div>
              </div>
            </div>

            <!-- ── 3a. Engagement band (gamification ACTIVE) ─────── -->
            <div v-if="canSeePrestasi" class="space-y-2.5">
              <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest px-1">
                {{ t('admin.dashboard.sectionEngagement') }}
              </p>
              <div class="grid grid-cols-1 lg:grid-cols-[1.9fr_1fr] gap-md items-start">
                <EngagementToggleCard
                  :teacher-highlight="adminHighlight"
                  :teacher-summary="adminSummary"
                  :staff-highlight="adminStaffHighlight"
                  :staff-summary="adminStaffSummary"
                />
                <div id="quick-actions-anchor" class="grid grid-cols-2 gap-3">
                  <button
                    v-for="tile in quickTilesWithGami"
                    :key="tile.to"
                    type="button"
                    class="flex flex-col items-center gap-2.5 rounded-2xl border border-slate-200 bg-white hover:border-role-admin hover:shadow-md p-4 text-xs font-bold text-slate-600 transition-all"
                    @click="router.push(tile.to)"
                  >
                    <span class="w-9 h-9 rounded-xl grid place-items-center" :class="tileTintClass(tile.tone)">
                      <NavIcon :name="tile.icon" :size="18" />
                    </span>
                    <span class="text-center leading-tight uppercase tracking-tight">{{ t(tile.labelKey) }}</span>
                  </button>
                </div>
              </div>
            </div>

            <!-- ── 3b. Akses cepat + upsell (gamification ABSENT) ── -->
            <template v-else>
              <div class="space-y-2.5">
                <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest px-1">
                  {{ t('admin.dashboard.sectionQuickAccess') }}
                </p>
                <div id="quick-actions-anchor" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
                  <button
                    v-for="tile in quickTilesNoGami"
                    :key="tile.to"
                    type="button"
                    class="flex flex-col items-center gap-2.5 rounded-2xl border border-slate-200 bg-white hover:border-role-admin hover:shadow-md p-4 text-xs font-bold text-slate-600 transition-all"
                    @click="router.push(tile.to)"
                  >
                    <span class="w-9 h-9 rounded-xl grid place-items-center" :class="tileTintClass(tile.tone)">
                      <NavIcon :name="tile.icon" :size="18" />
                    </span>
                    <span class="text-center leading-tight uppercase tracking-tight">{{ t(tile.labelKey) }}</span>
                  </button>
                </div>
              </div>

              <!-- Tasteful upsell — activate the Prestasi module. -->
              <button
                type="button"
                class="w-full flex items-center gap-4 p-4 rounded-2xl border border-violet-200 bg-gradient-to-r from-violet-50 to-white hover:shadow-md transition-all text-left"
                @click="gotoModules"
              >
                <span class="w-10 h-10 rounded-xl bg-violet-100 text-violet-600 grid place-items-center flex-shrink-0">
                  <NavIcon name="trophy" :size="20" />
                </span>
                <span class="min-w-0 flex-1">
                  <span class="block text-3xs font-bold text-violet-600 uppercase tracking-widest">
                    {{ t('admin.dashboard.upsell.eyebrow') }}
                  </span>
                  <span class="block text-sm font-black text-slate-900">{{ t('admin.dashboard.upsell.title') }}</span>
                  <span class="block text-3xs text-slate-500 mt-0.5">{{ t('admin.dashboard.upsell.sub') }}</span>
                </span>
                <span class="inline-flex items-center gap-1.5 bg-violet-600 text-white rounded-xl px-4 py-2 text-2xs font-black flex-shrink-0 whitespace-nowrap">
                  {{ t('admin.dashboard.upsell.cta') }}
                  <NavIcon name="arrow-right" :size="13" />
                </span>
              </button>
            </template>

            <!-- ── 4. Langganan — pinned to the bottom. ──────────── -->
            <SubscriptionMiniRow />
          </div>
          </template>

        </DashboardLayout>
      </template>
    </AsyncView>

    <AcademicYearPickerModal
      v-if="showYearPicker"
      role="admin"
      @close="showYearPicker = false"
    />
  </div>
</template>

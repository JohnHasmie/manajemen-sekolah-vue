<!--
  AdminDashboardView.vue - admin home.
  Mirrors Flutter's `admin_dashboard_body.dart` + mockup #1.

  Layout (no floating KPI overlap):
    1. Compact greeting + tingkat tabs (slice carousel)
    2. KPI strip (4 cards, inline) with progress strip per card
    3. Two-column: Heatmap kelas x hari (left), Finance snapshot (right)
    4. Quick-actions grid
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { useMeStore } from '@/stores/me';
import { DashboardService } from '@/services/dashboard.service';
import { formatNumber, formatRupiah } from '@/lib/format';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import DashboardLayout from '@/components/layout/DashboardLayout.vue';
import StatSummaryCard from '@/components/feature/StatSummaryCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import AcademicYearChip from '@/components/feature/AcademicYearChip.vue';
import AcademicYearPickerModal from '@/components/feature/AcademicYearPickerModal.vue';
import PriorityInbox from '@/components/feature/PriorityInbox.vue';
import TutoringEntryBanner from '@/components/feature/TutoringEntryBanner.vue';
import AdminControlCenterCard from '@/components/feature/AdminControlCenterCard.vue';
import SubscriptionMiniRow from '@/components/feature/SubscriptionMiniRow.vue';
import AdminTutoringDashboardView from '@/views/admin/tutoring/AdminTutoringDashboardView.vue';
import GamificationHighlightCard from '@/components/feature/gamification/GamificationHighlightCard.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
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
import { usePriorityInbox } from '@/composables/usePriorityInbox';
import PinnedAnnouncementCarousel from '@/components/feature/PinnedAnnouncementCarousel.vue';

type StatsPayload = Record<string, any>;
type Slice = Record<string, any>;

const auth = useAuthStore();
const me = useMeStore();
const meApi = useMe();
const router = useRouter();
const { t } = useI18n();

// Prestasi (paid module). Both `canSeePrestasi` and the payloads
// stay null when the school hasn't subscribed — the ability strip
// on the server side makes `meApi.can(...)` false so nothing renders.
const canSeePrestasi = computed(() => meApi.can('gamification.admin.view'));
const adminHighlight = ref<AdminHighlightPayload | null>(null);
const adminSummary = ref<AdminSummaryPayload | null>(null);
// Staff-side highlight + summary (BE MR6/7 /admin/staff-engagement/*).
// Gated on the SAME ability as the teacher variant; both null when
// the school owns no staff so the right column self-hides and the
// dashboard degrades gracefully to guru-only for single-guru bimbel.
const adminStaffHighlight = ref<AdminStaffHighlightPayload | null>(null);
const adminStaffSummary = ref<AdminStaffSummaryPayload | null>(null);

// Readiness teaser — CORE feature, gated only on `readiness.view`. Uses
// the same silent-on-failure pattern as `loadPrestasi()` above so a
// mid-session ability strip / network hiccup drops the card without
// disturbing the rest of the dashboard.
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
    // Silent — a mid-session sub loss must not disrupt the rest
    // of the dashboard. The v-if drops the section cleanly.
    adminHighlight.value = null;
    adminSummary.value = null;
  }
  // Staff highlight + summary fetched independently. A tenant may have
  // zero staff rows (single-guru bimbel) — the right column self-hides
  // when `total_staff === 0`, so we still fetch to know that.
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
    // Silent — teaser card v-if drops when this stays null.
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
const { mapToPriorityItems, handlePriorityTap, priorityCountLabel } =
  usePriorityInbox('admin');

const stats = ref<StatsPayload>({});
const state = ref<AsyncState<StatsPayload>>({ status: 'loading' });
const priorityRaw = ref<unknown>([]);
const priorityTotal = ref<number>(0);

const priorityItems = computed(() => mapToPriorityItems(priorityRaw.value));
const priorityHeaderLabel = computed(() =>
  priorityCountLabel(priorityItems.value.length, priorityTotal.value),
);

function gotoAdminInbox() {
  router.push({ name: 'admin.inbox' });
}

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

const sliceLabel = computed(() => String(current.value.label ?? ''));
const sliceLabelMuted = computed(() => Boolean(current.value.is_aggregate));

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
    const [data, inbox] = await Promise.all([
      DashboardService.getStats('admin'),
      DashboardService.adminPriorityInbox(),
    ]);
    stats.value = data;
    priorityRaw.value = inbox.items;
    priorityTotal.value = inbox.total;
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

// Re-fetch the server-localised priority inbox (+ stats) when the user
// switches app language so "Perlu Perhatian" / "Needs Attention" labels
// follow the new locale without a manual page reload.
useLocaleWatcher(() => load());

interface QuickAction {
  labelKey: string;
  icon: string;
  to: string;
  /**
   * Gate the action against the tenant's entitlement. Predicate
   * evaluates once per computed refresh — the `visible` field on
   * `quickActions` (see below) resolves it into a filter.
   *
   * `undefined` = ungated (Guru is always available; every tenant
   *                       with attendance_staff needs the roster).
   */
  visible?: () => boolean;
}

// Same mirror as `useNavMenu.ts` — siswa/kelas gate on
// hasStudentContext (any student-touching module owned) and mapel on
// hasAcademicContext (grades/report_cards/schedule/lms/class_activity).
// Reports quick-actions gate on the same abilities the router now uses
// so what the sidebar and dashboard grid show ALWAYS agree.
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

// Heatmap data - reads stats.attendance_heatmap[] when backend supplies it,
// otherwise synthesises a placeholder grid so the section is never empty.
interface HeatmapRow { class_name: string; cells: number[] }
const heatmap = computed<HeatmapRow[]>(() => {
  const raw = stats.value.attendance_heatmap;
  if (Array.isArray(raw)) return raw as HeatmapRow[];
  // Synthesized placeholder so admin sees the shape on first connect.
  const sample = ['7A', '7B', '8A', '8B', '9A'];
  return sample.map((cls) => ({
    class_name: cls,
    cells: Array.from({ length: 10 }, () => 80 + Math.floor(Math.random() * 20)),
  }));
});

function heatCellClass(pct: number): string {
  if (pct < 75) return 'bg-red-200';
  if (pct < 80) return 'bg-emerald-100';
  if (pct < 90) return 'bg-emerald-300';
  if (pct < 95) return 'bg-emerald-500';
  return 'bg-emerald-700';
}

const financeReceived = computed(() => topLevelNum('finance_received'));
const financeOutstanding = computed(() => topLevelNum('finance_outstanding'));
const financeTotal = computed(() => financeReceived.value + financeOutstanding.value);
const financePct = computed(() =>
  financeTotal.value > 0
    ? Math.round((financeReceived.value / financeTotal.value) * 100)
    : 0,
);
</script>

<template>
  <AdminTutoringDashboardView v-if="isTutoringCenter" />
  <div v-else class="space-y-md">
    <AsyncView :state="state" :empty-title="t('common.empty')" @retry="load">
      <template #default>
        <!-- Shared scaffold: fixed vertical rhythm + slot order across
             every role dashboard. Slots: greeting → kpis → hero → main →
             quickActions. Content below is unchanged; only the outer
             wrapper + section grouping moved into named slots. -->
        <DashboardLayout>

          <!-- #greeting: compact greeting + slice tabs, then the bimbel
               entry banner (kept directly under the greeting row exactly
               as before, so nothing re-orders). -->
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

          <!-- #kpis: KPI strip (inline, no floating). Each card only
               renders when its destination route is entitled — Students
               hides when the tenant has no student-touching module,
               Attendance hides without any attendance.student.* ability,
               Pending Lesson Plans hides without academic.lesson_plan.view.
               Guru card is unconditional (roster always available). -->
          <template #kpis>
          <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            <StatSummaryCard
              v-if="me.hasStudentContext"
              :label="t('admin.dashboard.totalStudents')"
              :value="formatNumber(num('total_students') || topLevelNum('total_students'))"
              tone="brand"
              icon-name="users"
              :sublabel="`${num('total_classes') || topLevelNum('total_classes')} ${t('admin.dashboard.classCount')}`"
              :slices="sliceOptions.length"
              :active-slice="sliceOptions.findIndex((o) => o.key === sliceKey)"
              :slice-progress="1"
              :slice-label="sliceLabel"
              :slice-label-muted="sliceLabelMuted"
              @click="router.push('/admin/students')"
            />
            <StatSummaryCard
              :label="t('admin.dashboard.totalTeachers')"
              :value="formatNumber(num('total_teachers') || topLevelNum('total_teachers'))"
              tone="info"
              icon-name="user-check"
              :sublabel="t('admin.dashboard.viewTeacherList')"
              :slices="sliceOptions.length"
              :active-slice="sliceOptions.findIndex((o) => o.key === sliceKey)"
              :slice-progress="1"
              :slice-label="sliceLabel"
              :slice-label-muted="sliceLabelMuted"
              @click="router.push('/admin/teachers')"
            />
            <StatSummaryCard
              v-if="me.canAny(['attendance.student.view', 'attendance.student.export'])"
              :label="t('admin.dashboard.attendanceToday')"
              :value="`${num('attendance_rate') || topLevelNum('attendance_rate')}%`"
              tone="success"
              icon-name="check-circle"
              :trend="
                num('attendance_delta')
                  ? {
                      direction: num('attendance_delta') > 0 ? 'up' : 'down',
                      label: `${num('attendance_delta') > 0 ? '+' : ''}${num('attendance_delta')}%`,
                    }
                  : null
              "
              :sublabel="t('admin.dashboard.vsYesterday')"
              :slices="sliceOptions.length"
              :active-slice="sliceOptions.findIndex((o) => o.key === sliceKey)"
              :slice-progress="1"
              :slice-label="sliceLabel"
              :slice-label-muted="sliceLabelMuted"
              @click="router.push('/admin/student-attendance')"
            />
            <StatSummaryCard
              v-if="me.can('academic.lesson_plan.view')"
              :label="t('admin.dashboard.pendingLessonPlans')"
              :value="formatNumber(num('pending_lesson_plans') || topLevelNum('pending_lesson_plans'))"
              tone="warning"
              icon-name="clipboard-list"
              :sublabel="`${topLevelNum('rpp_rejected')} ${t('admin.dashboard.needRevision')}`"
              :slices="sliceOptions.length"
              :active-slice="sliceOptions.findIndex((o) => o.key === sliceKey)"
              :slice-progress="1"
              :slice-label="sliceLabel"
              :slice-label-muted="sliceLabelMuted"
              @click="router.push('/admin/lesson-plans')"
            />
          </section>
          </template>

          <!-- #hero: Pusat Kendali — navy gradient card that surfaces
               "score + streak" plus the top actionable alerts
               (attention_needed + overdue_bills + pending_lesson_plans +
               draft_announcements) as one-tap cards, then a chip strip
               to the most-used quick actions. Subscription lives one
               row below in the compact `SubscriptionMiniRow` so admin
               still sees "modul aktif · tagihan / bln" without eating
               hero real estate. -->
          <template #hero>
            <div class="space-y-3">
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
              <SubscriptionMiniRow />
            </div>
          </template>

          <!-- #main: heatmap + finance, then the priority inbox. Whole
               cards hide when the tenant doesn't own the module — a
               staff-only tenant sees zero empty cards instead of
               Attendance/Finance panels with placeholder digits + dead
               "Details" buttons. -->
          <template #main>
          <div class="space-y-md">

          <!-- Pengumuman disematkan — sits at the TOP of #main so it
               scrolls under the greeting + KPI strip like on mobile,
               not above the whole dashboard. Self-hides when empty. -->
          <PinnedAnnouncementCarousel viewer-role="admin" />

          <!-- Prestasi & Gamifikasi — paid module, ability-gated
               server-side. Rendered as TWO paired rows so height
               mismatch never surfaces:
                 · Row 1 — highlight hero cards (Guru | Staf)
                 · Row 2 — engagement tiles       (Guru | Staf)
               Each row is `grid grid-cols-1 lg:grid-cols-2 items-stretch`,
               so within a row the two cards always share height even
               when the Guru title wraps two lines or the Staf top-3
               has only one entry. If the tenant has zero staff
               (single-guru bimbel) the second column silently drops
               and both rows collapse to a single full-width column —
               nothing empty ever shows.

               Row 2 tiles always render THREE top-3 slots. Missing
               ranks appear as dashed placeholders ("Belum ada
               peringkat ke-N") so the two tiles line up row-for-row
               instead of the taller one hovering above a shorter
               neighbour.

               Role-anchored palette per `useRoleColor`:
                 · teacher = cobalt (#1B6FB8, `role-teacher`)
                 · staff   = amber  (#B45309, `role-staff`)
               Both the highlight card gradient (via
               GamificationHighlightCard states `teacher_of_month` /
               `staff_of_month`) and the tile header icon pick that
               role's tint, so the two columns read as "guru world" vs
               "staf world" at a glance without any explanatory copy. -->
          <template v-if="canSeePrestasi && adminHighlight">
            <!-- Row 1 — highlight hero cards, matched height via
                 items-stretch + h-full merged onto the card root. -->
            <div
              class="grid grid-cols-1 gap-md items-stretch"
              :class="adminStaffSummary && adminStaffSummary.total_staff > 0 ? 'lg:grid-cols-2' : ''"
            >
              <GamificationHighlightCard
                class="h-full min-w-0"
                :state="adminHighlight.teacher_of_month.state"
                :eyebrow="adminHighlight.teacher_of_month.eyebrow"
                :title="adminHighlight.teacher_of_month.title"
                :sub="adminHighlight.teacher_of_month.sub"
                :cta-label="adminHighlight.teacher_of_month.cta_label"
                :cta-target="adminHighlight.teacher_of_month.cta_target"
                :meta="null"
                @cta="router.push(adminHighlight.teacher_of_month.cta_target)"
              />
              <GamificationHighlightCard
                v-if="adminStaffSummary && adminStaffSummary.total_staff > 0 && adminStaffHighlight"
                class="h-full min-w-0"
                :state="adminStaffHighlight.staff_of_month.state"
                :eyebrow="adminStaffHighlight.staff_of_month.eyebrow"
                :title="adminStaffHighlight.staff_of_month.title"
                :sub="adminStaffHighlight.staff_of_month.sub"
                :cta-label="adminStaffHighlight.staff_of_month.cta_label"
                :cta-target="adminStaffHighlight.staff_of_month.cta_target"
                :meta="null"
                @cta="router.push(adminStaffHighlight.staff_of_month.cta_target)"
              />
            </div>

            <!-- Row 2 — engagement tiles, matched height. Each tile
                 uses `flex flex-col` + `mt-auto` on the Top-3 block so
                 whichever side is taller "wins", and the shorter side
                 pushes its Top-3 to the bottom edge to fill the gap
                 instead of leaving whitespace mid-card. -->
            <div
              class="grid grid-cols-1 gap-md items-stretch"
              :class="adminStaffSummary && adminStaffSummary.total_staff > 0 ? 'lg:grid-cols-2' : ''"
            >
              <!-- GURU engagement tile -->
              <section
                v-if="adminSummary"
                class="bg-white border border-slate-200 rounded-2xl p-4 flex flex-col h-full min-w-0"
              >
                <header class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2.5">
                    <div class="w-8 h-8 rounded-xl bg-role-teacher-soft text-role-teacher grid place-items-center">
                      <NavIcon name="medal" :size="16" />
                    </div>
                    <div>
                      <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Retensi</p>
                      <h3 class="text-sm font-black text-slate-900">Engagement Guru</h3>
                    </div>
                  </div>
                  <button
                    type="button"
                    class="text-2xs font-bold text-role-teacher hover:underline"
                    @click="router.push('/admin/teacher-engagement')"
                  >
                    Lihat detail →
                  </button>
                </header>
                <div class="grid grid-cols-2 md:grid-cols-4 gap-2 mb-3">
                  <div class="rounded-xl bg-slate-50 px-3 py-2">
                    <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Total</p>
                    <p class="text-base font-black text-slate-900 mt-0.5">{{ adminSummary.total_teachers }}</p>
                  </div>
                  <div class="rounded-xl bg-emerald-50 px-3 py-2">
                    <p class="text-3xs font-bold text-emerald-700 uppercase tracking-widest">Aktif</p>
                    <p class="text-base font-black text-emerald-900 mt-0.5">{{ adminSummary.active_this_week }}</p>
                  </div>
                  <div class="rounded-xl bg-orange-50 px-3 py-2">
                    <p class="text-3xs font-bold text-orange-700 uppercase tracking-widest">Streak</p>
                    <p class="text-base font-black text-orange-900 mt-0.5">
                      {{ adminSummary.average_streak }}<span class="text-3xs text-orange-700 font-bold ml-1">hr</span>
                    </p>
                  </div>
                  <div class="rounded-xl bg-red-50 px-3 py-2">
                    <p class="text-3xs font-bold text-red-700 uppercase tracking-widest">Sepi</p>
                    <p class="text-base font-black text-red-900 mt-0.5">{{ adminSummary.needs_attention_count }}</p>
                  </div>
                </div>
                <div class="pt-3 border-t border-slate-100 mt-auto">
                  <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest mb-2">Top minggu ini</p>
                  <ol class="space-y-2">
                    <!-- Real entries, iterated over the source array (keeps
                         Vue-tsc's item-typing intact — nested `top_three[i]`
                         inside a v-if wasn't narrowing). -->
                    <li
                      v-for="(t, i) in adminSummary.top_three"
                      :key="t.teacher_id"
                      class="flex items-center gap-2.5"
                    >
                      <span
                        class="w-5 h-5 rounded-full text-3xs font-black text-white grid place-items-center flex-shrink-0"
                        :class="i === 0 ? 'bg-amber-500' : i === 1 ? 'bg-slate-400' : 'bg-orange-400'"
                      >{{ i + 1 }}</span>
                      <InitialsAvatar
                        :name="t.name"
                        :image-url="t.photo_url"
                        :size="28"
                        color="#1B6FB8"
                        :border-radius="8"
                      />
                      <div class="flex-1 min-w-0">
                        <p class="text-2xs font-bold text-slate-800 truncate leading-tight">{{ t.name }}</p>
                        <p v-if="t.streak_days != null && t.streak_days > 0" class="text-3xs text-slate-500 leading-tight mt-0.5">
                          {{ t.streak_days }} hari beruntun
                        </p>
                      </div>
                      <p class="text-2xs font-black text-slate-800 flex-shrink-0">
                        {{ t.points }}<span class="text-3xs text-slate-500 font-bold ml-1">XP</span>
                      </p>
                    </li>
                    <!-- Placeholder rows to pad up to 3 slots so this tile
                         lines up row-for-row with the Staf tile next door. -->
                    <li
                      v-for="ph in Math.max(0, 3 - adminSummary.top_three.length)"
                      :key="`teacher-placeholder-${ph}`"
                      class="flex items-center gap-2.5 min-h-[28px]"
                    >
                      <span
                        class="w-5 h-5 rounded-full bg-slate-300 text-3xs font-black text-white grid place-items-center flex-shrink-0"
                      >{{ adminSummary.top_three.length + ph }}</span>
                      <div class="flex-1 border-t border-dashed border-slate-300"></div>
                      <span class="text-xs italic text-slate-400 flex-shrink-0">
                        Belum ada peringkat ke-{{ adminSummary.top_three.length + ph }}
                      </span>
                    </li>
                  </ol>
                </div>
              </section>

              <!-- STAF engagement tile — silent-drops when the school has no staff. -->
              <section
                v-if="adminStaffSummary && adminStaffSummary.total_staff > 0"
                class="bg-white border border-slate-200 rounded-2xl p-4 flex flex-col h-full min-w-0"
              >
                <header class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2.5">
                    <div class="w-8 h-8 rounded-xl bg-role-staff-soft text-role-staff grid place-items-center">
                      <NavIcon name="briefcase" :size="16" />
                    </div>
                    <div>
                      <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Retensi</p>
                      <h3 class="text-sm font-black text-slate-900">Engagement Staf</h3>
                    </div>
                  </div>
                  <button
                    type="button"
                    class="text-2xs font-bold text-role-staff hover:underline"
                    @click="router.push('/admin/staff-engagement')"
                  >
                    Lihat detail →
                  </button>
                </header>
                <div class="grid grid-cols-2 md:grid-cols-4 gap-2 mb-3">
                  <div class="rounded-xl bg-slate-50 px-3 py-2">
                    <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Total</p>
                    <p class="text-base font-black text-slate-900 mt-0.5">{{ adminStaffSummary.total_staff }}</p>
                  </div>
                  <div class="rounded-xl bg-emerald-50 px-3 py-2">
                    <p class="text-3xs font-bold text-emerald-700 uppercase tracking-widest">Aktif</p>
                    <p class="text-base font-black text-emerald-900 mt-0.5">{{ adminStaffSummary.active_this_week }}</p>
                  </div>
                  <div class="rounded-xl bg-orange-50 px-3 py-2">
                    <p class="text-3xs font-bold text-orange-700 uppercase tracking-widest">Streak</p>
                    <p class="text-base font-black text-orange-900 mt-0.5">
                      {{ adminStaffSummary.average_streak }}<span class="text-3xs text-orange-700 font-bold ml-1">hr</span>
                    </p>
                  </div>
                  <div class="rounded-xl bg-red-50 px-3 py-2">
                    <p class="text-3xs font-bold text-red-700 uppercase tracking-widest">Sepi</p>
                    <p class="text-base font-black text-red-900 mt-0.5">{{ adminStaffSummary.needs_attention_count }}</p>
                  </div>
                </div>
                <div class="pt-3 border-t border-slate-100 mt-auto">
                  <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest mb-2">Top minggu ini</p>
                  <ol class="space-y-2">
                    <!-- Real entries — see Guru tile above for the two-loop
                         rationale (Vue-tsc narrowing on nested array
                         indices doesn't reach v-if children). -->
                    <li
                      v-for="(t, i) in adminStaffSummary.top_three"
                      :key="t.user_id"
                      class="flex items-center gap-2.5"
                    >
                      <span
                        class="w-5 h-5 rounded-full text-3xs font-black text-white grid place-items-center flex-shrink-0"
                        :class="i === 0 ? 'bg-amber-500' : i === 1 ? 'bg-slate-400' : 'bg-orange-400'"
                      >{{ i + 1 }}</span>
                      <InitialsAvatar
                        :name="t.name"
                        :image-url="t.photo_url"
                        :size="28"
                        color="#B45309"
                        :border-radius="8"
                      />
                      <div class="flex-1 min-w-0">
                        <p class="text-2xs font-bold text-slate-800 truncate leading-tight">{{ t.name }}</p>
                        <p v-if="t.ability_role_tag || (t.streak_days != null && t.streak_days > 0)" class="text-3xs text-slate-500 leading-tight mt-0.5 truncate">
                          <template v-if="t.ability_role_tag">{{ t.ability_role_tag }}</template>
                          <template v-if="t.ability_role_tag && t.streak_days != null && t.streak_days > 0"> · </template>
                          <template v-if="t.streak_days != null && t.streak_days > 0">{{ t.streak_days }} hari beruntun</template>
                        </p>
                      </div>
                      <p class="text-2xs font-black text-slate-800 flex-shrink-0">
                        {{ t.points }}<span class="text-3xs text-slate-500 font-bold ml-1">XP</span>
                      </p>
                    </li>
                    <!-- Placeholder rows pad up to 3 slots so this tile
                         lines up row-for-row with the Guru tile beside it. -->
                    <li
                      v-for="ph in Math.max(0, 3 - adminStaffSummary.top_three.length)"
                      :key="`staff-placeholder-${ph}`"
                      class="flex items-center gap-2.5 min-h-[28px]"
                    >
                      <span
                        class="w-5 h-5 rounded-full bg-slate-300 text-3xs font-black text-white grid place-items-center flex-shrink-0"
                      >{{ adminStaffSummary.top_three.length + ph }}</span>
                      <div class="flex-1 border-t border-dashed border-slate-300"></div>
                      <span class="text-xs italic text-slate-400 flex-shrink-0">
                        Belum ada peringkat ke-{{ adminStaffSummary.top_three.length + ph }}
                      </span>
                    </li>
                  </ol>
                </div>
              </section>
            </div>
          </template>

          <section class="grid grid-cols-1 lg:grid-cols-3 gap-md">
            <div
              v-if="me.canAny(['attendance.student.view', 'attendance.student.export'])"
              class="lg:col-span-2 bg-white border border-slate-200 rounded-2xl p-4"
            >
              <header class="flex items-center justify-between mb-3 px-1">
                <div class="flex items-center gap-2.5">
                  <div class="w-8 h-8 rounded-xl bg-emerald-100 text-emerald-700 grid place-items-center">
                    <NavIcon name="activity" :size="16" />
                  </div>
                  <div>
                    <h3 class="text-sm font-black text-slate-900 leading-none">
                      {{ t('admin.dashboard.attendancePerDayClass') }}
                    </h3>
                    <p class="text-3xs text-slate-400 font-bold mt-0.5">{{ t('admin.dashboard.last10Days') }}</p>
                  </div>
                </div>
                <button
                  type="button"
                  class="text-2xs font-bold text-role-admin hover:underline"
                  @click="router.push('/admin/student-attendance')"
                >
                  {{ t('admin.dashboard.details') }}
                </button>
              </header>
              <div class="grid gap-1.5" style="grid-template-columns: 60px repeat(10, 1fr);">
                <template v-for="(row, ri) in heatmap" :key="`${row.class_name}-${ri}`">
                  <span class="text-3xs font-bold text-slate-400 uppercase tracking-wider self-center">{{ row.class_name }}</span>
                  <span
                    v-for="(pct, ci) in row.cells"
                    :key="`${ri}-${ci}`"
                    class="h-5 rounded"
                    :class="heatCellClass(pct)"
                    :title="`${row.class_name}: ${pct}%`"
                  ></span>
                </template>
              </div>
              <div class="flex items-center gap-3 mt-3 text-3xs text-slate-500 flex-wrap">
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-2 rounded bg-emerald-100"></span>80%</span>
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-2 rounded bg-emerald-500"></span>90%</span>
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-2 rounded bg-emerald-700"></span>95%+</span>
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-2 rounded bg-red-200"></span>&lt;75%</span>
              </div>
            </div>

            <div
              v-if="me.can('finance.bill.view')"
              class="bg-white border border-slate-200 rounded-2xl p-4"
            >
              <header class="flex items-center justify-between mb-3 px-1">
                <div class="flex items-center gap-2.5">
                  <div class="w-8 h-8 rounded-xl bg-emerald-100 text-emerald-700 grid place-items-center">
                    <NavIcon name="wallet" :size="16" />
                  </div>
                  <div>
                    <h3 class="text-sm font-black text-slate-900 leading-none">{{ t('admin.dashboard.financeThisMonth') }}</h3>
                    <p class="text-3xs text-slate-400 font-bold mt-0.5">{{ t('admin.dashboard.receivedVsOutstanding') }}</p>
                  </div>
                </div>
                <button
                  type="button"
                  class="text-2xs font-bold text-role-admin hover:underline"
                  @click="router.push('/admin/finance')"
                >
                  {{ t('admin.dashboard.details') }}
                </button>
              </header>
              <div class="grid grid-cols-2 gap-3 mb-3">
                <div>
                  <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.dashboard.received') }}</p>
                  <p class="text-base font-black text-emerald-700">{{ formatRupiah(financeReceived) }}</p>
                </div>
                <div>
                  <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.dashboard.outstanding') }}</p>
                  <p class="text-base font-black text-red-700">{{ formatRupiah(financeOutstanding) }}</p>
                </div>
              </div>
              <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                <div
                  class="h-full bg-emerald-500 transition-all"
                  :style="{ width: `${financePct}%` }"
                ></div>
              </div>
              <p class="text-2xs text-slate-500 mt-2">
                <b class="text-slate-900">{{ financePct }}%</b> {{ t('admin.dashboard.targetReached') }}
              </p>
            </div>
          </section>

          <!-- Priority inbox fallback — only when the admin has NO
               readiness ability (edge: a staff proxying into /admin or
               a legacy seed). Once `readiness.view` is universal, the
               new AdminControlCenterCard in the #hero slot owns the
               "perlu perhatian" signal, so this section drops out
               entirely. -->
          <section v-if="!canSeeReadiness && priorityItems.length > 0">
            <header class="flex items-center justify-between gap-3 mb-3 px-1">
              <div class="flex items-center gap-2">
                <h3 class="text-[12px] font-black text-slate-500 uppercase tracking-widest">
                  {{ t('admin.dashboard.needsAttention') }}
                </h3>
                <span
                  class="text-3xs font-bold px-2 py-0.5 rounded-full bg-role-admin/10 text-role-admin"
                >
                  {{ priorityHeaderLabel }}
                </span>
              </div>
              <button
                type="button"
                class="text-2xs font-bold text-role-admin hover:underline inline-flex items-center gap-1"
                @click="gotoAdminInbox"
              >
                {{ t('common.viewAll') }}
                <NavIcon name="chevron-right" :size="12" />
              </button>
            </header>
            <PriorityInbox
              :items="priorityItems"
              :show-header="false"
              @item-tap="handlePriorityTap"
              @see-all="gotoAdminInbox"
            />
          </section>
          </div>
          </template>

          <!-- #quickActions: school-management action grid. The `id`
               anchor is targeted by AdminControlCenterCard's "Lainnya"
               chip so the strip below the hero can scroll the admin
               here without a route change. -->
          <template #quickActions>
          <section id="quick-actions-anchor">
            <h3 class="text-[12px] font-black text-slate-500 uppercase tracking-widest mb-3 px-1">
              {{ t('admin.dashboard.schoolManagement') }}
            </h3>
            <div class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-3">
              <button
                v-for="a in quickActions"
                :key="a.to"
                type="button"
                class="flex flex-col items-center gap-2.5 rounded-2xl border border-slate-200 bg-white hover:border-role-admin hover:shadow-md p-4 text-xs font-bold text-slate-600 transition-all group"
                @click="router.push(a.to)"
              >
                <span class="w-10 h-10 rounded-xl bg-slate-50 text-slate-400 group-hover:bg-role-admin group-hover:text-white grid place-items-center transition-colors">
                  <NavIcon :name="a.icon" :size="18" />
                </span>
                <span class="text-center leading-tight uppercase tracking-tight">{{ t(a.labelKey) }}</span>
              </button>
            </div>
          </section>
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

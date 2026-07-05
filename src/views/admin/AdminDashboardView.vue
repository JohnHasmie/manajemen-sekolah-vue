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
import SubscriptionSummaryCard from '@/components/feature/SubscriptionSummaryCard.vue';
import AdminTutoringDashboardView from '@/views/admin/tutoring/AdminTutoringDashboardView.vue';
import { useTenant } from '@/composables/useTenant';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useLocaleWatcher } from '@/composables/useLocaleWatcher';
import { usePriorityInbox } from '@/composables/usePriorityInbox';

type StatsPayload = Record<string, any>;
type Slice = Record<string, any>;

const auth = useAuthStore();
const me = useMeStore();
const router = useRouter();
const { t } = useI18n();
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

onMounted(load);

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
                <p class="text-[10px] font-bold text-slate-400 tracking-widest uppercase">{{ greeting }}</p>
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
              <span class="hidden md:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 text-[10px] font-bold uppercase tracking-widest">
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

          <!-- #hero: Subscription summary — compact 1-row card that puts
               "modul aktif · tagihan bulan ini · perpanjangan" one
               scroll away from the KPI strip. Full detail + add/cancel
               actions live at /subscribe/manage-modules; this card
               is the sidebar-independent entry point so admin doesn't
               have to hunt for it. -->
          <template #hero>
            <SubscriptionSummaryCard />
          </template>

          <!-- #main: heatmap + finance, then the priority inbox. Whole
               cards hide when the tenant doesn't own the module — a
               staff-only tenant sees zero empty cards instead of
               Attendance/Finance panels with placeholder digits + dead
               "Details" buttons. -->
          <template #main>
          <div class="space-y-md">
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
                    <p class="text-[10px] text-slate-400 font-bold mt-0.5">{{ t('admin.dashboard.last10Days') }}</p>
                  </div>
                </div>
                <button
                  type="button"
                  class="text-[11px] font-bold text-role-admin hover:underline"
                  @click="router.push('/admin/student-attendance')"
                >
                  {{ t('admin.dashboard.details') }}
                </button>
              </header>
              <div class="grid gap-1.5" style="grid-template-columns: 60px repeat(10, 1fr);">
                <template v-for="(row, ri) in heatmap" :key="`${row.class_name}-${ri}`">
                  <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider self-center">{{ row.class_name }}</span>
                  <span
                    v-for="(pct, ci) in row.cells"
                    :key="`${ri}-${ci}`"
                    class="h-5 rounded"
                    :class="heatCellClass(pct)"
                    :title="`${row.class_name}: ${pct}%`"
                  ></span>
                </template>
              </div>
              <div class="flex items-center gap-3 mt-3 text-[10px] text-slate-500 flex-wrap">
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
                    <p class="text-[10px] text-slate-400 font-bold mt-0.5">{{ t('admin.dashboard.receivedVsOutstanding') }}</p>
                  </div>
                </div>
                <button
                  type="button"
                  class="text-[11px] font-bold text-role-admin hover:underline"
                  @click="router.push('/admin/finance')"
                >
                  {{ t('admin.dashboard.details') }}
                </button>
              </header>
              <div class="grid grid-cols-2 gap-3 mb-3">
                <div>
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.dashboard.received') }}</p>
                  <p class="text-base font-black text-emerald-700">{{ formatRupiah(financeReceived) }}</p>
                </div>
                <div>
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.dashboard.outstanding') }}</p>
                  <p class="text-base font-black text-red-700">{{ formatRupiah(financeOutstanding) }}</p>
                </div>
              </div>
              <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                <div
                  class="h-full bg-emerald-500 transition-all"
                  :style="{ width: `${financePct}%` }"
                ></div>
              </div>
              <p class="text-[11px] text-slate-500 mt-2">
                <b class="text-slate-900">{{ financePct }}%</b> {{ t('admin.dashboard.targetReached') }}
              </p>
            </div>
          </section>

          <!-- 3b. Perlu Perhatian — admin priority inbox -->
          <section>
            <header class="flex items-center justify-between gap-3 mb-3 px-1">
              <div class="flex items-center gap-2">
                <h3 class="text-[12px] font-black text-slate-500 uppercase tracking-widest">
                  {{ t('admin.dashboard.needsAttention') }}
                </h3>
                <span
                  v-if="priorityItems.length > 0"
                  class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-role-admin/10 text-role-admin"
                >
                  {{ priorityHeaderLabel }}
                </span>
              </div>
              <button
                v-if="priorityItems.length > 0"
                type="button"
                class="text-[11px] font-bold text-role-admin hover:underline inline-flex items-center gap-1"
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

          <!-- #quickActions: school-management action grid. -->
          <template #quickActions>
          <section>
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

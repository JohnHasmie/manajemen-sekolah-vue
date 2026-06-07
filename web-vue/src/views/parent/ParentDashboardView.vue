<!--
  ParentDashboardView.vue - parent home.
  Mirrors Flutter's `parent_dashboard_body.dart` + mockup #2.

  Layout:
    1. Compact greeting + child switcher tabs (slice carousel per anak)
    2. Hero gradient card with active child's attendance %
    3. KPI strip: rata-rata nilai / tagihan / tugas / pengumuman
    4. Two-column: Aktivitas terbaru (left), Pintasan (right)
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { DashboardService } from '@/services/dashboard.service';
import { formatNumber, formatRelative, formatRupiah } from '@/lib/format';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import StatSummaryCard from '@/components/feature/StatSummaryCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import AcademicYearChip from '@/components/feature/AcademicYearChip.vue';
import AcademicYearPickerModal from '@/components/feature/AcademicYearPickerModal.vue';
import PriorityInbox from '@/components/feature/PriorityInbox.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { usePriorityInbox } from '@/composables/usePriorityInbox';

type StatsPayload = Record<string, any>;
type Slice = Record<string, any>;

interface FeedItem {
  type?: string;
  title?: string;
  source?: string;
  time_ago?: string;
  badge?: string;
  extra?: string;
  created_at?: string;
  href?: string;
}

const auth = useAuthStore();
const showYearPicker = ref(false);
const { mapToPriorityItems, handlePriorityTap, priorityCountLabel } =
  usePriorityInbox('parent');
const priorityRaw = ref<unknown>([]);
const priorityTotal = ref<number>(0);
const router = useRouter();
const { t } = useI18n();

const stats = ref<StatsPayload>({});
const feed = ref<FeedItem[]>([]);
const state = ref<AsyncState<StatsPayload>>({ status: 'loading' });

// Child switcher (parent slices = per-anak)
const sliceKey = ref<string>('');

const slices = computed<Slice[]>(() => {
  const raw = stats.value.slices;
  if (Array.isArray(raw) && raw.length > 0) return raw as Slice[];
  // Single-anak fallback synthesised from top-level stats.
  return [
    {
      student_id: 'me',
      name: stats.value.child_name ?? t('parent.dashboard.yourChildFallback'),
      classLabel: stats.value.child_class ?? '',
      attendance_rate: asInt(stats.value.attendance_rate),
      attendance_delta: 0,
      attendance_present: asInt(stats.value.attendance_present),
      attendance_total: asInt(stats.value.attendance_total),
      avg_grade: asInt(stats.value.average_grade),
      overdue_total: asInt(stats.value.outstanding_bills),
      tugas_pending: asInt(stats.value.tugas_pending),
      unread_announcements: asInt(stats.value.unread_announcements),
      is_placeholder: false,
    },
  ];
});

const sliceOptions = computed(() =>
  slices.value.map((s) => ({
    key: String(s.student_id ?? s.name),
    label: `${s.name ?? t('parent.dashboard.childFallback')}${s.classLabel ? ' · ' + s.classLabel : s.class_label ? ' · ' + s.class_label : ''}`,
  })),
);

const current = computed<Slice>(() => {
  return (
    slices.value.find((s) => String(s.student_id ?? s.name) === sliceKey.value) ??
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

function str(key: string): string {
  const v = current.value[key];
  return typeof v === 'string' ? v : '';
}

const childName = computed(() => str('name') || str('child_name') || t('parent.dashboard.yourChildLower'));
const childClass = computed(() => str('classLabel') || str('class_label') || str('child_class'));
const childSubject = computed(() => str('child_subject'));

const greeting = computed(() => {
  const h = new Date().getHours();
  if (h < 11) return t('parent.dashboard.greetingMorning');
  if (h < 15) return t('parent.dashboard.greetingNoon');
  if (h < 18) return t('parent.dashboard.greetingAfternoon');
  return t('parent.dashboard.greetingNight');
});

const attendancePresent = computed(() => num('attendance_present'));
const attendanceTotal = computed(() => num('attendance_total'));
const attendanceRate = computed(() => num('attendance_rate'));
const attendanceDelta = computed(() => num('attendance_delta'));

async function load() {
  state.value = { status: 'loading' };
  try {
    const studentId = (current.value.student_id as string | undefined) ?? undefined;
    const [statsData, recent, inbox] = await Promise.all([
      DashboardService.getStats('wali'),
      DashboardService.parentAcademicRecent(8),
      DashboardService.parentPriorityInbox(studentId),
    ]);
    stats.value = statsData;
    feed.value = recent as FeedItem[];
    priorityRaw.value = inbox.items;
    priorityTotal.value = inbox.total;
    state.value = { status: 'content', data: statsData };
    if (sliceOptions.value.length > 0 && !sliceOptions.value.find((o) => o.key === sliceKey.value)) {
      sliceKey.value = sliceOptions.value[0].key;
    }
  } catch (e) {
    state.value = { status: 'error', error: (e as Error).message };
  }
}

async function reloadPriorityInbox() {
  const studentId = (current.value.student_id as string | undefined) ?? undefined;
  try {
    const inbox = await DashboardService.parentPriorityInbox(studentId);
    priorityRaw.value = inbox.items;
    priorityTotal.value = inbox.total;
  } catch {
    // keep previous data on transient failures
  }
}

onMounted(load);

// Refetch when the active academic year changes via the chip.
useAcademicYearWatcher(() => load());

interface QuickAction {
  label: string;
  icon: string;
  to: string;
  hint?: string;
  tone?: 'parent' | 'amber';
}

const quickActions = computed<QuickAction[]>(() => [
  {
    label: t('parent.dashboard.quickAttendance'),
    icon: 'check-square',
    to: '/parent/attendance',
    hint: t('parent.dashboard.daysPresent', { count: attendancePresent.value }),
  },
  {
    label: t('parent.dashboard.quickGrades'),
    icon: 'bar-chart',
    to: '/parent/grades',
    hint: t('parent.dashboard.subjectsCount', { count: num('subjects_count') || 10 }),
  },
  {
    label: t('parent.dashboard.quickBills'),
    icon: 'wallet',
    to: '/parent/billing',
    hint: formatRupiah(num('overdue_total') || num('outstanding_bills')),
    tone: 'amber',
  },
  {
    label: t('parent.dashboard.quickReports'),
    icon: 'clipboard',
    to: '/parent/report-cards',
    hint: t('parent.dashboard.semesterValue', { n: 2 }),
  },
]);

function feedTone(type?: string) {
  switch (type) {
    case 'announcement':
      return 'blue';
    case 'grade':
      return 'green';
    case 'class_activity':
      return 'amber';
    case 'report_card':
      return 'parent';
    case 'billing':
      return 'red';
    default:
      return 'slate';
  }
}

function feedLabel(type?: string) {
  const labels: Record<string, string> = {
    announcement: t('parent.dashboard.feedAnnouncement'),
    grade: t('parent.dashboard.feedGrade'),
    class_activity: t('parent.dashboard.feedClassActivity'),
    report_card: t('parent.dashboard.feedReportCard'),
    billing: t('parent.dashboard.feedBilling'),
  };
  return type ? labels[type] ?? type : t('parent.dashboard.feedOther');
}

const priorityItems = computed(() => mapToPriorityItems(priorityRaw.value));
const priorityHeaderLabel = computed(() =>
  priorityCountLabel(priorityItems.value.length, priorityTotal.value),
);

function gotoParentInbox() {
  router.push({ name: 'parent.inbox' });
}

// When the user flips the child slice, refetch only the priority inbox
// so the new child's scope applies without reloading the rest of the
// dashboard.
watch(sliceKey, () => {
  reloadPriorityInbox();
});
</script>

<template>
  <div class="space-y-md">
    <AsyncView :state="state" :empty-title="t('common.empty')" @retry="load">
      <template #default>
        <div class="max-w-[1600px] mx-auto space-y-md">

          <!-- 1. Compact greeting + child switcher -->
          <section class="flex items-center justify-between gap-4 flex-wrap">
            <div class="flex items-center gap-3 min-w-0">
              <div class="w-10 h-10 rounded-2xl bg-role-parent/10 grid place-items-center text-role-parent flex-shrink-0">
                <NavIcon name="users" :size="20" />
              </div>
              <div class="min-w-0">
                <p class="text-[10px] font-bold text-slate-400 tracking-widest uppercase">{{ greeting }}</p>
                <h1 class="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                  {{ t('parent.dashboard.helloPrefix') }}, <span class="text-role-parent">{{ auth.user?.name }}</span>
                </h1>
              </div>
            </div>
            <div class="flex items-center gap-2 flex-wrap">
              <div v-if="sliceOptions.length > 1" class="flex items-center gap-2">
                <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest hidden sm:inline">{{ t('parent.dashboard.childLabel') }}:</span>
                <SegmentedControl v-model="sliceKey" :options="sliceOptions" size="sm" />
              </div>
              <AcademicYearChip
                variant="light"
                :min-width="140"
                @open="showYearPicker = true"
              />
            </div>
          </section>

          <!-- 2. Hero gradient with attendance focus -->
          <section
            class="rounded-3xl p-6 text-white shadow-lg relative overflow-hidden"
            style="background: linear-gradient(135deg, #1B6FB8 0%, #21AFE6 100%);"
          >
            <div class="absolute -top-12 -right-12 w-44 h-44 bg-white/15 rounded-full blur-3xl"></div>
            <div class="relative z-10 flex items-center justify-between gap-4 flex-wrap">
              <div>
                <p class="text-[10px] font-bold tracking-widest uppercase text-white/75">
                  {{ childName }} {{ childClass ? '· ' + childClass : '' }}{{ childSubject ? ' · ' + childSubject : '' }}
                </p>
                <h2 class="text-2xl sm:text-3xl font-black mt-1">
                  {{ t('parent.dashboard.attendanceTitle', { rate: attendanceRate }) }}
                </h2>
                <p class="text-[12px] text-white/85 mt-2">
                  {{ attendanceTotal
                    ? t('parent.dashboard.daysPresentOf', { count: attendancePresent, total: attendanceTotal })
                    : t('parent.dashboard.daysPresent', { count: attendancePresent }) }}
                  <span v-if="attendanceDelta !== 0" class="ml-2">
                    {{ attendanceDelta > 0 ? '▲' : '▼' }} {{ Math.abs(attendanceDelta) }}% {{ t('parent.dashboard.vsLastMonth') }}
                  </span>
                </p>
              </div>
              <button
                type="button"
                class="rounded-xl bg-white text-brand-cobalt font-bold py-2.5 px-5 text-sm hover:bg-white/95 transition-colors flex items-center gap-2"
                @click="router.push('/parent/attendance')"
              >
                <NavIcon name="check-square" :size="14" />
                {{ t('parent.dashboard.viewDetail') }}
              </button>
            </div>
          </section>

          <!-- 3. KPI strip per anak -->
          <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            <StatSummaryCard
              :label="t('parent.dashboard.avgGrade')"
              :value="num('avg_grade') || num('average_grade') || '—'"
              tone="success"
              icon-name="bar-chart"
              :sublabel="t('parent.dashboard.thisSemester')"
              :slices="sliceOptions.length"
              :active-slice="sliceOptions.findIndex((o) => o.key === sliceKey)"
              :slice-progress="1"
              @click="router.push('/parent/grades')"
            />
            <StatSummaryCard
              :label="t('parent.dashboard.bills')"
              :value="formatRupiah(num('overdue_total') || num('outstanding_bills'))"
              tone="warning"
              icon-name="wallet"
              :sublabel="t('parent.dashboard.clickToPay')"
              :slices="sliceOptions.length"
              :active-slice="sliceOptions.findIndex((o) => o.key === sliceKey)"
              :slice-progress="1"
              @click="router.push('/parent/billing')"
            />
            <StatSummaryCard
              :label="t('parent.dashboard.pendingTasks')"
              :value="formatNumber(num('tugas_pending'))"
              tone="info"
              icon-name="edit"
              :sublabel="num('tugas_overdue') ? t('parent.dashboard.overdueCount', { count: num('tugas_overdue') }) : t('parent.dashboard.noOverdue')"
              :slices="sliceOptions.length"
              :active-slice="sliceOptions.findIndex((o) => o.key === sliceKey)"
              :slice-progress="1"
              @click="router.push('/parent/grades')"
            />
            <StatSummaryCard
              :label="t('parent.dashboard.newAnnouncements')"
              :value="formatNumber(num('unread_announcements'))"
              tone="brand"
              icon-name="megaphone"
              :sublabel="t('parent.dashboard.unread')"
              :slices="sliceOptions.length"
              :active-slice="sliceOptions.findIndex((o) => o.key === sliceKey)"
              :slice-progress="1"
              @click="router.push('/parent/announcements')"
            />
          </section>

          <!-- 3b. Perlu Perhatian — parent priority inbox -->
          <section>
            <header class="flex items-center justify-between gap-3 mb-3 px-1">
              <div class="flex items-center gap-2">
                <h3 class="text-[12px] font-black text-slate-500 uppercase tracking-widest">
                  {{ t('parent.dashboard.needsAttention') }}
                </h3>
                <span
                  v-if="priorityItems.length > 0"
                  class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-role-parent/10 text-role-parent"
                >
                  {{ priorityHeaderLabel }}
                </span>
              </div>
            </header>
            <PriorityInbox
              :items="priorityItems"
              :show-header="false"
              @item-tap="handlePriorityTap"
              @see-all="gotoParentInbox"
            />
          </section>

          <!-- 4. Activity feed + Pintasan -->
          <section class="grid grid-cols-1 lg:grid-cols-3 gap-md">
            <div class="lg:col-span-2 bg-white border border-slate-200 rounded-2xl p-4">
              <header class="flex items-center justify-between mb-3 px-1">
                <div class="flex items-center gap-2.5">
                  <div class="w-8 h-8 rounded-xl bg-role-parent/10 text-role-parent grid place-items-center">
                    <NavIcon name="activity" :size="16" />
                  </div>
                  <div>
                    <h3 class="text-sm font-black text-slate-900 leading-none">{{ t('parent.dashboard.recentActivity') }}</h3>
                    <p class="text-[10px] text-slate-400 font-bold mt-0.5">{{ t('parent.dashboard.recentActivitySubtitle') }}</p>
                  </div>
                </div>
                <button
                  type="button"
                  class="text-[11px] font-bold text-role-parent hover:underline"
                >
                  {{ t('parent.dashboard.viewAll') }}
                </button>
              </header>
              <div v-if="feed.length === 0" class="text-center py-6 text-slate-400 text-sm">
                {{ t('parent.dashboard.noRecentActivity') }}
              </div>
              <ul v-else class="divide-y divide-slate-100">
                <li
                  v-for="(item, idx) in feed"
                  :key="`${item.type}-${idx}`"
                >
                  <button
                    type="button"
                    class="w-full px-2 py-3 flex items-start gap-3 hover:bg-slate-50 rounded-xl transition-colors text-left"
                    @click="item.href && router.push(item.href)"
                  >
                    <span
                      class="w-8 h-8 rounded-lg grid place-items-center flex-shrink-0"
                      :class="{
                        'bg-blue-100 text-blue-700': feedTone(item.type) === 'blue',
                        'bg-emerald-100 text-emerald-700': feedTone(item.type) === 'green',
                        'bg-amber-100 text-amber-700': feedTone(item.type) === 'amber',
                        'bg-role-parent/10 text-role-parent': feedTone(item.type) === 'parent',
                        'bg-red-100 text-red-700': feedTone(item.type) === 'red',
                        'bg-slate-100 text-slate-600': feedTone(item.type) === 'slate',
                      }"
                    >
                      <NavIcon
                        :name="
                          item.type === 'grade'
                            ? 'bar-chart'
                            : item.type === 'announcement'
                              ? 'megaphone'
                              : item.type === 'class_activity'
                                ? 'activity'
                                : item.type === 'billing'
                                  ? 'wallet'
                                  : 'bell'
                        "
                        :size="14"
                      />
                    </span>
                    <div class="flex-1 min-w-0">
                      <p class="text-[12px] font-bold text-slate-900 truncate">{{ item.title }}</p>
                      <p v-if="item.source" class="text-[10px] text-slate-400 truncate">{{ item.source }}</p>
                      <p v-if="item.extra" class="text-[11px] text-slate-500 mt-0.5 truncate">{{ item.extra }}</p>
                    </div>
                    <div class="text-right flex-shrink-0">
                      <p v-if="item.badge" class="text-[11px] font-bold text-role-parent">{{ item.badge }}</p>
                      <p class="text-[10px] text-slate-400">
                        {{ item.time_ago || formatRelative(item.created_at) }}
                      </p>
                    </div>
                  </button>
                </li>
              </ul>
            </div>

            <div class="bg-white border border-slate-200 rounded-2xl p-4">
              <header class="flex items-center gap-2.5 mb-3 px-1">
                <div class="w-8 h-8 rounded-xl bg-role-parent/10 text-role-parent grid place-items-center">
                  <NavIcon name="sparkles" :size="16" />
                </div>
                <h3 class="text-sm font-black text-slate-900 leading-none">{{ t('parent.dashboard.shortcuts') }}</h3>
              </header>
              <div class="grid grid-cols-2 gap-2.5">
                <button
                  v-for="a in quickActions"
                  :key="a.to"
                  type="button"
                  class="text-left p-3 rounded-xl bg-slate-50 hover:bg-role-parent/5 border border-transparent hover:border-role-parent/20 transition-all group"
                  @click="router.push(a.to)"
                >
                  <div
                    class="w-9 h-9 rounded-lg bg-white border border-slate-100 group-hover:bg-role-parent group-hover:border-role-parent grid place-items-center transition-colors mb-2.5"
                    :class="a.tone === 'amber' ? 'text-amber-600' : 'text-role-parent'"
                  >
                    <NavIcon :name="a.icon" :size="16" />
                  </div>
                  <p class="text-[12px] font-black text-slate-900 leading-none">{{ a.label }}</p>
                  <p class="text-[10px] font-bold text-slate-400 mt-1.5 truncate">{{ a.hint }}</p>
                </button>
              </div>
            </div>
          </section>

        </div>
      </template>
    </AsyncView>

    <AcademicYearPickerModal
      v-if="showYearPicker"
      role="wali"
      @close="showYearPicker = false"
    />
  </div>
</template>

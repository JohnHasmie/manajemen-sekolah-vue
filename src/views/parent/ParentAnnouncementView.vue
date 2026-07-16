<!--
  ParentAnnouncementView.vue — Announcement sekolah untuk parent.

  Web port of Flutter's `parent_announcement_screen.dart`. Same flow
  shape as Schedule/Presensi: BrandPageHeader (parent) + KpiStripCards +
  PageFilterToolbar (search + Priority/Status chips) + list of shared
  AnnouncementCards grouped by month + shared detail modal + Event Banner.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { api } from '@/lib/http';
import { ParentService } from '@/services/parent.service';
import { AnnouncementService } from '@/services/announcements.service';
import type { Announcement as ParentAnnouncement } from '@/types/parent';
import {
  announcementFromJson,
  type Announcement,
  type AnnouncementCategory,
  type AnnouncementPriority,
} from '@/types/announcements';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import AnnouncementCard from '@/components/feature/AnnouncementCard.vue';
import AnnouncementDetailModal from '@/components/feature/AnnouncementDetailModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const { t } = useI18n();

const items = ref<Announcement[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const detail = ref<Announcement | null>(null);

// ── Filters (Flutter parity, canonical English post-rename) ──
type PriorityFilter = 'all' | AnnouncementPriority;
type StatusFilter = 'all' | 'active' | 'scheduled' | 'expired';

const priorityFilter = ref<PriorityFilter>('all');
const statusFilter = ref<StatusFilter>('all');
const searchQuery = ref('');

const showPriorityPicker = ref(false);
const showStatusPicker = ref(false);

// Labels are computed so they re-render when the locale switches.
const PRIORITY_OPTIONS = computed<{ key: PriorityFilter; label: string }[]>(() => [
  { key: 'all', label: t('parent.announcements.priorityAll') },
  { key: 'urgent', label: t('parent.announcements.priorityUrgent') },
  { key: 'high', label: t('parent.announcements.priorityHigh') },
  { key: 'normal', label: t('parent.announcements.priorityNormal') },
  { key: 'low', label: t('parent.announcements.priorityLow') },
]);

const STATUS_OPTIONS = computed<{ key: StatusFilter; label: string }[]>(() => [
  { key: 'all', label: t('parent.announcements.statusAll') },
  { key: 'active', label: t('parent.announcements.statusActive') },
  { key: 'scheduled', label: t('parent.announcements.statusScheduled') },
  { key: 'expired', label: t('parent.announcements.statusExpired') },
]);

const activePriority = computed(
  () =>
    PRIORITY_OPTIONS.value.find((p) => p.key === priorityFilter.value) ??
    PRIORITY_OPTIONS.value[0],
);

const activeStatus = computed(
  () =>
    STATUS_OPTIONS.value.find((s) => s.key === statusFilter.value) ??
    STATUS_OPTIONS.value[0],
);

// ── Event Banner Data & State ──
interface EventData {
  id: string;
  title: string;
  body: string;
  category: string;
  event_at: string;
  event_end_at?: string | null;
  event_has_time?: boolean;
  event_location?: string | null;
  [key: string]: any;
}

const upcomingEvents = ref<EventData[]>([]);
const dismissedEventIds = ref<Set<string>>(new Set());

const visibleEvents = computed(() => {
  return upcomingEvents.value.filter(
    (ev) => !dismissedEventIds.value.has(ev.id)
  );
});

function getEventState(ev: EventData) {
  const now = Date.now();
  const eventAt = Date.parse(ev.event_at);
  if (isNaN(eventAt)) return 'past';
  const eventEndAt = ev.event_end_at ? Date.parse(ev.event_end_at) : NaN;

  if (!isNaN(eventEndAt)) {
    if (now < eventAt) return 'upcoming';
    if (now > eventEndAt) return 'past';
    return 'live';
  }

  if (now < eventAt) return 'upcoming';
  if (now < eventAt + 60 * 60 * 1000) return 'live'; // Treat first hour as live
  return 'past';
}

function getEventCountdownLabel(ev: EventData) {
  const state = getEventState(ev);
  if (state === 'past') return t('wali.sekolah.announcement.eventDone');
  if (state === 'live') return t('wali.sekolah.announcement.eventLiveNow');

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const eventAtDate = new Date(ev.event_at);
  const eventDay = new Date(eventAtDate.getFullYear(), eventAtDate.getMonth(), eventAtDate.getDate());

  const diffMs = eventDay.getTime() - today.getTime();
  const days = Math.floor(diffMs / (24 * 60 * 60 * 1000));

  if (days === 0) return t('wali.sekolah.announcement.eventToday');
  if (days === 1) return t('wali.sekolah.announcement.eventTomorrow');
  if (days < 7) return t('wali.sekolah.announcement.eventDaysLeft', { count: days });
  if (days < 30) return t('wali.sekolah.announcement.eventWeeksLeft', { count: Math.floor(days / 7) });
  return t('wali.sekolah.announcement.eventMonthsLeft', { count: Math.floor(days / 30) });
}

function formatEventTime(ev: EventData) {
  const d = new Date(ev.event_at);
  if (isNaN(d.getTime())) return '';
  const hm = ev.event_has_time !== false
    ? `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
    : t('wali.sekolah.announcement.allDay');
  const parts = [hm];
  if (ev.event_location) parts.push(ev.event_location);
  return parts.join(' · ');
}

function dismissEvent(id: string) {
  dismissedEventIds.value.add(id);
}

function openEventDetail(ev: EventData) {
  const ann = announcementFromJson(ev);
  openDetail(ann);
}

// ── Filtering Logic (Client-side) ──
function lifecycleOf(a: Announcement): StatusFilter {
  if (a.status === 'scheduled') return 'scheduled';
  if (a.status === 'expired') return 'expired';
  const now = Date.now();
  const sched = a.scheduled_at ? Date.parse(a.scheduled_at) : NaN;
  const expires = a.expires_at ? Date.parse(a.expires_at) : NaN;
  if (!Number.isNaN(sched) && sched > now) return 'scheduled';
  if (!Number.isNaN(expires) && expires < now) return 'expired';
  return 'active';
}

const filtered = computed<Announcement[]>(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return items.value.filter((a) => {
    if (priorityFilter.value !== 'all') {
      const ap = a.priority ?? 'normal';
      if (ap !== priorityFilter.value) return false;
    }
    if (statusFilter.value !== 'all') {
      const mapped = lifecycleOf(a);
      if (mapped !== statusFilter.value) return false;
    }
    if (q) {
      const blob = `${a.title} ${a.body} ${a.source ?? ''}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

// ── Group by Month ──
interface MonthGroup {
  label: string;
  count: number;
  items: Announcement[];
}

const grouped = computed<MonthGroup[]>(() => {
  const monthsId = [
    t('wali.sekolah.announcement.monthJanuary'),
    t('wali.sekolah.announcement.monthFebruary'),
    t('wali.sekolah.announcement.monthMarch'),
    t('wali.sekolah.announcement.monthApril'),
    t('wali.sekolah.announcement.monthMay'),
    t('wali.sekolah.announcement.monthJune'),
    t('wali.sekolah.announcement.monthJuly'),
    t('wali.sekolah.announcement.monthAugust'),
    t('wali.sekolah.announcement.monthSeptember'),
    t('wali.sekolah.announcement.monthOctober'),
    t('wali.sekolah.announcement.monthNovember'),
    t('wali.sekolah.announcement.monthDecember'),
  ];

  const groupsMap = new Map<string, Announcement[]>();
  const groupOrder: string[] = [];

  for (const a of filtered.value) {
    const dateStr = a.published_at ?? a.created_at;
    let key = t('wali.sekolah.announcement.monthOther');
    if (dateStr) {
      const dt = new Date(dateStr);
      if (!isNaN(dt.getTime())) {
        key = `${monthsId[dt.getMonth()]} ${dt.getFullYear()}`;
      }
    }

    if (!groupsMap.has(key)) {
      groupsMap.set(key, []);
      groupOrder.push(key);
    }
    groupsMap.get(key)!.push(a);
  }

  return groupOrder.map((key) => ({
    label: key,
    count: groupsMap.get(key)!.length,
    items: groupsMap.get(key)!,
  }));
});

const state = computed<AsyncState<Announcement[]>>(() => {
  if (isLoading.value && items.value.length === 0)
    return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filtered.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filtered.value };
});

const unreadCount = computed(
  () => items.value.filter((a) => a.is_read === false).length,
);
const pentingCount = computed(
  () => items.value.filter((a) => a.priority === 'high' || a.priority === 'urgent').length,
);
const acaraCount = computed(
  () => items.value.filter((a) => a.category === 'event').length,
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'megaphone',
    label: t('parent.announcements.kpiTotal'),
    value: items.value.length,
    tone: 'violet',
  },
  {
    icon: 'bell',
    label: t('parent.announcements.kpiUnread'),
    value: unreadCount.value,
    tone: unreadCount.value > 0 ? 'amber' : 'green',
    accented: unreadCount.value > 0,
  },
  {
    icon: 'star',
    label: t('parent.announcements.kpiImportant'),
    value: pentingCount.value,
    tone: 'red',
  },
  {
    icon: 'calendar',
    label: t('parent.announcements.kpiEvents'),
    value: acaraCount.value,
    tone: 'brand',
  },
]);

/**
 * Lift the parent inbox payload into the shared Announcement shape so
 * AnnouncementCard / AnnouncementDetailModal render the same fields.
 */
function fromParent(a: ParentAnnouncement): Announcement {
  return announcementFromJson({
    id: a.id,
    title: a.title,
    body: a.body,
    category: a.category ?? 'announcement',
    source: a.source,
    is_read: !!a.read_at,
    read_at: a.read_at ?? null,
    created_at: a.created_at,
  });
}

async function reload() {
  isLoading.value = true;
  error.value = null;
  try {
    const [list, events] = await Promise.all([
      ParentService.announcements(),
      AnnouncementService.fetchUpcomingEvents({ limit: 3 }),
    ]);
    items.value = list.map(fromParent);
    upcomingEvents.value = events;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function openDetail(a: Announcement) {
  detail.value = a;
  if (a.is_read === false) {
    try {
      await ParentService.markAnnouncementRead(a.id);
    } catch {
      // ignore — try the shared endpoint
      AnnouncementService.markAsRead(a.id);
    }
    // Reflect locally so the unread dot disappears immediately.
    const hit = items.value.find((it) => it.id === a.id);
    if (hit) {
      hit.is_read = true;
      hit.read_at = new Date().toISOString();
    }
  }
}

onMounted(reload);
useAcademicYearWatcher(() => reload());

function pickPriority(k: PriorityFilter) {
  priorityFilter.value = k;
  showPriorityPicker.value = false;
}

function pickStatus(k: StatusFilter) {
  statusFilter.value = k;
  showStatusPicker.value = false;
}
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- ── 1. Header ────────────────────────────────────────── -->
    <ParentPageHeader
      :kicker="t('parent.announcements.kicker')"
      :title="t('parent.announcements.title')"
      :interpolate-child="false"
      :meta="t('parent.announcements.metaCounts', { count: items.length, unread: unreadCount })"
    />

    <!-- ── 2. KPI strip ─────────────────────────────────────── -->
    <KpiStripCards :cards="kpiCards" :loading="isLoading" />

    <!-- ── 3. Filter toolbar ────────────────────────────────── -->
    <PageFilterToolbar
      :search="searchQuery"
      :search-placeholder="t('parent.announcements.searchPlaceholder')"
      @update:search="(v) => (searchQuery = v)"
    >
      <template #chips>
        <AppFilterChip
          :label="t('parent.announcements.chipPriority')"
          :value="activePriority.label"
          icon-name="bell"
          tone="amber"
          @click="showPriorityPicker = true"
        />
        <AppFilterChip
          :label="t('parent.announcements.chipStatus')"
          :value="activeStatus.label"
          icon-name="calendar"
          tone="violet"
          @click="showStatusPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- ── 4. Upcoming Events Banner ────────────────────────── -->
    <section v-if="visibleEvents.length > 0" class="space-y-2">
      <div
        v-for="ev in visibleEvents"
        :key="ev.id"
        class="flex items-start gap-3 p-3.5 rounded-2xl border transition-all cursor-pointer shadow-sm hover:shadow-md"
        :class="
          getEventState(ev) === 'live'
            ? 'bg-gradient-to-r from-red-50 to-red-100/80 border-red-200 text-red-900'
            : 'bg-gradient-to-r from-amber-50 to-amber-100/80 border-amber-200 text-amber-900'
        "
        @click="openEventDetail(ev)"
      >
        <!-- Icon -->
        <div
          class="w-8 h-8 rounded-xl bg-white flex items-center justify-center flex-shrink-0 shadow-sm"
        >
          <NavIcon
            :name="getEventState(ev) === 'live' ? 'megaphone' : 'bell'"
            :size="15"
            :class="getEventState(ev) === 'live' ? 'text-red-600' : 'text-amber-600'"
          />
        </div>

        <!-- Content -->
        <div class="flex-1 min-w-0">
          <div class="flex items-center justify-between gap-2">
            <span
              class="text-3xs font-black uppercase tracking-wider"
              :class="getEventState(ev) === 'live' ? 'text-red-700' : 'text-amber-700'"
            >
              {{ getEventCountdownLabel(ev) }}
            </span>

            <!-- Close Button -->
            <button
              type="button"
              class="p-0.5 rounded-full hover:bg-black/5 -mr-1 -mt-1 flex-shrink-0 transition-colors"
              :class="getEventState(ev) === 'live' ? 'text-red-600' : 'text-amber-600'"
              @click.stop="dismissEvent(ev.id)"
            >
              <NavIcon name="x" :size="12" />
            </button>
          </div>

          <h4 class="text-[14px] font-extrabold mt-0.5 text-slate-900 truncate">
            {{ ev.title }}
          </h4>

          <p class="text-[11.5px] text-slate-600 mt-0.5 truncate">
            {{ formatEventTime(ev) }}
          </p>
        </div>
      </div>
    </section>

    <!-- ── 5. Body ──────────────────────────────────────────── -->
    <AsyncView
      :state="state"
      :empty-title="t('parent.announcements.emptyTitle')"
      :empty-description="t('parent.announcements.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="space-y-md">
          <div v-for="g in grouped" :key="g.label" class="space-y-2.5">
            <!-- Section header with month and badge count -->
            <header class="flex items-center gap-2 px-1 pt-4 pb-1">
              <span class="text-[13px] font-extrabold uppercase tracking-widest text-slate-500">
                {{ g.label }}
              </span>
              <div class="flex-1 h-px bg-slate-100"></div>
              <span class="inline-flex items-center justify-center px-2 py-0.5 text-3xs font-extrabold rounded-full bg-slate-100 text-slate-500">
                {{ g.count }}
              </span>
            </header>

            <!-- Cards -->
            <AnnouncementCard
              v-for="a in g.items"
              :key="a.id"
              :announcement="a"
              viewer-role="parent"
              @tap="openDetail"
            />
          </div>
        </div>
      </template>
    </AsyncView>

    <!-- ── Priority picker ──────────────────────────────────── -->
    <Modal
      v-if="showPriorityPicker"
      :title="t('parent.announcements.filterPriorityTitle')"
      @close="showPriorityPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="p in PRIORITY_OPTIONS" :key="p.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors"
            :class="{
              'bg-role-parent/5 text-role-parent font-bold':
                p.key === priorityFilter,
            }"
            @click="pickPriority(p.key)"
          >
            {{ p.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Status picker ────────────────────────────────────── -->
    <Modal
      v-if="showStatusPicker"
      :title="t('parent.announcements.filterStatusTitle')"
      @close="showStatusPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="s in STATUS_OPTIONS" :key="s.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors"
            :class="{
              'bg-role-parent/5 text-role-parent font-bold':
                s.key === statusFilter,
            }"
            @click="pickStatus(s.key)"
          >
            {{ s.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Detail modal (shared) ────────────────────────────── -->
    <AnnouncementDetailModal
      v-if="detail"
      :announcement="detail"
      viewer-role="parent"
      :auto-mark-read="false"
      @close="detail = null"
    />
  </div>
</template>

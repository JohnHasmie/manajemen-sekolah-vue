<!--
  NotificationListView.vue — port of `notification_list_screen.dart`.
  Lists notifications with read/unread badges, "tandai semua dibaca"
  action, infinite scroll (via pagination), and tap-to-navigate.
-->
<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useNotificationsStore } from '@/stores/notifications';
import { useMeStore } from '@/stores/me';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import Card from '@/components/ui/Card.vue';
import Pagination from '@/components/data/Pagination.vue';
import { formatRelative } from '@/lib/format';
import type { AppNotification } from '@/types/notification';

const store = useNotificationsStore();
const me = useMeStore();
const router = useRouter();
const { t } = useI18n();

/**
 * Map notification category → module_key. Kept in lockstep with the
 * backend `NotificationModuleGate::moduleForType()` map — the two
 * gates need to agree on which category belongs to which module or a
 * tenant can end up with the inbox filtering different from the tap
 * behavior. `null` means "core / unknown" — always allow (system
 * alerts, teaching reminders, etc.).
 */
const CATEGORY_MODULE: Record<string, string | null> = {
  announcement: 'communication',
  attendance: 'attendance_class',
  grade: 'grades',
  class_activity: 'class_activity',
  lesson_plan: 'lms',
  billing: 'finance',
  system: null,
  other: null,
};

function isEntitled(n: AppNotification): boolean {
  const mod = CATEGORY_MODULE[n.category];
  if (mod === null || mod === undefined) return true;
  // Attendance is either class OR gate — a tenant that only owns
  // gate should still see attendance notifs (e.g. gerbang scan alerts).
  if (mod === 'attendance_class') {
    return me.hasAnyModule(['attendance_class', 'attendance_gate']);
  }
  return me.hasModule(mod);
}

/**
 * Filtered list — hide notifications whose category maps to a module
 * the tenant no longer owns. Backend R4 also filters at the API
 * boundary, but keeping this here means a mid-session module-loss
 * doesn't stale-render before the next inbox refetch.
 */
const visibleItems = computed<AppNotification[]>(() =>
  store.items.filter(isEntitled),
);

const state = computed<AsyncState<AppNotification[]>>(() => {
  if (store.isLoading && visibleItems.value.length === 0) return { status: 'loading' };
  if (store.error) return { status: 'error', error: store.error };
  if (visibleItems.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleItems.value };
});

onMounted(() => {
  store.fetch(1);
});

async function open(n: AppNotification) {
  // Mark read ONLY on an explicit click (per founder request: web should
  // not mark a notification read just because it scrolled into view). Even
  // rows with no deep-link target (e.g. bare test notifications) clear their
  // unread state on click. "Tandai semua dibaca" remains for bulk clearing.
  if (!n.read_at) await store.markRead(n.id);
  // Belt-and-suspenders — the backend R4 inbox filter drops entries whose
  // category maps to an unowned module, and the visible list here does
  // the same client-side. This last check catches races where the store
  // holds an unfiltered snapshot from before the module was cancelled.
  if (!isEntitled(n)) return;
  if (n.href) {
    router.push(n.href).catch(() => {
      // Swallow redundant-navigation errors (already on the page).
    });
  }
}

function categoryColor(cat: AppNotification['category']) {
  switch (cat) {
    case 'announcement':
      return 'bg-brand-50 text-brand-700';
    case 'attendance':
      return 'bg-status-info-soft text-status-info';
    case 'grade':
      return 'bg-status-success-soft text-emerald-700';
    case 'class_activity':
      return 'bg-status-info-soft text-status-info';
    case 'lesson_plan':
      return 'bg-role-teacher-soft text-role-teacher';
    case 'billing':
      return 'bg-status-warning-soft text-amber-700';
    case 'system':
      return 'bg-slate-100 text-slate-600';
    default:
      return 'bg-slate-100 text-slate-600';
  }
}

function categoryLabel(cat: AppNotification['category']) {
  const labels: Record<AppNotification['category'], string> = {
    announcement: t('common.announcement'),
    attendance: t('common.attendance'),
    grade: t('common.grade'),
    class_activity: t('common.activity'),
    lesson_plan: t('common.lessonPlan'),
    billing: t('common.billing'),
    system: t('common.system'),
    other: t('common.other'),
  };
  return labels[cat] ?? t('common.other');
}
</script>

<template>
  <div class="space-y-md">
    <header class="flex items-center justify-between gap-md">
      <div>
        <h1 class="text-xl sm:text-2xl font-bold text-slate-900">
          {{ t('common.notifications') }}
        </h1>
        <p class="text-sm text-slate-500">
          {{ store.unreadCount }} {{ t('common.unread') }}
        </p>
      </div>
      <button
        v-if="store.unreadCount > 0"
        type="button"
        class="text-sm font-medium text-brand hover:underline"
        @click="store.markAllRead()"
      >
        {{ t('common.markAllRead') }}
      </button>
    </header>

    <Card padded>
      <AsyncView
        :state="state"
        :empty-title="t('common.empty')"
        :empty-description="t('common.noNotificationsNow')"
        @retry="store.fetch(1)"
      >
        <template #default="{ data }">
          <ul class="divide-y divide-slate-100 -mt-md -mx-lg sm:-mx-xl">
            <li v-for="n in data" :key="n.id">
              <button
                type="button"
                class="w-full text-left px-lg sm:px-xl py-md hover:bg-slate-50 flex gap-md transition-colors"
                @click="open(n)"
              >
                <span
                  class="w-2 h-2 mt-2 rounded-full flex-shrink-0"
                  :class="n.read_at ? 'bg-transparent' : 'bg-status-danger'"
                  aria-hidden="true"
                />
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-0.5">
                    <span
                      class="text-3xs font-semibold uppercase tracking-wider rounded-full px-2 py-0.5"
                      :class="categoryColor(n.category)"
                    >
                      {{ categoryLabel(n.category) }}
                    </span>
                    <span class="text-xs text-slate-400 ml-auto">
                      {{ formatRelative(n.created_at) }}
                    </span>
                  </div>
                  <p
                    class="text-sm font-semibold text-slate-900"
                    :class="{ 'font-medium': n.read_at }"
                  >
                    {{ n.title }}
                  </p>
                  <p class="text-sm text-slate-500 line-clamp-2">
                    {{ n.body }}
                  </p>
                </div>
              </button>
            </li>
          </ul>
        </template>
      </AsyncView>

      <Pagination
        v-if="store.pagination && store.pagination.total_pages > 1"
        :pagination="store.pagination"
        class="mt-md"
        @change="store.fetch($event)"
      />
    </Card>
  </div>
</template>

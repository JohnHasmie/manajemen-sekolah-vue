<!--
  NotificationListView.vue — port of `notification_list_screen.dart`.
  Lists notifications with read/unread badges, "tandai semua dibaca"
  action, infinite scroll (via pagination), and tap-to-navigate.
-->
<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useNotificationsStore } from '@/stores/notifications';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import Card from '@/components/ui/Card.vue';
import Pagination from '@/components/data/Pagination.vue';
import { formatRelative } from '@/lib/format';
import type { AppNotification } from '@/types/notification';

const store = useNotificationsStore();
const router = useRouter();
const { t } = useI18n();

const state = computed<AsyncState<AppNotification[]>>(() => {
  if (store.isLoading && store.items.length === 0) return { status: 'loading' };
  if (store.error) return { status: 'error', error: store.error };
  if (store.items.length === 0) return { status: 'empty' };
  return { status: 'content', data: store.items };
});

onMounted(() => {
  store.fetch(1);
  setupObserver();
});

async function open(n: AppNotification) {
  if (!n.read_at) await store.markRead(n.id);
  if (n.href) router.push(n.href);
}

// ── IntersectionObserver auto-mark-as-read (mobile parity) ────
//
// Mobile auto-marks visible unread notifications as read via a
// scroll listener. The web port mirrors that: when an unread row
// scrolls into view (≥60% visible) we queue it for a debounced
// batch mark. One store.markRead call per id keeps the optimistic
// state in sync; failure is silent (next pull-refresh recovers).
const listRoot = ref<HTMLElement | null>(null);
let observer: IntersectionObserver | null = null;
const pendingReads = new Set<string>();
let flushTimer: number | null = null;

function flushPendingReads() {
  if (pendingReads.size === 0) return;
  const ids = Array.from(pendingReads);
  pendingReads.clear();
  for (const id of ids) {
    void store.markRead(id);
  }
}

function scheduleFlush() {
  if (flushTimer != null) window.clearTimeout(flushTimer);
  flushTimer = window.setTimeout(flushPendingReads, 600);
}

function setupObserver() {
  if (observer) return;
  if (typeof IntersectionObserver === 'undefined') return;
  observer = new IntersectionObserver(
    (records) => {
      for (const r of records) {
        if (!r.isIntersecting) continue;
        const id = (r.target as HTMLElement).dataset.notificationId;
        if (id) pendingReads.add(id);
      }
      if (pendingReads.size > 0) scheduleFlush();
    },
    { threshold: 0.6 },
  );
}

function attachUnreadObservers() {
  if (!observer || !listRoot.value) return;
  const nodes = listRoot.value.querySelectorAll<HTMLElement>(
    '[data-unread="1"]',
  );
  nodes.forEach((n) => observer!.observe(n));
}

onBeforeUnmount(() => {
  observer?.disconnect();
  observer = null;
  if (flushTimer != null) window.clearTimeout(flushTimer);
});

// Re-attach observers whenever the visible item list changes.
watch(
  () => store.items.map((i) => i.id).join(','),
  async () => {
    await nextTick();
    attachUnreadObservers();
  },
);

function categoryColor(cat: AppNotification['category']) {
  switch (cat) {
    case 'announcement':
      return 'bg-brand-50 text-brand-700';
    case 'attendance':
      return 'bg-status-info-soft text-status-info';
    case 'grade':
      return 'bg-status-success-soft text-emerald-700';
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
          <ul
            ref="listRoot"
            class="divide-y divide-slate-100 -mt-md -mx-lg sm:-mx-xl"
          >
            <li
              v-for="n in data"
              :key="n.id"
              :data-notification-id="n.id"
              :data-unread="n.read_at ? '0' : '1'"
            >
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
                      class="text-[10px] font-semibold uppercase tracking-wider rounded-full px-2 py-0.5"
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

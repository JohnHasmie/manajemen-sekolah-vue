<!--
  ParentTutoring2NotificationsView.vue — Wali bimbel notifications inbox.

  ── History ──

  This shipped rendering a HARDCODED sample list: "Nadia hadir sesi
  16:00", "SPP Jan jatuh tempo 25 Jan", "Nilai TO #3 terbit". Fabricated
  attendance for a fabricated child, and a bill due date a parent could
  act on. Mark-all-read was a `notAvailable` toast.

  There was never a missing endpoint. `NotificationService` has existed
  the whole time — `/notifications`, `/notifications/mark-all-read`,
  `/notifications/unread-count` — and the LEGACY view this screen
  replaced (`parent/tutoring/ParentNotificationsView.vue`) has been using
  it all along. The greenfield rewrite lost working functionality and
  replaced it with fiction.

  Now on the real feed. `NotificationService.list()` role-scopes the
  request to the active context, so a wali cannot be served admin
  billing notifications.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { NotificationService } from '@/services/notification.service';
import type { AppNotification } from '@/types/notification';

const { t } = useI18n();
const toast = useToast();

/**
 * Icon per backend category. Deliberately `Record<string, string>` and
 * not keyed to the category enum: finance-job types (bill_generated,
 * payment_verified, …) arrive as raw strings outside it and still need
 * an icon. Same reasoning as the legacy view.
 */
const ICON_BY_CATEGORY: Record<string, string> = {
  billing: 'wallet',
  attendance: 'user-check',
  grade: 'chart-bar',
  assessment: 'chart-bar',
  announcement: 'megaphone',
  session: 'calendar',
};

function iconFor(n: AppNotification): string {
  return ICON_BY_CATEGORY[String(n.category)] ?? 'bell';
}

/**
 * Relative age, computed from the server timestamp.
 *
 * The sample rows carried strings like "2j" and "kemarin" as DATA, which
 * is why they never went stale — they were never times to begin with.
 */
function relativeTime(iso: string): string {
  const then = new Date(iso).getTime();
  if (!Number.isFinite(then)) return '';
  const mins = Math.max(0, Math.round((Date.now() - then) / 60_000));
  if (mins < 60) return t('tutoring2.parent.notifications.minutesAgo', { n: mins });
  const hours = Math.round(mins / 60);
  if (hours < 24) return t('tutoring2.parent.notifications.hoursAgo', { n: hours });
  return t('tutoring2.parent.notifications.daysAgo', { n: Math.round(hours / 24) });
}


const { state, reload } = useDataRefresh<AppNotification[]>(async () => {
  const { items } = await NotificationService.list(1, 50);
  return items;
});

const unreadCount = computed<number>(() => {
  const items = state.value.status === 'content' ? state.value.data ?? [] : [];
  return items.filter((n) => !n.read_at).length;
});

const markingAll = ref(false);

/**
 * `/notifications/mark-all-read` has existed all along; this was a
 * `notAvailable` toast.
 *
 * Reloads afterwards rather than mutating the rows in place, so what the
 * wali sees is what the server recorded — a local flip would show every
 * badge cleared even if the request failed.
 */
async function markAll() {
  if (markingAll.value) return;
  markingAll.value = true;
  try {
    await NotificationService.markAllRead();
    await reload();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring2.common.error'));
  } finally {
    markingAll.value = false;
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.notifications.title')"
      :meta="t('tutoring2.parent.notifications.meta', { count: unreadCount })"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.parent.notifications.emptyTitle')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="n in (data as AppNotification[])"
              :key="n.id"
              class="flex items-center gap-3 px-4 py-3"
              :class="!n.read_at ? 'bg-brand-azure/5' : ''"
            >
              <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-azure/10 text-brand-azure">
                <NavIcon :name="iconFor(n)" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">{{ n.title }}</p>
                <p class="text-2xs text-slate-500">{{ relativeTime(n.created_at) }}</p>
              </div>
              <span
                v-if="!n.read_at"
                class="ml-2 h-2 w-2 rounded-full bg-brand-azure"
                aria-hidden="true"
              ></span>
            </li>
          </ul>
        </div>

        <Button variant="secondary" block :loading="markingAll" @click="markAll">
          {{ t('tutoring2.parent.notifications.markAllRead') }}
        </Button>
      </template>
    </AsyncView>
  </div>
</template>

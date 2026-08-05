<!--
  ParentTutoring2NotificationsView.vue — Wali bimbel notifications inbox.

  MVP: no backend feed yet. We render a hardcoded sample list wrapped in
  the standard AsyncView + useDataRefresh scaffolding so the shape stays
  consistent with the rest of the tutoring2 views. When the real endpoint
  lands, swap the loader body — the template and state contract don't
  need to change.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const toast = useToast();

interface NotificationRow {
  id: string;
  icon: string;
  title: string;
  time: string;
  unread: boolean;
}

// TODO i18n key: notification titles are dynamic backend copy
const samples: NotificationRow[] = [
  { id: '1', icon: 'user-check', title: 'Nadia hadir sesi 16:00', time: '2j', unread: true },
  { id: '2', icon: 'wallet', title: 'SPP Jan jatuh tempo 25 Jan', time: '5j', unread: true },
  { id: '3', icon: 'chart-bar', title: 'Nilai TO #3 terbit', time: 'kemarin', unread: false },
  { id: '4', icon: 'user-check', title: 'Aldi hadir 100% minggu ini', time: 'kemarin', unread: false },
];

const { state, reload } = useDataRefresh<NotificationRow[]>(async () => {
  // MVP: resolve immediately with the hardcoded sample. Replace with a
  // real service call once the notifications endpoint exists.
  return samples;
});

const unreadCount = computed<number>(() => {
  const items = state.value.status === 'content' ? state.value.data ?? [] : [];
  return items.filter((n) => n.unread).length;
});

function markAll() {
  // Stub — the mark-all endpoint doesn't exist yet.
  toast.info(t('tutoring2.common.notAvailable'));
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
              v-for="n in (data as NotificationRow[])"
              :key="n.id"
              class="flex items-center gap-3 px-4 py-3"
              :class="n.unread ? 'bg-brand-azure/5' : ''"
            >
              <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-azure/10 text-brand-azure">
                <NavIcon :name="n.icon" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">{{ n.title }}</p>
                <p class="text-2xs text-slate-500">{{ n.time }}</p>
              </div>
              <span
                v-if="n.unread"
                class="ml-2 h-2 w-2 rounded-full bg-brand-azure"
                aria-hidden="true"
              ></span>
            </li>
          </ul>
        </div>

        <Button variant="secondary" block @click="markAll">
          {{ t('tutoring2.parent.notifications.markAllRead') }}
        </Button>
      </template>
    </AsyncView>
  </div>
</template>

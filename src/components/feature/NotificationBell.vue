<!--
  NotificationBell.vue — bell icon with unread badge in the topbar.
  Routes to /notifications on click.

  The unread count reads DIRECTLY from the notifications store so the
  badge is reactive end-to-end: it updates the instant the store's
  `unreadCount` changes (mount hydration via refreshUnreadCount, a
  realtime `prepend`, a `markRead`, or `markAllRead`) with no parent
  having to re-pass a prop snapshot. The optional `unreadCount` prop is
  kept only as an explicit override for tests/storybook; when omitted
  (the normal case) the store value drives the badge.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useNotificationsStore } from '@/stores/notifications';

const props = defineProps<{ unreadCount?: number }>();

const router = useRouter();

const store = useNotificationsStore();
const { unreadCount: storeUnreadCount } = storeToRefs(store);

// Prefer an explicit prop override when supplied; otherwise track the
// store's reactive count. `storeToRefs` keeps reactivity intact.
const count = computed(() =>
  props.unreadCount !== undefined ? props.unreadCount : storeUnreadCount.value,
);
</script>

<template>
  <button
    type="button"
    class="relative inline-flex items-center justify-center w-9 h-9 rounded-full bg-white/15 hover:bg-white/25 text-white"
    aria-label="Notifikasi"
    @click="router.push('/notifications')"
  >
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="w-4 h-4"
    >
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
    <span
      v-if="count > 0"
      class="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 rounded-full bg-status-danger text-white text-[10px] font-bold flex items-center justify-center"
    >
      {{ count > 99 ? '99+' : count }}
    </span>
  </button>
</template>

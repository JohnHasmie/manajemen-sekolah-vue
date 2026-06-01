<!--
  NotificationBell.vue — bell icon with unread badge in the topbar.
  Routes to /notifications on click. Unread count comes from the
  notifications store (populated by Firebase Cloud Messaging hooks +
  the /notifications/unread-count endpoint).

  For now this is a thin shell — the count source will be wired into
  task #16's notifications store.
-->
<script setup lang="ts">
import { useRouter } from 'vue-router';

defineProps<{ unreadCount?: number }>();

const router = useRouter();
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
      v-if="unreadCount && unreadCount > 0"
      class="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 rounded-full bg-status-danger text-white text-[10px] font-bold flex items-center justify-center"
    >
      {{ unreadCount > 99 ? '99+' : unreadCount }}
    </span>
  </button>
</template>

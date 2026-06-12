<!--
  ToastHost.vue — renders the singleton useToast() queue.
  Mount once in the app shell + once in any "outside-shell" route
  (login, register-demo). Stacks multiple active toasts vertically.
-->
<script setup lang="ts">
import { useToastQueue, type ToastMessage } from '@/composables/useToast';
import Toast from './Toast.vue';

const { toasts, dismiss } = useToastQueue();

function activate(t: ToastMessage) {
  // Fire the click action (e.g. navigate + mark read) then clear the toast.
  t.onClick?.();
  dismiss(t.id);
}
</script>

<template>
  <Toast
    v-for="(t, idx) in toasts.slice(-3)"
    :key="t.id"
    :message="t.message"
    :title="t.title"
    :tone="t.tone"
    :duration-ms="t.durationMs"
    :clickable="!!t.onClick"
    :style="{ marginBottom: `${idx * 4}px` }"
    @activate="activate(t)"
    @close="dismiss(t.id)"
  />
</template>

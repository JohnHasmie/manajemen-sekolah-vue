<!--
  ToastHost.vue — renders the singleton useToast() queue.
  Mount once in the app shell + once in any "outside-shell" route
  (login, register-demo). Stacks multiple active toasts vertically.
-->
<script setup lang="ts">
import { useToastQueue } from '@/composables/useToast';
import Toast from './Toast.vue';

const { toasts, dismiss } = useToastQueue();
</script>

<template>
  <Toast
    v-for="(t, idx) in toasts.slice(-3)"
    :key="t.id"
    :message="t.message"
    :tone="t.tone"
    :duration-ms="t.durationMs"
    :style="{ marginBottom: `${idx * 4}px` }"
    @close="dismiss(t.id)"
  />
</template>

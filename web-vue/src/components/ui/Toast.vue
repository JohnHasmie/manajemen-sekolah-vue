<!--
  Toast.vue — minimal snackbar primitive, web equivalent of
  SnackBarUtils.showSuccess / showError.
  Auto-dismisses after 5s; emits `close` so parents can clear local state.
-->
<script setup lang="ts">
import { onMounted, onBeforeUnmount } from 'vue';

const props = defineProps<{
  message: string;
  tone?: 'success' | 'error' | 'info';
  durationMs?: number;
}>();

const emit = defineEmits<{ close: [] }>();

let timer: ReturnType<typeof setTimeout> | null = null;

onMounted(() => {
  timer = setTimeout(() => emit('close'), props.durationMs ?? 5000);
});

onBeforeUnmount(() => {
  if (timer) clearTimeout(timer);
});
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-x-0 bottom-4 z-[60] flex justify-center px-md pointer-events-none">
      <div
        class="rounded-xl shadow-card px-md py-sm text-sm font-medium pointer-events-auto flex items-center gap-2 max-w-md w-full sm:w-auto"
        :class="{
          'bg-status-success text-white': tone === 'success',
          'bg-status-danger text-white': tone === 'error' || !tone,
          'bg-slate-900 text-white': tone === 'info',
        }"
        role="alert"
      >
        <span class="flex-1">{{ message }}</span>
        <button
          type="button"
          class="opacity-80 hover:opacity-100"
          aria-label="Tutup"
          @click="emit('close')"
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
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </button>
      </div>
    </div>
  </Teleport>
</template>

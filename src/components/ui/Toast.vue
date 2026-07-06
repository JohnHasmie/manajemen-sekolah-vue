<!--
  Toast.vue — minimal snackbar primitive, web equivalent of
  SnackBarUtils.showSuccess / showError.
  Auto-dismisses after 5s; emits `close` so parents can clear local state.

  Optionally renders a bold `title` above `message` and, when an `onClick`
  handler is provided (via the `clickable` prop), turns the body into a
  tappable surface — used by the realtime notification toast to deep-link
  into the relevant page on click.
-->
<script setup lang="ts">
import { onMounted, onBeforeUnmount } from 'vue';

const props = defineProps<{
  message: string;
  tone?: 'success' | 'error' | 'info';
  durationMs?: number;
  title?: string;
  /** When true the body is a button that emits `activate` on click. */
  clickable?: boolean;
  /** When set, render an inline action button (e.g. "Batal" for undo). */
  actionLabel?: string;
}>();

const emit = defineEmits<{ close: []; activate: []; action: [] }>();

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
        class="rounded-xl shadow-card px-md py-sm text-sm font-medium pointer-events-auto flex items-start gap-2 max-w-md w-full sm:w-auto"
        :class="{
          'bg-status-success text-white': tone === 'success',
          'bg-status-danger text-white': tone === 'error' || !tone,
          'bg-slate-900 text-white': tone === 'info',
        }"
        role="alert"
      >
        <component
          :is="clickable ? 'button' : 'div'"
          :type="clickable ? 'button' : undefined"
          class="flex-1 min-w-0 text-left"
          :class="clickable ? 'cursor-pointer focus:outline-none' : ''"
          @click="clickable ? emit('activate') : undefined"
        >
          <span v-if="title" class="block font-semibold leading-snug">{{ title }}</span>
          <span class="block" :class="title ? 'opacity-90 font-normal' : ''">{{ message }}</span>
        </component>
        <button
          v-if="actionLabel"
          type="button"
          class="uppercase tracking-widest text-xs font-black opacity-90 hover:opacity-100 flex-shrink-0 self-center px-2 py-1 rounded-md hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-white/40"
          @click="emit('action')"
        >
          {{ actionLabel }}
        </button>
        <button
          type="button"
          class="opacity-80 hover:opacity-100 flex-shrink-0 mt-0.5"
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

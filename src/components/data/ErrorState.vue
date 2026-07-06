<!--
  ErrorState.vue — error-screen placeholder.
  Mirrors Flutter's ErrorScreen in `lib/core/widgets/`.

  Defaults are resolved through `useI18n` so they track the active
  locale. Callers can still pass explicit `title` / `message` /
  `retryLabel` strings to override.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import type { ErrorHint } from '@/lib/errorHints';

const props = defineProps<{
  title?: string;
  message?: string;
  retryLabel?: string;
  /**
   * Warm cause hint. Rendered as a short second line under the message
   * with a matching icon — turns "Terjadi kesalahan" into an actionable
   * "Sepertinya koneksi internet Anda terputus."
   */
  hint?: ErrorHint | null;
}>();

defineEmits<{ retry: [] }>();

const { t } = useI18n();

const titleText = computed(() => props.title ?? t('common.errorTitle'));
const messageText = computed(() => props.message ?? t('common.errorMessage'));
const retryText = computed(() => props.retryLabel ?? t('common.tryAgain'));

const HINT_KEYS: Record<ErrorHint, string> = {
  network: 'common.errorHintNetwork',
  timeout: 'common.errorHintTimeout',
  session: 'common.errorHintSession',
  permission: 'common.errorHintPermission',
  notFound: 'common.errorHintNotFound',
  server: 'common.errorHintServer',
};

const hintText = computed(() =>
  props.hint ? t(HINT_KEYS[props.hint]) : '',
);
</script>

<template>
  <div
    class="flex flex-col items-center justify-center text-center py-xl px-md"
  >
    <div
      class="w-14 h-14 rounded-full bg-status-danger-soft text-status-danger flex items-center justify-center mb-md"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.75"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-7 h-7"
      >
        <circle cx="12" cy="12" r="10" />
        <line x1="12" y1="8" x2="12" y2="12" />
        <line x1="12" y1="16" x2="12.01" y2="16" />
      </svg>
    </div>

    <h3 class="text-base font-semibold text-slate-900 mb-1">{{ titleText }}</h3>
    <p class="text-sm text-slate-500 max-w-sm">{{ messageText }}</p>
    <p
      v-if="hintText"
      class="mt-1 text-xs text-slate-400 max-w-sm italic"
    >
      {{ hintText }}
    </p>

    <button
      type="button"
      class="mt-md rounded-xl bg-brand hover:bg-brand-700 text-white font-medium px-md py-sm text-sm"
      @click="$emit('retry')"
    >
      {{ retryText }}
    </button>
  </div>
</template>

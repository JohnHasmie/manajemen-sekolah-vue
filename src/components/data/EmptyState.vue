<!--
  EmptyState.vue — empty list/screen placeholder.
  Mirrors Flutter's EmptyState in `lib/core/widgets/`.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = withDefaults(
  defineProps<{
    title?: string;
    description?: string;
    actionLabel?: string;
    icon?: string;
  }>(),
  {
    description: '',
    actionLabel: '',
    icon: 'inbox',
  },
);

defineEmits<{ action: [] }>();

const { t } = useI18n();
// Translated default — only kicks in when `title` is empty or undefined.
const titleText = computed(() => props.title?.trim() ? props.title : t('common.emptyTitle'));
</script>

<template>
  <div
    class="flex flex-col items-center justify-center text-center py-xl px-md text-slate-500"
  >
    <div
      class="w-14 h-14 rounded-full bg-slate-100 flex items-center justify-center mb-md text-slate-400"
    >
      <!-- inbox -->
      <svg
        v-if="icon === 'inbox' || !icon"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.75"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-7 h-7"
      >
        <polyline points="22 12 16 12 14 15 10 15 8 12 2 12" />
        <path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z" />
      </svg>
      <!-- search -->
      <svg
        v-else-if="icon === 'search'"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.75"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-7 h-7"
      >
        <circle cx="11" cy="11" r="8" />
        <line x1="21" y1="21" x2="16.65" y2="16.65" />
      </svg>
    </div>

    <h3 class="text-base font-semibold text-slate-900 mb-1">{{ titleText }}</h3>
    <p v-if="description" class="text-sm max-w-sm">{{ description }}</p>

    <button
      v-if="actionLabel"
      type="button"
      class="mt-md rounded-xl bg-brand hover:bg-brand-700 text-white font-medium px-md py-sm text-sm"
      @click="$emit('action')"
    >
      {{ actionLabel }}
    </button>
  </div>
</template>

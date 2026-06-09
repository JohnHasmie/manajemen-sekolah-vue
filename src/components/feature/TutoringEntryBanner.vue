<!--
  TutoringEntryBanner — additive dashboard entry into the tutoring
  (bimbel) surface. Renders ONLY when the active tenant is a tutoring
  center (useTenant().isTutoringCenter); for a formal-school tenant it
  renders nothing, so the school dashboards stay unchanged.

  Web mirror of the Flutter TutoringEntryBanner. The parent caller
  passes the destination via @click.
-->
<script setup lang="ts">
import { useTenant } from '@/composables/useTenant';

defineProps<{
  title?: string;
  subtitle?: string;
}>();
defineEmits<{ (e: 'click'): void }>();

const { isTutoringCenter } = useTenant();
</script>

<template>
  <button
    v-if="isTutoringCenter"
    type="button"
    class="flex w-full items-center gap-3 rounded-2xl bg-violet-100 p-4 text-left transition hover:bg-violet-200/70"
    @click="$emit('click')"
  >
    <span
      class="grid h-11 w-11 flex-shrink-0 place-items-center rounded-xl bg-violet-600 text-white"
    >
      <svg
        class="h-5 w-5"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
      >
        <path
          d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M4 19.5A2.5 2.5 0 0 0 6.5 22H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15z"
        />
      </svg>
    </span>
    <span class="min-w-0 flex-1">
      <span class="block font-extrabold text-violet-900">
        {{ title ?? 'Menu Bimbel' }}
      </span>
      <span class="block text-[11.5px] text-violet-700">
        {{ subtitle ?? 'Kelola program, sesi, dan absensi bimbel' }}
      </span>
    </span>
    <svg
      class="h-5 w-5 flex-shrink-0 text-violet-600"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
    >
      <path d="M9 6l6 6-6 6" />
    </svg>
  </button>
</template>

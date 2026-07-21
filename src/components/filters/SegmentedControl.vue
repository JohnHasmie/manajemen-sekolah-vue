<!--
  SegmentedControl.vue - iOS-style segmented buttons inside a slate container.

  The single canonical tab-switch across the app: Jadwal's List/Timetable,
  the admin data-page view toggles (Kartu/Padat), session/asesmen/period
  selectors, etc. One fixed size so every switch reads identically — the
  old `size` variant was dropped so pages can't drift apart.

  Each option can carry an optional `meta` (e.g. start time, count) shown
  smaller after the main label.
-->
<script setup lang="ts">
export interface SegmentOption {
  key: string;
  label: string;
  meta?: string;
}

defineProps<{
  modelValue: string;
  options: SegmentOption[];
}>();

defineEmits<{ 'update:modelValue': [string] }>();
</script>

<template>
  <div
    class="inline-flex gap-0.5 bg-slate-100 rounded-xl p-1"
    role="tablist"
  >
    <button
      v-for="opt in options"
      :key="opt.key"
      type="button"
      role="tab"
      :aria-selected="modelValue === opt.key"
      class="rounded-lg font-bold transition-all text-2xs px-3 py-1.5"
      :class="
        modelValue === opt.key
          ? 'bg-white text-slate-900 shadow-sm'
          : 'text-slate-500 hover:text-slate-900'
      "
      @click="$emit('update:modelValue', opt.key)"
    >
      {{ opt.label }}<span
        v-if="opt.meta"
        class="ml-1 font-bold opacity-60 text-3xs"
      >· {{ opt.meta }}</span>
    </button>
  </div>
</template>

<!--
  SegmentedControl.vue - iOS-style segmented buttons inside a slate container.

  Used for Session selector (Session 1/2/3/4) and Asesmen type selector
  (Semua / Tugas / UH / UTS / UAS).

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
  size?: 'sm' | 'md';
}>();

defineEmits<{ 'update:modelValue': [string] }>();
</script>

<template>
  <div
    class="inline-flex gap-0.5 bg-slate-100 rounded-xl"
    :class="size === 'sm' ? 'p-0.5' : 'p-1'"
    role="tablist"
  >
    <button
      v-for="opt in options"
      :key="opt.key"
      type="button"
      role="tab"
      :aria-selected="modelValue === opt.key"
      class="rounded-lg font-bold transition-all"
      :class="[
        modelValue === opt.key
          ? 'bg-white text-slate-900 shadow-sm'
          : 'text-slate-500 hover:text-slate-900',
        size === 'sm' ? 'text-3xs px-2.5 py-1' : 'text-2xs px-3 py-1.5',
      ]"
      @click="$emit('update:modelValue', opt.key)"
    >
      {{ opt.label }}<span
        v-if="opt.meta"
        class="ml-1 font-bold opacity-60"
        :class="size === 'sm' ? 'text-4xs' : 'text-3xs'"
      >· {{ opt.meta }}</span>
    </button>
  </div>
</template>

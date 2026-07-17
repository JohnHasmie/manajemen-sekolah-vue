<!--
  CohortPillGroup.vue — segmented control for peringkat kelompok.
  Emits the currently-selected cohort key.
-->
<script setup lang="ts">
import type { Cohort } from '@/services/teacher-progress.service';

const props = defineProps<{
  modelValue: Cohort;
  /** Which cohorts to expose; useful for hiding unused ones. */
  available?: Cohort[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: Cohort): void;
}>();

const ALL: { key: Cohort; label: string }[] = [
  { key: 'general', label: 'Guru Umum' },
  { key: 'subject', label: 'Guru Mapel' },
  { key: 'homeroom', label: 'Wali Kelas' },
  { key: 'staff', label: 'Staf' },
];

function shown() {
  return props.available && props.available.length > 0
    ? ALL.filter((c) => props.available!.includes(c.key))
    : ALL;
}
</script>

<template>
  <div class="inline-flex bg-slate-100 rounded-xl p-1 overflow-x-auto">
    <button
      v-for="c in shown()"
      :key="c.key"
      type="button"
      class="px-3 py-1.5 rounded-lg text-2xs font-bold transition whitespace-nowrap"
      :class="modelValue === c.key
        ? 'bg-white text-brand-cobalt shadow-sm'
        : 'text-slate-600 hover:text-slate-900'"
      @click="emit('update:modelValue', c.key)"
    >
      {{ c.label }}
    </button>
  </div>
</template>

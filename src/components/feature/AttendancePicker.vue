<!--
  AttendancePicker.vue - full-label Hadir/Sakit/Izin/Alpa selector.
  Mirrors Flutter's per-student presence picker.

  Each option is a minimum 76px button with full label, role-color tint
  when selected, and an icon indicator. On mobile, the label collapses
  to icon-only via the responsive layer in the parent view.
-->
<script setup lang="ts">
import { ATTENDANCE_LABELS, type AttendanceStatus } from '@/types/attendance';

defineProps<{
  modelValue: AttendanceStatus;
  disabled?: boolean;
}>();

defineEmits<{ 'update:modelValue': [AttendanceStatus] }>();
</script>

<template>
  <div class="inline-flex gap-1" role="radiogroup" aria-label="Status kehadiran">
    <button
      v-for="opt in (['hadir', 'sakit', 'izin', 'alpa'] as const)"
      :key="opt"
      type="button"
      role="radio"
      :aria-checked="modelValue === opt"
      :disabled="disabled"
      class="rounded-lg border border-slate-200 bg-white text-slate-500 hover:border-slate-400 hover:text-slate-900 transition-all px-3 py-1.5 text-[11px] font-bold inline-flex items-center justify-center gap-1.5 min-w-[68px] sm:min-w-[76px] disabled:opacity-60 disabled:cursor-not-allowed"
      :class="{
        'border-transparent text-white bg-emerald-700': modelValue === opt && opt === 'hadir',
        'border-transparent text-white bg-amber-700': modelValue === opt && opt === 'sakit',
        'border-transparent text-white bg-blue-700': modelValue === opt && opt === 'izin',
        'border-transparent text-white bg-red-700': modelValue === opt && opt === 'alpa',
      }"
      @click="$emit('update:modelValue', modelValue === opt ? null : opt)"
    >
      <svg
        v-if="modelValue === opt"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-3 h-3"
        aria-hidden="true"
      >
        <template v-if="opt === 'hadir'">
          <polyline points="20 6 9 17 4 12" />
        </template>
        <template v-else-if="opt === 'sakit'">
          <path d="M14 4v2a2 2 0 0 1-2 2h-1a2 2 0 0 0-2 2v3a2 2 0 0 1-2 2H5l-1 2v2a2 2 0 0 0 2 2h8a4 4 0 0 0 4-4V4" />
        </template>
        <template v-else-if="opt === 'izin'">
          <polyline points="9 11 12 14 22 4" />
          <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
        </template>
        <template v-else>
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </template>
      </svg>
      <span class="hidden sm:inline">{{ ATTENDANCE_LABELS[opt] }}</span>
      <span class="sm:hidden">{{ ATTENDANCE_LABELS[opt].charAt(0) }}</span>
    </button>
  </div>
</template>

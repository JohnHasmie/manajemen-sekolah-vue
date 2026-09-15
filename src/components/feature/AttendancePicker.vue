<!--
  AttendancePicker.vue - full-label Hadir/Sakit/Izin/Alpa selector.
  Mirrors Flutter's per-student presence picker.

  Each option is a minimum 76px button with full label, role-color tint
  when selected, and an icon indicator. On mobile, the label collapses
  to icon-only via the responsive layer in the parent view.

  ── Why every colour lives in `:class` and none in the static class ──

  The selected chip used to render INVISIBLE: white text on a white
  background with a transparent border. The static class carried
  `bg-white text-slate-500 border-slate-200` while `:class` added
  `bg-emerald-700 text-white border-transparent`, so both landed in the
  class list at equal specificity (one class each) and CSS SOURCE ORDER
  decided each property independently.

  Tailwind v3 emits colour utilities in LEXICOGRAPHIC order of the
  class-name suffix, not palette order, which splits the three
  properties apart. Measured in the emitted bundle:

    background-color  .bg-emerald-700 @240784  <  .bg-white @249662
    color             .text-slate-500 @271711  <  .text-white @273948
    border-color      .border-slate-200 @232889 < .border-transparent @234020

  So the STATIC `bg-white` won the background while the CONDITIONAL
  `text-white` and `border-transparent` won the text and the border —
  white on white, no border. All four statuses shared the defect; the
  selected one simply disappeared.

  There is a second failure mode with the same root cause. Under the
  `.tutoring-dark` wrapper that `AppShell` applies to the bimbel stack,
  `style.css` emits theme overrides keyed off the STATIC classes:

    .tutoring-dark .bg-white{background-color:var(--tutoring-panel)!important}
    .tutoring-dark .text-slate-500{color:var(--tutoring-text-mid)!important}
    .tutoring-dark .border-slate-200{border-color:var(--tutoring-border)!important}

  `!important` beats the conditional utilities outright, so a selected
  chip rendered byte-identical to an unselected one.

  Keeping the static class free of every background/text/border colour
  fixes both at once: the unselected branch opts INTO the themed
  greys, the selected branch is the only thing painting a status
  colour, and no pair of utilities ever competes. This is the repo's
  house pattern — see the sibling `AttendanceStatusPickerModal.vue`
  (same four statuses), `AppFilterChip.vue` and `SegmentedControl.vue`.

  The four hues and the check icon are unchanged: this is a rendering
  fix, not a redesign.
-->
<script setup lang="ts">
import { ATTENDANCE_LABELS, type AttendanceStatus } from '@/types/attendance';

defineProps<{
  modelValue: AttendanceStatus;
  disabled?: boolean;
}>();

defineEmits<{ 'update:modelValue': [AttendanceStatus] }>();

/**
 * Painted ONLY when the option is the selected one. Each string owns
 * all three colour properties so nothing is inherited from a static
 * class that could out-order it.
 */
const SELECTED_CLASS: Record<NonNullable<AttendanceStatus>, string> = {
  hadir: 'border-transparent text-white bg-emerald-700',
  sakit: 'border-transparent text-white bg-amber-700',
  izin: 'border-transparent text-white bg-blue-700',
  alpa: 'border-transparent text-white bg-red-700',
};

/**
 * The readable resting pair, plus the hover colours that used to sit in
 * the static class. Hover belongs here too — `hover:text-slate-900` on
 * a selected emerald chip was the same conflict one interaction later.
 */
const UNSELECTED_CLASS =
  'border-slate-200 bg-white text-slate-500 hover:border-slate-400 hover:text-slate-900';
</script>

<template>
  <div class="inline-flex gap-1" role="radiogroup" aria-label="Status kehadiran">
    <button
      v-for="opt in (['hadir', 'sakit', 'izin', 'alpa'] as const)"
      :key="opt"
      type="button"
      role="radio"
      :data-testid="`attendance-chip-${opt}`"
      :aria-checked="modelValue === opt"
      :disabled="disabled"
      class="rounded-lg border transition-all px-3 py-1.5 text-2xs font-bold inline-flex items-center justify-center gap-1.5 min-w-[68px] sm:min-w-[76px] disabled:opacity-60 disabled:cursor-not-allowed"
      :class="modelValue === opt ? SELECTED_CLASS[opt] : UNSELECTED_CLASS"
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

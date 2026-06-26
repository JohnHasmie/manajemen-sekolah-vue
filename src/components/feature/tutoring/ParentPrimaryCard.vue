<!--
  ParentPrimaryCard — accent-stripe card for "Hari ini" (next
  session) / "Perlu perhatian" patterns on parent Home. Mirror
  of TutorPrimaryCard but with parent-tuned tone defaults.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

withDefaults(
  defineProps<{
    icon?: string;
    kicker?: string;
    title: string;
    subtitle?: string;
    tone?: 'brand' | 'success' | 'warning' | 'danger';
    /** Right-side small chip text (e.g. countdown). */
    chip?: string;
  }>(),
  { tone: 'brand' },
);

const TONE: Record<
  'brand' | 'success' | 'warning' | 'danger',
  { bar: string; chip: string; chipText: string; kicker: string }
> = {
  brand: {
    bar: 'bg-[#21afe6]',
    chip: 'bg-[#21afe6]/15',
    chipText: 'text-[#1a8fbe] dark:text-[#85d4f4]',
    kicker: 'text-[#1a8fbe] dark:text-[#85d4f4]',
  },
  success: {
    bar: 'bg-emerald-500',
    chip: 'bg-emerald-500/15',
    chipText: 'text-emerald-700 dark:text-emerald-300',
    kicker: 'text-emerald-700 dark:text-emerald-300',
  },
  warning: {
    bar: 'bg-amber-500',
    chip: 'bg-amber-500/15',
    chipText: 'text-amber-800 dark:text-amber-300',
    kicker: 'text-amber-800 dark:text-amber-300',
  },
  danger: {
    bar: 'bg-rose-500',
    chip: 'bg-rose-500/15',
    chipText: 'text-rose-700 dark:text-rose-300',
    kicker: 'text-rose-700 dark:text-rose-300',
  },
};
</script>

<template>
  <div
    class="relative overflow-hidden rounded-2xl border border-tutoring-border-soft bg-tutoring-panel pl-5 pr-4 py-3.5"
  >
    <span class="absolute left-0 top-0 h-full w-1.5" :class="TONE[tone].bar" />
    <div class="flex items-start justify-between gap-3">
      <div class="min-w-0 flex-1">
        <p
          v-if="kicker"
          class="text-[13px] font-extrabold uppercase tracking-widest"
          :class="TONE[tone].kicker"
        >
          {{ kicker }}
        </p>
        <h3
          class="mt-0.5 flex items-center gap-2 text-[15px] font-extrabold tracking-tight text-tutoring-text-hi"
        >
          <NavIcon v-if="icon" :name="icon" :size="15" :class="TONE[tone].chipText" />
          <span class="truncate">{{ title }}</span>
        </h3>
        <p v-if="subtitle" class="mt-0.5 text-[13px] text-tutoring-text-mid">{{ subtitle }}</p>
      </div>
      <span
        v-if="chip"
        class="flex-shrink-0 rounded-full px-2.5 py-1 text-[13px] font-extrabold"
        :class="[TONE[tone].chip, TONE[tone].chipText]"
      >
        {{ chip }}
      </span>
    </div>
    <div v-if="$slots.default" class="mt-2.5 text-[13px] text-tutoring-text-mid">
      <slot />
    </div>
    <div v-if="$slots.actions" class="mt-3 flex flex-wrap gap-2">
      <slot name="actions" />
    </div>
  </div>
</template>

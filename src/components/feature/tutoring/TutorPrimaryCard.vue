<!--
  TutorPrimaryCard — accent-stripe card used for the "Sesi berikutnya"
  hero block + "Perlu perhatian" / "Hari ini" patterns. A 4px tinted
  bar on the left identifies tone (`brand` cyan, `success` green,
  `warning` amber, `danger` red).

  Slot `meta` is the small pill in the top-right (e.g. countdown).
  Slot `actions` is the bottom button row. Body content goes in default.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

withDefaults(
  defineProps<{
    /** Optional icon shown next to title. */
    icon?: string;
    /** ALL-CAPS micro-label (e.g. "SESI BERIKUTNYA"). */
    kicker?: string;
    /** Bold display title. */
    title: string;
    /** Optional secondary line under the title. */
    subtitle?: string;
    /** Accent tone — drives the stripe + kicker color. */
    tone?: 'brand' | 'success' | 'warning' | 'danger';
  }>(),
  { tone: 'brand' },
);

const TONE: Record<
  'brand' | 'success' | 'warning' | 'danger',
  { bar: string; chip: string; chipText: string }
> = {
  brand: {
    bar: 'bg-bimbel-accent',
    chip: 'bg-bimbel-accent-dim',
    chipText: 'text-bimbel-accent',
  },
  success: {
    bar: 'bg-emerald-500',
    chip: 'bg-emerald-500/15',
    chipText: 'text-emerald-600 dark:text-emerald-400',
  },
  warning: {
    bar: 'bg-amber-500',
    chip: 'bg-amber-500/15',
    chipText: 'text-amber-700 dark:text-amber-400',
  },
  danger: {
    bar: 'bg-rose-500',
    chip: 'bg-rose-500/15',
    chipText: 'text-rose-600 dark:text-rose-400',
  },
};
</script>

<template>
  <div
    class="relative overflow-hidden rounded-3xl border border-bimbel-border-soft bg-bimbel-panel pl-5 pr-4 py-4"
  >
    <span
      class="absolute left-0 top-0 h-full w-1.5"
      :class="TONE[tone].bar"
    />

    <div class="flex items-start justify-between gap-3">
      <div class="min-w-0 flex-1">
        <p
          v-if="kicker"
          class="text-[12px] font-extrabold uppercase tracking-widest"
          :class="TONE[tone].chipText"
        >
          {{ kicker }}
        </p>
        <h3
          class="mt-0.5 flex items-center gap-2 text-base font-extrabold tracking-tight text-bimbel-text-hi"
        >
          <NavIcon
            v-if="icon"
            :name="icon"
            :size="16"
            :class="TONE[tone].chipText"
          />
          <span class="truncate">{{ title }}</span>
        </h3>
        <p v-if="subtitle" class="mt-0.5 text-[13px] text-bimbel-text-mid">
          {{ subtitle }}
        </p>
      </div>

      <div v-if="$slots.meta" class="flex-shrink-0">
        <slot name="meta" />
      </div>
    </div>

    <div v-if="$slots.default" class="mt-3 text-[14px] text-bimbel-text-mid">
      <slot />
    </div>

    <div v-if="$slots.actions" class="mt-3 flex flex-wrap gap-2">
      <slot name="actions" />
    </div>
  </div>
</template>

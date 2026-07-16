<!--
  KpiStripCards.vue — shared 4-up KPI strip used across teacher pages
  (Schedule, Presensi, Gradebook, etc.).

  Pattern (port of Flutter's `_HeaderStatChip` + the redesigned
  inline KPI strip in `teacher_schedule_screen.dart`):

    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │ [▤] LABEL   │ │ [▤] LABEL   │ │ [▤] LABEL   │ │ [▤] LABEL   │
    │ 24 session     │ │  8 hari ini │ │ 12 mapel    │ │ 92%         │
    └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘

  - tinted icon-square (28×28 rounded-lg) at top-left
  - uppercase 9.5px label next to it
  - large 2xl black value below
  - optional `suffix` (small light suffix after the value, e.g. "session")
  - `accented` flips the card to use the tone color for label/value +
    an inset border accent (1px), matching the Schedule's "Hari Ini" card.

  Tailwind classes are looked up via a static map so JIT keeps them.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

export type KpiTone =
  | 'brand'
  | 'amber'
  | 'violet'
  | 'green'
  | 'red'
  | 'slate';

export interface KpiCard {
  /** NavIcon name (e.g. "calendar", "check-circle", "users"). */
  icon: string;
  /** Uppercase label rendered next to the icon square. */
  label: string;
  /** The big value. Numbers are stringified by Vue. */
  value: string | number;
  /** Small de-emphasised suffix after the value (e.g. "session", "%"). */
  suffix?: string;
  /** Icon-square + accent colour family. */
  tone?: KpiTone;
  /**
   * When true, the card uses the tone colour for the label + value text
   * and gets an inset tinted ring — mirrors Schedule's "Hari Ini" card.
   */
  accented?: boolean;
}

const props = withDefaults(
  defineProps<{
    cards: KpiCard[];
    /**
     * Number of columns at the lg breakpoint. Defaults to 4 for the
     * canonical 4-up strip; pass 3 for screens with only 3 cards.
     */
    lgCols?: 3 | 4;
    /**
     * When true, renders one skeleton row per card slot instead of the
     * real values — the label/icon still show, but the big value flips
     * to a pulsing bar. Consumers pass `:loading="isLoading"` so pages
     * don't flash "0" before the fetch resolves. The card `label` +
     * `icon` still render because they're static copy — only the
     * unknown value pulses.
     */
    loading?: boolean;
  }>(),
  { lgCols: 4, loading: false },
);

// ── Tone classes — kept as static literals so Tailwind JIT picks them up ─
const ICON_BG: Record<KpiTone, string> = {
  brand: 'bg-brand-cobalt/10 text-brand-cobalt',
  amber: 'bg-amber-100 text-amber-700',
  violet: 'bg-violet-100 text-violet-700',
  green: 'bg-emerald-100 text-emerald-700',
  red: 'bg-red-100 text-red-700',
  slate: 'bg-slate-100 text-slate-600',
};

const ACCENTED_BORDER: Record<KpiTone, string> = {
  brand:
    'border-brand-cobalt/30 shadow-[inset_0_0_0_1px_rgba(27,111,184,0.08)]',
  amber:
    'border-amber-300/60 shadow-[inset_0_0_0_1px_rgba(180,83,9,0.08)]',
  violet:
    'border-violet-300/60 shadow-[inset_0_0_0_1px_rgba(109,40,217,0.08)]',
  green:
    'border-emerald-300/60 shadow-[inset_0_0_0_1px_rgba(21,128,61,0.08)]',
  red: 'border-red-300/60 shadow-[inset_0_0_0_1px_rgba(185,28,28,0.08)]',
  slate: 'border-slate-300 shadow-[inset_0_0_0_1px_rgba(15,23,42,0.05)]',
};

const ACCENTED_TEXT: Record<KpiTone, string> = {
  brand: 'text-brand-cobalt',
  amber: 'text-amber-700',
  violet: 'text-violet-700',
  green: 'text-emerald-700',
  red: 'text-red-700',
  slate: 'text-slate-700',
};

function cardClass(c: KpiCard): string {
  const tone = c.tone ?? 'brand';
  if (c.accented) {
    return `bg-white border ${ACCENTED_BORDER[tone]} rounded-2xl p-3.5`;
  }
  return 'bg-white border border-slate-200 rounded-2xl p-3.5';
}

function iconSquareClass(c: KpiCard): string {
  const tone = c.tone ?? 'brand';
  return `w-7 h-7 rounded-lg grid place-items-center ${ICON_BG[tone]}`;
}

function labelClass(c: KpiCard): string {
  if (c.accented) {
    return `text-[9.5px] font-bold uppercase tracking-widest ${ACCENTED_TEXT[c.tone ?? 'brand']}`;
  }
  return 'text-[9.5px] font-bold text-slate-400 uppercase tracking-widest';
}

function valueClass(c: KpiCard): string {
  if (c.accented) {
    return `text-2xl font-black mt-2 leading-none tracking-tight ${ACCENTED_TEXT[c.tone ?? 'brand']}`;
  }
  return 'text-2xl font-black text-slate-900 mt-2 leading-none tracking-tight';
}

const gridClass = computed(() =>
  ['grid', 'grid-cols-2', 'gap-3', `lg:grid-cols-3`, `lg:grid-cols-4`]
    .filter((c) => !c.startsWith('lg:'))
    .concat([`lg:grid-cols-${4}`])
    .join(' '),
);
void gridClass; // placeholder if we want it later
</script>

<template>
  <section
    class="grid grid-cols-2 gap-3"
    :class="lgCols === 3 ? 'lg:grid-cols-3' : 'lg:grid-cols-4'"
  >
    <div
      v-for="(c, idx) in cards"
      :key="idx"
      :class="cardClass(c)"
    >
      <div class="flex items-center gap-2">
        <span :class="iconSquareClass(c)">
          <NavIcon :name="c.icon" :size="14" />
        </span>
        <p :class="labelClass(c)">{{ c.label }}</p>
      </div>
      <p v-if="props.loading" class="mt-2 h-6 w-14 rounded-md bg-slate-200 animate-pulse" aria-hidden="true" />
      <p v-else :class="valueClass(c)">
        {{ c.value }}
        <span
          v-if="c.suffix"
          class="text-2xs font-normal text-slate-500"
        >{{ c.suffix }}</span>
      </p>
    </div>
  </section>
</template>

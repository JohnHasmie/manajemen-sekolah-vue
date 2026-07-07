<!--
  GradeSubjectCard.vue — shared per-(class, subject) tile.

  Extracted from the inline card block in TeacherGradeBookView.vue
  around L1220 so both TeacherGradeBookView (nilai main) and
  TeacherGradeRecapView (rekap main) can render the same visual card.
  Before this component the nilai grid + rekap grid rendered
  visibly different tiles for the same conceptual thing — user-
  reported UI inconsistency (see task #188).

  Layout, top to bottom:
    ┌──────────────────────────────────────────────────┐
    │ ┌───┐  KELAS 7A                                  │
    │ │82 │  B. Arab                          Buka  ›  │
    │ └───┘  BAR · Bu Salma                            │
    │                                                  │
    │ ┌────────┬────────┬────────┐                     │
    │ │ SISWA  │ ASESMEN│ NILAI  │                     │
    │ │   16   │   3    │   34   │                     │
    │ └────────┴────────┴────────┘                     │
    │                                                  │
    │ [slot: footer — nilai renders type chips + a     │
    │  progress bar; rekap leaves it empty]            │
    └──────────────────────────────────────────────────┘

  Deliberately NOT baking the meta-cell labels or the type-pill
  logic into the component — the two consumers translate labels
  through their own i18n scope + resolve their own tone maps (nilai
  uses KKM, rekap uses a fixed threshold). Passing rendered strings
  + tone-class arrays keeps the component free of i18n or feature
  coupling.

  Emits `click` on the outer button. Consumers already wrap the
  card in a template that turns the whole tile into a click target;
  keeping the `<button>` here so keyboard focus + accessibility
  work without the consumer having to remember.
-->
<script setup lang="ts">
defineProps<{
  /**
   * Numeric average score to render in the badge. Pass null to
   * render an em-dash.
   */
  avgScore: number | null;
  /**
   * Tone classes for the avg badge — background, text, border.
   * Consumer computes this from its own avgTone(score, kkm?)
   * helper so nilai (KKM-relative) and rekap (fixed thresholds)
   * each keep their existing tone logic.
   */
  avgTone: { bg: string; text: string; border: string };
  /**
   * Class name label shown as the top-line kicker
   * (e.g. "KELAS 7A"). Pre-translated by the caller.
   */
  classLabel: string;
  /**
   * Subject / mapel name — the tile's main heading.
   */
  subjectName: string;
  /**
   * Optional secondary line under the subject name. Nilai uses it
   * for the subject code (BAR); rekap uses it for
   * "BAR · Bu Salma" (code + optional teacher name in wali mode).
   * null / empty → line hides entirely.
   */
  subjectDetail?: string | null;
  /**
   * Label for the trailing "Buka ›" action. Pre-translated.
   */
  openLabel: string;
  /**
   * Three meta cells shown below the header. Values render as
   * `<p>{{ value }}</p>` so callers can pass a plain number for
   * counts or a formatted "5 / 34" for fractions.
   */
  metaCells: Array<{ label: string; value: string | number }>;
}>();

const emit = defineEmits<{
  (e: 'click'): void;
}>();
</script>

<template>
  <button
    type="button"
    class="w-full text-left bg-white border border-slate-200 rounded-2xl p-4 hover:border-brand-cobalt/40 hover:shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30 transition-all"
    @click="emit('click')"
  >
    <!-- Header row: avg badge + kelas/mapel/detail + Buka -->
    <div class="flex items-start gap-3">
      <span
        class="w-12 h-12 rounded-2xl border grid place-items-center text-[13px] font-black flex-shrink-0"
        :class="[avgTone.bg, avgTone.text, avgTone.border]"
      >
        <span v-if="avgScore !== null">{{ Math.round(avgScore) }}</span>
        <span v-else>—</span>
      </span>
      <div class="flex-1 min-w-0">
        <p
          class="text-3xs font-bold text-brand-cobalt uppercase tracking-widest"
        >
          {{ classLabel }}
        </p>
        <p
          class="text-[14px] font-black text-slate-900 leading-tight mt-0.5 truncate"
        >
          {{ subjectName }}
        </p>
        <p
          v-if="subjectDetail"
          class="text-[10.5px] text-slate-400 mt-0.5 truncate"
        >
          {{ subjectDetail }}
        </p>
      </div>
      <span
        class="text-3xs font-bold text-brand-cobalt inline-flex items-center gap-0.5 flex-shrink-0"
      >
        {{ openLabel }}
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <polyline points="9 18 15 12 9 6" />
        </svg>
      </span>
    </div>

    <!-- 3 meta cells -->
    <div class="grid grid-cols-3 gap-1.5 mt-3">
      <div
        v-for="(cell, idx) in metaCells"
        :key="idx"
        class="bg-slate-50 rounded-lg px-2 py-1.5 text-center"
      >
        <p
          class="text-[8.5px] font-bold text-slate-400 uppercase tracking-widest"
        >
          {{ cell.label }}
        </p>
        <p class="text-[12px] font-black text-slate-900 mt-0.5">
          {{ cell.value }}
        </p>
      </div>
    </div>

    <!-- Optional footer for consumer-specific bits (nilai type
         chips + progress bar; rekap leaves empty). -->
    <div v-if="$slots.footer" class="mt-3">
      <slot name="footer" />
    </div>
  </button>
</template>

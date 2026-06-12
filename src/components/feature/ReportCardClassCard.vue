<!--
  ReportCardClassCard.vue — class hub card (Rapor Frame A).

  Web port of `teacher_report_card_overview.dart`'s per-class tile.
  One card per homeroom class showing 4-cell completion stats +
  completion ring + drill chevron.

  Layout, top to bottom:
    ┌─────────────────────────────────────────────────────────┐
    │ [▤] VII A · WALI KELAS                          ›       │
    │     N siswa                                              │
    │                                                         │
    │ ┌───┐ ┌───┐ ┌───┐ ┌───┐                                 │
    │ │ 2 │ │ 1 │ │18 │ │ 4 │                                 │
    │ │DRA│ │DIP│ │TER│ │BEL│                                 │
    │ └───┘ └───┘ └───┘ └───┘                                 │
    │                                                         │
    │ ▰▰▰▰▰▰▰▰▱▱  75%  (15/20)                                │
    └─────────────────────────────────────────────────────────┘

  Completion bar tone:
    - 100%      → emerald (success)
    - 60-99%    → cobalt → azure gradient
    - 1-59%     → amber
    - 0%        → slate
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { RaportClassSummary } from '@/types/report-card';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  cls: RaportClassSummary;
}>();

const emit = defineEmits<{
  click: [cls: RaportClassSummary];
}>();

// Belum = students - any-status raport. Coalesce both operands: if the
// class summary omits either field, `undefined - n` is NaN and
// `Math.max(0, NaN)` stays NaN — which rendered literally as "NaN" on the
// "Belum" stat (founder report). Guard so it falls back to 0.
const belumCount = computed(() => {
  const s = props.cls;
  return Math.max(0, (s.student_count ?? 0) - (s.total_raports ?? 0));
});

const completionPct = computed(() => {
  const s = props.cls;
  if (s.completion_pct !== undefined) return Math.round(s.completion_pct);
  if (s.student_count === 0) return 0;
  // Use published as the "done" axis (matches Flutter overview ring).
  return Math.round((s.published_count / s.student_count) * 100);
});

const progressStyle = computed(() => {
  const pct = completionPct.value;
  if (pct >= 100) {
    return {
      width: '100%',
      background: 'linear-gradient(90deg, #10B981 0%, #059669 100%)',
    };
  }
  if (pct >= 60) {
    return {
      width: `${pct}%`,
      background: 'linear-gradient(90deg, #1B6FB8 0%, #1A8FBE 100%)',
    };
  }
  if (pct > 0) {
    return {
      width: `${pct}%`,
      background: 'linear-gradient(90deg, #F59E0B 0%, #D97706 100%)',
    };
  }
  return { width: '0%', background: 'rgb(148 163 184)' };
});

const kicker = computed(() => {
  const tingkat = props.cls.grade_level
    ? ` · TINGKAT ${String(props.cls.grade_level).toUpperCase()}`
    : '';
  return `${props.cls.class_name.toUpperCase()}${tingkat}`;
});
</script>

<template>
  <article
    class="bg-white border border-slate-200 rounded-2xl p-3.5 hover:border-brand-cobalt/30 hover:shadow-sm transition cursor-pointer"
    @click="emit('click', cls)"
  >
    <!-- HEADER -->
    <div class="flex items-center gap-3">
      <span
        class="w-11 h-11 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0"
      >
        <NavIcon name="book" :size="18" />
      </span>
      <div class="flex-1 min-w-0">
        <p class="text-[9.5px] font-black text-brand-cobalt uppercase tracking-widest leading-none">
          {{ kicker }}
        </p>
        <p class="text-[14px] font-black text-slate-900 mt-1 leading-tight truncate">
          Kelas {{ cls.class_name }}
        </p>
        <p class="text-[11px] text-slate-500 mt-0.5">
          {{ cls.student_count }} siswa
        </p>
      </div>
      <NavIcon
        name="chevron-right"
        :size="14"
        class="text-slate-400 flex-shrink-0"
      />
    </div>

    <!-- 4-CELL STATS -->
    <div class="grid grid-cols-4 gap-2 mt-3">
      <div
        class="rounded-xl px-2 py-2 text-center"
        :class="cls.draft_count > 0 ? 'bg-slate-100' : 'bg-slate-50'"
      >
        <p
          class="text-lg font-black leading-none tabular-nums"
          :class="cls.draft_count > 0 ? 'text-slate-700' : 'text-slate-400'"
        >
          {{ cls.draft_count }}
        </p>
        <p class="text-[8.5px] font-bold uppercase tracking-widest mt-1 text-slate-500">
          Draf
        </p>
      </div>
      <div
        class="rounded-xl px-2 py-2 text-center"
        :class="cls.final_count > 0 ? 'bg-amber-50' : 'bg-slate-50'"
      >
        <p
          class="text-lg font-black leading-none tabular-nums"
          :class="cls.final_count > 0 ? 'text-amber-700' : 'text-slate-400'"
        >
          {{ cls.final_count }}
        </p>
        <p class="text-[8.5px] font-bold uppercase tracking-widest mt-1 text-slate-500">
          Diperiksa
        </p>
      </div>
      <div
        class="rounded-xl px-2 py-2 text-center"
        :class="cls.published_count > 0 ? 'bg-emerald-50' : 'bg-slate-50'"
      >
        <p
          class="text-lg font-black leading-none tabular-nums"
          :class="cls.published_count > 0 ? 'text-emerald-700' : 'text-slate-400'"
        >
          {{ cls.published_count }}
        </p>
        <p class="text-[8.5px] font-bold uppercase tracking-widest mt-1 text-slate-500">
          Terbit
        </p>
      </div>
      <div
        class="rounded-xl px-2 py-2 text-center"
        :class="belumCount > 0 ? 'bg-red-50' : 'bg-slate-50'"
      >
        <p
          class="text-lg font-black leading-none tabular-nums"
          :class="belumCount > 0 ? 'text-red-700' : 'text-slate-400'"
        >
          {{ belumCount }}
        </p>
        <p class="text-[8.5px] font-bold uppercase tracking-widest mt-1 text-slate-500">
          Belum
        </p>
      </div>
    </div>

    <!-- PROGRESS BAR -->
    <div class="flex items-center gap-2 mt-3">
      <div
        class="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden"
        :aria-label="`Selesai ${completionPct} persen`"
      >
        <div class="h-full transition-all" :style="progressStyle" />
      </div>
      <span
        class="text-[10.5px] font-black tabular-nums"
        :class="
          completionPct >= 100
            ? 'text-emerald-700'
            : completionPct >= 60
              ? 'text-brand-cobalt'
              : completionPct > 0
                ? 'text-amber-700'
                : 'text-slate-400'
        "
      >
        {{ completionPct }}%
      </span>
      <span class="text-[10px] text-slate-400 tabular-nums">
        ({{ cls.published_count }}/{{ cls.student_count }})
      </span>
    </div>
  </article>
</template>

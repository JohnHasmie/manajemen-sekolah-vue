<!--
  RecommendationClassCard.vue — class hub card (Frame A).

  Web port of `lib/features/recommendations/presentation/widgets/
  recommendation_class_card.dart`. One card per class with a 4-cell
  stats grid + gradient progress bar + dual CTA (Lihat Student / Buat
  Baru). Used by both the Mengajar and Homeroom Teacher modes of the
  recommendations hub — `isHomeroom` swaps the kicker style.

  Layout, top to bottom:
    ┌─────────────────────────────────────────────┐
    │ [▤] VII A · WALI                            │
    │     Kelas VII A · Matematika                │
    │                                             │
    │ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐             │
    │ │  3  │ │  1  │ │  8  │ │  0  │             │
    │ │PEND │ │PRO  │ │SEL  │ │DIT  │             │
    │ └─────┘ └─────┘ └─────┘ └─────┘             │
    │                                             │
    │ ▰▰▰▰▰▰▰▱▱▱  60%                            │
    │                                             │
    │ [ Lihat Student ]      [ ✨ Buat Baru ]       │
    └─────────────────────────────────────────────┘

  Progress bar tone:
    - 0%        → slate
    - 1-39%     → amber
    - 40-79%    → cobalt → azure gradient
    - 80-100%   → emerald (success)
-->
<script setup lang="ts">
import { computed } from 'vue';
import type {
  RecommendationClassSummary,
  RecStatus,
} from '@/types/recommendations';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';

interface ClassMeta {
  id: string;
  name: string;
  /** Optional — when present, drives the "n student" sub-meta. */
  student_count?: number;
  /** Optional — when present (Mengajar mode), shown next to class name. */
  subject_name?: string | null;
}

const props = withDefaults(
  defineProps<{
    /** The class this card represents. */
    cls: ClassMeta;
    /** Summary from `RecommendationService.getClassSummary()`. */
    summary?: RecommendationClassSummary | null;
    /** Loading skeleton while summary fetch is in flight. */
    isLoading?: boolean;
    /** Show the violet AI spinner on the Buat Baru button. */
    isGenerating?: boolean;
    /** Parent-kelas scope → kicker says "VII A · WALI" + book icon. */
    isHomeroom?: boolean;
  }>(),
  {
    summary: null,
    isLoading: false,
    isGenerating: false,
    isHomeroom: false,
  },
);

const emit = defineEmits<{
  /** Tap card or "Lihat Student" → student list. */
  viewStudents: [cls: ClassMeta];
  /** Tap "Buat Baru" → generate sheet. */
  generate: [cls: ClassMeta];
}>();

// ── Derived ──
const stats = computed(() => {
  const by = props.summary?.by_status ?? {};
  const pending = Number((by as Record<RecStatus, number>).pending ?? 0);
  const inProgress = Number(
    (by as Record<RecStatus, number>).in_progress ?? 0,
  );
  const completed = Number((by as Record<RecStatus, number>).completed ?? 0);
  const dismissed = Number((by as Record<RecStatus, number>).dismissed ?? 0);
  const total = pending + inProgress + completed + dismissed;
  return { pending, in_progress: inProgress, completed, dismissed, total };
});

const completionPct = computed(() => {
  const s = stats.value;
  if (s.total === 0) return 0;
  return Math.round((s.completed / s.total) * 100);
});

const progressBarStyle = computed(() => {
  const pct = completionPct.value;
  if (pct === 0) {
    return {
      width: '0%',
      background: 'rgb(148 163 184)', // slate-400 — visible at 0% as a hair
    };
  }
  if (pct >= 80) {
    return {
      width: `${pct}%`,
      background: 'linear-gradient(90deg, #10B981 0%, #059669 100%)',
    };
  }
  if (pct >= 40) {
    return {
      width: `${pct}%`,
      background: 'linear-gradient(90deg, #1B6FB8 0%, #1A8FBE 100%)',
    };
  }
  return {
    width: `${pct}%`,
    background: 'linear-gradient(90deg, #F59E0B 0%, #D97706 100%)',
  };
});

const kicker = computed(() => {
  if (props.isHomeroom) return `${props.cls.name.toUpperCase()} · WALI`;
  if (props.cls.subject_name) {
    return `${props.cls.name.toUpperCase()} · MENGAJAR`;
  }
  return `${props.cls.name.toUpperCase()} · KELAS`;
});

const subtitle = computed(() => {
  const subj = props.cls.subject_name?.trim();
  if (props.isHomeroom) return `Kelas ${props.cls.name}`;
  return subj ? `Kelas ${props.cls.name} · ${subj}` : `Kelas ${props.cls.name}`;
});

const hasActivity = computed(() => stats.value.total > 0);
</script>

<template>
  <article
    class="bg-white border border-slate-200 rounded-2xl p-3.5 hover:border-brand-cobalt/30 hover:shadow-sm transition-all cursor-pointer"
    @click="emit('viewStudents', cls)"
  >
    <!-- HEADER ROW -->
    <div class="flex items-center gap-3">
      <span
        class="w-11 h-11 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0"
      >
        <NavIcon
          :name="isHomeroom ? 'book' : 'sparkles'"
          :size="18"
        />
      </span>
      <div class="flex-1 min-w-0">
        <p class="text-[9.5px] font-black text-brand-cobalt uppercase tracking-widest leading-none">
          {{ kicker }}
        </p>
        <p class="text-[14px] font-black text-slate-900 mt-1 leading-tight truncate">
          {{ subtitle }}
        </p>
        <p
          v-if="cls.student_count !== undefined"
          class="text-2xs text-slate-500 mt-0.5"
        >
          {{ cls.student_count }} siswa
        </p>
      </div>
      <NavIcon
        name="chevron-right"
        :size="14"
        class="text-slate-400 flex-shrink-0"
      />
    </div>

    <!-- 4-CELL STATS GRID -->
    <div class="grid grid-cols-4 gap-2 mt-3">
      <!-- Pending — amber -->
      <div
        class="rounded-xl px-2 py-2 text-center"
        :class="
          isLoading
            ? 'bg-slate-50'
            : stats.pending > 0
              ? 'bg-amber-50'
              : 'bg-slate-50'
        "
      >
        <p
          class="text-lg font-black leading-none tabular-nums"
          :class="
            isLoading
              ? 'text-slate-300'
              : stats.pending > 0
                ? 'text-amber-700'
                : 'text-slate-400'
          "
        >
          {{ isLoading ? '—' : stats.pending }}
        </p>
        <p class="text-[8.5px] font-bold uppercase tracking-widest mt-1 text-slate-500">
          Pending
        </p>
      </div>
      <!-- In progress — cobalt -->
      <div
        class="rounded-xl px-2 py-2 text-center"
        :class="
          isLoading
            ? 'bg-slate-50'
            : stats.in_progress > 0
              ? 'bg-brand-cobalt/10'
              : 'bg-slate-50'
        "
      >
        <p
          class="text-lg font-black leading-none tabular-nums"
          :class="
            isLoading
              ? 'text-slate-300'
              : stats.in_progress > 0
                ? 'text-brand-cobalt'
                : 'text-slate-400'
          "
        >
          {{ isLoading ? '—' : stats.in_progress }}
        </p>
        <p class="text-[8.5px] font-bold uppercase tracking-widest mt-1 text-slate-500">
          Proses
        </p>
      </div>
      <!-- Completed — emerald -->
      <div
        class="rounded-xl px-2 py-2 text-center"
        :class="
          isLoading
            ? 'bg-slate-50'
            : stats.completed > 0
              ? 'bg-emerald-50'
              : 'bg-slate-50'
        "
      >
        <p
          class="text-lg font-black leading-none tabular-nums"
          :class="
            isLoading
              ? 'text-slate-300'
              : stats.completed > 0
                ? 'text-emerald-700'
                : 'text-slate-400'
          "
        >
          {{ isLoading ? '—' : stats.completed }}
        </p>
        <p class="text-[8.5px] font-bold uppercase tracking-widest mt-1 text-slate-500">
          Selesai
        </p>
      </div>
      <!-- Dismissed — slate -->
      <div
        class="rounded-xl px-2 py-2 text-center"
        :class="
          isLoading
            ? 'bg-slate-50'
            : stats.dismissed > 0
              ? 'bg-slate-100'
              : 'bg-slate-50'
        "
      >
        <p
          class="text-lg font-black leading-none tabular-nums"
          :class="
            isLoading
              ? 'text-slate-300'
              : stats.dismissed > 0
                ? 'text-slate-700'
                : 'text-slate-400'
          "
        >
          {{ isLoading ? '—' : stats.dismissed }}
        </p>
        <p class="text-[8.5px] font-bold uppercase tracking-widest mt-1 text-slate-500">
          Ditolak
        </p>
      </div>
    </div>

    <!-- PROGRESS BAR -->
    <div class="flex items-center gap-2 mt-3">
      <div
        class="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden"
        :aria-label="`Progress ${completionPct} persen`"
      >
        <div class="h-full transition-all" :style="progressBarStyle" />
      </div>
      <span
        class="text-[10.5px] font-black tabular-nums"
        :class="
          completionPct >= 80
            ? 'text-emerald-700'
            : completionPct >= 40
              ? 'text-brand-cobalt'
              : completionPct > 0
                ? 'text-amber-700'
                : 'text-slate-400'
        "
      >
        {{ completionPct }}%
      </span>
    </div>

    <!-- DUAL CTA -->
    <div class="grid grid-cols-2 gap-2 mt-3">
      <Button
        variant="secondary"
        size="sm"
        block
        @click.stop="emit('viewStudents', cls)"
      >
        <NavIcon name="users" :size="13" />
        Lihat Siswa
      </Button>
      <button
        type="button"
        class="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl text-[11.5px] font-bold transition-all"
        :class="[
          hasActivity
            ? 'bg-violet-600 text-white hover:bg-violet-700 shadow-sm'
            : 'bg-white text-violet-700 border-2 border-dashed border-violet-300 hover:bg-violet-50',
          isGenerating ? 'opacity-60 cursor-wait' : '',
        ]"
        :disabled="isGenerating"
        @click.stop="emit('generate', cls)"
      >
        <NavIcon
          :name="isGenerating ? 'loader' : 'sparkles'"
          :size="13"
          :class="isGenerating ? 'animate-spin' : ''"
        />
        {{ isGenerating ? 'Memproses…' : hasActivity ? 'Buat Baru' : 'Generate AI' }}
      </button>
    </div>
  </article>
</template>

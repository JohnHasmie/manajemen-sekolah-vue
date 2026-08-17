<!--
  SubjectGradeDetailModal.vue — drill-in modal for one subject's
  grade breakdown.

  Used by ParentGradeView (per-subject row click → show all
  assessments for that subject with their individual scores +
  KKM hint). Mirrors Flutter's `showGradeDetail` per-subject sheet.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { ParentGradeRow } from '@/types/parent';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    row: ParentGradeRow;
    /** Optional child label rendered in the meta strip ("9A · Ahmad"). */
    childLabel?: string;
    /** Semester label ("Semester 1 (Ganjil)"). */
    semesterLabel?: string;
  }>(),
  { childLabel: '', semesterLabel: '' },
);

defineEmits<{ close: [] }>();

const totalEntries = computed(() => props.row.scores.length);
const entriesWithScore = computed(
  () => props.row.scores.filter((s) => typeof s.score === 'number').length,
);
// The KKM is optional: a school may never have set a passing threshold for
// this subject. Without one there is nothing to count above or below, and no
// tuntas/remedial verdict to state — so these all go null rather than being
// measured against an invented 75.
const kkm = computed<number | null>(() => props.row.kkm);

const aboveKkm = computed<number | null>(() => {
  const k = kkm.value;
  if (k == null) return null;
  return props.row.scores.filter(
    (s) => typeof s.score === 'number' && (s.score as number) >= k,
  ).length;
});
const belowKkm = computed<number | null>(() => {
  const k = kkm.value;
  if (k == null) return null;
  return props.row.scores.filter(
    (s) => typeof s.score === 'number' && (s.score as number) < k,
  ).length;
});

/** How far the average sits below the KKM — null unless both are known. */
const gapBelowKkm = computed<string | null>(() => {
  const k = kkm.value;
  if (k == null || props.row.average == null) return null;
  return (k - props.row.average).toFixed(1);
});

/** true / false only when both the average and the KKM are known. */
const isTuntas = computed<boolean | null>(() => {
  const k = kkm.value;
  if (k == null || props.row.average == null) return null;
  return props.row.average >= k;
});

/** Letter grade derived from score ≥85/75/65/55. */
function letterFor(score: number | null | undefined): string {
  if (typeof score !== 'number') return '—';
  if (score >= 85) return 'A';
  if (score >= 75) return 'B';
  if (score >= 65) return 'C';
  if (score >= 55) return 'D';
  return 'E';
}

function scoreTone(score: number | null | undefined): {
  bg: string;
  text: string;
  border: string;
} {
  const k = props.row.kkm;
  if (typeof score !== 'number' || k == null)
    return { bg: 'bg-slate-50', text: 'text-slate-400', border: 'border-slate-200' };
  if (score >= k)
    return {
      bg: 'bg-emerald-50',
      text: 'text-emerald-700',
      border: 'border-emerald-200',
    };
  return { bg: 'bg-red-50', text: 'text-red-700', border: 'border-red-200' };
}

const headerTone = computed(() => {
  if (props.row.average === null) return scoreTone(null);
  return scoreTone(props.row.average);
});
</script>

<template>
  <Modal title="" @close="$emit('close')">
    <!-- Header -->
    <header class="-mt-2 mb-4 flex items-start gap-3">
      <div
        class="w-12 h-12 rounded-2xl grid place-items-center text-lg font-black flex-shrink-0 border"
        :class="[headerTone.bg, headerTone.text, headerTone.border]"
      >
        {{ letterFor(row.average) }}
      </div>
      <div class="flex-1 min-w-0">
        <p
          class="text-3xs font-bold text-brand-cobalt uppercase tracking-widest"
        >
          Detail Nilai
          <span v-if="semesterLabel"> · {{ semesterLabel }}</span>
        </p>
        <h2 class="text-base font-black text-slate-900 leading-tight mt-0.5">
          {{ row.subject_name }}
        </h2>
        <p class="text-2xs text-slate-500 mt-0.5">
          {{ childLabel ? childLabel + ' · ' : '' }}
          <template v-if="row.kkm != null">KKM {{ row.kkm }} · </template>
          {{ entriesWithScore }} dari {{ totalEntries }} asesmen dinilai
        </p>
      </div>
    </header>

    <!-- KPI strip -->
    <div class="grid grid-cols-3 gap-2 mb-3">
      <div class="bg-slate-50 rounded-xl p-3 text-center">
        <p class="text-4xs font-bold text-slate-500 uppercase tracking-widest">
          Rata-rata
        </p>
        <p
          class="text-lg font-black mt-1"
          :class="{
            'text-emerald-700': isTuntas === true,
            'text-red-700': isTuntas === false,
            'text-slate-400': isTuntas === null,
          }"
        >
          {{ row.average ?? '—' }}
        </p>
      </div>
      <template v-if="row.kkm != null">
        <div class="bg-emerald-50 rounded-xl p-3 text-center">
          <p class="text-4xs font-bold text-emerald-700 uppercase tracking-widest">
            Di atas KKM
          </p>
          <p class="text-lg font-black text-emerald-700 mt-1">{{ aboveKkm }}</p>
        </div>
        <div class="bg-red-50 rounded-xl p-3 text-center">
          <p class="text-4xs font-bold text-red-700 uppercase tracking-widest">
            Di bawah KKM
          </p>
          <p class="text-lg font-black text-red-700 mt-1">{{ belowKkm }}</p>
        </div>
      </template>
      <div v-else class="col-span-2 bg-slate-50 rounded-xl p-3 text-center">
        <p class="text-4xs font-bold text-slate-500 uppercase tracking-widest">
          Ketuntasan
        </p>
        <p class="text-2xs font-bold text-slate-500 mt-1.5">
          KKM belum diatur sekolah
        </p>
      </div>
    </div>

    <!-- Status banner -->
    <div
      class="flex items-center gap-2 px-3 py-2 rounded-lg text-2xs font-bold mb-3"
      :class="{
        'bg-emerald-50 text-emerald-700 border border-emerald-100':
          isTuntas === true,
        'bg-red-50 text-red-700 border border-red-100': isTuntas === false,
        'bg-slate-50 text-slate-500 border border-dashed border-slate-200':
          isTuntas === null,
      }"
    >
      <NavIcon :name="isTuntas === true ? 'check-circle' : 'bell'" :size="13" />
      <span v-if="row.average === null">Belum ada nilai untuk semester ini.</span>
      <span v-else-if="isTuntas === null">
        Sudah dinilai — sekolah belum menetapkan KKM untuk mata pelajaran ini.
      </span>
      <span v-else-if="isTuntas">
        Tuntas — di atas KKM {{ row.kkm }}.
      </span>
      <span v-else>
        Remedial — rata-rata {{ gapBelowKkm }} poin di bawah KKM.
      </span>
    </div>

    <!-- Assessment list -->
    <section>
      <p
        class="text-2xs font-bold text-slate-500 uppercase tracking-widest mb-2"
      >
        Daftar Asesmen
      </p>
      <div
        v-if="totalEntries === 0"
        class="py-8 text-center text-sm text-slate-400"
      >
        Belum ada asesmen untuk mata pelajaran ini.
      </div>
      <ul v-else class="space-y-1.5 max-h-[40vh] overflow-y-auto pr-1">
        <li
          v-for="(s, idx) in row.scores"
          :key="idx"
          class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl px-3 py-2.5"
        >
          <div class="flex-1 min-w-0">
            <p class="text-[12.5px] font-bold text-slate-900 truncate">
              {{ s.assessment || `Asesmen ${idx + 1}` }}
            </p>
            <p
              v-if="row.kkm != null"
              class="text-[10.5px] text-slate-400 mt-0.5"
            >
              KKM {{ row.kkm }}
            </p>
          </div>
          <span
            class="inline-flex items-center justify-center min-w-[44px] px-2.5 py-1 rounded-lg text-[12px] font-black border"
            :class="[
              scoreTone(s.score).bg,
              scoreTone(s.score).text,
              scoreTone(s.score).border,
            ]"
          >
            {{ s.score ?? '—' }}
          </span>
        </li>
      </ul>
    </section>

    <!-- Footer -->
    <footer
      class="mt-4 pt-3 border-t border-slate-100 flex items-center justify-end"
    >
      <Button variant="secondary" size="sm" @click="$emit('close')">Tutup</Button>
    </footer>
  </Modal>
</template>

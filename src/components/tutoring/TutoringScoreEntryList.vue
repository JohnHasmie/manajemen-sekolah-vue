<!--
  TutoringScoreEntryList.vue — single-assessment score input for the
  bimbel grade surface.

  Analogue of the school-side `TeacherGradeMatrixView` inline matrix,
  but flattened: bimbel scores ONE assessment at a time (not the full
  student×assessment grid). Keyed by `enrollment_id` — bimbel scores
  FK to `bimbel_enrollments`, not `student_classes`.

  Validation semantics mirror TeacherGradeMatrixView.updateCell:
    - accept numbers in [0, maxScore];
    - reject NaN + out-of-range;
    - `dirty=true` on any accepted change;
    - null (empty input) clears.

  Emits `update:score` per keystroke and `saveDirty` for the sticky
  bar — parent debounces via useDataRefresh / a manual timer.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { TutoringScoreRow } from '@/types/tutoring-bimbel';

const props = withDefaults(
  defineProps<{
    assessmentId: string;
    rows: TutoringScoreRow[];
    maxScore?: number;
    kkm?: number | null;
    loading?: boolean;
    saving?: boolean;
  }>(),
  { maxScore: 100, kkm: null, loading: false, saving: false },
);

const emit = defineEmits<{
  'update:score': [{ enrollment_id: string; score: number | null }];
  saveDirty: [TutoringScoreRow[]];
}>();

const dirtyCount = computed(() => props.rows.filter((r) => r.dirty).length);

function onInput(row: TutoringScoreRow, raw: string) {
  const trimmed = raw.trim();
  if (trimmed === '') {
    emit('update:score', { enrollment_id: row.enrollment_id, score: null });
    return;
  }
  const parsed = Number(trimmed);
  if (Number.isNaN(parsed) || parsed < 0 || parsed > props.maxScore) {
    // Silently drop invalid input — the input's own value stays as
    // the last valid one because parent controls the row array.
    return;
  }
  emit('update:score', { enrollment_id: row.enrollment_id, score: parsed });
}

function belowKkm(row: TutoringScoreRow): boolean {
  if (props.kkm == null || row.score == null) return false;
  return row.score < props.kkm;
}
</script>

<template>
  <section
    class="rounded-card border-0.5 border-tutoring-border-soft bg-tutoring-panel"
    :aria-busy="loading || saving"
  >
    <header class="flex items-baseline justify-between border-b-0.5 border-tutoring-border-soft px-4 py-3">
      <div>
        <p class="text-sm font-bold text-tutoring-text-hi">Nilai · {{ rows.length }} siswa</p>
        <p v-if="kkm != null" class="text-2xs text-tutoring-text-mid">KKM {{ kkm }} · maksimum {{ maxScore }}</p>
        <p v-else class="text-2xs text-tutoring-text-mid">Maksimum {{ maxScore }}</p>
      </div>
    </header>

    <ul class="divide-y-0.5 divide-tutoring-border-soft" role="list">
      <li
        v-for="row in rows"
        :key="row.enrollment_id"
        class="flex items-center gap-3 px-4 py-3"
      >
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-bold text-tutoring-text-hi">{{ row.student_name }}</p>
          <p v-if="row.student_number" class="text-2xs text-tutoring-text-mid">NIS {{ row.student_number }}</p>
        </div>
        <input
          type="number"
          inputmode="numeric"
          :min="0"
          :max="maxScore"
          step="0.5"
          :aria-label="`Skor untuk ${row.student_name}`"
          :value="row.score ?? ''"
          class="w-20 rounded-lg border-0.5 px-2 py-1.5 text-center text-sm font-bold transition focus:outline-none focus:ring-2 focus:ring-[#21afe6]/60"
          :class="[
            row.dirty ? 'ring-2 ring-warning/60' : '',
            belowKkm(row)
              ? 'border-danger bg-danger-soft text-danger'
              : 'border-tutoring-border-soft bg-tutoring-panel text-tutoring-text-hi',
          ]"
          :disabled="loading || saving"
          @input="(e) => onInput(row, (e.target as HTMLInputElement).value)"
        >
      </li>
    </ul>

    <footer
      v-if="dirtyCount > 0"
      class="flex items-center justify-between border-t-0.5 border-warning/40 bg-warning-soft px-4 py-3"
      role="status"
    >
      <span class="text-xs font-bold text-warning">
        {{ dirtyCount }} sel belum disimpan
      </span>
      <button
        type="button"
        class="rounded-lg bg-[#21afe6] px-4 py-1.5 text-sm font-bold text-white transition hover:bg-[#1a8fbe] disabled:opacity-60"
        :disabled="loading || saving"
        @click="emit('saveDirty', rows.filter((r) => r.dirty))"
      >{{ saving ? 'Menyimpan…' : 'Simpan' }}</button>
    </footer>
  </section>
</template>

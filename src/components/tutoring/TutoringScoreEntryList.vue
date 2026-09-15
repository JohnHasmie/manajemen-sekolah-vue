<!--
  TutoringScoreEntryList.vue — single-assessment score input for the
  bimbel grade surface.

  Analogue of the school-side `TeacherGradeMatrixView` inline matrix,
  but flattened: bimbel scores ONE assessment at a time (not the full
  student×assessment grid). Keyed by `enrollment_id` — bimbel scores
  FK to `bimbel_enrollments`, not `student_classes`.

  ── `props.rows` is the SERVER TRUTH; edits live in `draft` ──────────

  The prop array is never mutated. It is the snapshot of what the
  backend last told us, and it is what every "did this actually
  change?" question is answered against:

    - Save is enabled only while some draft score DIFFERS from its
      saved counterpart. Re-typing 80 over a saved 80 changes nothing,
      and typing 81 then back to 80 leaves nothing to save — neither is
      expressible with a dirty flag that only ever flips on.
    - A row is marked "sudah dinilai" from its SAVED score, not from
      whatever is currently in the box. Keying the badge off the live
      value would make it appear the instant a tutor started typing
      into a never-scored row, which is a claim the server has not
      agreed to yet.

  Same working-copy shape as `ActivitySubmissionPickerModal`, which
  diffs its own draft against `props.rows` for the same reason.

  ── Editing stays unrestricted ──────────────────────────────────────

  An already-scored row is directly editable — no Edit button, no
  confirm step. The endpoint is an upsert and a correction should cost
  one keystroke. What this component adds is the AFFORDANCE the screen
  was missing (scored marker, last-changed time, a Save control that
  says whether it has anything to do), not a lock.

  Validation semantics mirror TeacherGradeMatrixView.updateCell:
    - accept numbers in [0, maxScore];
    - reject NaN + out-of-range;
    - null (empty input) clears.

  Emits `saveDirty` with ONLY the changed rows — the parent POSTs that
  array verbatim, so a row the tutor never touched is never restamped
  server-side.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatDateTime } from '@/lib/format';
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
  saveDirty: [TutoringScoreRow[]];
}>();

const { t } = useI18n();

/**
 * Local working copy. Reset whenever the parent hands over a new array
 * — which happens after every successful save, because the view
 * reloads and the server's rows (with their refreshed `marked_at`)
 * become the new baseline.
 */
const draft = ref<TutoringScoreRow[]>([]);

watch(
  () => props.rows,
  (next) => {
    draft.value = next.map((r) => ({ ...r }));
  },
  { immediate: true },
);

/** Saved state by enrollment — the baseline every comparison uses. */
const savedByEnrollment = computed(
  () => new Map(props.rows.map((r) => [r.enrollment_id, r])),
);

function savedOf(row: TutoringScoreRow): TutoringScoreRow | undefined {
  return savedByEnrollment.value.get(row.enrollment_id);
}

/**
 * Changed relative to what the server gave us. A row with no saved
 * counterpart counts as changed — it can only have come from a draft
 * the backend has never seen.
 */
function isDirty(row: TutoringScoreRow): boolean {
  const saved = savedOf(row);
  if (!saved) return true;
  return (saved.score ?? null) !== (row.score ?? null);
}

const dirtyRows = computed(() => draft.value.filter(isDirty));
const dirtyCount = computed(() => dirtyRows.value.length);

/** Scored ON THE SERVER — never "the tutor is mid-keystroke". */
function isScored(row: TutoringScoreRow): boolean {
  return savedOf(row)?.score != null;
}

/**
 * When this mark was last submitted, in the reader's LOCAL zone.
 *
 * `marked_at` (not `updated_at`) is the field that means "a tutor last
 * submitted this": `UpsertScoresAction` writes `'marked_at' => now()`
 * inside the values array of `updateOrCreate`, so it is restamped on
 * re-mark as well as on first mark. `updated_at` is a generic row-touch
 * stamp that the demo seeder and the v1→v2 backfill move on their own.
 *
 * Formatted through `lib/format`'s `formatDateTime` — the repo's single
 * locale-aware instant formatter (Intl, no `timeZone` override, so it
 * resolves in the browser's zone). Never `toISOString()` slicing, which
 * would render a WIB 08:00 mark as the previous day's 01:00.
 */
function lastChangedLabel(row: TutoringScoreRow): string {
  const at = savedOf(row)?.marked_at;
  return at ? formatDateTime(at) : '';
}

function belowKkm(row: TutoringScoreRow): boolean {
  if (props.kkm == null || row.score == null) return false;
  return row.score < props.kkm;
}

function onInput(row: TutoringScoreRow, raw: string) {
  const idx = draft.value.findIndex((r) => r.enrollment_id === row.enrollment_id);
  if (idx < 0) return;
  const trimmed = raw.trim();
  if (trimmed === '') {
    draft.value[idx] = { ...draft.value[idx], score: null };
    return;
  }
  const parsed = Number(trimmed);
  if (Number.isNaN(parsed) || parsed < 0 || parsed > props.maxScore) {
    // Silently drop invalid input — the draft keeps its last valid
    // value, so nothing downstream ever sees an out-of-range score.
    return;
  }
  draft.value[idx] = { ...draft.value[idx], score: parsed };
}
</script>

<template>
  <section
    class="rounded-card border-0.5 border-tutoring-border-soft bg-tutoring-panel"
    :aria-busy="loading || saving"
  >
    <header class="flex items-baseline justify-between border-b-0.5 border-tutoring-border-soft px-4 py-3">
      <div>
        <p class="text-sm font-bold text-tutoring-text-hi">
          {{ t('tutoring2.scoreEntry.listTitle', { count: draft.length }) }}
        </p>
        <p v-if="kkm != null" class="text-2xs text-tutoring-text-mid">
          {{ t('tutoring2.scoreEntry.kkmLine', { kkm, max: maxScore }) }}
        </p>
        <p v-else class="text-2xs text-tutoring-text-mid">
          {{ t('tutoring2.scoreEntry.maxLine', { max: maxScore }) }}
        </p>
      </div>
    </header>

    <ul class="divide-y-0.5 divide-tutoring-border-soft" role="list">
      <li
        v-for="row in draft"
        :key="row.enrollment_id"
        class="flex items-center gap-3 px-4 py-3"
        :data-testid="`score-row-${row.enrollment_id}`"
      >
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-bold text-tutoring-text-hi">{{ row.student_name }}</p>
          <p v-if="row.student_number" class="text-2xs text-tutoring-text-mid">
            {{ t('tutoring2.scoreEntry.nis', { number: row.student_number }) }}
          </p>

          <!-- The affordance the screen was missing: this row already
               carries a mark, and here is when it was last set. -->
          <p
            v-if="isScored(row)"
            class="mt-1 flex flex-wrap items-center gap-1.5"
            :data-testid="`score-marked-${row.enrollment_id}`"
          >
            <span
              class="rounded-full bg-success-soft px-1.5 py-0.5 text-2xs font-bold text-success"
              :data-testid="`score-badge-${row.enrollment_id}`"
            >{{ t('tutoring2.scoreEntry.scoredBadge') }}</span>
            <span
              v-if="lastChangedLabel(row)"
              class="text-2xs text-tutoring-text-mid"
              :data-testid="`score-time-${row.enrollment_id}`"
            >{{ t('tutoring2.scoreEntry.lastChanged', { at: lastChangedLabel(row) }) }}</span>
          </p>
        </div>
        <input
          type="number"
          inputmode="numeric"
          :min="0"
          :max="maxScore"
          step="0.5"
          :aria-label="t('tutoring2.scoreEntry.inputLabel', { name: row.student_name })"
          :value="row.score ?? ''"
          :data-testid="`score-input-${row.enrollment_id}`"
          class="w-20 rounded-lg border-0.5 px-2 py-1.5 text-center text-sm font-bold transition focus:outline-none focus:ring-2 focus:ring-[#21afe6]/60"
          :class="[
            isDirty(row) ? 'ring-2 ring-warning/60' : '',
            belowKkm(row)
              ? 'border-danger bg-danger-soft text-danger'
              : 'border-tutoring-border-soft bg-tutoring-panel text-tutoring-text-hi',
          ]"
          :disabled="loading || saving"
          @input="(e) => onInput(row, (e.target as HTMLInputElement).value)"
        >
      </li>
    </ul>

    <!-- Always rendered. A save bar that disappears when there is
         nothing to save tells the tutor nothing; one that is visibly
         disabled says "your edits are already stored". -->
    <footer
      class="flex items-center justify-between border-t-0.5 px-4 py-3"
      :class="
        dirtyCount > 0
          ? 'border-warning/40 bg-warning-soft'
          : 'border-tutoring-border-soft bg-tutoring-panel'
      "
      role="status"
      data-testid="score-save-bar"
    >
      <span
        v-if="dirtyCount > 0"
        class="text-xs font-bold text-warning"
        data-testid="score-dirty-label"
      >{{ t('tutoring2.scoreEntry.pendingChanges', { count: dirtyCount }) }}</span>
      <span
        v-else
        class="text-xs text-tutoring-text-mid"
        data-testid="score-clean-label"
      >{{ t('tutoring2.scoreEntry.noChanges') }}</span>
      <button
        type="button"
        class="rounded-lg bg-[#21afe6] px-4 py-1.5 text-sm font-bold text-white transition hover:bg-[#1a8fbe] disabled:opacity-60"
        :disabled="loading || saving || dirtyCount === 0"
        data-testid="score-save"
        @click="emit('saveDirty', dirtyRows)"
      >{{ saving ? t('tutoring2.scoreEntry.saving') : t('tutoring2.scoreEntry.save') }}</button>
    </footer>
  </section>
</template>

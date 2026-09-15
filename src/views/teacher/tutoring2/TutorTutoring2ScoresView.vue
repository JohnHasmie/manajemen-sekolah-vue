<!--
  TutorTutoring2ScoresView.vue — Input skor per asesmen (WEB-4).

  Wraps the WEB-2 `TutoringScoreEntryList` component end-to-end: loads
  the assessment's score rows from the greenfield backend and saves the
  changed ones via bulk-upsert.

  `rows` here is the SERVER's answer, verbatim. The in-progress edits
  live in the component's own draft, which diffs against this array —
  so "has anything changed?" is a comparison against what was loaded,
  never a flag that flipped when a key was pressed.

  ── "Kenapa tidak ada edit skor?" ───────────────────────────────────

  There was never anything to add: the input is not locked once a score
  exists and the endpoint is an upsert, so a correction has always been
  one keystroke. What was missing was any sign of it — nothing said a
  row had been scored, when it was last changed, or whether Save had
  work to do. That is what the entry list now renders. The fix was an
  affordance, not a new capability, and deliberately NOT an Edit button
  (which would have added a step to a correction that needs none).

  Route: /teacher/tutoring2/assessments/:id/scores where `id` is the
  assessment id.

  The ceiling and the pass mark are real. This view used to hardcode
  `maxScore = 100` and `kkm = 75`, so an assessment worth 50 showed a
  passing 45 as "45 / 100", and every row was coloured against a
  threshold nobody had set. Both now come from
  `GET /tutoring-v2/assessments/:id`, fetched alongside the rows.

  `kkm` stays nullable end to end — `TutoringScoreEntryList` skips the
  pass/fail colouring when it is null, which is the honest answer for
  an assessment with no threshold.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import TutoringScoreEntryList from '@/components/tutoring/TutoringScoreEntryList.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { TutoringBimbelService, type BimbelAssessment } from '@/services/tutoring-bimbel.service';
import type { TutoringScoreRow } from '@/types/tutoring-bimbel';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

const assessmentId = ref<string>((route.params.id as string) ?? '');
if (!assessmentId.value) {
  router.replace({ name: 'teacher.tutoring2.assessments' });
}

const rows = ref<TutoringScoreRow[]>([]);
const saving = ref(false);
const assessment = ref<BimbelAssessment | null>(null);

// Null until the assessment loads. The component treats a null kkm as
// "no threshold", and maxScore falls back only for the frame before
// the fetch settles — never as a standing value.
const maxScore = computed(() => assessment.value?.max_score ?? null);
const kkm = computed(() => assessment.value?.kkm ?? null);

const { state, reload } = useDataRefresh(async () => {
  // Both at once: the rows are meaningless without the ceiling they
  // are measured against, and the ceiling is a single row.
  const [scores, meta] = await Promise.all([
    TutoringBimbelService.listScores(assessmentId.value),
    TutoringBimbelService.getAssessment(assessmentId.value),
  ]);
  assessment.value = meta;
  return scores.items;
});

watch(state, (s) => {
  if (s.status === 'content' || s.status === 'empty') {
    // Straight from the server, unannotated. These rows ARE the
    // baseline `TutoringScoreEntryList` diffs its draft against, so
    // anything we stamped on here would be compared against itself.
    rows.value = (s as { status: string; data?: TutoringScoreRow[] }).data ?? [];
  }
});

async function onSaveDirty(dirtyRows: TutoringScoreRow[]) {
  if (saving.value || dirtyRows.length === 0) return;
  saving.value = true;
  const count = dirtyRows.length;
  try {
    await TutoringBimbelService.upsertScores(
      assessmentId.value,
      dirtyRows.map((r) => ({
        enrollment_id: r.enrollment_id,
        score: r.score,
        notes: r.notes ?? null,
      })),
    );
    toast.success(t('tutoring2.tutor.scores.saved', { count }));
    // Refetch rather than merge the POST response: the upsert reply is
    // built from `$row->fresh()` with no eager-loaded enrollment, so
    // `ScoreResource` omits student_id/student_name/student_number
    // entirely. Spreading it over the list would blank every name. The
    // reload is also what brings back the refreshed `marked_at` the row
    // badges render.
    reload();
  } catch (e) {
    toast.error(t('tutoring2.tutor.scores.saveFailed', { msg: (e as Error).message }));
  } finally {
    saving.value = false;
  }
}

function goBack() {
  router.push({ name: 'teacher.tutoring2.assessments' });
}

const metaLabel = computed(() =>
  t('tutoring2.tutor.scores.meta', { count: rows.value.length }),
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.scores.title')"
      :meta="metaLabel"
    />

    <Button variant="ghost" size="sm" @click="goBack">← {{ t('tutoring2.common.back') }}</Button>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="6"
      :empty-title="t('tutoring2.tutor.scores.emptyTitle')"
      empty-description="Asesmen ini belum memiliki peserta yang bisa diberi skor."
      @retry="reload"
    >
      <!-- TODO i18n key: empty-description "Asesmen ini belum memiliki peserta yang bisa diberi skor." -->
      <template #default>
        <!-- The assessment resolves in the same Promise.all as the
             rows, so it is always loaded by the time this slot runs.
             The guard makes that explicit rather than papering over a
             null max with a fabricated 0. -->
        <TutoringScoreEntryList
          v-if="maxScore != null"
          :assessment-id="assessmentId"
          :rows="rows"
          :max-score="maxScore"
          :kkm="kkm"
          :loading="state.status === 'loading'"
          :saving="saving"
          @save-dirty="onSaveDirty"
        />
      </template>
    </AsyncView>
  </div>
</template>

<!--
  TutorTutoring2ScoresView.vue — Input skor per asesmen (WEB-4).

  Wraps the WEB-2 `TutoringScoreEntryList` component end-to-end: loads
  the assessment's score rows from the greenfield backend, holds the
  row list locally for optimistic updates with a dirty flag, saves
  dirty rows via bulk-upsert.

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
    const data = (s as { status: string; data?: TutoringScoreRow[] }).data ?? [];
    // Reset dirty flags on reload — server state is now the truth.
    rows.value = data.map((r) => ({ ...r, dirty: false }));
  }
});

function onUpdateScore(payload: { enrollment_id: string; score: number | null }) {
  const idx = rows.value.findIndex((r) => r.enrollment_id === payload.enrollment_id);
  if (idx >= 0) {
    rows.value[idx] = { ...rows.value[idx], score: payload.score, dirty: true };
  }
}

async function onSaveDirty(dirtyRows: TutoringScoreRow[]) {
  if (saving.value || dirtyRows.length === 0) return;
  saving.value = true;
  try {
    await TutoringBimbelService.upsertScores(
      assessmentId.value,
      dirtyRows.map((r) => ({
        enrollment_id: r.enrollment_id,
        score: r.score,
        notes: r.notes ?? null,
      })),
    );
    toast.success(t('tutoring2.tutor.scores.saved'));
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
          @update:score="onUpdateScore"
          @save-dirty="onSaveDirty"
        />
      </template>
    </AsyncView>
  </div>
</template>

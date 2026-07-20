<!--
  TutorTutoring2ScoresView.vue — Input skor per asesmen (WEB-4).

  Wraps the WEB-2 `TutoringScoreEntryList` component end-to-end: loads
  the assessment's score rows from the greenfield backend, holds the
  row list locally for optimistic updates with a dirty flag, saves
  dirty rows via bulk-upsert.

  Route: /teacher/tutoring2/assessments/:id/scores where `id` is the
  assessment id.

  MVP knobs — hardcode maxScore=100 + kkm=75 so the score entry list
  can render before the parent assessment surface is wired.
  // TODO WEB-4+ fetch maxScore + kkm from the parent assessment (BE
  //   already carries `max_score` + `kkm` on BimbelAssessment; the
  //   AssessmentsView returns them in the list envelope — pass via
  //   route state or a lightweight GET /assessments/:id).
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
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
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

// TODO WEB-4+ fetch maxScore + kkm from the parent assessment (see file header).
const MAX_SCORE = 100;
const KKM = 75;

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listScores(assessmentId.value);
  return items;
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
      empty-title="Belum ada peserta"
      empty-description="Asesmen ini belum memiliki peserta yang bisa diberi skor."
      @retry="reload"
    >
      <!-- TODO i18n key: empty-title 'Belum ada peserta' / empty-description -->
      <template #default>
        <TutoringScoreEntryList
          :assessment-id="assessmentId"
          :rows="rows"
          :max-score="MAX_SCORE"
          :kkm="KKM"
          :loading="state.status === 'loading'"
          :saving="saving"
          @update:score="onUpdateScore"
          @save-dirty="onSaveDirty"
        />
      </template>
    </AsyncView>
  </div>
</template>

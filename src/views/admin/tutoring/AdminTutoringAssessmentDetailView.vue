<!--
  AdminTutoringAssessmentDetailView — viewer for one assessment + its
  persisted AI question set. Uses the shared `TutoringQuestionCard` so
  the renderer is identical to the AI generator preview.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringAssessment } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import TutoringQuestionCard from '@/components/feature/tutoring/TutoringQuestionCard.vue';

const { t } = useI18n();
const route = useRoute();
const toast = useToast();
const assessmentId = String(route.params.assessmentId ?? '');
const title = String(route.query.name ?? t('tutoring.programDetail.assessments'));

const loading = ref(true);
const assessment = ref<TutoringAssessment | null>(null);

async function load() {
  loading.value = true;
  try {
    assessment.value = await TutoringService.getAssessment(assessmentId);
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.assessment.loadFailed'),
    );
  } finally {
    loading.value = false;
  }
}
onMounted(load);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.assessment_detail.kicker_prefix', { title })"
      :title="title"
      :meta="`${assessment?.questions?.length ?? 0} ${t('tutoring.assessment.questions')}`"
    />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else>
      <TutoringEmpty
        v-if="!assessment?.questions?.length"
        :text="t('tutoring.assessment.noQuestions')"
        icon="file-text"
      />
      <div v-else class="space-y-2">
        <TutoringQuestionCard
          v-for="(q, i) in assessment.questions"
          :key="i"
          :index="i + 1"
          :q="q"
        />
      </div>
    </template>
  </div>
</template>

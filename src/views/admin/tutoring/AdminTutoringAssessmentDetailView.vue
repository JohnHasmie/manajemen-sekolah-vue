<!--
  AdminTutoringAssessmentDetailView — viewer for one assessment + its
  persisted AI question set. Web mirror of the Flutter
  `tutoring_assessment_detail_screen.dart`. Consumes the questions stored
  by "Simpan sebagai Try-out".
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringAssessment } from '@/types/tutoring';

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
  <div class="mx-auto max-w-3xl p-4">
    <h1 class="mb-4 text-lg font-bold text-slate-800">{{ title }}</h1>

    <div v-if="loading" class="py-16 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <p
      v-else-if="!assessment?.questions?.length"
      class="py-12 text-center text-slate-500"
    >
      {{ t('tutoring.assessment.noQuestions') }}
    </p>

    <div v-else class="space-y-3">
      <p class="text-sm font-bold text-slate-500">
        {{ assessment.questions.length }} {{ t('tutoring.assessment.questions') }}
      </p>
      <article
        v-for="(q, i) in assessment.questions"
        :key="i"
        class="rounded-2xl border border-slate-200 p-4"
      >
        <p class="font-bold text-slate-800">{{ i + 1 }}. {{ q.question }}</p>
        <ul class="mt-2 space-y-1">
          <li
            v-for="(o, oi) in q.options ?? []"
            :key="oi"
            :class="o.is_correct ? 'font-bold text-emerald-700' : 'text-slate-700'"
          >
            {{ o.label }}. {{ o.text }}
          </li>
        </ul>
        <p v-if="q.correct_answer" class="mt-2 font-bold text-emerald-700">
          {{ t('tutoring.assessment.answer') }}: {{ q.correct_answer }}
        </p>
        <p v-if="q.explanation" class="mt-1 text-sm text-slate-500">
          {{ t('tutoring.assessment.explanation') }}: {{ q.explanation }}
        </p>
      </article>
    </div>
  </div>
</template>

<!--
  StudentTutoring2TakeAssessmentView.vue — Siswa quiz runner (WEB-5 MVP).

  Route: /student/tutoring2/assessments/:id/take.

  Composition contract (mirrors WEB-5 exemplar):
    1. BrandPageHeader        — role="student".
    2. AsyncView              — state machine (fake-loads the sample deck
                                so the state contract already matches
                                what the real fetch will slot into).
    3. Question card          — one soal + 4 option buttons.
    4. Progress bar + footer  — Prev / Next|Kumpulkan.

  MVP: BE-5 does not yet expose per-assessment question rows, so this
  view runs against a static 10-question sample. Answers stay in a
  local `Record<index, option>` map; on submit we toast + push to
  the Hasil view.
-->
<script setup lang="ts">
// TODO WEB-5+ swap sample questions to /tutoring2/assessments/:id/questions once BE exposes it
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';

interface SampleQuestion {
  id: number;
  text: string;
  options: string[];
}

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

const assessmentId = (route.params.id as string) ?? '';

// TODO WEB-5+ swap sample questions to /tutoring2/assessments/:id/questions once BE exposes it
const sampleQuestions: SampleQuestion[] = Array.from({ length: 10 }, (_, i) => ({
  id: i,
  text: 'Contoh soal ' + (i + 1),
  options: ['A', 'B', 'C', 'D'],
}));

const { state, reload } = useDataRefresh<SampleQuestion[]>(async () => {
  // Simulated latency so the state-machine path exercises `loading`.
  await new Promise((r) => setTimeout(r, 100));
  return sampleQuestions;
});

const questions = computed<SampleQuestion[]>(() =>
  state.value.status === 'content' ? (state.value.data as SampleQuestion[]) : [],
);

const currentIndex = ref(0);
const answers = ref<Record<number, string>>({});

const currentQuestion = computed<SampleQuestion | null>(() => {
  return questions.value[currentIndex.value] ?? null;
});

const progressPct = computed<number>(() => {
  if (questions.value.length === 0) return 0;
  return (currentIndex.value / questions.value.length) * 100;
});

const isLast = computed<boolean>(() =>
  questions.value.length > 0 && currentIndex.value === questions.value.length - 1,
);

const headerMeta = computed<string>(() => {
  if (questions.value.length === 0) return t('tutoring2.common.loading');
  return t('tutoring2.student.takeAssessment.progress', {
    current: currentIndex.value + 1,
    total: questions.value.length,
  });
});

function selectOption(opt: string) {
  answers.value = { ...answers.value, [currentIndex.value]: opt };
}

function prev() {
  if (currentIndex.value > 0) currentIndex.value -= 1;
}

function next() {
  if (isLast.value) {
    submit();
    return;
  }
  if (currentIndex.value < questions.value.length - 1) {
    currentIndex.value += 1;
  }
}

function submit() {
  toast.success(t('tutoring2.student.takeAssessment.submitted'));
  router.push({ name: 'student.tutoring2.result', params: { id: assessmentId } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.takeAssessment.title')"
      :meta="headerMeta"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="2"
      :empty-title="t('tutoring2.common.noData')"
      @retry="reload"
    >
      <template #default>
        <div
          v-if="currentQuestion"
          class="rounded-3xl border border-slate-100 bg-white shadow-sm p-4 space-y-4"
        >
          <p class="text-sm font-bold text-slate-900">{{ currentQuestion.text }}</p>

          <div class="space-y-2">
            <button
              v-for="opt in currentQuestion.options"
              :key="opt"
              type="button"
              class="w-full text-left rounded-2xl border border-slate-200 px-4 py-3 text-sm font-bold transition-colors"
              :class="answers[currentIndex] === opt
                ? 'bg-brand-azure text-white border-brand-azure'
                : 'bg-white text-slate-900 hover:bg-slate-50'"
              @click="selectOption(opt)"
            >
              <span class="mr-2 text-2xs uppercase opacity-70">{{ t('tutoring2.student.takeAssessment.optionLabel') }}</span>
              {{ opt }}
            </button>
          </div>

          <div class="h-1 bg-slate-100 rounded-full">
            <div
              class="h-1 bg-brand-azure rounded-full transition-all"
              :style="{ width: progressPct + '%' }"
            ></div>
          </div>
        </div>

        <div class="flex items-center gap-2 pt-2">
          <Button
            variant="secondary"
            :disabled="currentIndex === 0"
            @click="prev"
          >{{ t('tutoring2.student.takeAssessment.prev') }}</Button>
          <div class="flex-1"></div>
          <Button variant="primary" @click="next">
            {{ isLast ? t('tutoring2.student.takeAssessment.submit') : t('tutoring2.student.takeAssessment.next') }}
          </Button>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

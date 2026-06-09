<!--
  TutorTryoutGenerateView — generate try-out / exercise questions with AI.
  Web mirror of the Flutter `tutor_tryout_generate_screen.dart`. Calls the
  AI microservice (aiApi) and renders questions with options, correct
  answer, and explanation.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringAiQuestion, TutoringGroup } from '@/types/tutoring';

const { t } = useI18n();
const toast = useToast();

const mode = ref<'tryout' | 'exercise'>('tryout');
const subject = ref('');
const level = ref('SMA');
const topic = ref('');
const count = ref(10);
const difficulty = ref('mixed');

const loading = ref(false);
const questions = ref<TutoringAiQuestion[]>([]);

// "Simpan sebagai Try-out" — needs a target group.
const groups = ref<TutoringGroup[]>([]);
const groupId = ref<string | null>(null);
const saving = ref(false);

onMounted(async () => {
  try {
    groups.value = await TutoringService.getAllGroups();
  } catch {
    // Non-fatal: generation still works without the save option.
  }
});

async function saveAsTryout() {
  if (!groupId.value) {
    toast.error(t('tutoring.ai.pickGroup'));
    return;
  }
  saving.value = true;
  try {
    const subj = subject.value.trim() || 'Try-out';
    await TutoringService.createAssessment({
      type: 'TRYOUT',
      title: `Try-out ${subj}`,
      held_at: new Date().toISOString(),
      tutoring_group_id: groupId.value,
      questions: questions.value,
    });
    toast.success(t('tutoring.ai.savedOk'));
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.ai.saveFailed'));
  } finally {
    saving.value = false;
  }
}

async function generate() {
  if (!subject.value.trim()) {
    toast.error(t('tutoring.ai.subjectRequired'));
    return;
  }
  loading.value = true;
  questions.value = [];
  try {
    const data = await TutoringService.generateTryout({
      subject: subject.value.trim(),
      target_education_level: level.value.trim() || undefined,
      topic: topic.value.trim() || undefined,
      question_count: count.value,
      difficulty: difficulty.value,
      mode: mode.value,
    });
    questions.value = data.questions ?? [];
    if (questions.value.length === 0) {
      toast.info(t('tutoring.ai.noGenerated'));
    }
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.ai.genFailed'));
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <h1 class="mb-4 text-lg font-bold text-slate-800">
      {{ t('tutoring.ai.title') }}
    </h1>

    <div class="space-y-3 rounded-2xl border border-slate-200 p-4">
      <div class="flex gap-2">
        <button
          v-for="m in (['tryout', 'exercise'] as const)"
          :key="m"
          class="rounded-lg px-3 py-1.5 text-sm font-semibold"
          :class="
            mode === m
              ? 'bg-teal-700 text-white'
              : 'bg-slate-100 text-slate-700'
          "
          @click="mode = m"
        >
          {{ m === 'tryout' ? t('tutoring.ai.tryout') : t('tutoring.ai.exercise') }}
        </button>
      </div>

      <input
        v-model="subject"
        :placeholder="t('tutoring.ai.subjectPh')"
        class="w-full rounded-lg border border-slate-300 px-3 py-2"
      />
      <div class="flex gap-2">
        <input
          v-model="level"
          :placeholder="t('tutoring.ai.levelPh')"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        />
        <input
          v-model="topic"
          :placeholder="t('tutoring.ai.topicPh')"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        />
      </div>
      <div class="flex gap-2">
        <select
          v-model.number="count"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        >
          <option :value="5">{{ t('tutoring.ai.count', { n: 5 }) }}</option>
          <option :value="10">{{ t('tutoring.ai.count', { n: 10 }) }}</option>
          <option :value="15">{{ t('tutoring.ai.count', { n: 15 }) }}</option>
          <option :value="20">{{ t('tutoring.ai.count', { n: 20 }) }}</option>
        </select>
        <select
          v-model="difficulty"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        >
          <option value="mixed">{{ t('tutoring.ai.mixed') }}</option>
          <option value="easy">{{ t('tutoring.ai.easy') }}</option>
          <option value="medium">{{ t('tutoring.ai.medium') }}</option>
          <option value="hard">{{ t('tutoring.ai.hard') }}</option>
        </select>
      </div>

      <button
        :disabled="loading"
        class="w-full rounded-lg bg-teal-700 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="generate"
      >
        {{ loading ? t('tutoring.ai.generating') : t('tutoring.ai.generate') }}
      </button>
    </div>

    <!-- Save as trackable try-out (tryout mode only, after generation) -->
    <div
      v-if="questions.length > 0 && mode === 'tryout'"
      class="mt-4 space-y-2 rounded-2xl border border-slate-200 p-4"
    >
      <label class="block text-sm font-semibold text-slate-700">
        {{ t('tutoring.ai.saveForGroup') }}
      </label>
      <select
        v-model="groupId"
        class="w-full rounded-lg border border-slate-300 px-3 py-2"
      >
        <option :value="null" disabled>{{ t('tutoring.ai.pickGroupPh') }}</option>
        <option v-for="g in groups" :key="g.id" :value="g.id">
          {{ g.name }}
        </option>
      </select>
      <button
        :disabled="saving || !groupId"
        class="rounded-lg border border-teal-700 px-4 py-2 text-sm font-semibold text-teal-700 disabled:opacity-50"
        @click="saveAsTryout"
      >
        {{ saving ? t('tutoring.common.saving') : t('tutoring.ai.saveAsTryout') }}
      </button>
    </div>

    <div class="mt-4 space-y-3">
      <article
        v-for="(q, i) in questions"
        :key="i"
        class="rounded-2xl border border-slate-200 p-4"
      >
        <p class="font-bold text-slate-800">{{ i + 1 }}. {{ q.question }}</p>
        <ul class="mt-2 space-y-1">
          <li
            v-for="(o, oi) in q.options ?? []"
            :key="oi"
            :class="
              o.is_correct
                ? 'font-bold text-emerald-700'
                : 'text-slate-700'
            "
          >
            {{ o.label }}. {{ o.text }}
          </li>
        </ul>
        <p v-if="q.correct_answer" class="mt-2 font-bold text-emerald-700">
          {{ t('tutoring.ai.answer') }}: {{ q.correct_answer }}
        </p>
        <p v-if="q.explanation" class="mt-1 text-sm text-slate-500">
          {{ t('tutoring.ai.explanation') }}: {{ q.explanation }}
        </p>
      </article>
    </div>
  </div>
</template>

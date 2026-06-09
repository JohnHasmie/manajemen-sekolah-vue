<!--
  TutorTryoutGenerateView — generate try-out / exercise questions with
  AI. Rebuilt on the tutoring shared components. The generated
  questions use the shared `TutoringQuestionCard`.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringAiQuestion, TutoringGroup } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringFlowTag from '@/components/feature/tutoring/TutoringFlowTag.vue';
import TutoringChipsRow from '@/components/feature/tutoring/TutoringChipsRow.vue';
import TutoringQuestionCard from '@/components/feature/tutoring/TutoringQuestionCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

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

const groups = ref<TutoringGroup[]>([]);
const groupId = ref<string | null>(null);
const saving = ref(false);

onMounted(async () => {
  try {
    groups.value = await TutoringService.getAllGroups();
  } catch {/* non-fatal */}
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

const inputCls =
  'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher';
</script>

<template>
  <div class="mx-auto max-w-3xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.ai.title')"
      crumbs="Bimbel · Generator Soal"
    />

    <TutoringFlowTag
      class="mb-3"
      text="Atur → Generate → Simpan sebagai try-out untuk kelompok"
    />

    <div class="space-y-3 bg-white border border-slate-100 rounded-2xl p-4">
      <TutoringChipsRow
        v-model="mode"
        :options="[
          { value: 'tryout', label: t('tutoring.ai.tryout') },
          { value: 'exercise', label: t('tutoring.ai.exercise') },
        ]"
      />

      <input
        v-model="subject"
        :placeholder="t('tutoring.ai.subjectPh')"
        :class="inputCls"
      />
      <div class="flex gap-2">
        <input
          v-model="level"
          :placeholder="t('tutoring.ai.levelPh')"
          :class="inputCls"
        />
        <input
          v-model="topic"
          :placeholder="t('tutoring.ai.topicPh')"
          :class="inputCls"
        />
      </div>
      <div class="flex gap-2">
        <select v-model.number="count" :class="inputCls">
          <option :value="5">{{ t('tutoring.ai.count', { n: 5 }) }}</option>
          <option :value="10">{{ t('tutoring.ai.count', { n: 10 }) }}</option>
          <option :value="15">{{ t('tutoring.ai.count', { n: 15 }) }}</option>
          <option :value="20">{{ t('tutoring.ai.count', { n: 20 }) }}</option>
        </select>
        <select v-model="difficulty" :class="inputCls">
          <option value="mixed">{{ t('tutoring.ai.mixed') }}</option>
          <option value="easy">{{ t('tutoring.ai.easy') }}</option>
          <option value="medium">{{ t('tutoring.ai.medium') }}</option>
          <option value="hard">{{ t('tutoring.ai.hard') }}</option>
        </select>
      </div>

      <button
        :disabled="loading"
        class="w-full rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2.5 font-semibold text-white disabled:opacity-50 inline-flex items-center justify-center gap-2"
        @click="generate"
      >
        <NavIcon name="sparkles" :size="16" />
        {{ loading ? t('tutoring.ai.generating') : t('tutoring.ai.generate') }}
      </button>
    </div>

    <!-- Save block (tryout mode only, after generation) -->
    <div
      v-if="questions.length > 0 && mode === 'tryout'"
      class="mt-4 space-y-2 bg-white border border-slate-100 rounded-2xl p-4"
    >
      <p class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
        {{ t('tutoring.ai.saveForGroup') }}
      </p>
      <select v-model="groupId" :class="inputCls">
        <option :value="null" disabled>{{ t('tutoring.ai.pickGroupPh') }}</option>
        <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
      </select>
      <button
        :disabled="saving || !groupId"
        class="w-full rounded-lg border border-role-teacher text-role-teacher hover:bg-role-teacher-soft px-4 py-2 text-sm font-semibold disabled:opacity-50 inline-flex items-center justify-center gap-2"
        @click="saveAsTryout"
      >
        <NavIcon name="bookmark" :size="14" />
        {{ saving ? t('tutoring.common.saving') : t('tutoring.ai.saveAsTryout') }}
      </button>
    </div>

    <div class="mt-4 space-y-2">
      <TutoringQuestionCard
        v-for="(q, i) in questions"
        :key="i"
        :index="i + 1"
        :q="q"
      />
    </div>
  </div>
</template>

<!--
  TutorTryoutGenerateView — generate try-out / exercise questions with AI.
  Web mirror of the Flutter `tutor_tryout_generate_screen.dart`. Calls the
  AI microservice (aiApi) and renders questions with options, correct
  answer, and explanation.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringAiQuestion } from '@/types/tutoring';

const toast = useToast();

const mode = ref<'tryout' | 'exercise'>('tryout');
const subject = ref('');
const level = ref('SMA');
const topic = ref('');
const count = ref(10);
const difficulty = ref('mixed');

const loading = ref(false);
const questions = ref<TutoringAiQuestion[]>([]);

async function generate() {
  if (!subject.value.trim()) {
    toast.error('Mata pelajaran wajib diisi.');
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
      toast.info('Tidak ada soal yang dihasilkan. Coba lagi.');
    }
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal membuat soal.');
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <h1 class="mb-4 text-lg font-bold text-slate-800">Generator Soal AI</h1>

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
          {{ m === 'tryout' ? 'Try-out' : 'Latihan' }}
        </button>
      </div>

      <input
        v-model="subject"
        placeholder="Mata pelajaran (cth. Matematika UTBK)"
        class="w-full rounded-lg border border-slate-300 px-3 py-2"
      />
      <div class="flex gap-2">
        <input
          v-model="level"
          placeholder="Jenjang (cth. SMA)"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        />
        <input
          v-model="topic"
          placeholder="Topik (opsional)"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        />
      </div>
      <div class="flex gap-2">
        <select
          v-model.number="count"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        >
          <option :value="5">5 soal</option>
          <option :value="10">10 soal</option>
          <option :value="15">15 soal</option>
          <option :value="20">20 soal</option>
        </select>
        <select
          v-model="difficulty"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        >
          <option value="mixed">Campuran</option>
          <option value="easy">Mudah</option>
          <option value="medium">Sedang</option>
          <option value="hard">Sulit</option>
        </select>
      </div>

      <button
        :disabled="loading"
        class="w-full rounded-lg bg-teal-700 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="generate"
      >
        {{ loading ? 'Membuat soal…' : 'Generate' }}
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
          Jawaban: {{ q.correct_answer }}
        </p>
        <p v-if="q.explanation" class="mt-1 text-sm text-slate-500">
          Pembahasan: {{ q.explanation }}
        </p>
      </article>
    </div>
  </div>
</template>

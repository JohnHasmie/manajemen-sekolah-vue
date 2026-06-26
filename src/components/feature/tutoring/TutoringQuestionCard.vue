<!--
  TutoringQuestionCard — MCQ renderer shared between the AI generator
  preview and the saved-assessment viewer. Mirrors Flutter
  `TutoringQuestionCard`.
-->
<script setup lang="ts">
import type { TutoringAiQuestion } from '@/types/tutoring';

defineProps<{
  index: number;
  q: TutoringAiQuestion | Record<string, unknown>;
}>();

function asOptions(
  q: Record<string, unknown>,
): { label?: string; text?: string; is_correct?: boolean }[] {
  return (q.options as never) ?? [];
}
function asStr(v: unknown): string {
  return v == null ? '' : String(v);
}
</script>

<template>
  <article
    class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4 mb-2"
  >
    <p class="font-semibold text-tutoring-text-hi tracking-tight">
      {{ index }}. {{ asStr((q as Record<string, unknown>).question) }}
    </p>
    <ul class="mt-2 space-y-1">
      <li
        v-for="(o, oi) in asOptions(q as Record<string, unknown>)"
        :key="oi"
        class="text-sm"
        :class="o.is_correct ? 'font-bold text-tutoring-green' : 'text-tutoring-text-mid'"
      >
        {{ o.label }}. {{ o.text }}
      </li>
    </ul>
    <p
      v-if="(q as Record<string, unknown>).correct_answer"
      class="mt-2 text-xs font-bold text-tutoring-green"
    >
      Jawaban: {{ asStr((q as Record<string, unknown>).correct_answer) }}
    </p>
    <p
      v-if="(q as Record<string, unknown>).explanation"
      class="mt-1 text-xs text-tutoring-text-mid"
    >
      Pembahasan: {{ asStr((q as Record<string, unknown>).explanation) }}
    </p>
  </article>
</template>

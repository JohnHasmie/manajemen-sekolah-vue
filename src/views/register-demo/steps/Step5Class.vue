<!--
  Step 5 — Classes. Pattern picker (small/medium/large) plus
  optional per-grade override sliders. Preview shows resulting
  class names like "7A · 7B · 7C".
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const wizard = useDemoWizardStore();

const GRADE_LISTS: Record<string, string[]> = {
  SD: ['1', '2', '3', '4', '5', '6'],
  MI: ['1', '2', '3', '4', '5', '6'],
  SMP: ['7', '8', '9'],
  MTs: ['7', '8', '9'],
  SMA: ['10', '11', '12'],
  MA: ['10', '11', '12'],
  SMK: ['10', '11', '12'],
  TK: ['A', 'B'],
  PAUD: ['KB'],
  Pesantren: ['7', '8', '9', '10', '11', '12'],
};

const PATTERN_DEFAULT: Record<'small' | 'medium' | 'large', number> = {
  small: 1,
  medium: 3,
  large: 5,
};

const grades = computed(() => GRADE_LISTS[wizard.payload.school.education_level] ?? GRADE_LISTS.SMP);

const pattern = computed({
  get: () => wizard.payload.classes.pattern,
  set: (v: 'small' | 'medium' | 'large' | 'custom') => {
    wizard.patchPayload('classes', { pattern: v });
    if (v !== 'custom') {
      const def = PATTERN_DEFAULT[v];
      const map: Record<string, number> = {};
      grades.value.forEach((g) => (map[g] = def));
      wizard.patchPayload('classes', { per_grade: map });
    }
  },
});

const perGrade = computed({
  get: () => {
    const m = wizard.payload.classes.per_grade;
    if (Object.keys(m).length === 0) {
      const def = PATTERN_DEFAULT[(pattern.value === 'custom' ? 'medium' : pattern.value) as 'small' | 'medium' | 'large'];
      const fresh: Record<string, number> = {};
      grades.value.forEach((g) => (fresh[g] = def));
      return fresh;
    }
    return m;
  },
  set: (v: Record<string, number>) => wizard.patchPayload('classes', { per_grade: v }),
});

function setGradeCount(grade: string, n: number) {
  perGrade.value = { ...perGrade.value, [grade]: Math.max(1, Math.min(10, n)) };
  wizard.patchPayload('classes', { pattern: 'custom' });
}

const previewNames = computed(() => {
  const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
  const out: string[] = [];
  for (const grade of grades.value) {
    const n = perGrade.value[grade] ?? 1;
    for (let i = 0; i < n; i++) out.push(`${grade}${letters[i]}`);
  }
  return out;
});
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.stepCounter', { current: wizard.stepNumber, total: wizard.stepTotal }) }} · {{ t('registerDemo.step6Label') }}
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      {{ t('registerDemo.step6Title') }}
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">{{ t('registerDemo.step6Subtitle') }}</p>

    <div class="grid grid-cols-3 gap-3 mb-4">
      <button
        v-for="p in (['small', 'medium', 'large'] as const)"
        :key="p"
        type="button"
        class="border rounded-xl py-2.5 transition"
        :class="
          pattern === p
            ? 'border-2 border-role-admin bg-role-admin/10'
            : 'border-slate-300 bg-white hover:border-slate-400'
        "
        @click="pattern = p"
      >
        <div class="text-[13px] font-bold capitalize">
          {{ p === 'small' ? t('registerDemo.step6PatternSmall') : p === 'medium' ? t('registerDemo.step6PatternMedium') : t('registerDemo.step6PatternLarge') }}
        </div>
        <div class="text-[11px] text-slate-500">
          {{ PATTERN_DEFAULT[p] }} {{ t('registerDemo.step6PatternHint') }}
        </div>
      </button>
    </div>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.step6CustomizeLabel') }}
    </p>
    <div class="space-y-2 mb-4">
      <div
        v-for="g in grades"
        :key="g"
        class="flex items-center gap-3 border border-slate-200 rounded-lg px-3 py-2"
      >
        <span class="text-[12.5px] font-bold w-16">{{ t('registerDemo.step6GradeLabel', { g }) }}</span>
        <input
          type="range"
          min="1"
          max="6"
          :value="perGrade[g] ?? 1"
          class="flex-1 accent-role-admin"
          @input="setGradeCount(g, +($event.target as HTMLInputElement).value)"
        />
        <span class="text-[13px] font-bold w-16 text-right">{{ perGrade[g] ?? 1 }} {{ t('registerDemo.step6RombelLabel') }}</span>
      </div>
    </div>

    <div class="border border-dashed border-slate-300 rounded-lg p-3 text-[12px] text-slate-600">
      <strong class="text-slate-900 font-bold">{{ t('registerDemo.step6WillCreateLabel') }}</strong>
      {{ previewNames.join(' · ') || '—' }}
      <span class="text-slate-500">({{ previewNames.length }} {{ t('registerDemo.step6CountLabel') }})</span>
    </div>
  </div>
</template>

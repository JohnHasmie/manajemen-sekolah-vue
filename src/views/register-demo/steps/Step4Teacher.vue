<!--
  Step 4 — Teachers. Slider for count + acak/manual choice.
  Manual mode shows a minimal name+subject list editor.
-->
<script setup lang="ts">
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const wizard = useDemoWizardStore();

const count = computed({
  get: () => wizard.payload.teachers.count,
  set: (v: number) => wizard.patchPayload('teachers', { count: v }),
});

const fillMode = computed({
  get: () => wizard.payload.teachers.fill_mode,
  set: (v: 'random' | 'manual') => wizard.patchPayload('teachers', { fill_mode: v }),
});

const manualList = computed({
  get: () => wizard.payload.teachers.manual_list,
  set: (v: Array<{ name: string; subject: string | null }>) =>
    wizard.patchPayload('teachers', { manual_list: v }),
});

function syncManualLength() {
  // When user is in manual mode, pad/trim the list to match count.
  const list = [...manualList.value];
  while (list.length < count.value) list.push({ name: '', subject: null });
  if (list.length > count.value) list.length = count.value;
  manualList.value = list;
}

function updateManual(idx: number, field: 'name' | 'subject', value: string) {
  const list = [...manualList.value];
  // Empty-string subject means "round-robin / random" — store as null
  // so backend's null-check works the same as the random branch.
  const normalized = field === 'subject' && value === '' ? null : value;
  list[idx] = { ...list[idx], [field]: normalized };
  manualList.value = list;
}

// Mapel options come from step 4's payload, NOT a free-text input.
// Keeps subject_schools wired to the canonical list and prevents
// the seed engine from spawning orphan mapel rows.
const subjectsList = computed(() => wizard.payload.subjects.names);

// Sync manual_list length when count slider OR fill mode changes so
// the form always has exactly `count` rows.
watch(
  [count, fillMode],
  ([n, mode]) => {
    if (mode !== 'manual') return;
    syncManualLength();
  },
  { immediate: false },
);
</script>

<template>
  <div>
    <p class="text-2xs font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.stepCounter', { current: wizard.stepNumber, total: wizard.stepTotal }) }} · {{ t('registerDemo.step5Label') }}
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      {{ t('registerDemo.step5Title') }}
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">{{ t('registerDemo.step5Subtitle') }}</p>

    <div class="flex items-center gap-4 mb-5">
      <input
        v-model.number="count"
        type="range"
        min="3"
        max="60"
        step="1"
        class="flex-1 accent-role-admin"
      />
      <span class="text-[22px] font-black text-slate-900 w-10 text-right">{{ count }}</span>
    </div>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.step5FillModeLabel') }}
    </p>
    <div class="grid grid-cols-2 gap-3">
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="
          fillMode === 'random'
            ? 'border-2 border-role-admin bg-role-admin/10'
            : 'border-slate-300 bg-white hover:border-slate-400'
        "
        @click="fillMode = 'random'"
      >
        <NavIcon name="zap" :size="20" :class="fillMode === 'random' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">{{ t('registerDemo.step5RandomMode') }}</div>
        <div class="text-2xs" :class="fillMode === 'random' ? 'text-role-admin' : 'text-slate-500'">
          {{ t('registerDemo.step5RandomHint') }}
        </div>
      </button>
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="
          fillMode === 'manual'
            ? 'border-2 border-role-admin bg-role-admin/10'
            : 'border-slate-300 bg-white hover:border-slate-400'
        "
        @click="fillMode = 'manual'; syncManualLength()"
      >
        <NavIcon name="edit" :size="20" :class="fillMode === 'manual' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">{{ t('registerDemo.step5ManualMode') }}</div>
        <div class="text-2xs" :class="fillMode === 'manual' ? 'text-role-admin' : 'text-slate-500'">
          {{ t('registerDemo.step5ManualHint') }}
        </div>
      </button>
    </div>

    <div v-if="fillMode === 'random'" class="mt-4 border border-dashed border-slate-300 rounded-lg p-3 text-[12px] text-slate-600">
      <strong class="text-slate-900 font-bold">{{ t('registerDemo.step5PreviewLabel') }}</strong>
      <!-- TODO(i18n): review -->
      {{ t('registerDemo.step5PreviewNames') }}
      <span class="text-slate-400"> + {{ Math.max(0, count - 3) }} {{ t('registerDemo.step5PreviewMore') }}</span>
    </div>

    <div v-else>
      <p class="text-[11.5px] text-slate-500 mt-4 mb-2">
        {{ t('registerDemo.step5ManualInstruction1') }}
        {{ t('registerDemo.step5ManualInstruction2') }}
        <span class="font-bold text-slate-700">{{ t('registerDemo.step5Step4Ref') }}</span>.
      </p>

      <p
        v-if="subjectsList.length === 0"
        class="text-[12px] text-amber-700 bg-amber-50 border border-amber-200 rounded-lg p-2.5 mb-2"
      >
        <NavIcon name="alert-circle" :size="13" class="inline-block -mt-0.5 mr-1" />
        {{ t('registerDemo.step5NoSubjects') }}
      </p>

      <div class="max-h-[280px] overflow-y-auto border border-slate-200 rounded-lg p-2 space-y-1.5">
        <div
          v-for="(teacher, idx) in manualList"
          :key="idx"
          class="flex items-center gap-2"
        >
          <span class="w-6 text-2xs text-slate-400 text-right">{{ idx + 1 }}.</span>
          <input
            :value="teacher.name"
            type="text"
            :placeholder="t('registerDemo.step5NamePlaceholder', { idx: idx + 1 })"
            class="flex-1 border border-slate-300 rounded px-2 py-1.5 text-[12.5px] outline-none focus:border-role-admin"
            @input="updateManual(idx, 'name', ($event.target as HTMLInputElement).value)"
          />
          <select
            :value="teacher.subject ?? ''"
            class="w-40 border border-slate-300 rounded px-2 py-1.5 text-[12.5px] outline-none focus:border-role-admin bg-white"
            :disabled="subjectsList.length === 0"
            @change="updateManual(idx, 'subject', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">{{ t('registerDemo.step5RandomOption') }}</option>
            <option v-for="name in subjectsList" :key="name" :value="name">
              {{ name }}
            </option>
          </select>
        </div>
      </div>

      <p class="text-2xs text-slate-500 mt-2">
        {{ t('registerDemo.step5TipPrefix') }}
        <code class="bg-slate-100 px-1.5 py-0.5 rounded text-[10.5px]">{{ t('registerDemo.step5RandomOption') }}</code>
        {{ t('registerDemo.step5TipSuffix') }}
      </p>
    </div>
  </div>
</template>

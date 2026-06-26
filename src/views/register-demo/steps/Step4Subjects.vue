<!--
  Step 4 — Mata Pelajaran.
  Pre-fills chip list from the jenjang template picked in step 2.
  User can toggle defaults + add custom (mulok, program keahlian).
  Final list seeds both `subjects` master + `subject_schools` per
  school in the provision action.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import { defaultSubjectsFor, SUBJECTS_TEMPLATE, type EducationLevel } from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const wizard = useDemoWizardStore();

const jenjang = computed<EducationLevel>(() => wizard.payload.school.education_level);
const names = computed({
  get: () => wizard.payload.subjects.names,
  set: (v: string[]) => wizard.patchPayload('subjects', { names: v }),
});

// Auto re-seed when user changes jenjang BACK in step 2 without
// editing subjects manually. We detect "manual edit" by comparing
// the current list against the template — if identical to ANY
// jenjang template, it's still default-shaped and safe to re-seed.
watch(jenjang, (newJenjang, oldJenjang) => {
  if (newJenjang === oldJenjang) return;
  const oldTemplate = defaultSubjectsFor(oldJenjang as EducationLevel);
  const sameAsOld =
    names.value.length === oldTemplate.length &&
    names.value.every((n) => oldTemplate.includes(n));
  if (sameAsOld) {
    names.value = defaultSubjectsFor(newJenjang);
  }
});

function toggle(name: string) {
  const set = new Set(names.value);
  if (set.has(name)) set.delete(name);
  else set.add(name);
  names.value = Array.from(set);
}

const newCustom = ref('');

function addCustom() {
  const v = newCustom.value.trim();
  if (v.length < 2) return;
  if (names.value.includes(v)) {
    newCustom.value = '';
    return;
  }
  names.value = [...names.value, v];
  newCustom.value = '';
}

function removeCustom(name: string) {
  names.value = names.value.filter((n) => n !== name);
}

const templateNames = computed(() => SUBJECTS_TEMPLATE[jenjang.value] ?? []);

const customNames = computed(() =>
  names.value.filter((n) => !templateNames.value.includes(n)),
);

function resetToTemplate() {
  names.value = defaultSubjectsFor(jenjang.value);
}
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.stepCounter', { current: wizard.stepNumber, total: wizard.stepTotal }) }} · {{ t('registerDemo.step4Label') }}
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      {{ t('registerDemo.step4Title') }}
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">
      {{ t('registerDemo.step4Subtitle1') }}
      <span class="font-bold text-slate-800">{{ jenjang }}</span>.
      {{ t('registerDemo.step4Subtitle2') }}
    </p>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.step4TemplateLabel', { jenjang, count: templateNames.length }) }}
    </p>
    <div class="flex flex-wrap gap-1.5 mb-1">
      <button
        v-for="name in templateNames"
        :key="name"
        type="button"
        class="px-3 py-1.5 rounded-full text-[12px] font-bold transition border inline-flex items-center gap-1.5"
        :class="
          names.includes(name)
            ? 'bg-role-admin text-white border-role-admin'
            : 'bg-white text-slate-500 border-slate-300 hover:border-slate-400'
        "
        @click="toggle(name)"
      >
        <NavIcon v-if="names.includes(name)" name="check" :size="11" />
        {{ name }}
      </button>
    </div>

    <div v-if="customNames.length > 0">
      <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mt-4 mb-2">
        {{ t('registerDemo.step4CustomLabel', { count: customNames.length }) }}
      </p>
      <div class="flex flex-wrap gap-1.5">
        <span
          v-for="name in customNames"
          :key="name"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12px] font-bold bg-amber-100 text-amber-800 border border-amber-300"
        >
          {{ name }}
          <button
            type="button"
            class="hover:text-amber-900"
            :aria-label="t('registerDemo.step4DeleteSubject')"
            @click="removeCustom(name)"
          >
            <NavIcon name="x" :size="11" />
          </button>
        </span>
      </div>
    </div>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mt-5 mb-2">
      {{ t('registerDemo.step4AddCustomLabel') }}
    </p>
    <div class="flex items-center gap-2">
      <input
        v-model="newCustom"
        type="text"
        :placeholder="t('registerDemo.step4AddCustomPlaceholder')"
        class="flex-1 border border-slate-300 rounded-lg px-3 py-2.5 text-[13px] outline-none focus:border-role-admin"
        @keydown.enter.prevent="addCustom"
      />
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-lg bg-role-admin text-white text-[12.5px] font-bold hover:bg-role-admin/90 disabled:opacity-60"
        :disabled="newCustom.trim().length < 2"
        @click="addCustom"
      >
        <NavIcon name="plus" :size="13" />
        {{ t('common.add') }}
      </button>
    </div>

    <div class="flex items-center justify-between mt-5 pt-4 border-t border-slate-100">
      <div class="text-[13px]">
        <strong class="font-bold text-slate-900">{{ names.length }} mapel</strong>
        <span class="text-slate-500"> {{ t('registerDemo.step4Summary') }}</span>
      </div>
      <button
        type="button"
        class="text-[12px] font-bold text-role-admin hover:underline"
        @click="resetToTemplate"
      >
        <NavIcon name="refresh-cw" :size="11" class="inline-block -mt-0.5 mr-1" />
        {{ t('registerDemo.step4ResetButton') }}
      </button>
    </div>
  </div>
</template>

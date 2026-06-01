<!--
  Step 6 — Students. Slider per-class + fill mode (random/CSV/manual).
  CSV/manual modes are stub placeholders for the demo — they fall
  through to random on provision so the user never sees an error.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import NavIcon from '@/components/feature/NavIcon.vue';

const wizard = useDemoWizardStore();

const perClass = computed({
  get: () => wizard.payload.students.per_class,
  set: (v: number) => wizard.patchPayload('students', { per_class: v }),
});

const fillMode = computed({
  get: () => wizard.payload.students.fill_mode,
  set: (v: 'random' | 'manual' | 'csv') => wizard.patchPayload('students', { fill_mode: v }),
});

const totalClasses = computed(() => {
  const m = wizard.payload.classes.per_grade;
  return Object.values(m).reduce((a, b) => a + b, 0) || 1;
});

const total = computed(() => perClass.value * totalClasses.value);
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Langkah 7 dari 12 · Siswa
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      Rata-rata siswa per kelas?
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">Sistem akan generate roster otomatis.</p>

    <div class="flex items-center gap-4 mb-5">
      <input
        v-model.number="perClass"
        type="range"
        min="10"
        max="40"
        step="1"
        class="flex-1 accent-role-admin"
      />
      <span class="text-[22px] font-black text-slate-900 w-10 text-right">{{ perClass }}</span>
    </div>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Cara isi nama
    </p>
    <div class="grid grid-cols-3 gap-3">
      <button
        type="button"
        v-for="opt in [
          { v: 'random', label: 'Acak', hint: 'Rekomendasi', icon: 'zap' },
          { v: 'csv', label: 'Upload CSV', hint: 'Punya data?', icon: 'upload' },
          { v: 'manual', label: 'Manual', hint: 'Per siswa', icon: 'edit' },
        ]"
        :key="opt.v"
        class="border rounded-xl p-3 text-center transition"
        :class="
          fillMode === opt.v
            ? 'border-2 border-role-admin bg-role-admin/10'
            : 'border-slate-300 bg-white hover:border-slate-400'
        "
        @click="fillMode = opt.v as 'random' | 'manual' | 'csv'"
      >
        <NavIcon
          :name="opt.icon"
          :size="20"
          :class="fillMode === opt.v ? 'text-role-admin' : 'text-slate-500'"
          class="mx-auto mb-1"
        />
        <div class="text-[13px] font-bold">{{ opt.label }}</div>
        <div class="text-[11px]" :class="fillMode === opt.v ? 'text-role-admin' : 'text-slate-500'">
          {{ opt.hint }}
        </div>
      </button>
    </div>

    <div class="bg-slate-50 rounded-lg mt-4 p-3 text-[13px] text-slate-700">
      <NavIcon name="users" :size="14" class="inline-block mr-1.5 -mt-0.5" />
      Total siswa: <strong class="font-bold">{{ total }} siswa</strong>
      ({{ perClass }} × {{ totalClasses }} kelas)
    </div>

    <p v-if="fillMode !== 'random'" class="text-[11.5px] text-slate-500 mt-3">
      Catatan: untuk versi demo, mode <span class="font-mono">{{ fillMode }}</span> akan
      di-fall-back ke acak. Anda bisa upload CSV / edit per siswa di dashboard setelah selesai.
    </p>
  </div>
</template>

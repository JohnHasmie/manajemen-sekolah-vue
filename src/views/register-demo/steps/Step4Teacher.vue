<!--
  Step 4 — Teachers. Slider for count + acak/manual choice.
  Manual mode shows a minimal name+subject list editor.
-->
<script setup lang="ts">
import { computed, watch } from 'vue';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import NavIcon from '@/components/feature/NavIcon.vue';

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
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Langkah 5 dari 12 · Guru
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      Berapa guru di sekolah Anda?
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">Geser perkiraan. Bisa tambah nanti.</p>

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
      Cara isi nama
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
        <div class="text-[13px] font-bold">Acak otomatis</div>
        <div class="text-[11px]" :class="fillMode === 'random' ? 'text-role-admin' : 'text-slate-500'">
          Rekomendasi · 5 detik
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
        <div class="text-[13px] font-bold">Atur manual</div>
        <div class="text-[11px]" :class="fillMode === 'manual' ? 'text-role-admin' : 'text-slate-500'">
          Ketik nama + mapel
        </div>
      </button>
    </div>

    <div v-if="fillMode === 'random'" class="mt-4 border border-dashed border-slate-300 rounded-lg p-3 text-[12px] text-slate-600">
      <strong class="text-slate-900 font-bold">Pratinjau:</strong>
      Budi Santoso (Mat), Siti Rahmawati (IPA), Andi Pratama (B.Ind)
      <span class="text-slate-400"> + {{ Math.max(0, count - 3) }} lagi</span>
    </div>

    <div v-else>
      <p class="text-[11.5px] text-slate-500 mt-4 mb-2">
        Isi nama yang Anda tahu — sisanya akan di-generate acak otomatis.
        Mapel dipilih dari daftar di
        <span class="font-bold text-slate-700">Langkah 4</span>.
      </p>

      <p
        v-if="subjectsList.length === 0"
        class="text-[12px] text-amber-700 bg-amber-50 border border-amber-200 rounded-lg p-2.5 mb-2"
      >
        <NavIcon name="alert-circle" :size="13" class="inline-block -mt-0.5 mr-1" />
        Belum ada mapel yang dipilih. Kembali ke Langkah 4 untuk pilih dulu.
      </p>

      <div class="max-h-[280px] overflow-y-auto border border-slate-200 rounded-lg p-2 space-y-1.5">
        <div
          v-for="(t, idx) in manualList"
          :key="idx"
          class="flex items-center gap-2"
        >
          <span class="w-6 text-[11px] text-slate-400 text-right">{{ idx + 1 }}.</span>
          <input
            :value="t.name"
            type="text"
            :placeholder="`Nama guru ${idx + 1} (opsional)`"
            class="flex-1 border border-slate-300 rounded px-2 py-1.5 text-[12.5px] outline-none focus:border-role-admin"
            @input="updateManual(idx, 'name', ($event.target as HTMLInputElement).value)"
          />
          <select
            :value="t.subject ?? ''"
            class="w-40 border border-slate-300 rounded px-2 py-1.5 text-[12.5px] outline-none focus:border-role-admin bg-white"
            :disabled="subjectsList.length === 0"
            @change="updateManual(idx, 'subject', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">— acak —</option>
            <option v-for="name in subjectsList" :key="name" :value="name">
              {{ name }}
            </option>
          </select>
        </div>
      </div>

      <p class="text-[11px] text-slate-500 mt-2">
        Tip: pilih
        <code class="bg-slate-100 px-1.5 py-0.5 rounded text-[10.5px]">— acak —</code>
        di kolom Mapel untuk round-robin distribusi otomatis.
      </p>
    </div>
  </div>
</template>

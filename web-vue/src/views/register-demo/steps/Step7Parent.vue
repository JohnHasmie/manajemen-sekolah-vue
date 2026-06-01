<!--
  Step 7 — Parents (wali). Auto-link or skip. Auto-link creates a
  user per student; skip leaves the parent slots empty so the admin
  can invite later from /admin/manajemen.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import NavIcon from '@/components/feature/NavIcon.vue';

const wizard = useDemoWizardStore();

const mode = computed({
  get: () => wizard.payload.parents.mode,
  set: (v: 'auto_link' | 'skip') => wizard.patchPayload('parents', { mode: v }),
});

const studentCount = computed(() => {
  const classCount = Object.values(wizard.payload.classes.per_grade).reduce((a, b) => a + b, 0);
  return classCount * wizard.payload.students.per_class;
});
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Langkah 8 dari 12 · Wali murid
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      Tautkan wali murid?
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">
      Wali butuh akun untuk lihat nilai, presensi, dan tagihan anaknya.
    </p>

    <div class="grid grid-cols-2 gap-3 mb-4">
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="
          mode === 'auto_link'
            ? 'border-2 border-role-admin bg-role-admin/10'
            : 'border-slate-300 bg-white hover:border-slate-400'
        "
        @click="mode = 'auto_link'"
      >
        <NavIcon name="link" :size="22" :class="mode === 'auto_link' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">Tautkan otomatis</div>
        <div class="text-[11px]" :class="mode === 'auto_link' ? 'text-role-admin' : 'text-slate-500'">
          1 wali / siswa · Rekomendasi
        </div>
      </button>
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="
          mode === 'skip'
            ? 'border-2 border-role-admin bg-role-admin/10'
            : 'border-slate-300 bg-white hover:border-slate-400'
        "
        @click="mode = 'skip'"
      >
        <NavIcon name="clock" :size="22" :class="mode === 'skip' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">Atur nanti</div>
        <div class="text-[11px]" :class="mode === 'skip' ? 'text-role-admin' : 'text-slate-500'">
          Lewati untuk sekarang
        </div>
      </button>
    </div>

    <div class="border border-dashed border-slate-300 rounded-lg p-3 text-[12px] text-slate-600 leading-relaxed">
      <strong class="text-slate-900 font-bold">Contoh:</strong>
      Aulia Putri (7A) → Bapak Hendra Putri ·
      Bayu Saputra (7B) → Ibu Lina Saputra
      <span class="text-slate-400">+ {{ Math.max(0, studentCount - 2) }} lagi</span>
    </div>
  </div>
</template>

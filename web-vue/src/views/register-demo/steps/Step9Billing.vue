<!--
  Step 9 — Billing. Multi-select template chips + SPP nominal slider
  + build/skip choice. Last step before provision — the next button
  on this step triggers the backend transaction.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import type { DemoBillingTemplate } from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';

const wizard = useDemoWizardStore();

const TEMPLATES: { v: DemoBillingTemplate; label: string }[] = [
  { v: 'spp_bulanan', label: 'SPP bulanan' },
  { v: 'uang_gedung', label: 'Uang gedung' },
  { v: 'seragam', label: 'Seragam' },
  { v: 'buku_paket', label: 'Buku paket' },
  { v: 'uts_uas', label: 'UTS / UAS' },
  { v: 'ekstrakurikuler', label: 'Ekstrakurikuler' },
];

const templates = computed({
  get: () => wizard.payload.billing.templates,
  set: (v: DemoBillingTemplate[]) => wizard.patchPayload('billing', { templates: v }),
});

const mode = computed({
  get: () => wizard.payload.billing.mode,
  set: (v: 'build_year' | 'skip') => wizard.patchPayload('billing', { mode: v }),
});

const nominal = computed({
  get: () => wizard.payload.billing.spp_nominal,
  set: (v: number) => wizard.patchPayload('billing', { spp_nominal: v }),
});

function toggleTemplate(t: DemoBillingTemplate) {
  const set = new Set(templates.value);
  if (set.has(t)) set.delete(t);
  else set.add(t);
  templates.value = Array.from(set);
}

const formattedNominal = computed(() =>
  new Intl.NumberFormat('id-ID').format(nominal.value),
);
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Langkah 10 dari 12 · Tagihan
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      Skenario tagihan
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">Pilih jenis yang Anda jalankan. Bisa multi-pilih.</p>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Template tagihan
    </p>
    <div class="flex flex-wrap gap-1.5 mb-5">
      <button
        v-for="t in TEMPLATES"
        :key="t.v"
        type="button"
        class="px-3 py-1.5 rounded-full text-[12px] font-bold transition border"
        :class="
          templates.includes(t.v)
            ? 'bg-role-admin text-white border-role-admin'
            : 'bg-white text-slate-700 border-slate-300 hover:border-slate-400'
        "
        @click="toggleTemplate(t.v)"
      >
        {{ t.label }}
      </button>
    </div>

    <template v-if="templates.includes('spp_bulanan')">
      <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
        SPP bulanan · nominal
      </p>
      <div class="flex items-center gap-4 mb-5">
        <input
          v-model.number="nominal"
          type="range"
          min="100000"
          max="2000000"
          step="50000"
          class="flex-1 accent-role-admin"
        />
        <span class="text-[15px] font-bold w-24 text-right">Rp {{ formattedNominal }}</span>
      </div>
    </template>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Skenario pembayaran
    </p>
    <div class="grid grid-cols-2 gap-3">
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="mode === 'build_year' ? 'border-2 border-role-admin bg-role-admin/10' : 'border-slate-300 bg-white hover:border-slate-400'"
        @click="mode = 'build_year'"
      >
        <NavIcon name="rocket" :size="22" :class="mode === 'build_year' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">Bangun setahun</div>
        <div class="text-[11px]" :class="mode === 'build_year' ? 'text-role-admin' : 'text-slate-500'">
          12 bulan · sebagian sudah lunas
        </div>
      </button>
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="mode === 'skip' ? 'border-2 border-role-admin bg-role-admin/10' : 'border-slate-300 bg-white hover:border-slate-400'"
        @click="mode = 'skip'"
      >
        <NavIcon name="clock" :size="22" :class="mode === 'skip' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">Skip</div>
        <div class="text-[11px]" :class="mode === 'skip' ? 'text-role-admin' : 'text-slate-500'">
          Atur nanti dari Keuangan
        </div>
      </button>
    </div>
  </div>
</template>

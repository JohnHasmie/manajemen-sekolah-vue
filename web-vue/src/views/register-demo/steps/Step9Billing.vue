<!--
  Step 9 — Billing. Multi-select template chips + SPP nominal slider
  + build/skip choice. Last step before provision — the next button
  on this step triggers the backend transaction.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import type { DemoBillingTemplate } from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const wizard = useDemoWizardStore();

const TEMPLATES = computed<{ v: DemoBillingTemplate; label: string }[]>(() => [
  { v: 'spp_bulanan', label: t('registerDemo.billingTemplateSppBulanan') },
  { v: 'uang_gedung', label: t('registerDemo.billingTemplateUangGedung') },
  { v: 'seragam', label: t('registerDemo.billingTemplateSeragam') },
  { v: 'buku_paket', label: t('registerDemo.billingTemplateBukuPaket') },
  { v: 'uts_uas', label: t('registerDemo.billingTemplateUtsUas') },
  { v: 'ekstrakurikuler', label: t('registerDemo.billingTemplateEkstrakurikuler') },
]);

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

function toggleTemplate(tpl: DemoBillingTemplate) {
  const set = new Set(templates.value);
  if (set.has(tpl)) set.delete(tpl);
  else set.add(tpl);
  templates.value = Array.from(set);
}

const formattedNominal = computed(() =>
  new Intl.NumberFormat('id-ID').format(nominal.value),
);
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.stepCounter', { current: wizard.stepNumber, total: wizard.stepTotal }) }} · {{ t('registerDemo.step10Label') }}
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      {{ t('registerDemo.step10Title') }}
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">{{ t('registerDemo.step10Subtitle') }}</p>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.step10TemplateLabel') }}
    </p>
    <div class="flex flex-wrap gap-1.5 mb-5">
      <button
        v-for="tpl in TEMPLATES"
        :key="tpl.v"
        type="button"
        class="px-3 py-1.5 rounded-full text-[12px] font-bold transition border"
        :class="
          templates.includes(tpl.v)
            ? 'bg-role-admin text-white border-role-admin'
            : 'bg-white text-slate-700 border-slate-300 hover:border-slate-400'
        "
        @click="toggleTemplate(tpl.v)"
      >
        {{ tpl.label }}
      </button>
    </div>

    <template v-if="templates.includes('spp_bulanan')">
      <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
        {{ t('registerDemo.step10SppLabel') }}
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
      {{ t('registerDemo.step10ScenarioLabel') }}
    </p>
    <div class="grid grid-cols-2 gap-3">
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="mode === 'build_year' ? 'border-2 border-role-admin bg-role-admin/10' : 'border-slate-300 bg-white hover:border-slate-400'"
        @click="mode = 'build_year'"
      >
        <NavIcon name="rocket" :size="22" :class="mode === 'build_year' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">{{ t('registerDemo.step10BuildYear') }}</div>
        <div class="text-[11px]" :class="mode === 'build_year' ? 'text-role-admin' : 'text-slate-500'">
          {{ t('registerDemo.step10BuildYearHint') }}
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
          {{ t('registerDemo.step10SkipHint') }}
        </div>
      </button>
    </div>
  </div>
</template>

<!--
  PricingCalculator.vue — Bulanan/Tahunan toggle + two sliders +
  live cost breakdown.

  All state is pushed up to the parent (SubscribeView) via v-model so
  the signup card + subscribe payload can read the same numbers. This
  component is pure UI + local formatting; it never calls the API.

  Sliders:
    - Siswa (0 - 2000, step 10, default 500)
    - Guru/Tutor/Staf (0 - 200, step 1, default 30)
  Label swaps based on tenantType (sekolah → "Guru dan staf",
  bimbel → "Tutor dan staf").

  Toggle:
    - Bulanan (monthly)
    - Tahunan (yearly, with "hemat 20%" green pill; discount comes
      from the plan payload so the pill text stays in sync with the
      backend rate)
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import type {
  BillingPeriod,
  PricingPlan,
  TenantType,
} from '@/types/subscription-billing';

const props = defineProps<{
  plan: PricingPlan;
  tenantType: TenantType;
  studentCount: number;
  staffCount: number;
  period: BillingPeriod;
  /** True when we're topping up an existing tenant (banner shows the
   *  tenant's current counts and we lock the sliders' initial values).
   *  We don't disable the sliders — the user may want to project a
   *  higher usage — but the caption reflects the source. */
  fromExistingTenant: boolean;
}>();

const emit = defineEmits<{
  'update:studentCount': [number];
  'update:staffCount': [number];
  'update:period': [BillingPeriod];
}>();

const { t } = useI18n();

const currency = computed(() => props.plan.currency || 'IDR');

// Format `12345` → `Rp 12.345`. Uses id-ID grouping which matches the
// mockup ("Rp 5.000") — the app-wide default across other billing
// screens too, so it's consistent with the parent SPP surface.
function money(v: number): string {
  const n = Math.max(0, Math.round(v));
  const grouped = new Intl.NumberFormat('id-ID').format(n);
  const prefix = currency.value === 'IDR' ? 'Rp' : currency.value;
  return `${prefix} ${grouped}`;
}

const studentSubtotal = computed(
  () => props.studentCount * props.plan.price_per_student,
);
const staffSubtotal = computed(
  () => props.staffCount * props.plan.price_per_staff,
);
const monthlyAmount = computed(() => studentSubtotal.value + staffSubtotal.value);
const yearlyGross = computed(() => monthlyAmount.value * 12);
const yearlyDiscount = computed(
  () => (yearlyGross.value * props.plan.yearly_discount_pct) / 100,
);
const yearlyAmount = computed(() => yearlyGross.value - yearlyDiscount.value);

const activeAmount = computed(() =>
  props.period === 'yearly' ? yearlyAmount.value : monthlyAmount.value,
);
const periodLabel = computed(() =>
  props.period === 'yearly'
    ? t('subscribe.calc.perYear')
    : t('subscribe.calc.perMonth'),
);

const staffLabel = computed(() =>
  props.tenantType === 'bimbel'
    ? t('subscribe.calc.staffLabelBimbel')
    : t('subscribe.calc.staffLabelSekolah'),
);
const staffUnitLabel = computed(() =>
  props.tenantType === 'bimbel'
    ? t('subscribe.calc.unitTutor')
    : t('subscribe.calc.unitStaff'),
);

function onSliderInput(kind: 'student' | 'staff', ev: Event) {
  const v = Number((ev.target as HTMLInputElement).value);
  if (!Number.isFinite(v)) return;
  if (kind === 'student') emit('update:studentCount', v);
  else emit('update:staffCount', v);
}

function setPeriod(p: BillingPeriod) {
  if (p !== props.period) emit('update:period', p);
}
</script>

<template>
  <section class="rounded-2xl border border-slate-200 bg-white p-5 sm:p-6">
    <!-- Toggle: Bulanan / Tahunan -->
    <div class="flex items-center justify-center mb-5">
      <div class="inline-flex rounded-full bg-slate-100 p-1">
        <button
          type="button"
          class="px-4 py-1.5 rounded-full text-sm font-semibold transition-colors"
          :class="period === 'monthly'
            ? 'bg-white text-slate-900 shadow-sm'
            : 'text-slate-500 hover:text-slate-700'"
          @click="setPeriod('monthly')"
        >
          {{ t('subscribe.calc.monthly') }}
        </button>
        <button
          type="button"
          class="relative px-4 py-1.5 rounded-full text-sm font-semibold transition-colors"
          :class="period === 'yearly'
            ? 'bg-white text-slate-900 shadow-sm'
            : 'text-slate-500 hover:text-slate-700'"
          @click="setPeriod('yearly')"
        >
          {{ t('subscribe.calc.yearly') }}
          <span
            class="ml-1.5 inline-flex items-center rounded-full bg-emerald-100 text-emerald-700 px-1.5 py-0.5 text-[10px] font-bold"
          >
            {{ t('subscribe.calc.savePctPill', { pct: plan.yearly_discount_pct }) }}
          </span>
        </button>
      </div>
    </div>

    <header class="mb-4">
      <p class="text-[11px] font-black tracking-[0.24em] uppercase text-brand-cobalt">
        {{ t('subscribe.calc.kicker') }}
      </p>
      <h2 class="text-lg font-bold text-slate-900 mt-1">
        {{ t('subscribe.calc.title') }}
      </h2>
    </header>

    <!-- Sliders -->
    <div class="space-y-5">
      <div>
        <div class="flex items-baseline justify-between mb-1.5">
          <label class="text-sm font-semibold text-slate-800">
            {{ t('subscribe.calc.studentLabel') }}
          </label>
          <span class="text-sm font-bold text-slate-900 tabular-nums">
            {{ studentCount }}
            <span class="text-xs font-normal text-slate-500 ml-1">
              {{ t('subscribe.calc.unitStudent') }}
            </span>
          </span>
        </div>
        <input
          type="range"
          min="0"
          max="2000"
          step="10"
          :value="studentCount"
          class="w-full accent-brand-cobalt"
          @input="onSliderInput('student', $event)"
        />
        <div class="mt-1 flex justify-between text-[10px] text-slate-400">
          <span>0</span>
          <span>2.000</span>
        </div>
      </div>

      <div>
        <div class="flex items-baseline justify-between mb-1.5">
          <label class="text-sm font-semibold text-slate-800">
            {{ staffLabel }}
          </label>
          <span class="text-sm font-bold text-slate-900 tabular-nums">
            {{ staffCount }}
            <span class="text-xs font-normal text-slate-500 ml-1">
              {{ staffUnitLabel }}
            </span>
          </span>
        </div>
        <input
          type="range"
          min="0"
          max="200"
          step="1"
          :value="staffCount"
          class="w-full accent-brand-cobalt"
          @input="onSliderInput('staff', $event)"
        />
        <div class="mt-1 flex justify-between text-[10px] text-slate-400">
          <span>0</span>
          <span>200</span>
        </div>
      </div>
    </div>

    <!-- Bottom split: TAGIHAN AKTIF · RINCIAN -->
    <div class="mt-6 grid grid-cols-1 md:grid-cols-2 rounded-xl border border-slate-200 overflow-hidden">
      <div class="p-4 sm:p-5 bg-gradient-to-br from-brand-cobalt to-brand-dark-blue text-white">
        <p class="text-[10px] font-black tracking-[0.24em] uppercase text-white/70">
          {{ t('subscribe.calc.activeTitle') }}
        </p>
        <p class="mt-1.5 text-2xl sm:text-3xl font-black leading-none tabular-nums">
          {{ money(activeAmount) }}
        </p>
        <p class="mt-1 text-xs text-white/70">
          {{ periodLabel }}
        </p>
        <p
          v-if="fromExistingTenant"
          class="mt-3 text-[11px] leading-relaxed text-white/80"
        >
          {{ t('subscribe.calc.demoNote') }}
        </p>
      </div>
      <div class="p-4 sm:p-5 bg-slate-50">
        <p class="text-[10px] font-black tracking-[0.24em] uppercase text-slate-500">
          {{ t('subscribe.calc.breakdownTitle') }}
        </p>
        <dl class="mt-2 space-y-1.5 text-[13px]">
          <div class="flex items-baseline justify-between gap-2">
            <dt class="text-slate-600">
              {{ t('subscribe.calc.breakdownStudent', {
                count: studentCount,
                unit: money(plan.price_per_student),
              }) }}
            </dt>
            <dd class="font-semibold text-slate-800 tabular-nums">
              {{ money(studentSubtotal) }}
            </dd>
          </div>
          <div class="flex items-baseline justify-between gap-2">
            <dt class="text-slate-600">
              {{ t('subscribe.calc.breakdownStaff', {
                count: staffCount,
                unit: money(plan.price_per_staff),
                label: staffUnitLabel,
              }) }}
            </dt>
            <dd class="font-semibold text-slate-800 tabular-nums">
              {{ money(staffSubtotal) }}
            </dd>
          </div>
          <div class="pt-1.5 mt-1 border-t border-slate-200 flex items-baseline justify-between gap-2">
            <dt class="text-slate-500 text-xs">
              {{ t('subscribe.calc.monthlyLine') }}
            </dt>
            <dd class="font-semibold text-slate-800 tabular-nums">
              {{ money(monthlyAmount) }}
            </dd>
          </div>
          <div v-if="period === 'yearly'" class="flex items-baseline justify-between gap-2">
            <dt class="text-emerald-600 text-xs font-semibold">
              {{ t('subscribe.calc.yearlyDiscountLine', { pct: plan.yearly_discount_pct }) }}
            </dt>
            <dd class="font-semibold text-emerald-700 tabular-nums">
              −{{ money(yearlyDiscount) }}
            </dd>
          </div>
        </dl>
      </div>
    </div>
  </section>
</template>

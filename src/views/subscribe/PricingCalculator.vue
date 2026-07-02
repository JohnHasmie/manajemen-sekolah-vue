<!--
  PricingCalculator.vue — Bulanan/Tahunan toggle + two sliders +
  live cost breakdown.

  All state is pushed up to the parent (SubscribeView) via v-model so
  the signup card + subscribe payload can read the same numbers. This
  component is pure UI + local formatting; it never calls the API.

  Sliders + custom inputs:
    - Siswa: slider 0–2000 (step 10, default 500) + free-form number
      input alongside that can go up to 100_000 (the backend's hard
      max on `student_count`). When the typed value exceeds 2000 the
      slider max grows to the current value so the thumb stays
      draggable and stops feeling stuck at "2.000".
    - Guru/Tutor/Staf: same shape, 0–200 slider (step 1, default 30),
      input up to 100_000.
  Label swaps based on tenantType (sekolah → "Guru dan staf",
  bimbel → "Tutor dan staf").

  Locked mode (`locked=true`):
    - The user submitted and a pending bank-transfer order was
      created upstream. Adjusting seats now WITHOUT explicitly
      re-submitting would silently desync the calculator from the
      amount printed on the transfer instructions, so we grey the
      controls out. The parent shows an "Ubah pesanan" affordance to
      leave locked mode.

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
  /** Freeze the inputs after the user submitted and a pending order
   *  was created. Parent unlocks via a dedicated "Ubah pesanan" flow. */
  locked?: boolean;
}>();

const emit = defineEmits<{
  'update:studentCount': [number];
  'update:staffCount': [number];
  'update:period': [BillingPeriod];
}>();

// Slider "typical" caps — most tenants sit under these, so we
// keep the visual scale (0 → 2.000 / 0 → 200) meaningful.
const STUDENT_SLIDER_BASE = 2000;
const STAFF_SLIDER_BASE = 200;
// Backend guardrail (CreateSubscriptionRequest validates
// student_count/staff_count max=100000). Custom inputs cap here.
const HARD_MAX = 100_000;

/**
 * Give the slider enough headroom to represent the current value.
 * Without this the slider silently pins to 2.000 while the input
 * shows 3.500 — user drags but sees no change.
 */
const studentSliderMax = computed(() =>
  Math.max(STUDENT_SLIDER_BASE, props.studentCount || 0),
);
const staffSliderMax = computed(() =>
  Math.max(STAFF_SLIDER_BASE, props.staffCount || 0),
);

function grouped(n: number): string {
  return new Intl.NumberFormat('id-ID').format(n);
}

const studentSliderMaxLabel = computed(() => grouped(studentSliderMax.value));
const staffSliderMaxLabel = computed(() => grouped(staffSliderMax.value));

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

function clampCount(raw: number): number {
  if (!Number.isFinite(raw)) return 0;
  return Math.max(0, Math.min(HARD_MAX, Math.round(raw)));
}

function onSliderInput(kind: 'student' | 'staff', ev: Event) {
  if (props.locked) return;
  const v = clampCount(Number((ev.target as HTMLInputElement).value));
  if (kind === 'student') emit('update:studentCount', v);
  else emit('update:staffCount', v);
}

/**
 * Number-input onInput handler. Uses valueAsNumber so an empty field
 * reads back as NaN → collapses to 0 (rather than throwing the price
 * to NaN → "Rp NaN"). Callers still see the raw input onscreen; the
 * emitted value is what we commit to state.
 */
function onNumberInput(kind: 'student' | 'staff', ev: Event) {
  if (props.locked) return;
  const target = ev.target as HTMLInputElement;
  const v = clampCount(target.valueAsNumber);
  if (kind === 'student') emit('update:studentCount', v);
  else emit('update:staffCount', v);
}

/**
 * Rehydrate the input display when the user tabs out. If they had
 * typed a value above HARD_MAX, the emitted state was already
 * clamped — pushing that clamped value back into the DOM makes the
 * ceiling visible.
 */
function onNumberBlur(kind: 'student' | 'staff', ev: Event) {
  const target = ev.target as HTMLInputElement;
  const committed = kind === 'student' ? props.studentCount : props.staffCount;
  target.value = String(committed);
}

function setPeriod(p: BillingPeriod) {
  if (props.locked) return;
  if (p !== props.period) emit('update:period', p);
}
</script>

<template>
  <section class="rounded-2xl border border-slate-200 bg-white p-5 sm:p-6">
    <!-- Toggle: Bulanan / Tahunan -->
    <div class="flex items-center justify-center mb-5">
      <div
        class="inline-flex rounded-full bg-slate-100 p-1"
        :class="locked ? 'opacity-60 pointer-events-none' : ''"
      >
        <button
          type="button"
          :disabled="locked"
          class="px-4 py-1.5 rounded-full text-sm font-semibold transition-colors disabled:cursor-not-allowed"
          :class="period === 'monthly'
            ? 'bg-white text-slate-900 shadow-sm'
            : 'text-slate-500 hover:text-slate-700'"
          @click="setPeriod('monthly')"
        >
          {{ t('subscribe.calc.monthly') }}
        </button>
        <button
          type="button"
          :disabled="locked"
          class="relative px-4 py-1.5 rounded-full text-sm font-semibold transition-colors disabled:cursor-not-allowed"
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

    <!-- Sliders + custom number input -->
    <div class="space-y-5" :class="locked ? 'opacity-60 pointer-events-none select-none' : ''">
      <div>
        <div class="flex items-center justify-between gap-3 mb-1.5">
          <label class="text-sm font-semibold text-slate-800">
            {{ t('subscribe.calc.studentLabel') }}
          </label>
          <div class="flex items-center gap-2">
            <input
              type="number"
              min="0"
              :max="HARD_MAX"
              step="1"
              inputmode="numeric"
              :value="studentCount"
              :disabled="locked"
              class="w-24 rounded-lg border border-slate-300 px-2.5 py-1 text-sm font-bold text-slate-900 tabular-nums text-right focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none disabled:bg-slate-50 disabled:cursor-not-allowed"
              @input="onNumberInput('student', $event)"
              @blur="onNumberBlur('student', $event)"
            />
            <span class="text-xs text-slate-500">
              {{ t('subscribe.calc.unitStudent') }}
            </span>
          </div>
        </div>
        <input
          type="range"
          min="0"
          :max="studentSliderMax"
          step="10"
          :value="studentCount"
          :disabled="locked"
          class="w-full accent-brand-cobalt disabled:cursor-not-allowed"
          @input="onSliderInput('student', $event)"
        />
        <div class="mt-1 flex justify-between text-[10px] text-slate-400">
          <span>0</span>
          <span>{{ studentSliderMaxLabel }}</span>
        </div>
      </div>

      <div>
        <div class="flex items-center justify-between gap-3 mb-1.5">
          <label class="text-sm font-semibold text-slate-800">
            {{ staffLabel }}
          </label>
          <div class="flex items-center gap-2">
            <input
              type="number"
              min="0"
              :max="HARD_MAX"
              step="1"
              inputmode="numeric"
              :value="staffCount"
              :disabled="locked"
              class="w-24 rounded-lg border border-slate-300 px-2.5 py-1 text-sm font-bold text-slate-900 tabular-nums text-right focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none disabled:bg-slate-50 disabled:cursor-not-allowed"
              @input="onNumberInput('staff', $event)"
              @blur="onNumberBlur('staff', $event)"
            />
            <span class="text-xs text-slate-500">
              {{ staffUnitLabel }}
            </span>
          </div>
        </div>
        <input
          type="range"
          min="0"
          :max="staffSliderMax"
          step="1"
          :value="staffCount"
          :disabled="locked"
          class="w-full accent-brand-cobalt disabled:cursor-not-allowed"
          @input="onSliderInput('staff', $event)"
        />
        <div class="mt-1 flex justify-between text-[10px] text-slate-400">
          <span>0</span>
          <span>{{ staffSliderMaxLabel }}</span>
        </div>
      </div>
    </div>

    <p v-if="locked" class="mt-3 text-[11px] text-slate-500 leading-relaxed">
      {{ t('subscribe.calc.lockedNotice') }}
    </p>

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

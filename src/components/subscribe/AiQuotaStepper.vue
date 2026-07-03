<!--
  AiQuotaStepper.vue — expanded state of a selected AI module card
  with a slider that lets the customer bump the monthly quota in +10
  steps. No model name, no "cheap" language — just price and quota.

  Emits `update:quota` (extra generates over the base) so the parent's
  ai_quota map + quote refresh stays in sync.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { ModuleCatalogItem } from '@/types/subscription-billing';
import {
  CATEGORY_TINTS,
  MODULE_ICONS,
  MODULE_TAGLINES,
  money,
} from './moduleTokens';

const props = defineProps<{
  item: ModuleCatalogItem;
  monthlyBase: number;
  stepUnitPrice: number;
  topupUnitPrice: number;
  staffCount: number;
  /** Total quota the user is choosing = base + extra bumps. */
  totalQuota: number;
}>();

const emit = defineEmits<{
  'update:quota': [extra: number];
}>();

const tint = computed(
  () => CATEGORY_TINTS[props.item.group] ?? CATEGORY_TINTS.Default,
);
const icon = computed(() => MODULE_ICONS[props.item.key] ?? 'sparkles');
const tagline = computed(
  () => MODULE_TAGLINES[props.item.key] ?? props.item.label,
);

const extraGenerates = computed(() =>
  Math.max(0, props.totalQuota - props.monthlyBase),
);

// Slider steps: 0, 10, 20, 30, 40, 50, 60+ over the base.
const MAX_EXTRA = 60;
const percent = computed(() =>
  Math.min(100, (extraGenerates.value / MAX_EXTRA) * 100),
);

const ticks = computed(() => {
  const step = 10;
  const arr: number[] = [];
  for (let i = 0; i <= MAX_EXTRA + step; i += step) {
    arr.push(props.monthlyBase + i);
  }
  return arr;
});

const stepCount = computed(() => Math.ceil(extraGenerates.value / 10));
const quotaUpgradeMonthly = computed(
  () => stepCount.value * props.stepUnitPrice,
);
const baseAccessMonthly = computed(
  () => props.item.price_per_staff, // base price/staff/month
);
const totalPerStaff = computed(
  () => baseAccessMonthly.value + quotaUpgradeMonthly.value,
);
const totalMonthly = computed(() => totalPerStaff.value * props.staffCount);

function onSlide(evt: Event) {
  const raw = parseInt((evt.target as HTMLInputElement).value, 10);
  emit('update:quota', Math.max(0, raw));
}
</script>

<template>
  <div class="aq-card">
    <div class="aq-glow" />

    <div class="aq-head">
      <div class="aq-icon" :style="{ background: tint.bg, color: tint.fg }">
        <i :class="`ti ti-${icon}`" aria-hidden="true" />
      </div>
      <div class="aq-body">
        <div class="aq-title">{{ item.label }}</div>
        <div class="aq-desc">{{ tagline }}</div>
      </div>
      <div class="aq-check">
        <i class="ti ti-check" aria-hidden="true" />
      </div>
    </div>

    <div class="aq-quota-block">
      <div class="aq-quota-head">
        <div>
          <div class="aq-quota-lbl">Kuota per guru per bulan</div>
          <div class="aq-quota-hint">
            Termasuk {{ monthlyBase }} gratis · +10 = {{ money(stepUnitPrice) }} / guru / bln
          </div>
        </div>
        <div class="aq-quota-val">
          {{ totalQuota }}<span class="u">generate</span>
        </div>
      </div>

      <div class="aq-slider">
        <input
          type="range"
          :min="0"
          :max="MAX_EXTRA"
          :step="10"
          :value="extraGenerates"
          @input="onSlide"
        />
        <div class="aq-slider-visual">
          <div class="aq-slider-track">
            <div
              class="aq-slider-fill"
              :style="{ width: `${percent}%` }"
            />
            <div
              class="aq-slider-thumb"
              :style="{ left: `${percent}%` }"
            />
          </div>
          <div class="aq-slider-ticks">
            <span
              v-for="(t, i) in ticks"
              :key="i"
              :class="{ 'is-cur': t === totalQuota }"
            >{{ t }}</span>
          </div>
        </div>
      </div>

      <div class="aq-impact">
        <div class="aq-impact-tile">
          <div class="aq-impact-lbl">Akses / guru</div>
          <div class="aq-impact-val">
            {{ money(baseAccessMonthly) }}<span class="u"> / bln</span>
          </div>
        </div>
        <div class="aq-impact-tile">
          <div class="aq-impact-lbl">Kuota +{{ stepCount * 10 }}</div>
          <div class="aq-impact-val">
            {{ money(quotaUpgradeMonthly) }}<span class="u"> / bln</span>
          </div>
        </div>
        <div class="aq-impact-tile is-hi">
          <div class="aq-impact-lbl">
            Total {{ item.label }} untuk {{ staffCount }} guru
          </div>
          <div class="aq-impact-val big">
            {{ money(totalMonthly) }}<span class="u"> / bln</span>
          </div>
        </div>
      </div>
    </div>

    <div class="aq-foot">
      <i class="ti ti-info-circle" aria-hidden="true" />
      <div>
        Kalau kuota habis di tengah bulan, guru bisa top up bebas —
        <strong>{{ money(topupUnitPrice) }}</strong> per generate ekstra,
        hangus akhir bulan. Bulan depan kuota kembali ke
        <strong>{{ totalQuota }}</strong>.
      </div>
    </div>
  </div>
</template>

<style scoped>
.aq-card {
  background: #FFFFFF;
  border: 1.5px solid #1B6FB8;
  border-radius: 14px;
  padding: 14px 16px 16px;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04),
              0 8px 24px rgba(27, 111, 184, 0.08);
  position: relative; overflow: hidden;
}
.aq-glow {
  position: absolute; top: -40px; right: -40px;
  width: 160px; height: 160px;
  background: radial-gradient(circle, rgba(27, 111, 184, 0.06) 0%, transparent 70%);
  pointer-events: none;
}

.aq-head { display: flex; align-items: flex-start; gap: 12px; position: relative; }
.aq-icon {
  width: 44px; height: 44px; border-radius: 12px;
  display: grid; place-items: center;
  font-size: 22px;
  flex-shrink: 0;
}
.aq-body { flex: 1; min-width: 0; }
.aq-title { font-size: 15px; font-weight: 500; letter-spacing: -0.1px; color: #0F172A; }
.aq-desc {
  font-size: 12px; color: #64748B;
  margin-top: 4px; line-height: 1.55;
}

.aq-check {
  margin-left: auto;
  width: 22px; height: 22px; border-radius: 6px;
  background: #1B6FB8; color: #fff;
  display: grid; place-items: center;
  flex-shrink: 0;
  font-size: 14px;
}

.aq-quota-block {
  margin-top: 14px;
  background: #F5F8FC;
  border-radius: 10px;
  padding: 12px 14px;
  position: relative;
}
.aq-quota-head { display: flex; justify-content: space-between; align-items: flex-end; }
.aq-quota-lbl {
  font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px;
  color: #64748B; font-weight: 500;
}
.aq-quota-hint { font-size: 10.5px; color: #94A3B8; margin-top: 2px; }
.aq-quota-val {
  font-size: 22px; font-weight: 600; color: #113E75;
  letter-spacing: -0.4px; text-align: right;
}
.aq-quota-val .u {
  font-size: 11px; font-weight: 400;
  color: #64748B; margin-left: 3px;
}

.aq-slider { margin-top: 14px; position: relative; }
.aq-slider input[type='range'] {
  position: absolute; inset: 0;
  opacity: 0; cursor: pointer; margin: 0;
  width: 100%; height: 100%;
}
.aq-slider-visual { pointer-events: none; }
.aq-slider-track {
  position: relative; height: 6px;
  background: #E2E8F0; border-radius: 3px;
}
.aq-slider-fill {
  position: absolute; left: 0; top: 0; bottom: 0;
  background: linear-gradient(90deg, #1B6FB8 0%, #378ADD 100%);
  border-radius: 3px;
  transition: width 0.15s;
}
.aq-slider-thumb {
  position: absolute; top: 50%;
  width: 18px; height: 18px; border-radius: 50%;
  background: #FFFFFF; border: 3px solid #1B6FB8;
  transform: translate(-50%, -50%);
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.15);
  transition: left 0.15s;
}
.aq-slider-ticks {
  display: flex; justify-content: space-between;
  margin-top: 8px;
  font-size: 10px; color: #94A3B8;
}
.aq-slider-ticks .is-cur { color: #1B6FB8; font-weight: 500; }

.aq-impact {
  margin-top: 14px; padding-top: 12px;
  border-top: 0.5px solid #E7ECF3;
  display: grid; grid-template-columns: 1fr 1fr; gap: 10px;
}
.aq-impact-tile {
  background: #FFFFFF;
  border: 0.5px solid #E7ECF3; border-radius: 10px;
  padding: 10px 12px;
}
.aq-impact-tile.is-hi { grid-column: span 2; background: #F0F7FF; border-color: #B5D4F4; }
.aq-impact-lbl {
  font-size: 10px; text-transform: uppercase; letter-spacing: 0.4px;
  color: #94A3B8; font-weight: 500;
}
.aq-impact-val {
  font-size: 14px; font-weight: 500; color: #0F172A;
  margin-top: 3px; font-variant-numeric: tabular-nums;
}
.aq-impact-val.big { font-size: 18px; color: #113E75; }
.aq-impact-val .u {
  font-size: 10.5px; color: #64748B; font-weight: 400;
  margin-left: 2px;
}

.aq-foot {
  display: flex; align-items: flex-start; gap: 8px;
  margin-top: 14px;
  padding: 10px 12px;
  background: #FEF3C7;
  border-radius: 10px;
  border: 0.5px solid #FDE68A;
  color: #78350F;
}
.aq-foot .ti { color: #B45309; font-size: 15px; flex-shrink: 0; margin-top: 1px; }
.aq-foot div {
  font-size: 11px; line-height: 1.55;
}
.aq-foot strong { font-weight: 600; }
</style>

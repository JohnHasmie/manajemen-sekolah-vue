<!--
  DiscountAppliedCard.vue — the green "applied" state below the total
  in PricingCalculatorV2. Matches the approved mockup:

    • Green pill row: check + CODE + [-20%] chip + remove ✕
    • Description string (pulled from the code's `description` field —
      that's the "informasi terkait discount" Yahya asked for)
    • Meta row: duration months / valid until / used_count / max_uses

  Kept as its own component so the sidebar can render it in exactly
  ONE place, with a stable snapshot, even if the user is still
  editing plan / modules.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { AppliedDiscount } from '@/types/subscription-billing';
import { money } from './moduleTokens';

const props = defineProps<{
  discount: AppliedDiscount;
}>();

const emit = defineEmits<{ remove: [] }>();

const pctPill = computed(() => {
  return props.discount.type === 'percent'
    ? `-${props.discount.value}%`
    : `-${money(props.discount.value)}`;
});

const durationLabel = computed(() => {
  const m = props.discount.duration_months;
  if (m === null) return 'Seumur langganan';
  return `${m} bulan`;
});

const validUntilLabel = computed(() => {
  const s = props.discount.valid_until;
  if (!s) return null;
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return null;
  return d.toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
});

const usageLabel = computed(() => {
  if (props.discount.max_uses === null) return null;
  return `${props.discount.used_count}/${props.discount.max_uses} terpakai`;
});
</script>

<template>
  <div class="dac-root">
    <div class="dac-head">
      <span class="dac-icon">✓</span>
      <span class="dac-code">{{ discount.code }}</span>
      <span class="dac-pct">{{ pctPill }}</span>
      <button
        type="button"
        class="dac-x"
        title="Hapus kode"
        @click="emit('remove')"
      >
        ✕
      </button>
    </div>

    <p class="dac-desc">{{ discount.description }}</p>

    <div class="dac-meta">
      <span class="dac-meta-item">
        <span class="dac-meta-ico">⏱</span>{{ durationLabel }}
      </span>
      <span v-if="validUntilLabel" class="dac-meta-item">
        <span class="dac-meta-ico">📅</span>sd {{ validUntilLabel }}
      </span>
      <span v-if="usageLabel" class="dac-meta-item">
        <span class="dac-meta-ico">👥</span>{{ usageLabel }}
      </span>
    </div>
  </div>
</template>

<style scoped>
.dac-root {
  margin-top: 10px;
  background: #F0FDF4;
  border: 1px solid #DCFCE7;
  border-radius: 10px;
  padding: 10px 12px;
}
.dac-head { display: flex; align-items: center; gap: 8px; }
.dac-icon {
  width: 22px; height: 22px; border-radius: 6px;
  background: #16A34A; color: #fff;
  display: grid; place-items: center;
  font-size: 12px; font-weight: 900;
  flex-shrink: 0;
}
.dac-code {
  font-size: 12px; font-weight: 800;
  color: #166534;
  letter-spacing: 0.5px;
  font-family: -apple-system, "SF Pro Text", monospace;
}
.dac-pct {
  background: #16A34A; color: #fff;
  font-size: 10px; font-weight: 800;
  padding: 3px 6px; border-radius: 4px;
  margin-left: 2px;
}
.dac-x {
  margin-left: auto;
  width: 22px; height: 22px;
  display: grid; place-items: center;
  color: #15803D; font-size: 12px;
  cursor: pointer; border-radius: 5px;
  border: none; background: transparent;
  transition: background 0.12s;
}
.dac-x:hover { background: rgba(21, 128, 61, 0.08); }

.dac-desc {
  margin-top: 8px; padding-top: 8px;
  border-top: 0.5px solid #DCFCE7;
  font-size: 10.5px; line-height: 1.5;
  color: #166534;
}

.dac-meta {
  margin-top: 6px;
  display: flex; gap: 10px; flex-wrap: wrap;
  font-size: 9.5px; font-weight: 700;
  color: #15803D;
}
.dac-meta-item { display: inline-flex; align-items: center; gap: 3px; }
.dac-meta-ico { font-size: 10px; }
</style>

<!--
  ModuleRow.vue — compact stacked row used inside a bordered card in
  the /subscribe conversion flow. Matches mockup 2's `.sc-modrow`.

  Same tint + tagline lookups as ModuleCard but with a toggle-switch
  visual affordance suited to a stacked list.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { ModuleCatalogItem } from '@/types/subscription-billing';
import {
  CATEGORY_TINTS,
  MODULE_ICONS,
  moduleLabel,
  moduleTagline,
  money,
  seatUnit,
} from './moduleTokens';

const props = defineProps<{
  item: ModuleCatalogItem;
  selected: boolean;
  tenantType?: 'sekolah' | 'bimbel' | null;
}>();

defineEmits<{ toggle: [] }>();

const tint = computed(
  () => CATEGORY_TINTS[props.item.group] ?? CATEGORY_TINTS.Default,
);
const icon = computed(() => MODULE_ICONS[props.item.key] ?? 'circle-plus');
const label = computed(() => moduleLabel(props.item, props.tenantType));
const tagline = computed(() => moduleTagline(props.item, props.tenantType));
const price = computed(() =>
  props.item.pricing_seat === 'staff'
    ? props.item.price_per_staff
    : props.item.price_per_student,
);
const unit = computed(() => seatUnit(props.item, props.tenantType));
</script>

<template>
  <button
    type="button"
    class="mr-row"
    :class="{ 'is-on': selected }"
    @click="$emit('toggle')"
  >
    <div
      class="mr-icon"
      :style="{ background: tint.bg, color: tint.fg }"
    >
      <i :class="`ti ti-${icon}`" aria-hidden="true" />
    </div>
    <div class="mr-body">
      <div class="mr-title">{{ label }}</div>
      <div class="mr-desc">{{ tagline }}</div>
    </div>
    <div class="mr-price">
      {{ money(price) }}
      <span class="u">{{ unit }}</span>
    </div>
    <div class="mr-tog" />
  </button>
</template>

<style scoped>
.mr-row {
  padding: 12px 14px;
  display: flex; align-items: center; gap: 12px;
  border-bottom: 0.5px solid #F1F5F9;
  cursor: pointer;
  width: 100%; text-align: left;
  background: transparent;
  border-left: none; border-right: none; border-top: none;
  transition: background 0.15s;
}
.mr-row:last-child { border-bottom: none; }
.mr-row:hover { background: #FBFDFF; }
.mr-row.is-on { background: #F0F7FF; }

.mr-icon {
  width: 32px; height: 32px; border-radius: 8px;
  display: grid; place-items: center;
  font-size: 16px;
  flex-shrink: 0;
}
.mr-body { flex: 1; min-width: 0; }
.mr-title { font-size: 12.5px; font-weight: 500; color: #0F172A; }
.mr-desc { font-size: 10.5px; color: #64748B; margin-top: 1px; }

.mr-price {
  font-size: 12px; font-weight: 500; text-align: right;
  font-variant-numeric: tabular-nums; color: #0F172A;
}
.mr-price .u {
  display: block; font-size: 10px;
  color: #64748B; font-weight: 400;
}

.mr-tog {
  width: 34px; height: 20px; border-radius: 999px;
  background: #CBD5E1; position: relative;
  transition: background 0.15s;
  flex-shrink: 0;
}
.mr-tog::after {
  content: '';
  position: absolute; top: 2px; left: 2px;
  width: 16px; height: 16px;
  background: #FFFFFF; border-radius: 50%;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.15);
  transition: left 0.15s;
}
.mr-row.is-on .mr-tog { background: #1B6FB8; }
.mr-row.is-on .mr-tog::after { left: 16px; }
</style>

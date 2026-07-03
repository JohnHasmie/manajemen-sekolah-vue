<!--
  BundleStrip.vue — "Rekomendasi · Paket Lengkap" horizontal card that
  sits above the module catalog. Matches mockup 1's blue bundle strip.

  Click emits `select` so the parent can toggle bundle selection.
-->
<script setup lang="ts">
import { money } from './moduleTokens';

const props = defineProps<{
  label: string;
  description: string;
  pricePerStudent: number;
  seatUnit?: string;
  active?: boolean;
}>();

defineEmits<{
  select: [];
}>();
</script>

<template>
  <button
    type="button"
    class="bs-root"
    :class="{ 'is-active': active }"
    @click="$emit('select')"
  >
    <div class="bs-icon">
      <i class="ti ti-package" aria-hidden="true" />
    </div>
    <div class="bs-body">
      <div class="bs-title-row">
        <span class="bs-badge">Rekomendasi</span>
        <span class="bs-title">{{ label }}</span>
      </div>
      <div class="bs-desc">{{ description }}</div>
    </div>
    <div class="bs-price">
      {{ money(pricePerStudent) }}
      <span class="u">{{ seatUnit ?? 'per siswa / bln' }}</span>
    </div>
  </button>
</template>

<style scoped>
.bs-root {
  border: 0.5px solid #B5D4F4;
  background: linear-gradient(180deg, #F0F7FF 0%, #E7F1FE 100%);
  border-radius: 12px;
  padding: 12px 14px;
  margin: 0 0 16px;
  display: flex; align-items: center; gap: 12px;
  width: 100%;
  cursor: pointer; text-align: left;
  transition: box-shadow 0.15s, border-color 0.15s;
}
.bs-root:hover {
  box-shadow: 0 2px 6px rgba(27, 111, 184, 0.08),
              0 8px 20px rgba(27, 111, 184, 0.06);
}
.bs-root.is-active {
  border: 1.5px solid #1B6FB8;
  padding: 11.5px 13.5px;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.08);
}

.bs-icon {
  width: 32px; height: 32px; border-radius: 10px;
  background: #1B6FB8; color: #fff;
  display: grid; place-items: center;
  flex-shrink: 0;
}
.bs-icon .ti { font-size: 18px; }

.bs-body { flex: 1; min-width: 0; }
.bs-title-row {
  display: flex; align-items: center; gap: 6px;
  flex-wrap: wrap;
}
.bs-badge {
  background: #1B6FB8; color: #fff;
  font-size: 10px; font-weight: 600;
  letter-spacing: 0.4px;
  padding: 2px 8px; border-radius: 999px;
  text-transform: uppercase;
}
.bs-title { font-size: 12.5px; font-weight: 500; color: #113E75; }
.bs-desc { font-size: 11px; color: #185FA5; margin-top: 1px; }

.bs-price {
  font-size: 12.5px; font-weight: 600; color: #113E75;
  text-align: right;
  flex-shrink: 0;
}
.bs-price .u {
  display: block;
  font-size: 10px; color: #185FA5;
  font-weight: 400;
}
</style>

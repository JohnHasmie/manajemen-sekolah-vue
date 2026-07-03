<!--
  BundleNudge.vue — emerald recommendation banner that appears in the
  calculator when the à la carte total meets or exceeds the flat
  Paket Lengkap price. Matches mockup 2 (`subscribe_bundle_nudge`).

  Emits `switch` when the user clicks the primary CTA; parent replaces
  their selection with the bundle key.
-->
<script setup lang="ts">
import { money } from './moduleTokens';

defineProps<{
  alacarteTotal: number;
  bundleTotal: number;
  bonusModuleCount: number;
}>();

defineEmits<{
  switch: [];
  skip: [];
}>();
</script>

<template>
  <div class="bn-nudge">
    <div class="bn-nudge-row">
      <div class="bn-nudge-icon">
        <i class="ti ti-sparkles" aria-hidden="true" />
      </div>
      <div class="bn-nudge-body">
        <div class="bn-nudge-title">Paket Lengkap malah lebih hemat</div>
        <div class="bn-nudge-desc">
          Dengan pilihan Anda sekarang, biayanya
          <strong>{{ money(alacarteTotal) }}</strong>/bln. Paket Lengkap
          semua modul non-AI cuma
          <strong>{{ money(bundleTotal) }}</strong>/bln.
        </div>
        <div class="bn-savings-pill">
          <i class="ti ti-trending-down" aria-hidden="true" />
          Hemat {{ money(alacarteTotal - bundleTotal) }}/bln
          <template v-if="bonusModuleCount > 0">
            + dapat {{ bonusModuleCount }} modul bonus
          </template>
        </div>
      </div>
    </div>

    <div class="bn-swap-row">
      <div class="bn-swap-card">
        <div class="bn-swap-lbl">Pilihan Anda</div>
        <div class="bn-swap-val strike">{{ money(alacarteTotal) }}</div>
      </div>
      <div class="bn-swap-card is-primary">
        <div class="bn-swap-lbl">Paket Lengkap</div>
        <div class="bn-swap-val">{{ money(bundleTotal) }}</div>
      </div>
    </div>

    <button type="button" class="bn-nudge-btn" @click="$emit('switch')">
      <i class="ti ti-package" aria-hidden="true" />
      Ambil Paket Lengkap · hemat {{ money(alacarteTotal - bundleTotal) }}
    </button>
    <div class="bn-nudge-skip">
      Atau
      <button type="button" class="bn-nudge-skip-btn" @click="$emit('skip')">
        tetap pakai pilihan à la carte
      </button>
    </div>
  </div>
</template>

<style scoped>
.bn-nudge {
  margin: 4px 14px 12px;
  border-radius: 12px;
  background: linear-gradient(180deg, #E1F5EE 0%, #C6EDDD 100%);
  border: 0.5px solid #5DCAA5;
  padding: 14px 14px 12px;
  position: relative; overflow: hidden;
}
.bn-nudge::before {
  content: '';
  position: absolute; top: -20px; right: -20px;
  width: 80px; height: 80px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.55) 0%, transparent 70%);
  pointer-events: none;
}

.bn-nudge-row { display: flex; align-items: flex-start; gap: 10px; position: relative; }
.bn-nudge-icon {
  width: 32px; height: 32px; border-radius: 10px;
  background: #1D9E75; color: #fff;
  display: grid; place-items: center;
  flex-shrink: 0;
  font-size: 18px;
}
.bn-nudge-body { flex: 1; }
.bn-nudge-title {
  font-size: 13px; font-weight: 500; color: #085041;
}
.bn-nudge-desc {
  font-size: 11.5px; color: #0F6E56;
  margin-top: 3px; line-height: 1.5;
}
.bn-nudge-desc strong { font-weight: 600; }
.bn-savings-pill {
  display: inline-flex; align-items: center; gap: 4px;
  margin-top: 8px;
  background: rgba(255, 255, 255, 0.7);
  color: #085041;
  padding: 3px 8px; border-radius: 999px;
  font-size: 10.5px; font-weight: 500;
}
.bn-savings-pill .ti { font-size: 11px; }

.bn-swap-row {
  display: grid; grid-template-columns: 1fr 1fr;
  gap: 8px; margin-top: 12px;
  position: relative;
}
.bn-swap-card {
  background: rgba(255, 255, 255, 0.72);
  border: 0.5px solid rgba(15, 111, 86, 0.18);
  border-radius: 10px;
  padding: 8px 10px;
}
.bn-swap-card.is-primary {
  background: #FFFFFF;
  border-color: #1D9E75;
}
.bn-swap-lbl {
  font-size: 10px;
  text-transform: uppercase; letter-spacing: 0.4px;
  color: #085041; font-weight: 500;
}
.bn-swap-val {
  font-size: 14px; font-weight: 600; color: #0F6E56;
  margin-top: 2px; font-variant-numeric: tabular-nums;
}
.bn-swap-val.strike {
  text-decoration: line-through;
  text-decoration-color: rgba(15, 111, 86, 0.4);
  color: rgba(15, 111, 86, 0.65);
  font-weight: 500;
}

.bn-nudge-btn {
  margin-top: 12px; width: 100%;
  background: #1D9E75; color: #fff; border: none;
  padding: 10px 12px; border-radius: 8px;
  font-size: 12.5px; font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center; gap: 6px;
  position: relative;
}
.bn-nudge-btn:hover { background: #0F6E56; }
.bn-nudge-skip {
  margin-top: 6px; text-align: center;
  font-size: 11px; color: #085041;
  position: relative;
}
.bn-nudge-skip-btn {
  background: none; border: none;
  color: #0F6E56;
  text-decoration: underline; text-underline-offset: 2px;
  cursor: pointer; font: inherit;
  padding: 0;
}
</style>

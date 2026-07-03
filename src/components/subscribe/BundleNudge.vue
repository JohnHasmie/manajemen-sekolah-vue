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
    <div class="bn-nudge-head">
      <div class="bn-nudge-icon" aria-hidden="true">
        <svg viewBox="0 0 20 20" width="16" height="16" fill="currentColor">
          <path d="M10 1.5l2.1 4.9 5.3.5-4 3.6 1.2 5.2L10 13l-4.6 2.7 1.2-5.2-4-3.6 5.3-.5z" />
        </svg>
      </div>
      <div class="bn-nudge-title">
        Paket Lengkap lebih hemat
      </div>
      <div class="bn-savings-pill" aria-hidden="true">
        <span>−{{ money(alacarteTotal - bundleTotal) }}</span>
      </div>
    </div>

    <p class="bn-nudge-desc">
      À la carte Anda <strong>{{ money(alacarteTotal) }}</strong>/bln.
      Paket Lengkap cuma <strong>{{ money(bundleTotal) }}</strong>/bln —
      <template v-if="bonusModuleCount > 0">
        dapat {{ bonusModuleCount }} modul bonus tambahan.
      </template>
      <template v-else>
        semua modul non-AI langsung aktif.
      </template>
    </p>

    <!-- Compact side-by-side compare. Grid columns split evenly + let
         the price own the row, no more tiny 100px cards. -->
    <div class="bn-compare">
      <div class="bn-compare-cell">
        <span class="bn-compare-lbl">Pilihan Anda</span>
        <span class="bn-compare-val strike">{{ money(alacarteTotal) }}</span>
      </div>
      <div class="bn-compare-arrow" aria-hidden="true">→</div>
      <div class="bn-compare-cell is-primary">
        <span class="bn-compare-lbl">Paket Lengkap</span>
        <span class="bn-compare-val">{{ money(bundleTotal) }}</span>
      </div>
    </div>

    <button type="button" class="bn-nudge-btn" @click="$emit('switch')">
      Ambil Paket Lengkap
    </button>
    <button
      type="button"
      class="bn-nudge-skip"
      @click="$emit('skip')"
    >
      Tetap pakai pilihan à la carte
    </button>
  </div>
</template>

<style scoped>
/* Full-bleed nudge inside the calculator sidebar. Sits under the
   Total + CTA (parent controls order) so it never hides the primary
   action. Wider sidebar (340px) means we can breathe: rows can hold
   Indonesian rupiah amounts on one line without truncation. */
.bn-nudge {
  margin: 12px 14px 14px;
  border-radius: 12px;
  background: linear-gradient(180deg, #E1F5EE 0%, #D2EFE0 100%);
  border: 0.5px solid #5DCAA5;
  padding: 12px;
  position: relative; overflow: hidden;
}

/* Header row — icon + title + savings chip on the right. */
.bn-nudge-head {
  display: flex; align-items: center; gap: 8px;
  margin-bottom: 8px;
}
.bn-nudge-icon {
  width: 26px; height: 26px; border-radius: 8px;
  background: #1D9E75; color: #fff;
  display: grid; place-items: center;
  flex-shrink: 0;
}
.bn-nudge-icon svg { display: block; }
.bn-nudge-title {
  font-size: 12.5px; font-weight: 600; color: #085041;
  letter-spacing: -0.1px;
  flex: 1;
}
.bn-savings-pill {
  background: #0F6E56; color: #fff;
  padding: 3px 8px; border-radius: 6px;
  font-size: 11px; font-weight: 600;
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
}

.bn-nudge-desc {
  font-size: 11.5px; color: #0F6E56;
  margin: 0 0 10px; line-height: 1.5;
}
.bn-nudge-desc strong { font-weight: 600; }

/* Compare row — full-width, grid with an arrow between. Each cell
   uses full column width so 7-digit rupiah amounts have room to
   breathe (Rp 8.100.000 fit fine, no truncation). */
.bn-compare {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  gap: 6px; align-items: stretch;
  margin-bottom: 12px;
}
.bn-compare-cell {
  background: rgba(255, 255, 255, 0.75);
  border: 0.5px solid rgba(15, 111, 86, 0.18);
  border-radius: 8px;
  padding: 7px 9px;
  display: flex; flex-direction: column; gap: 2px;
  min-width: 0;
}
.bn-compare-cell.is-primary {
  background: #FFFFFF;
  border-color: #1D9E75;
  box-shadow: 0 1px 2px rgba(29, 158, 117, 0.15);
}
.bn-compare-lbl {
  font-size: 9.5px;
  text-transform: uppercase; letter-spacing: 0.4px;
  color: #0F6E56; font-weight: 500;
}
.bn-compare-val {
  font-size: 12.5px; font-weight: 600; color: #085041;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.bn-compare-val.strike {
  text-decoration: line-through;
  text-decoration-color: rgba(15, 111, 86, 0.4);
  color: rgba(15, 111, 86, 0.65);
  font-weight: 500;
}
.bn-compare-arrow {
  align-self: center;
  color: #0F6E56;
  font-size: 13px;
  padding: 0 2px;
}

.bn-nudge-btn {
  width: 100%;
  background: #1D9E75; color: #fff; border: none;
  padding: 10px 12px; border-radius: 8px;
  font-size: 12.5px; font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center; gap: 6px;
  white-space: nowrap;
}
.bn-nudge-btn:hover { background: #0F6E56; }

.bn-nudge-skip {
  margin-top: 8px; width: 100%;
  background: none; border: none;
  color: #0F6E56;
  font: inherit; font-size: 11px;
  text-decoration: underline; text-underline-offset: 2px;
  cursor: pointer;
  padding: 4px 0;
}
</style>

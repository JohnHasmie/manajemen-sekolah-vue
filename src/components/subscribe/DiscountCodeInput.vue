<!--
  DiscountCodeInput.vue — 4-state discount code input for the
  subscribe sidebar. Matches the approved mockup:

    STATE 0 (empty)   — collapsed pill "Punya kode diskon?  Masukkan →"
    STATE 1 (input)   — input + Terapkan button + hint text
    STATE 2 (applied) — parent renders DiscountAppliedCard, this widget
                        collapses back to a chip. Not managed here — see
                        `AppliedDiscount` prop upstream in the sidebar.
    STATE 3 (error)   — red hint under the input with server-picked copy

  Parent-owned state (in PricingCalculatorV2):
    modelValue     — current input text (raw)
    applying       — spinner flag
    error          — { reason, message } | null
    v-if wraps this widget out when an AppliedDiscount is active, so
    the widget itself never has to know about STATE 2.
-->
<script setup lang="ts">
import { ref, computed } from 'vue';
import type { DiscountPreviewFailure } from '@/types/subscription-billing';

const props = defineProps<{
  modelValue: string;
  applying: boolean;
  error?: DiscountPreviewFailure | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: string];
  apply: [code: string];
}>();

const expanded = ref(false);

const value = computed({
  get: () => props.modelValue,
  set: (v: string) => emit('update:modelValue', v.toUpperCase()),
});

function open() {
  expanded.value = true;
}

function submit() {
  const code = value.value.trim();
  if (code === '' || props.applying) return;
  emit('apply', code);
}
</script>

<template>
  <div class="dc-root">
    <button v-if="!expanded" type="button" class="dc-empty" @click="open">
      <span class="dc-empty-icon">%</span>
      <span class="dc-empty-lbl">Punya kode diskon?</span>
      <span class="dc-empty-cta">Masukkan →</span>
    </button>

    <template v-else>
      <div class="dc-input-row">
        <input
          v-model.trim="value"
          class="dc-input"
          :class="{ 'has-error': !!error }"
          placeholder="Kode diskon"
          maxlength="24"
          autocomplete="off"
          spellcheck="false"
          @keyup.enter="submit"
        />
        <button
          type="button"
          class="dc-apply"
          :class="{ 'has-error': !!error }"
          :disabled="applying || value.trim() === ''"
          @click="submit"
        >
          <span v-if="applying" class="dc-spinner" />
          <span v-else>{{ error ? 'Coba lagi' : 'Terapkan' }}</span>
        </button>
      </div>
      <div v-if="!error" class="dc-hint">
        Hanya <b>1 kode</b> bisa aktif per periode.
      </div>
      <div v-else class="dc-error">
        <div class="dc-error-head">
          <span class="dc-error-icon">!</span>
          <span class="dc-error-msg">{{ error.message }}</span>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.dc-root { margin-top: 12px; }

.dc-empty {
  width: 100%;
  padding: 10px 12px;
  border: 1px dashed #CBD5E1;
  border-radius: 10px;
  background: #F8FAFC;
  display: flex; align-items: center; gap: 8px;
  cursor: pointer;
  text-align: left;
  transition: border-color 0.15s;
}
.dc-empty:hover { border-color: #94A3B8; }
.dc-empty-icon {
  width: 20px; height: 20px; border-radius: 6px;
  background: #E2E8F0; color: #475569;
  display: grid; place-items: center;
  font-size: 12px; font-weight: 800;
}
.dc-empty-lbl {
  font-size: 11.5px; font-weight: 600; color: #475569;
}
.dc-empty-cta {
  margin-left: auto; font-size: 10.5px; font-weight: 800;
  color: #1B6FB8;
}

.dc-input-row { display: flex; gap: 6px; }
.dc-input {
  flex: 1;
  padding: 9px 12px;
  border: 1px solid #CBD5E1; border-radius: 8px;
  background: #fff;
  font-size: 12px; font-weight: 700;
  color: #0F172A;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  outline: none;
  transition: border-color 0.12s, box-shadow 0.12s;
}
.dc-input:focus { border-color: #1B6FB8; box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.15); }
.dc-input.has-error { border-color: #F43F5E; }
.dc-input.has-error:focus { box-shadow: 0 0 0 3px rgba(244, 63, 94, 0.15); }
.dc-apply {
  padding: 9px 14px;
  background: #1B6FB8; color: #fff;
  font-size: 11px; font-weight: 800;
  border: none; border-radius: 8px; cursor: pointer;
  min-width: 82px;
  display: inline-flex; align-items: center; justify-content: center; gap: 4px;
}
.dc-apply:disabled { opacity: 0.5; cursor: default; }
.dc-apply.has-error { background: #F43F5E; }
.dc-hint {
  font-size: 10px; color: #64748B;
  margin-top: 6px; padding-left: 2px;
}
.dc-hint b { color: #334155; font-weight: 700; }

.dc-error {
  margin-top: 8px;
  background: #FFF1F2;
  border: 1px solid #FFE4E6;
  border-radius: 10px;
  padding: 8px 10px;
}
.dc-error-head { display: flex; align-items: flex-start; gap: 6px; }
.dc-error-icon {
  width: 18px; height: 18px; border-radius: 5px;
  background: #F43F5E; color: #fff;
  display: grid; place-items: center;
  font-size: 11px; font-weight: 900;
  flex-shrink: 0;
}
.dc-error-msg {
  font-size: 11px; font-weight: 700;
  color: #BE123C;
  line-height: 1.35;
}

.dc-spinner {
  width: 12px; height: 12px;
  border: 2px solid rgba(255,255,255,0.35);
  border-top-color: #fff;
  border-radius: 50%;
  animation: dc-spin 0.7s linear infinite;
}
@keyframes dc-spin { to { transform: rotate(360deg); } }
</style>

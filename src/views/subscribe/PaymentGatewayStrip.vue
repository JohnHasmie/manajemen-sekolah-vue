<!--
  PaymentGatewayStrip.vue — footer chip strip under the signup card.

  Shield icon + "Pembayaran melalui Midtrans Snap" + a chip row of the
  payment channels the backend accepts (QRIS, GoPay, OVO, DANA,
  ShopeePay, VA, CC). Plus a small toggle for the manual bank-transfer
  fallback.

  Chip list is driven by `supported_gateways` from the plan payload so
  we never advertise a channel the server can't actually process.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = withDefaults(
  defineProps<{
    supportedGateways: string[];
    manualTransfer: boolean;
  }>(),
  { manualTransfer: false },
);

const emit = defineEmits<{ 'update:manualTransfer': [boolean] }>();

const { t } = useI18n();

// Cosmetic label + short-form (for the pill) per canonical gateway key.
const CATALOG: Record<string, { label: string; short: string }> = {
  qris: { label: 'QRIS', short: 'QRIS' },
  gopay: { label: 'GoPay', short: 'GoPay' },
  ovo: { label: 'OVO', short: 'OVO' },
  dana: { label: 'DANA', short: 'DANA' },
  shopeepay: { label: 'ShopeePay', short: 'ShopeePay' },
  va: { label: 'Virtual Account (VA)', short: 'VA' },
  virtual_account: { label: 'Virtual Account', short: 'VA' },
  cc: { label: 'Kartu Kredit', short: 'CC' },
  credit_card: { label: 'Kartu Kredit', short: 'CC' },
};

const chips = computed(() => {
  const raw = props.supportedGateways?.length
    ? props.supportedGateways
    : ['qris', 'gopay', 'ovo', 'dana', 'shopeepay', 'va', 'credit_card'];
  const seen = new Set<string>();
  const out: { key: string; label: string; short: string }[] = [];
  for (const key of raw) {
    const k = String(key).toLowerCase();
    const info = CATALOG[k];
    if (!info) continue;
    // dedupe on the short label so `virtual_account` + `va` don't stack
    if (seen.has(info.short)) continue;
    seen.add(info.short);
    out.push({ key: k, ...info });
  }
  return out;
});
</script>

<template>
  <div class="rounded-2xl border border-slate-200 bg-white p-4 sm:p-5">
    <div class="flex items-start gap-3">
      <div class="flex-shrink-0 w-9 h-9 rounded-lg bg-emerald-50 text-emerald-600 grid place-items-center">
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        </svg>
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-sm font-semibold text-slate-900">
          {{ t('subscribe.gateway.title') }}
        </p>
        <p class="text-xs text-slate-500 mt-0.5">
          {{ t('subscribe.gateway.subtitle') }}
        </p>
        <div class="mt-3 flex flex-wrap gap-1.5">
          <span
            v-for="chip in chips"
            :key="chip.key"
            class="inline-flex items-center rounded-md border border-slate-200 bg-slate-50 px-2 py-0.5 text-[11px] font-semibold text-slate-700"
          >
            {{ chip.short }}
          </span>
        </div>
      </div>
    </div>

    <label class="mt-4 flex items-center gap-2.5 rounded-lg border border-slate-200 bg-slate-50 px-3 py-2.5 cursor-pointer hover:bg-slate-100 transition-colors">
      <input
        type="checkbox"
        class="h-4 w-4 rounded border-slate-300 text-brand-cobalt focus:ring-brand-cobalt"
        :checked="manualTransfer"
        @change="(ev) => emit('update:manualTransfer', (ev.target as HTMLInputElement).checked)"
      />
      <span class="text-xs text-slate-700 flex-1">
        {{ t('subscribe.gateway.manual') }}
      </span>
      <span class="text-[10px] font-semibold uppercase tracking-wider text-slate-400">
        {{ t('subscribe.gateway.manualHint') }}
      </span>
    </label>
  </div>
</template>

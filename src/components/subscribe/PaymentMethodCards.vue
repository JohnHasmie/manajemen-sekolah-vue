<!--
  PaymentMethodCards.vue — two-column selector for how the user pays.
  Matches mockup 2 (`.sc-paycards`) with Manual Transfer + Midtrans.

  When Midtrans isn't available (server has no key), the parent hides
  the card by passing `midtransAvailable=false`.
-->
<script setup lang="ts">
type Gateway = 'bank_transfer_manual' | 'midtrans';

const props = defineProps<{
  value: Gateway;
  midtransAvailable?: boolean;
  bankName?: string;
  bankHolder?: string;
}>();

const emit = defineEmits<{
  'update:value': [value: Gateway];
}>();

function pick(g: Gateway) {
  if (g === 'midtrans' && !props.midtransAvailable) return;
  emit('update:value', g);
}
</script>

<template>
  <div class="pm-row">
    <button
      type="button"
      class="pm-pay"
      :class="{ 'is-on': value === 'bank_transfer_manual' }"
      @click="pick('bank_transfer_manual')"
    >
      <div class="pm-pay-head">
        <div class="pm-pay-i" style="background:#FEF3C7; color:#B45309;">
          <i class="ti ti-building-bank" aria-hidden="true" />
        </div>
        <div class="pm-pay-title">Transfer bank manual</div>
        <div class="pm-pay-radio" />
      </div>
      <div class="pm-pay-desc">
        Anda transfer ke rekening {{ bankName ?? 'BSI' }} kami. Tim
        keuangan verifikasi dalam 1×24 jam kerja.
      </div>
      <div class="pm-pay-badges">
        <span class="pm-pay-b">{{ bankName ?? 'BSI' }} · {{ bankHolder ?? 'Yahya Al Hasymi' }}</span>
        <span class="pm-pay-b is-hi">
          <i
            class="ti ti-check"
            style="font-size:9px; vertical-align:-1px; margin-right:2px"
            aria-hidden="true"
          />Tanpa biaya admin
        </span>
      </div>
    </button>

    <button
      v-if="midtransAvailable"
      type="button"
      class="pm-pay"
      :class="{ 'is-on': value === 'midtrans' }"
      @click="pick('midtrans')"
    >
      <div class="pm-pay-head">
        <div class="pm-pay-i">
          <i class="ti ti-credit-card" aria-hidden="true" />
        </div>
        <div class="pm-pay-title">Midtrans</div>
        <div class="pm-pay-radio" />
      </div>
      <div class="pm-pay-desc">
        Bayar langsung dengan QRIS, e-wallet, atau kartu. Aktivasi
        otomatis dalam hitungan menit.
      </div>
      <div class="pm-pay-badges">
        <span class="pm-pay-b">QRIS</span>
        <span class="pm-pay-b">GoPay</span>
        <span class="pm-pay-b">OVO</span>
        <span class="pm-pay-b">VA</span>
        <span class="pm-pay-b">Kartu</span>
      </div>
    </button>
  </div>
</template>

<style scoped>
.pm-row {
  display: grid; grid-template-columns: 1fr 1fr;
  gap: 10px; margin-top: 4px;
}

.pm-pay {
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  padding: 14px;
  cursor: pointer; text-align: left;
  position: relative;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.pm-pay:hover { border-color: #C7D2E1; }
.pm-pay.is-on {
  border: 1.5px solid #1B6FB8;
  padding: 13.5px;
  background: #FBFDFF;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.06);
}

.pm-pay-head { display: flex; align-items: center; gap: 8px; }
.pm-pay-title { font-size: 12.5px; font-weight: 500; color: #0F172A; }
.pm-pay-radio {
  width: 16px; height: 16px; border-radius: 50%;
  border: 1.5px solid #CBD5E1;
  margin-left: auto;
  position: relative;
  flex-shrink: 0;
}
.pm-pay.is-on .pm-pay-radio { border-color: #1B6FB8; }
.pm-pay.is-on .pm-pay-radio::after {
  content: '';
  position: absolute; top: 2px; left: 2px; right: 2px; bottom: 2px;
  border-radius: 50%;
  background: #1B6FB8;
}

.pm-pay-desc { font-size: 11px; color: #64748B; margin-top: 8px; line-height: 1.45; }
.pm-pay-badges { display: flex; gap: 6px; margin-top: 10px; flex-wrap: wrap; }
.pm-pay-b {
  background: #F5F8FC; color: #475569;
  border: 0.5px solid #E2E8F0;
  padding: 3px 8px; border-radius: 5px;
  font-size: 10px; font-weight: 500;
  letter-spacing: 0.2px;
}
.pm-pay-b.is-hi { background: #DCFCE7; color: #085041; border-color: #9FE1CB; }

.pm-pay-i {
  width: 32px; height: 32px; border-radius: 8px;
  background: #F5F8FC;
  color: #185FA5;
  display: grid; place-items: center;
  font-size: 18px;
  flex-shrink: 0;
}
</style>

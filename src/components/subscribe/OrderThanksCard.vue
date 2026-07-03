<!--
  OrderThanksCard.vue — emerald-gradient thanks card shown after the
  user clicks "Saya sudah transfer". Matches mockup 3
  (`.st-thanks`).
-->
<script setup lang="ts">
defineProps<{
  email?: string | null;
  whatsapp?: string | null;
  expiredDemo?: boolean;
}>();

defineEmits<{
  home: [];
  invoice: [];
}>();
</script>

<template>
  <div class="tk-thanks">
    <div class="tk-thanks-i">
      <i class="ti ti-heart-handshake" aria-hidden="true" />
    </div>
    <div class="tk-thanks-kicker">Terima kasih!</div>
    <div class="tk-thanks-title">
      Konfirmasi transfer Anda sudah kami terima
    </div>
    <div class="tk-thanks-body">
      <template v-if="expiredDemo">
        Karena demo Anda sudah berakhir, dashboard baru bisa dibuka
        setelah tim keuangan memverifikasi transfer dan mengaktifkan
        langganan. Kami akan mengirim notifikasi email + WhatsApp
        begitu akun aktif kembali.
      </template>
      <template v-else>
        Tim keuangan akan mencocokkan dengan mutasi bank dalam 1×24
        jam kerja. Anda akan menerima notifikasi email dan WhatsApp
        begitu berlangganan aktif — tidak perlu menunggu di halaman ini.
      </template>
    </div>
    <div v-if="email || whatsapp" class="tk-thanks-chips">
      <div v-if="email" class="tk-chip">
        <i class="ti ti-mail" style="font-size:12px" aria-hidden="true" />
        {{ email }}
      </div>
      <div v-if="whatsapp" class="tk-chip">
        <i class="ti ti-brand-whatsapp" style="font-size:12px" aria-hidden="true" />
        {{ whatsapp }}
      </div>
    </div>
    <div v-if="!expiredDemo" class="tk-thanks-cta">
      <button type="button" class="tk-thanks-btn" @click="$emit('home')">
        <i class="ti ti-home" style="font-size:13px" aria-hidden="true" />
        Kembali ke dashboard
      </button>
      <button type="button" class="tk-thanks-ghost" @click="$emit('invoice')">
        <i class="ti ti-file-invoice" style="font-size:13px" aria-hidden="true" />
        Unduh invoice
      </button>
    </div>
  </div>
</template>

<style scoped>
.tk-thanks {
  background: linear-gradient(180deg, #ECFDF5 0%, #D1FAE5 100%);
  border: 0.5px solid #6EE7B7;
  border-radius: 14px;
  padding: 18px 20px 16px;
  position: relative; overflow: hidden;
}
.tk-thanks::before {
  content: '';
  position: absolute; top: -40px; right: -40px;
  width: 160px; height: 160px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.7) 0%, transparent 70%);
  pointer-events: none;
}
.tk-thanks-i {
  width: 44px; height: 44px; border-radius: 12px;
  background: #FFFFFF; color: #047857;
  display: grid; place-items: center;
  font-size: 22px;
  box-shadow: 0 2px 6px rgba(5, 150, 105, 0.15);
  position: relative;
}
.tk-thanks-kicker {
  font-size: 10px; text-transform: uppercase;
  letter-spacing: 0.8px; color: #047857;
  font-weight: 700;
  margin-top: 12px;
  position: relative;
}
.tk-thanks-title {
  font-size: 17px; font-weight: 500;
  letter-spacing: -0.2px; color: #064E3B;
  margin-top: 4px;
  position: relative;
}
.tk-thanks-body {
  font-size: 12.5px; color: #065F46;
  line-height: 1.55; margin-top: 6px;
  max-width: 480px;
  position: relative;
}
.tk-thanks-chips {
  display: flex; gap: 8px;
  margin-top: 12px;
  position: relative;
  flex-wrap: wrap;
}
.tk-chip {
  background: rgba(255, 255, 255, 0.7);
  border: 0.5px solid #A7F3D0;
  padding: 6px 10px; border-radius: 999px;
  font-size: 11px; color: #065F46;
  font-weight: 500;
  display: flex; align-items: center; gap: 5px;
}
.tk-thanks-cta {
  margin-top: 14px;
  display: flex; gap: 8px;
  position: relative;
  flex-wrap: wrap;
}
.tk-thanks-btn {
  padding: 9px 14px;
  background: #047857; color: #fff; border: none;
  border-radius: 8px;
  font-size: 12px; font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; gap: 5px;
}
.tk-thanks-btn:hover { background: #065F46; }
.tk-thanks-ghost {
  padding: 9px 14px;
  background: transparent;
  border: 0.5px solid #6EE7B7;
  color: #065F46;
  border-radius: 8px;
  font-size: 12px; font-weight: 500;
  cursor: pointer;
}
</style>

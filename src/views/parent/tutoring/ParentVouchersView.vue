<!--
  ParentVouchersView — wali voucher list. Mockup parent_web_pages_extra
  frame 2: hero + 2-col voucher grid (active + used).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { formatRupiah } from '@/lib/format';
import type { TutoringVoucher } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const loading = ref(true);
const vouchers = ref<TutoringVoucher[]>([]);
const view = ref<'active' | 'history'>('active');
const codeInput = ref('');
const codeMessage = ref<string | null>(null);

async function load() {
  loading.value = true;
  try { vouchers.value = await TutoringService.getVouchers(); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

function isExpired(v: TutoringVoucher): boolean {
  if (!v.valid_until) return false;
  return new Date(v.valid_until).valueOf() < Date.now();
}

function isMaxUsed(v: TutoringVoucher): boolean {
  return v.max_uses != null && v.used_count >= v.max_uses;
}

function isActive(v: TutoringVoucher): boolean {
  return v.is_active && !isExpired(v) && !isMaxUsed(v);
}

const active = computed(() => vouchers.value.filter(isActive));
const history = computed(() => vouchers.value.filter((v) => !isActive(v)));

const shown = computed(() => (view.value === 'active' ? active.value : history.value));

// "Segera kedaluwarsa" = aktif & valid_until <= 7 hari.
const expiringSoon = computed(() => {
  const sevenDays = 7 * 24 * 60 * 60 * 1000;
  return active.value.filter((v) => {
    if (!v.valid_until) return false;
    const t = new Date(v.valid_until).valueOf();
    return t - Date.now() <= sevenDays;
  });
});

function isUrgent(v: TutoringVoucher): boolean {
  if (!v.valid_until) return false;
  const sevenDays = 7 * 24 * 60 * 60 * 1000;
  return new Date(v.valid_until).valueOf() - Date.now() <= sevenDays;
}

function amountLabel(v: TutoringVoucher): string {
  if (v.type === 'PERCENTAGE') return `${v.value}%`;
  return formatRupiah(v.value);
}

// Color for the big amount per voucher type.
function amountColor(v: TutoringVoucher): string {
  if (!isActive(v)) return 'text-bimbel-text-mid';
  if (v.type === 'PERCENTAGE') return 'text-orange-700';
  // AMOUNT → hero blue. Referral / "gratis" not represented in API yet.
  return 'text-bimbel-hero';
}

function validity(v: TutoringVoucher): string {
  if (!isActive(v)) {
    if (isExpired(v)) {
      return `Kedaluwarsa ${new Date(v.valid_until!).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}`;
    }
    return `Dipakai ${v.used_count}×`;
  }
  if (v.valid_until) {
    return `Berlaku sampai ${new Date(v.valid_until).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}`;
  }
  return 'Tanpa batas waktu';
}

async function tryRedeem() {
  if (!codeInput.value.trim()) return;
  try {
    const preview = await TutoringService.validateVoucher(codeInput.value.trim().toUpperCase(), 100_000);
    codeMessage.value = `Kode valid · diskon ${formatRupiah(preview.discount_amount)} pada simulasi Rp 100rb.`;
  } catch (e) {
    codeMessage.value = e instanceof Error ? e.message : 'Kode tidak valid.';
  }
}

const heroSubtitle = computed(
  () => `${active.value.length} aktif · ${expiringSoon.value.length} segera kedaluwarsa`,
);
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · VOUCHER"
      title="Voucher & promo aktif"
      :subtitle="heroSubtitle"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-full bg-white text-bimbel-hero px-2.5 py-1 text-[12px] font-bold hover:bg-white/95"
          @click="view = view === 'active' ? 'history' : 'active'"
        >{{ view === 'active' ? 'Riwayat' : 'Aktif' }}</button>
      </template>
    </ParentBerandaHero>

    <!-- Redeem strip — kept from prior view, restyled to body palette -->
    <div class="bg-bimbel-panel border border-bimbel-border-soft rounded-lg p-3 flex flex-wrap items-center gap-2">
      <input
        v-model="codeInput"
        type="text"
        placeholder="Kode voucher"
        class="flex-1 min-w-[140px] rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-1.5 text-[12px] uppercase tracking-wider text-bimbel-text-hi focus:border-bimbel-hero focus:outline-none"
      />
      <button
        type="button"
        class="rounded-lg bg-bimbel-hero px-3 py-1.5 text-[12px] font-bold text-white hover:opacity-90"
        @click="tryRedeem"
      >Pakai kode</button>
      <p v-if="codeMessage" class="w-full text-[11px] text-bimbel-text-mid">{{ codeMessage }}</p>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <template v-else>
      <h4 class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
        {{ view === 'active' ? 'VOUCHER TERSEDIA' : 'RIWAYAT VOUCHER' }}
      </h4>

      <div v-if="shown.length" class="grid grid-cols-2 gap-2">
        <div
          v-for="v in shown"
          :key="v.id"
          class="rounded-lg bg-bimbel-panel p-3 relative overflow-hidden flex flex-col"
          :class="[
            isActive(v) ? 'border border-dashed' : 'border border-solid opacity-60',
            isActive(v) && isUrgent(v) ? 'border-orange-600' : 'border-bimbel-border-soft',
          ]"
        >
          <p
            class="text-[24px] font-extrabold leading-none"
            :class="amountColor(v)"
          >{{ amountLabel(v) }}</p>

          <p class="text-[11px] text-bimbel-text-mid my-1 line-clamp-2">
            {{ v.notes || 'Diskon biaya bimbel' }}
          </p>

          <span
            class="font-mono text-[11px] bg-bimbel-bg px-2 py-1 rounded inline-block tracking-wider mt-2 self-start text-bimbel-text-hi"
          >{{ v.code }}</span>

          <p
            class="text-[10px] mt-1.5 inline-flex items-center gap-1"
            :class="isActive(v) && isUrgent(v) ? 'text-red-800 font-semibold' : 'text-bimbel-text-lo'"
          >
            <i class="ti ti-clock" />
            <span>{{ validity(v) }}</span>
          </p>
        </div>
      </div>

      <div
        v-else
        class="rounded-lg bg-bimbel-panel border border-bimbel-border-soft p-8 text-center text-[13px] text-bimbel-text-mid"
      >
        <template v-if="view === 'active'">Belum ada voucher aktif.</template>
        <template v-else>Belum ada voucher di riwayat.</template>
      </div>
    </template>
  </div>
</template>

<!--
  ParentVouchersView — wali voucher list. Mockup parent_web_pages_extra
  frame 2: hero + Aktif/Riwayat seg + voucher grid + "pakai kode" CTA.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { formatRupiah } from '@/lib/format';
import type { TutoringVoucher } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentVoucherCard from '@/components/feature/tutoring/ParentVoucherCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

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

function amountLabel(v: TutoringVoucher): string {
  if (v.type === 'PERCENTAGE') return `${v.value}% off`;
  return formatRupiah(v.value);
}

function validity(v: TutoringVoucher): string {
  if (!isActive(v)) {
    if (isExpired(v)) {
      return `Kedaluwarsa ${new Date(v.valid_until!).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}`;
    }
    return 'Sudah dipakai';
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
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · VOUCHER"
      title="Voucher saya"
      :subtitle="`${active.length} aktif · ${history.length} riwayat`"
      :stats="[]"
    />

    <div class="flex flex-wrap items-center gap-2">
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'active' as const, label: `Aktif (${active.length})` },
            { id: 'history' as const, label: `Riwayat (${history.length})` },
          ]"
          :key="opt.id"
          type="button"
          class="rounded-full border px-3 py-1.5 text-[13px] font-semibold"
          :class="
            view === opt.id
              ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
              : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'
          "
          @click="view = opt.id"
        >{{ opt.label }}</button>
      </div>
      <div class="ml-auto flex items-center gap-2">
        <input
          v-model="codeInput"
          type="text"
          placeholder="Kode voucher"
          class="rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[13px] uppercase tracking-wider text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
        />
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-lg bg-[#21afe6] px-3 py-1.5 text-[13px] font-bold text-white hover:opacity-90"
          @click="tryRedeem"
        ><NavIcon name="check-circle" :size="13" /> Pakai</button>
      </div>
    </div>
    <p v-if="codeMessage" class="text-[13px] text-bimbel-text-mid">{{ codeMessage }}</p>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="shown.length" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <ParentVoucherCard
        v-for="v in shown"
        :key="v.id"
        :code="v.code"
        :amount="amountLabel(v)"
        :description="v.notes"
        :validity-label="validity(v)"
        :used="!isActive(v)"
      />
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      <template v-if="view === 'active'">Belum ada voucher aktif.</template>
      <template v-else>Belum ada voucher di riwayat.</template>
    </div>
  </div>
</template>

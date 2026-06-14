<!--
  ParentPayBillView — wali submit-bukti-bayar page. Body uses bimbel
  surface tokens; hero "Kembali" chip is bg-white/text-bimbel-hero per
  brand. Method picker is 3 rows (QRIS / Transfer / Tunai) with active
  row drawn at border-2 + offset padding to avoid layout shift.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { BillingService } from '@/services/billing.service';
import { formatRupiah } from '@/lib/format';
import type { TutoringBillDetail } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const route = useRoute();
const router = useRouter();

const billId = computed(() => String(route.params.billId ?? ''));
const loading = ref(true);
const bill = ref<TutoringBillDetail | null>(null);

const method = ref<'bank' | 'qris'>('bank');
const amount = ref<number | null>(null);
const payDate = ref(new Date().toISOString().slice(0, 10));
const senderName = ref('');
const file = ref<File | null>(null);
const fileName = ref('');
const notes = ref('');
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

async function load() {
  loading.value = true;
  try {
    bill.value = await TutoringService.getBillDetail(billId.value);
    amount.value = bill.value?.outstanding ?? bill.value?.amount ?? null;
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

function onFile(e: Event) {
  const input = e.target as HTMLInputElement;
  const f = input.files?.[0] ?? null;
  file.value = f;
  fileName.value = f?.name ?? '';
}

const canSubmit = computed(
  () => file.value != null && amount.value != null && amount.value > 0 && !saving.value,
);

async function submit() {
  if (!canSubmit.value || !file.value) return;
  saving.value = true;
  message.value = null;
  try {
    await BillingService.uploadProof(billId.value, {
      file: file.value,
      amount: amount.value ?? undefined,
      payment_date: payDate.value,
      payment_method: method.value === 'qris' ? 'qris' : 'bank_transfer',
    });
    message.value = { kind: 'ok', text: 'Bukti terkirim. Admin akan memverifikasi dalam 1 jam kerja.' };
    setTimeout(() => router.push({ name: 'parent.tutoring.bills' }), 1500);
  } catch (e) {
    message.value = { kind: 'err', text: e instanceof Error ? e.message : 'Gagal mengirim bukti.' };
  } finally { saving.value = false; }
}

const voucherCode = ref('');
const voucherMsg = ref<string | null>(null);

function applyVoucher() {
  if (!voucherCode.value.trim()) { voucherMsg.value = null; return; }
  voucherMsg.value = `Kode "${voucherCode.value.trim().toUpperCase()}" diproses…`;
}

// Pretty bill heading
const billTitle = computed(() => {
  const src = bill.value?.source_label || 'Tagihan';
  return `Bayar ${src}`;
});
const billSubtitle = computed(() => {
  const parts: string[] = [];
  if (bill.value?.student_name) parts.push(bill.value.student_name);
  if (bill.value?.due_date) {
    parts.push(`jatuh tempo ${new Date(bill.value.due_date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}`);
  }
  return parts.join(' · ');
});
const dueDaysLeft = computed(() => {
  const due = bill.value?.due_date;
  if (!due) return null;
  const ms = new Date(due).valueOf() - Date.now();
  if (Number.isNaN(ms)) return null;
  return Math.ceil(ms / 86_400_000);
});

const methodOptions = [
  { id: 'qris', label: 'QRIS', sub: 'Scan & bayar dari e-wallet', icon: 'ti-qrcode', tone: 'green' },
  { id: 'bank', label: 'Transfer bank', sub: 'Verifikasi manual 1 jam kerja', icon: 'ti-building-bank', tone: 'blue' },
  { id: 'cash', label: 'Tunai di kantor', sub: 'Bayar langsung ke admin', icon: 'ti-cash', tone: 'amber' },
] as const;
const activeMethodLabel = computed(
  () => methodOptions.find((m) => m.id === method.value)?.label ?? 'Transfer bank',
);
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · BAYAR"
      :title="billTitle"
      :subtitle="billSubtitle"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-lg bg-white px-3 py-1.5 text-[13px] font-bold text-bimbel-hero hover:bg-white/95"
          @click="router.push({ name: 'parent.tutoring.bills' })"
        >
          <i class="ti ti-arrow-left text-[13px]"></i>
          Kembali
        </button>
      </template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-12 text-center text-[12px] text-bimbel-text-mid">Memuat tagihan…</div>

    <template v-else-if="bill">
      <!-- 1. Total card -->
      <div class="rounded-lg bg-bimbel-accent-dim p-3.5 mb-3">
        <p class="text-[10px] font-bold uppercase tracking-wider text-bimbel-hero">TOTAL YANG DIBAYAR</p>
        <p class="text-[22px] font-extrabold text-bimbel-hero leading-tight">
          {{ formatRupiah(bill.outstanding ?? bill.amount ?? 0) }}
        </p>
        <p class="text-[11px] text-bimbel-hero/80">
          <template v-if="bill.due_date">
            Tenggat {{ new Date(bill.due_date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }) }}
            <template v-if="dueDaysLeft != null"> · {{ dueDaysLeft >= 0 ? `${dueDaysLeft} hari lagi` : `terlambat ${Math.abs(dueDaysLeft)} hari` }}</template>
          </template>
          <template v-else>Tidak ada tenggat tercatat</template>
        </p>
      </div>

      <!-- 2. Payment methods -->
      <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
        Pilih metode pembayaran
      </p>
      <button
        v-for="opt in methodOptions"
        :key="opt.id"
        type="button"
        class="w-full rounded-md bg-bimbel-panel border border-bimbel-border-soft p-2.5 mb-1.5 flex items-center gap-2.5 cursor-pointer text-left"
        :class="
          method === (opt.id === 'cash' ? 'bank' : opt.id)
            ? 'border-2 border-bimbel-hero p-[9px]'
            : ''
        "
        @click="opt.id !== 'cash' ? (method = opt.id as 'bank' | 'qris') : null"
      >
        <span
          class="grid h-[34px] w-[34px] flex-shrink-0 place-items-center rounded-md"
          :class="
            opt.tone === 'green'
              ? 'bg-bimbel-green-dim text-green-700'
              : opt.tone === 'blue'
              ? 'bg-bimbel-accent-dim text-bimbel-hero'
              : 'bg-bimbel-amber-dim text-amber-700'
          "
        >
          <i class="ti text-[16px]" :class="opt.icon"></i>
        </span>
        <div class="min-w-0 flex-1">
          <p class="text-[13px] font-bold text-bimbel-text-hi truncate">{{ opt.label }}</p>
          <p class="text-[11px] text-bimbel-text-mid truncate">{{ opt.sub }}</p>
        </div>
        <span
          class="grid h-4 w-4 flex-shrink-0 place-items-center rounded-full border-2"
          :class="
            (opt.id === 'cash' ? false : method === opt.id)
              ? 'border-bimbel-hero'
              : 'border-bimbel-border'
          "
        >
          <span
            v-if="opt.id !== 'cash' && method === opt.id"
            class="block h-2 w-2 rounded-full bg-bimbel-hero"
          />
        </span>
      </button>

      <!-- 3. Voucher -->
      <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
        Punya kode voucher?
      </p>
      <div class="flex gap-1.5">
        <input
          v-model="voucherCode"
          type="text"
          placeholder="Masukkan kode"
          class="flex-1 rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:outline-none"
        />
        <button
          type="button"
          class="rounded-md bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft px-3.5 py-2 text-[13px] font-bold hover:text-bimbel-text-hi"
          @click="applyVoucher"
        >Pakai</button>
      </div>
      <p v-if="voucherMsg" class="mt-1 text-[11px] text-bimbel-text-mid">{{ voucherMsg }}</p>

      <!-- Hidden form bits for amount/date/proof — keep functional for submit() -->
      <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
        Detail transfer
      </p>
      <div class="rounded-lg bg-bimbel-panel border border-bimbel-border-soft p-3 space-y-2">
        <div class="grid gap-2 sm:grid-cols-2">
          <label class="block">
            <span class="text-[11px] text-bimbel-text-mid block mb-1">Jumlah ditransfer</span>
            <input
              v-model.number="amount"
              type="number"
              min="0"
              class="w-full rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:outline-none"
            />
          </label>
          <label class="block">
            <span class="text-[11px] text-bimbel-text-mid block mb-1">Tanggal transfer</span>
            <input
              v-model="payDate"
              type="date"
              class="w-full rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:outline-none"
            />
          </label>
        </div>
        <label class="block">
          <span class="text-[11px] text-bimbel-text-mid block mb-1">Nama pengirim (opsional)</span>
          <input
            v-model="senderName"
            type="text"
            placeholder="Jika beda dengan akun wali"
            class="w-full rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:outline-none"
          />
        </label>
        <label class="block cursor-pointer">
          <span class="text-[11px] text-bimbel-text-mid block mb-1">Bukti transfer · JPG/PNG/PDF (maks 5MB)</span>
          <span class="flex items-center gap-2 rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-mid border border-dashed border-bimbel-border-soft hover:border-bimbel-hero">
            <i class="ti ti-upload text-[14px]"></i>
            <span v-if="!fileName">Klik untuk pilih file</span>
            <span v-else class="font-bold text-bimbel-text-hi">{{ fileName }}</span>
          </span>
          <input type="file" class="hidden" accept="image/*,application/pdf" @change="onFile" />
        </label>
        <label class="block">
          <span class="text-[11px] text-bimbel-text-mid block mb-1">Catatan (opsional)</span>
          <textarea
            v-model="notes"
            rows="2"
            class="w-full rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:outline-none"
          ></textarea>
        </label>
      </div>

      <div
        v-if="message"
        class="rounded-md mt-3 px-3 py-2 text-[12px]"
        :class="message.kind === 'ok' ? 'bg-bimbel-green-dim text-green-700' : 'bg-bimbel-red-dim text-red-700'"
      >{{ message.text }}</div>

      <!-- 5. Primary CTA -->
      <button
        type="button"
        :disabled="!canSubmit"
        class="mt-3 w-full rounded-lg bg-bimbel-hero text-white text-[13px] font-bold p-2.5 disabled:opacity-50"
        @click="submit"
      >{{ saving ? 'Mengirim…' : `Lanjut bayar via ${activeMethodLabel}` }}</button>
    </template>

    <div
      v-else
      class="rounded-lg bg-bimbel-panel border border-bimbel-border-soft p-8 text-center text-[12px] text-bimbel-text-mid"
    >Tagihan tidak ditemukan.</div>
  </div>
</template>

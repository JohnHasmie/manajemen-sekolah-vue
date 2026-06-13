<!--
  ParentBayarTagihanView — wali submit-bukti-bayar page. Mockup
  parent_web_pages_create_update frame 3: accent-stripe tagihan info +
  form di kiri (metode + jumlah + tanggal + upload + catatan), bank
  info + tips di kanan.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { BillingService } from '@/services/billing.service';
import { formatRupiah } from '@/lib/format';
import type { TutoringBillDetail } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

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

function copyAccountNumber() {
  const num = bill.value?.payment_account?.bank_account_number;
  if (num) navigator.clipboard?.writeText(num);
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
    setTimeout(() => router.push({ name: 'parent.tutoring.tagihan' }), 1500);
  } catch (e) {
    message.value = { kind: 'err', text: e instanceof Error ? e.message : 'Gagal mengirim bukti.' };
  } finally { saving.value = false; }
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1 text-[12px] text-bimbel-text-mid hover:text-bimbel-text-hi"
      @click="router.push({ name: 'parent.tutoring.tagihan' })"
    >
      <NavIcon name="chevron-left" :size="13" /> Kembali ke tagihan
    </button>

    <ParentBerandaHero
      kicker="BAYAR TAGIHAN"
      title="Bayar tagihan"
      subtitle="Transfer manual / QRIS · admin verifikasi dalam 1 jam kerja"
      :stats="[]"
    />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat tagihan…</div>

    <template v-else-if="bill">
      <div class="relative overflow-hidden rounded-2xl border border-bimbel-border-soft bg-bimbel-panel pl-5 pr-4 py-3.5">
        <span class="absolute left-0 top-0 h-full w-1.5 bg-emerald-500" />
        <p class="text-[10px] font-bold uppercase tracking-widest text-emerald-700 dark:text-emerald-300">TAGIHAN AKTIF</p>
        <p class="mt-0.5 text-xl font-extrabold tracking-tight text-bimbel-text-hi">{{ formatRupiah(bill.amount ?? 0) }}</p>
        <p class="text-[11.5px] text-bimbel-text-mid">
          {{ [bill.source_label, bill.due_date ? `jatuh tempo ${new Date(bill.due_date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}` : null, bill.student_name].filter(Boolean).join(' · ') }}
        </p>
      </div>

      <div class="grid gap-4 lg:grid-cols-5">
        <form
          class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-3 space-y-3"
          @submit.prevent="submit"
        >
          <h4 class="text-[12.5px] font-bold tracking-tight text-bimbel-text-hi">Detail pembayaran</h4>
          <div>
            <p class="text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Metode <span class="text-rose-500">*</span></p>
            <div class="mt-2 grid gap-2 sm:grid-cols-2">
              <button
                type="button"
                class="flex items-center gap-3 rounded-xl border p-3 text-left transition"
                :class="
                  method === 'bank'
                    ? 'border-2 border-[#21afe6] bg-[#21afe6]/8 p-[11px]'
                    : 'border-bimbel-border-soft hover:border-bimbel-border'
                "
                @click="method = 'bank'"
              >
                <span class="grid h-9 w-9 place-items-center rounded-lg bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]">
                  <NavIcon name="wallet" :size="16" />
                </span>
                <div><p class="text-[12.5px] font-bold text-bimbel-text-hi">Transfer bank</p><p class="text-[11px] text-bimbel-text-mid">Verifikasi manual</p></div>
              </button>
              <button
                type="button"
                class="flex items-center gap-3 rounded-xl border p-3 text-left transition"
                :class="
                  method === 'qris'
                    ? 'border-2 border-[#21afe6] bg-[#21afe6]/8 p-[11px]'
                    : 'border-bimbel-border-soft hover:border-bimbel-border'
                "
                @click="method = 'qris'"
              >
                <span class="grid h-9 w-9 place-items-center rounded-lg bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]">
                  <NavIcon name="sparkles" :size="16" />
                </span>
                <div><p class="text-[12.5px] font-bold text-bimbel-text-hi">QRIS</p><p class="text-[11px] text-bimbel-text-mid">Scan & bayar</p></div>
              </button>
            </div>
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <label class="block">
              <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Jumlah ditransfer <span class="text-rose-500">*</span></span>
              <input
                v-model.number="amount"
                type="number"
                min="0"
                required
                class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
              />
            </label>
            <label class="block">
              <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Tanggal transfer <span class="text-rose-500">*</span></span>
              <input
                v-model="payDate"
                type="date"
                required
                class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
              />
            </label>
          </div>
          <label class="block">
            <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Nama pengirim</span>
            <input
              v-model="senderName"
              type="text"
              placeholder="Opsional — jika beda dengan akun wali"
              class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
            />
          </label>
          <div>
            <p class="text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Bukti transfer <span class="text-rose-500">*</span></p>
            <label class="mt-2 flex cursor-pointer flex-col items-center gap-1 rounded-xl border-2 border-dashed border-bimbel-border py-6 text-center text-[11.5px] text-bimbel-text-mid hover:border-[#21afe6]">
              <NavIcon name="upload" :size="22" class="text-[#21afe6]" />
              <span>
                <span class="font-bold text-[#1a8fbe] dark:text-[#85d4f4]">Klik untuk pilih file</span>
                atau drag-drop di sini
              </span>
              <span class="text-[10.5px] text-bimbel-text-lo">JPG / PNG / PDF · maks 5MB</span>
              <span v-if="fileName" class="text-[11px] font-semibold text-bimbel-text-hi">{{ fileName }}</span>
              <input type="file" class="hidden" accept="image/*,application/pdf" @change="onFile" />
            </label>
          </div>
          <label class="block">
            <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Catatan</span>
            <textarea v-model="notes" rows="2" placeholder="Opsional" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"></textarea>
          </label>
          <div v-if="message" class="rounded-lg px-3 py-2 text-[11.5px]" :class="message.kind === 'ok' ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300' : 'bg-rose-500/10 text-rose-700 dark:text-rose-300'">
            {{ message.text }}
          </div>
          <div class="flex gap-2 pt-2">
            <button type="button" class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[12.5px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="router.push({ name: 'parent.tutoring.tagihan' })">Batal</button>
            <button type="submit" :disabled="!canSubmit" class="flex-1 rounded-lg bg-[#21afe6] px-3 py-2 text-[12.5px] font-bold text-white hover:opacity-90 disabled:opacity-50">{{ saving ? 'Mengirim…' : 'Kirim bukti bayar' }}</button>
          </div>
        </form>

        <aside class="space-y-3 lg:col-span-2">
          <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
            <h5 class="mb-2 text-[12px] font-bold text-bimbel-text-hi">Rekening bimbel</h5>
            <dl class="space-y-1.5 text-[11.5px]">
              <div class="flex justify-between"><dt class="text-bimbel-text-mid">Bank</dt><dd class="font-bold">{{ bill.payment_account?.bank_name ?? '—' }}</dd></div>
              <div class="flex justify-between"><dt class="text-bimbel-text-mid">No rek</dt><dd class="font-mono">{{ bill.payment_account?.bank_account_number ?? '—' }}</dd></div>
              <div class="flex justify-between"><dt class="text-bimbel-text-mid">a.n.</dt><dd>{{ bill.payment_account?.bank_account_holder ?? '—' }}</dd></div>
            </dl>
            <button
              type="button"
              class="mt-3 inline-flex items-center gap-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[11px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
              @click="copyAccountNumber"
            >
              <NavIcon name="copy" :size="11" /> Salin no rek
            </button>
          </div>
          <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
            <h5 class="mb-2 text-[12px] font-bold text-bimbel-text-hi">Tips bukti transfer</h5>
            <ul class="space-y-1 text-[11.5px] text-bimbel-text-mid list-disc pl-4">
              <li>Pastikan no rek tujuan terlihat</li>
              <li>Tanggal & jam transfer jelas</li>
              <li>Nominal sesuai jumlah ditransfer</li>
              <li>Hindari hasil edit / blur</li>
            </ul>
          </div>
        </aside>
      </div>
    </template>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Tagihan tidak ditemukan.
    </div>
  </div>
</template>

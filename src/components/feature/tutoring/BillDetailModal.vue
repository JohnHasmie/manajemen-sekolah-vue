<!--
  BillDetailModal — admin clicks a bill row → opens this modal.

  Three panels:
    1. Header summary: student, source, amount, due, status pill.
    2. Payment history (chronological) — proof link per row.
    3. Mark-paid form (only when bill is still unpaid) + tenant
       payment-account preview so the admin can copy the bank info
       to share with wali if they ask.

  Server-side a successful mark-paid creates a verified Payment +
  flips bill.status → paid in one transaction. Re-emits `done` so
  the list view can refresh.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah, formatDateShort } from '@/lib/format';
import type { TutoringBillDetail } from '@/types/tutoring';

import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';

const props = defineProps<{ billId: string }>();
const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'done'): void;
}>();

const toast = useToast();
const loading = ref(true);
const detail = ref<TutoringBillDetail | null>(null);

const showMarkPaid = ref(false);
const markAmount = ref<number | null>(null);
const markMethod = ref('manual_transfer');
const markDate = ref<string>(new Date().toISOString().slice(0, 10));
const markNotes = ref('');
const saving = ref(false);

const isPaid = computed(
  () => detail.value?.bill.status?.toLowerCase() === 'paid',
);

async function load() {
  loading.value = true;
  try {
    detail.value = await TutoringService.getBillDetail(props.billId);
    markAmount.value = detail.value?.outstanding ?? null;
  } catch (e) {
    toast.error(e instanceof Error ? e.message : String(e));
  } finally {
    loading.value = false;
  }
}

async function submitMarkPaid() {
  saving.value = true;
  try {
    await TutoringService.markBillPaid(props.billId, {
      amount: markAmount.value ?? undefined,
      payment_method: markMethod.value || undefined,
      payment_date: markDate.value || undefined,
      admin_notes: markNotes.value.trim() || undefined,
    });
    toast.success('Tagihan ditandai lunas.');
    emit('done');
  } catch (e) {
    toast.error(e instanceof Error ? e.message : String(e));
  } finally {
    saving.value = false;
  }
}

function copy(text: string | null | undefined) {
  if (!text) return;
  navigator.clipboard?.writeText(text);
  toast.success('Disalin ke clipboard.');
}

onMounted(load);
</script>

<template>
  <Modal title="Detail Tagihan" size="lg" @close="emit('close')">
    <div v-if="loading" class="py-10 text-center text-sm text-slate-400">
      Memuat detail…
    </div>

    <template v-else-if="detail">
      <!-- Header summary -->
      <section class="rounded-xl border border-slate-200 bg-slate-50 p-3 mb-4">
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0 flex-1">
            <div class="text-[11px] font-bold uppercase tracking-wider text-slate-500">
              {{ detail.bill.source_label ?? 'Tagihan' }}
            </div>
            <div class="text-base font-extrabold text-slate-900 mt-0.5 tracking-tight">
              {{ detail.student?.name ?? detail.bill.student_name ?? '—' }}
            </div>
            <div class="text-xs text-slate-500 mt-0.5">
              {{ detail.bill.due_date
                ? `Jatuh tempo ${formatDateShort(detail.bill.due_date)}`
                : 'Tanpa jatuh tempo' }}
            </div>
          </div>
          <TutoringStatusPill :bill="detail.bill.status" />
        </div>
        <div class="grid grid-cols-3 gap-2 mt-3 text-center">
          <div>
            <div class="text-[9px] font-bold uppercase tracking-wider text-slate-500">Total</div>
            <div class="text-sm font-extrabold text-slate-900">{{ formatRupiah(detail.bill.amount ?? 0) }}</div>
          </div>
          <div>
            <div class="text-[9px] font-bold uppercase tracking-wider text-slate-500">Sudah bayar</div>
            <div class="text-sm font-extrabold text-emerald-600">{{ formatRupiah(detail.paid_total) }}</div>
          </div>
          <div>
            <div class="text-[9px] font-bold uppercase tracking-wider text-slate-500">Sisa</div>
            <div class="text-sm font-extrabold" :class="detail.outstanding > 0 ? 'text-status-danger' : 'text-slate-500'">
              {{ formatRupiah(detail.outstanding) }}
            </div>
          </div>
        </div>
      </section>

      <!-- Payment history -->
      <section class="mb-4">
        <h4 class="text-xs font-extrabold uppercase tracking-wider text-slate-500 mb-2">
          Riwayat Pembayaran
        </h4>
        <div v-if="detail.payments.length === 0" class="text-xs text-slate-400 py-2 text-center bg-slate-50 rounded-lg">
          Belum ada pembayaran tercatat.
        </div>
        <ul v-else class="space-y-1.5">
          <li
            v-for="p in detail.payments"
            :key="p.id"
            class="flex items-center gap-3 rounded-lg border border-slate-200 bg-white px-3 py-2"
          >
            <span class="flex h-7 w-7 items-center justify-center rounded-md bg-emerald-50 text-emerald-600 shrink-0">
              <NavIcon name="wallet" :size="13" />
            </span>
            <div class="min-w-0 flex-1">
              <div class="text-sm font-bold text-slate-900">{{ formatRupiah(p.amount) }}</div>
              <div class="text-[11px] text-slate-500 truncate">
                {{ [
                  p.payment_method,
                  p.payment_date ? formatDateShort(p.payment_date) : null,
                  p.status,
                ].filter(Boolean).join(' · ') }}
              </div>
              <div v-if="p.admin_notes" class="text-[11px] text-slate-400 truncate">
                {{ p.admin_notes }}
              </div>
            </div>
            <a
              v-if="p.proof_proxy_url || p.proof_url"
              :href="p.proof_proxy_url || p.proof_url || '#'"
              target="_blank"
              rel="noopener"
              class="rounded-md border border-slate-200 px-2 py-1 text-[10px] font-bold text-slate-600 hover:bg-slate-50"
            >
              Bukti
            </a>
          </li>
        </ul>
      </section>

      <!-- Payment account (admin reference) -->
      <section v-if="detail.payment_account" class="mb-4">
        <h4 class="text-xs font-extrabold uppercase tracking-wider text-slate-500 mb-2">
          Rekening Bimbel
        </h4>
        <div class="rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs text-slate-700">
          <template v-if="detail.payment_account.bank_name || detail.payment_account.bank_account_number">
            <div class="font-bold text-slate-900">{{ detail.payment_account.bank_name ?? '—' }}</div>
            <button
              type="button"
              class="font-mono mt-0.5 text-slate-700 hover:text-role-admin"
              :title="'Salin: ' + (detail.payment_account.bank_account_number ?? '')"
              @click="copy(detail.payment_account.bank_account_number)"
            >
              {{ detail.payment_account.bank_account_number ?? '—' }}
            </button>
            <div v-if="detail.payment_account.bank_account_holder" class="text-slate-500 mt-0.5">
              a.n. {{ detail.payment_account.bank_account_holder }}
            </div>
          </template>
          <p v-else class="text-slate-400 italic">
            Rekening belum dikonfigurasi. Buka Pengaturan Billing.
          </p>
          <div v-if="detail.payment_account.payment_instructions" class="mt-2 text-[11px] text-slate-500 whitespace-pre-line">
            {{ detail.payment_account.payment_instructions }}
          </div>
        </div>
      </section>

      <!-- Mark paid form -->
      <section v-if="!isPaid">
        <button
          v-if="!showMarkPaid"
          type="button"
          class="w-full rounded-lg bg-role-admin px-3 py-2.5 text-sm font-bold text-white hover:bg-role-admin/90"
          @click="showMarkPaid = true"
        >
          Tandai Lunas
        </button>
        <div v-else class="rounded-xl border border-emerald-200 bg-emerald-50/30 p-3 space-y-2">
          <h4 class="text-xs font-extrabold uppercase tracking-wider text-emerald-700 mb-1">
            Tandai Lunas — Manual
          </h4>
          <div class="grid grid-cols-2 gap-2">
            <label class="block">
              <span class="text-[10px] font-bold text-slate-500 uppercase">Nominal</span>
              <input
                v-model.number="markAmount"
                type="number"
                min="0"
                class="mt-0.5 w-full rounded-md border border-slate-200 px-2 py-1.5 text-sm"
              />
            </label>
            <label class="block">
              <span class="text-[10px] font-bold text-slate-500 uppercase">Tanggal</span>
              <input
                v-model="markDate"
                type="date"
                class="mt-0.5 w-full rounded-md border border-slate-200 px-2 py-1.5 text-sm"
              />
            </label>
          </div>
          <label class="block">
            <span class="text-[10px] font-bold text-slate-500 uppercase">Metode</span>
            <select
              v-model="markMethod"
              class="mt-0.5 w-full rounded-md border border-slate-200 px-2 py-1.5 text-sm"
            >
              <option value="manual_transfer">Transfer manual</option>
              <option value="cash">Tunai</option>
              <option value="qris">QRIS</option>
              <option value="other">Lainnya</option>
            </select>
          </label>
          <label class="block">
            <span class="text-[10px] font-bold text-slate-500 uppercase">Catatan</span>
            <input
              v-model="markNotes"
              type="text"
              maxlength="500"
              placeholder="Mis. transfer BCA 14:32, bukti via WA"
              class="mt-0.5 w-full rounded-md border border-slate-200 px-2 py-1.5 text-sm"
            />
          </label>
          <div class="flex items-center justify-end gap-2 pt-1">
            <button
              type="button"
              class="rounded-md px-3 py-1.5 text-xs font-bold text-slate-600 hover:bg-slate-100"
              @click="showMarkPaid = false"
            >
              Batal
            </button>
            <button
              type="button"
              :disabled="saving"
              class="rounded-md bg-emerald-600 hover:bg-emerald-700 px-3 py-1.5 text-xs font-bold text-white disabled:opacity-50"
              @click="submitMarkPaid"
            >
              {{ saving ? 'Menyimpan…' : 'Konfirmasi Lunas' }}
            </button>
          </div>
        </div>
      </section>
    </template>
  </Modal>
</template>

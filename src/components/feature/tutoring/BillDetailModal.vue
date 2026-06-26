<!--
  BillDetailModal — admin clicks a bill row → opens this modal.

  Three panels:
    1. Header summary: student, source, amount, due, status pill.
    2. Payment history (chronological) — proof link per row.
    3. Mark-paid form (only when bill is still unpaid) + tenant
       payment-account preview so the admin can copy the bank info
       to share with parent if they ask.

  Server-side a successful mark-paid creates a verified Payment +
  flips bill.status → paid in one transaction. Re-emits `done` so
  the list view can refresh.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
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

const { t } = useI18n();
const toast = useToast();
const loading = ref(true);
const detail = ref<TutoringBillDetail | null>(null);

const showMarkPaid = ref(false);
const markAmount = ref<number | null>(null);
const markMethod = ref('manual_transfer');
const markDate = ref<string>(new Date().toISOString().slice(0, 10));
const markNotes = ref('');
const saving = ref(false);

// Paid-only actions — invoice PDF download + admin resend.
const downloadingPdf = ref(false);
const resending = ref(false);

const isPaid = computed(
  () => detail.value?.bill.status?.toLowerCase() === 'paid',
);

async function downloadInvoice() {
  if (downloadingPdf.value) return;
  downloadingPdf.value = true;
  try {
    await TutoringService.downloadInvoicePdf(props.billId);
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.billDetail.downloadFailed'));
  } finally {
    downloadingPdf.value = false;
  }
}

async function resendInvoice() {
  if (resending.value) return;
  // Lightweight confirm via window.confirm — keeps the modal simple and
  // matches the destructive-action pattern used elsewhere in admin views.
  if (!window.confirm(t('tutoring.billDetail.resendConfirm'))) return;
  resending.value = true;
  try {
    await TutoringService.resendInvoice(props.billId);
    toast.success(t('tutoring.billDetail.resendSuccess'));
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.billDetail.resendFailed'));
  } finally {
    resending.value = false;
  }
}

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
    <div v-if="loading" class="py-10 text-center text-sm text-bimbel-text-lo">
      Memuat detail…
    </div>

    <template v-else-if="detail">
      <!-- Header summary -->
      <section class="rounded-xl border border-bimbel-border bg-bimbel-bg p-3 mb-4">
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0 flex-1">
            <div class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">
              {{ detail.bill.source_label ?? 'Tagihan' }}
            </div>
            <div class="text-base font-extrabold text-bimbel-text-hi mt-0.5 tracking-tight">
              {{ detail.student?.name ?? detail.bill.student_name ?? '—' }}
            </div>
            <div class="text-xs text-bimbel-text-mid mt-0.5">
              {{ detail.bill.due_date
                ? `Jatuh tempo ${formatDateShort(detail.bill.due_date)}`
                : 'Tanpa jatuh tempo' }}
            </div>
          </div>
          <TutoringStatusPill :bill="detail.bill.status" />
        </div>
        <div class="grid grid-cols-3 gap-2 mt-3 text-center">
          <div>
            <div class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Total</div>
            <div class="text-sm font-extrabold text-bimbel-text-hi">{{ formatRupiah(detail.bill.amount ?? 0) }}</div>
          </div>
          <div>
            <div class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Sudah bayar</div>
            <div class="text-sm font-extrabold text-emerald-600">{{ formatRupiah(detail.paid_total) }}</div>
          </div>
          <div>
            <div class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Sisa</div>
            <div class="text-sm font-extrabold" :class="detail.outstanding > 0 ? 'text-bimbel-red' : 'text-bimbel-text-mid'">
              {{ formatRupiah(detail.outstanding) }}
            </div>
          </div>
        </div>
      </section>

      <!-- Payment history -->
      <section class="mb-4">
        <h4 class="text-xs font-extrabold uppercase tracking-wider text-bimbel-text-mid mb-2">
          Riwayat Pembayaran
        </h4>
        <div v-if="detail.payments.length === 0" class="text-xs text-bimbel-text-lo py-2 text-center bg-bimbel-bg rounded-lg">
          Belum ada pembayaran tercatat.
        </div>
        <ul v-else class="space-y-1.5">
          <li
            v-for="p in detail.payments"
            :key="p.id"
            class="flex items-center gap-3 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2"
          >
            <span class="flex h-7 w-7 items-center justify-center rounded-md bg-emerald-50 text-emerald-600 shrink-0">
              <NavIcon name="wallet" :size="13" />
            </span>
            <div class="min-w-0 flex-1">
              <div class="text-sm font-bold text-bimbel-text-hi">{{ formatRupiah(p.amount) }}</div>
              <div class="text-[12px] text-bimbel-text-mid truncate">
                {{ [
                  p.payment_method,
                  p.payment_date ? formatDateShort(p.payment_date) : null,
                  p.status,
                ].filter(Boolean).join(' · ') }}
              </div>
              <div v-if="p.admin_notes" class="text-[12px] text-bimbel-text-lo truncate">
                {{ p.admin_notes }}
              </div>
            </div>
            <a
              v-if="p.proof_proxy_url || p.proof_url"
              :href="p.proof_proxy_url || p.proof_url || '#'"
              target="_blank"
              rel="noopener"
              class="rounded-md border border-bimbel-border px-2 py-1 text-[12px] font-bold text-bimbel-text-mid hover:bg-bimbel-bg"
            >
              Bukti
            </a>
          </li>
        </ul>
      </section>

      <!-- Payment account (admin reference) -->
      <section v-if="detail.payment_account" class="mb-4">
        <h4 class="text-xs font-extrabold uppercase tracking-wider text-bimbel-text-mid mb-2">
          Rekening Bimbel
        </h4>
        <div class="rounded-lg border border-bimbel-border bg-bimbel-bg p-3 text-xs text-bimbel-text-mid">
          <template v-if="detail.payment_account.bank_name || detail.payment_account.bank_account_number">
            <div class="font-bold text-bimbel-text-hi">{{ detail.payment_account.bank_name ?? '—' }}</div>
            <button
              type="button"
              class="font-mono mt-0.5 text-bimbel-text-mid hover:text-bimbel-accent"
              :title="'Salin: ' + (detail.payment_account.bank_account_number ?? '')"
              @click="copy(detail.payment_account.bank_account_number)"
            >
              {{ detail.payment_account.bank_account_number ?? '—' }}
            </button>
            <div v-if="detail.payment_account.bank_account_holder" class="text-bimbel-text-mid mt-0.5">
              a.n. {{ detail.payment_account.bank_account_holder }}
            </div>
          </template>
          <p v-else class="text-bimbel-text-lo italic">
            Rekening belum dikonfigurasi. Buka Pengaturan Billing.
          </p>
          <div v-if="detail.payment_account.payment_instructions" class="mt-2 text-[12px] text-bimbel-text-mid whitespace-pre-line">
            {{ detail.payment_account.payment_instructions }}
          </div>
        </div>
      </section>

      <!-- Paid-bill actions: invoice PDF download + admin manual resend
           (email + WhatsApp). Backend already auto-fires both channels
           on payment verification; these are explicit re-sends when parent
           lost the original notification. -->
      <section v-if="isPaid" class="space-y-2">
        <button
          type="button"
          :disabled="downloadingPdf"
          class="w-full inline-flex items-center justify-center gap-1.5 rounded-lg bg-bimbel-accent px-3 py-2.5 text-sm font-bold text-white hover:opacity-90 disabled:opacity-50"
          @click="downloadInvoice"
        >
          <NavIcon name="download" :size="14" />
          {{ downloadingPdf ? t('tutoring.billDetail.downloadingInvoice') : t('tutoring.billDetail.downloadInvoice') }}
        </button>
        <button
          type="button"
          :disabled="resending"
          class="w-full inline-flex items-center justify-center gap-1.5 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2.5 text-sm font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft disabled:opacity-50"
          @click="resendInvoice"
        >
          <NavIcon name="send" :size="14" />
          {{ resending ? t('tutoring.billDetail.resending') : t('tutoring.billDetail.resendInvoice') }}
        </button>
      </section>

      <!-- Mark paid form -->
      <section v-if="!isPaid">
        <button
          v-if="!showMarkPaid"
          type="button"
          class="w-full rounded-lg bg-bimbel-accent px-3 py-2.5 text-sm font-bold text-white hover:opacity-90"
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
              <span class="text-[12px] font-bold text-bimbel-text-mid uppercase">Nominal</span>
              <input
                v-model.number="markAmount"
                type="number"
                min="0"
                class="mt-0.5 w-full rounded-md border border-bimbel-border px-2 py-1.5 text-sm"
              />
            </label>
            <label class="block">
              <span class="text-[12px] font-bold text-bimbel-text-mid uppercase">Tanggal</span>
              <input
                v-model="markDate"
                type="date"
                class="mt-0.5 w-full rounded-md border border-bimbel-border px-2 py-1.5 text-sm"
              />
            </label>
          </div>
          <label class="block">
            <span class="text-[12px] font-bold text-bimbel-text-mid uppercase">Metode</span>
            <select
              v-model="markMethod"
              class="mt-0.5 w-full rounded-md border border-bimbel-border px-2 py-1.5 text-sm"
            >
              <option value="manual_transfer">Transfer manual</option>
              <option value="cash">Tunai</option>
              <option value="qris">QRIS</option>
              <option value="other">Lainnya</option>
            </select>
          </label>
          <label class="block">
            <span class="text-[12px] font-bold text-bimbel-text-mid uppercase">Catatan</span>
            <input
              v-model="markNotes"
              type="text"
              maxlength="500"
              placeholder="Mis. transfer BCA 14:32, bukti via WA"
              class="mt-0.5 w-full rounded-md border border-bimbel-border px-2 py-1.5 text-sm"
            />
          </label>
          <div class="flex items-center justify-end gap-2 pt-1">
            <button
              type="button"
              class="rounded-md px-3 py-1.5 text-xs font-bold text-bimbel-text-mid hover:bg-bimbel-border-soft"
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

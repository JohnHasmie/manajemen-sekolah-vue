<!--
  PaymentTypeFormModal.vue — admin Jenis Pembayaran add/edit sheet.

  Used by AdminFinanceJenisView. Posts to:
    POST   /payment-types          (create — auto-generates bills if status=active)
    PUT    /payment-types/{id}     (edit)
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { FinanceService } from '@/services/finance.service';
import { formatThousands, parseDigits } from '@/lib/format';
import type { PaymentType, PaymentTypePayload } from '@/types/billing';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';

const props = defineProps<{
  paymentType?: PaymentType | null;
}>();

const emit = defineEmits<{
  close: [];
  saved: [PaymentType, { bills_generated?: number; bills_skipped?: number }];
}>();

const form = ref<PaymentTypePayload>({
  name: props.paymentType?.name ?? '',
  description: props.paymentType?.description ?? '',
  amount: props.paymentType?.amount ?? 0,
  period: String(props.paymentType?.period ?? 'monthly'),
  status: String(props.paymentType?.status ?? 'active'),
  goal: props.paymentType?.goal ?? null,
  start_date: props.paymentType?.start_date ?? null,
  day_of_month: props.paymentType?.day_of_month ?? null,
});

watch(
  () => props.paymentType,
  (pt) => {
    if (!pt) return;
    form.value = {
      name: pt.name,
      description: pt.description ?? '',
      amount: pt.amount,
      period: String(pt.period),
      status: String(pt.status),
      goal: pt.goal ?? null,
      start_date: pt.start_date ?? null,
      day_of_month: pt.day_of_month ?? null,
    };
  },
);

const isSaving = ref(false);
const err = ref<string | null>(null);

/**
 * Nominal money input — shows Indonesian thousand separators as the
 * user types (`500000` → `500.000`) while `form.amount` stays the RAW
 * integer that gets submitted to the API. `amountDisplay` is the
 * formatted string bound to the (text) input; the setter strips dots
 * back to a plain int. Mirrors Flutter's `CurrencyInputFormatter`.
 */
const amountDisplay = computed<string>({
  get: () => (form.value.amount ? formatThousands(form.value.amount) : ''),
  set: (raw: string) => {
    form.value.amount = parseDigits(raw);
  },
});

// Backend stores `payment_types.period` as canonical English (monthly /
// yearly / once). Labels stay Indonesian.
const PERIOD_OPTS = [
  { key: 'monthly', label: 'Bulanan' },
  { key: 'yearly', label: 'Tahunan' },
  { key: 'once', label: 'Sekali bayar' },
];

async function save() {
  if (!form.value.name.trim()) {
    err.value = 'Nama jenis wajib diisi.';
    return;
  }
  if (!form.value.amount || form.value.amount <= 0) {
    err.value = 'Nominal harus lebih dari 0.';
    return;
  }

  isSaving.value = true;
  err.value = null;
  try {
    if (props.paymentType?.id) {
      const updated = await FinanceService.updatePaymentType(props.paymentType.id, form.value);
      emit('saved', updated, {});
    } else {
      const res = await FinanceService.createPaymentType(form.value);
      emit('saved', res.type, {
        bills_generated: res.bills_generated,
        bills_skipped: res.bills_skipped,
      });
    }
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <Modal
    :title="paymentType ? 'Edit Jenis Pembayaran' : 'Tambah Jenis Pembayaran'"
    :subtitle="paymentType ? 'Perubahan langsung dipakai pada tagihan berikutnya.' : 'Jenis aktif otomatis generate tagihan untuk bulan ini.'"
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Nama jenis
        </label>
        <input
          v-model="form.name"
          type="text"
          placeholder="SPP / Uang Pangkal / Seragam ..."
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        />
      </div>

      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Deskripsi
        </label>
        <textarea
          v-model="form.description"
          rows="2"
          placeholder="Detail singkat (opsional)"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] text-slate-900 outline-none focus:border-role-admin"
        ></textarea>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Nominal
          </label>
          <div class="mt-1 relative">
            <span
              class="absolute left-3 top-1/2 -translate-y-1/2 text-[13px] font-bold text-slate-400 pointer-events-none"
            >Rp</span>
            <input
              v-model="amountDisplay"
              type="text"
              inputmode="numeric"
              placeholder="0"
              class="w-full bg-slate-50 border border-slate-200 rounded-xl pl-9 pr-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
            />
          </div>
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Periode
          </label>
          <select
            v-model="form.period"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option v-for="o in PERIOD_OPTS" :key="o.key" :value="o.key">{{ o.label }}</option>
          </select>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Mulai berlaku
          </label>
          <input
            v-model="form.start_date"
            type="date"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          />
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Tanggal jatuh tempo bulanan
          </label>
          <input
            v-model.number="form.day_of_month"
            type="number"
            min="1"
            max="28"
            placeholder="10"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          />
        </div>
      </div>

      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Status
        </label>
        <div class="mt-1 inline-flex gap-2 p-1 bg-slate-100 rounded-xl">
          <button
            type="button"
            class="px-3 py-1.5 rounded-lg text-2xs font-bold transition-colors"
            :class="form.status === 'active' ? 'bg-emerald-500 text-white' : 'text-slate-500'"
            @click="form.status = 'active'"
          >Aktif</button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-lg text-2xs font-bold transition-colors"
            :class="form.status === 'inactive' ? 'bg-slate-500 text-white' : 'text-slate-500'"
            @click="form.status = 'inactive'"
          >Nonaktif</button>
        </div>
      </div>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button variant="primary" block :loading="isSaving" @click="save">
          {{ paymentType ? 'Simpan perubahan' : 'Buat jenis' }}
        </Button>
      </div>
    </div>
  </Modal>
</template>

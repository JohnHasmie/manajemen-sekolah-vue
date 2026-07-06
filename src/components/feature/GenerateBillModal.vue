<!--
  GenerateBillModal.vue — admin bulk generate bills for a month.

  POST /generate-bill
    { payment_type_id?, month: YYYY-MM, academic_year_id }

  Disables months that have already been generated for the chosen
  jenis (via GET /finance/generated-months).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { FinanceService } from '@/services/finance.service';
import { AcademicYearService } from '@/services/academic-year.service';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useConfirm } from '@/composables/useConfirm';
import { formatRupiah } from '@/lib/format';
import type { PaymentType } from '@/types/billing';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  paymentTypes: PaymentType[];
  /** Pre-select a jenis when opened from a row. */
  initialPaymentTypeId?: string;
}>();

const emit = defineEmits<{
  close: [];
  done: [{ created: number; skipped: number }];
}>();

const ayStore = useAcademicYearStore();
const { confirm } = useConfirm();

const selectedTypeId = ref<string>(props.initialPaymentTypeId ?? '');
const selectedYear = ref<number>(new Date().getFullYear());
const selectedMonth = ref<number>(new Date().getMonth() + 1);
const academicYearId = ref<string>(String(ayStore.selectedYearId ?? ''));

const isGenerating = ref(false);
const err = ref<string | null>(null);

// Generated months for the selected jenis (so we can disable).
const generatedSet = ref<Set<string>>(new Set());

async function refreshGenerated() {
  if (!selectedTypeId.value || !academicYearId.value) {
    generatedSet.value = new Set();
    return;
  }
  const list = await FinanceService.generatedMonths({
    payment_type_id: selectedTypeId.value,
    academic_year_id: academicYearId.value,
  });
  generatedSet.value = new Set(list);
}

onMounted(refreshGenerated);
watch([selectedTypeId, academicYearId], refreshGenerated);

// Academic years for picker.
const academicYears = ref<{ id: string | number; year: string; current?: boolean }[]>([]);
onMounted(async () => {
  try {
    academicYears.value = await AcademicYearService.list();
  } catch {
    academicYears.value = [];
  }
});

const MONTHS = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

function monthKey(year: number, month: number): string {
  return `${year}-${String(month).padStart(2, '0')}`;
}

const monthLocked = computed(() => generatedSet.value.has(monthKey(selectedYear.value, selectedMonth.value)));

const selectedType = computed(() =>
  props.paymentTypes.find((t) => t.id === selectedTypeId.value) ?? null,
);

async function submit() {
  if (!selectedTypeId.value) {
    err.value = 'Pilih jenis pembayaran.';
    return;
  }
  if (!academicYearId.value) {
    err.value = 'Pilih tahun ajaran.';
    return;
  }
  if (monthLocked.value) {
    err.value = 'Tagihan untuk bulan ini sudah pernah digenerate.';
    return;
  }

  // Confirmation step — the bulk create can't be undone in the UI, so
  // narrate exactly what's about to fire (jenis, periode, nominal) and
  // require an explicit second tap. Cheaper than a wrong-month
  // accident that ends up owning 300 wali murid a phantom tagihan.
  const type = selectedType.value;
  const monthLabel = `${MONTHS[selectedMonth.value - 1]} ${selectedYear.value}`;
  const amountLabel = type
    ? formatRupiah(Number(type.amount))
    : 'nominal jenis ini';
  const jenisLabel = type ? type.name : 'jenis terpilih';
  const ok = await confirm({
    title: `Generate tagihan ${monthLabel}?`,
    message:
      `Setiap siswa aktif akan mendapat 1 tagihan "${jenisLabel}" senilai ` +
      `${amountLabel} untuk periode ${monthLabel}. ` +
      `Setelah dijalankan, tagihan tidak bisa dibatalkan massal — ` +
      `hanya bisa dihapus satu per satu dari daftar tagihan.`,
    confirmLabel: 'Ya, generate',
  });
  if (!ok) return;

  isGenerating.value = true;
  err.value = null;
  try {
    const res = await FinanceService.generateBills({
      payment_type_id: selectedTypeId.value,
      month: monthKey(selectedYear.value, selectedMonth.value),
      academic_year_id: academicYearId.value,
    });
    emit('done', { created: res.created, skipped: res.skipped });
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isGenerating.value = false;
  }
}

const yearOptions = computed(() => {
  const this_year = new Date().getFullYear();
  return [this_year - 1, this_year, this_year + 1];
});
</script>

<template>
  <Modal
    title="Generate Tagihan Bulanan"
    subtitle="Buat tagihan untuk semua siswa di kelas yang sesuai jenis ini."
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Jenis pembayaran
        </label>
        <select
          v-model="selectedTypeId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">— pilih —</option>
          <option v-for="pt in paymentTypes" :key="pt.id" :value="pt.id">
            {{ pt.name }} ({{ pt.period }})
          </option>
        </select>
      </div>

      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Tahun ajaran
        </label>
        <select
          v-model="academicYearId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">— pilih —</option>
          <option v-for="ay in academicYears" :key="ay.id" :value="String(ay.id)">
            {{ ay.year }}{{ ay.current ? ' (aktif)' : '' }}
          </option>
        </select>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Tahun
          </label>
          <select
            v-model.number="selectedYear"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option v-for="y in yearOptions" :key="y" :value="y">{{ y }}</option>
          </select>
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Bulan
          </label>
          <select
            v-model.number="selectedMonth"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option v-for="(m, idx) in MONTHS" :key="idx" :value="idx + 1">{{ m }}</option>
          </select>
        </div>
      </div>

      <!-- Calendar-style preview -->
      <div v-if="selectedTypeId" class="bg-slate-50 rounded-xl p-3">
        <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-2">
          Status bulan ({{ selectedYear }})
        </p>
        <div class="grid grid-cols-6 gap-1.5">
          <button
            v-for="(m, idx) in MONTHS"
            :key="m"
            type="button"
            :disabled="generatedSet.has(monthKey(selectedYear, idx + 1))"
            class="rounded-lg py-2 text-3xs font-bold transition-all"
            :class="
              generatedSet.has(monthKey(selectedYear, idx + 1))
                ? 'bg-emerald-100 text-emerald-700 cursor-not-allowed'
                : selectedMonth === idx + 1
                  ? 'bg-role-admin text-white'
                  : 'bg-white text-slate-600 border border-slate-200 hover:border-role-admin'
            "
            @click="selectedMonth = idx + 1"
          >
            {{ m.slice(0, 3) }}
            <span
              v-if="generatedSet.has(monthKey(selectedYear, idx + 1))"
              class="block text-[8px] text-emerald-700 uppercase tracking-widest"
            >✓</span>
          </button>
        </div>
        <p class="text-3xs text-slate-500 mt-2 flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
          Sudah digenerate
          <span class="w-2 h-2 rounded-full bg-role-admin ml-2"></span>
          Akan digenerate
        </p>
      </div>

      <p
        v-if="monthLocked"
        class="text-2xs text-amber-700 bg-amber-50 border border-amber-200 rounded-xl p-3"
      >
        Tagihan {{ MONTHS[selectedMonth - 1] }} {{ selectedYear }} sudah pernah digenerate.
        Pilih bulan lain.
      </p>
      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <p v-if="selectedType" class="text-2xs text-slate-500">
        <NavIcon name="info" :size="12" class="inline mr-1" />
        Nominal per siswa: <strong>{{ selectedType.amount }}</strong> · Periode {{ selectedType.period }}.
      </p>

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isGenerating"
          :disabled="monthLocked"
          @click="submit"
        >
          Generate
        </Button>
      </div>
    </div>
  </Modal>
</template>

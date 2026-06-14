<!--
  ParentEnrollWizardView — wali 4-step enrollment wizard. New layout:
  hero with kicker + "Batalkan" chip, full-width 4-step stepper with
  done/current/pending states, then per-step choice cards or summary.
  Script logic (state shape, validation, submit) unchanged.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import { formatRupiah } from '@/lib/format';
import type {
  TutoringGroup,
  TutoringPackage,
  TutoringProgram,
  TutoringVoucherPreview,
} from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const router = useRouter();
const { children } = useChildPicker();

type Step = 1 | 2 | 3 | 4;
const step = ref<Step>(1);

const studentId = ref('');
const programs = ref<TutoringProgram[]>([]);
const programId = ref('');
const packages = ref<TutoringPackage[]>([]);
const packageId = ref('');
const billingMode = ref('PREPAID');
const groups = ref<TutoringGroup[]>([]);
const groupId = ref('');
const voucherCode = ref('');
const voucherPreview = ref<TutoringVoucherPreview | null>(null);
const voucherMessage = ref<string | null>(null);
const saving = ref(false);
const successId = ref<string | null>(null);
const errorMsg = ref<string | null>(null);

onMounted(async () => {
  try { programs.value = await TutoringService.getPrograms(); }
  catch {/* non-fatal */}
  if (children.value[0]) studentId.value = children.value[0].student_id;
});

watch(programId, async (id) => {
  packageId.value = '';
  if (!id) { packages.value = []; groups.value = []; return; }
  try {
    [packages.value, groups.value] = await Promise.all([
      TutoringService.getPackages(id),
      TutoringService.getGroups(id),
    ]);
  } catch {/* non-fatal */}
});

const selectedPackage = computed(() => packages.value.find((p) => p.id === packageId.value) ?? null);
const selectedProgram = computed(() => programs.value.find((p) => p.id === programId.value) ?? null);
const selectedChild = computed(() => children.value.find((c) => c.student_id === studentId.value) ?? null);
const selectedGroup = computed(() => groups.value.find((g) => g.id === groupId.value) ?? null);

const childFirstName = computed(() => (selectedChild.value?.name ?? children.value[0]?.name ?? 'anak').split(' ')[0]);

const subtotal = computed(() => selectedPackage.value?.price ?? 0);
const discount = computed(() => voucherPreview.value?.discount_amount ?? 0);
const total = computed(() => Math.max(0, subtotal.value - discount.value));

async function tryVoucher() {
  voucherMessage.value = null;
  voucherPreview.value = null;
  if (!voucherCode.value.trim() || subtotal.value <= 0) return;
  try {
    voucherPreview.value = await TutoringService.validateVoucher(
      voucherCode.value.trim().toUpperCase(),
      subtotal.value,
    );
    voucherMessage.value = `Kode valid · diskon ${formatRupiah(discount.value)}.`;
  } catch (e) {
    voucherMessage.value = e instanceof Error ? e.message : 'Kode tidak valid.';
  }
}

const canNext = computed(() => {
  if (step.value === 1) return !!studentId.value && !!programId.value;
  if (step.value === 2) return !!packageId.value;
  if (step.value === 3) return true;
  return true;
});

function next() {
  if (step.value < 4) step.value = ((step.value + 1) as Step);
}
function back() {
  if (step.value > 1) step.value = ((step.value - 1) as Step);
}

async function submit() {
  if (!packageId.value || !studentId.value) return;
  saving.value = true;
  errorMsg.value = null;
  try {
    const id = await TutoringService.createEnrollment({
      student_id: studentId.value,
      package_id: packageId.value,
      billing_mode: billingMode.value,
      group_id: groupId.value || undefined,
    });
    successId.value = id;
  } catch (e) {
    errorMsg.value = e instanceof Error ? e.message : 'Gagal mendaftarkan.';
  } finally { saving.value = false; }
}

const stepLabels = ['Program', 'Paket', 'Mode bayar', 'Konfirmasi'];

const stepHeader = computed(() => {
  const ctx = selectedProgram.value?.name ?? 'pilih program';
  if (step.value === 1) return `PILIH ANAK & PROGRAM`;
  if (step.value === 2) return `PILIH PAKET — ${ctx}`;
  if (step.value === 3) return `MODE BAYAR & VOUCHER — ${ctx}`;
  return `KONFIRMASI — ${ctx}`;
});

const nextCtaLabel = computed(() => {
  if (step.value === 1) return 'Lanjut: pilih paket →';
  if (step.value === 2) return 'Lanjut: pilih mode bayar →';
  if (step.value === 3) return 'Lanjut: konfirmasi →';
  return saving.value ? 'Memproses…' : 'Daftarkan';
});

const packageTone = (idx: number) =>
  ['blue', 'green', 'amber', 'blue', 'green'][idx % 5];
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · DAFTAR PROGRAM"
      :title="`Daftarkan ${childFirstName} ke program baru`"
      :subtitle="`Langkah ${step} dari 4`"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-lg bg-white px-3 py-1.5 text-[13px] font-bold text-bimbel-hero hover:bg-white/95"
          @click="router.back()"
        >
          <i class="ti ti-x text-[13px]"></i>
          Batalkan
        </button>
      </template>
    </ParentBerandaHero>

    <!-- Success state -->
    <div
      v-if="successId"
      class="rounded-lg bg-bimbel-green-dim p-6 text-center"
    >
      <div class="mx-auto mb-2 grid h-10 w-10 place-items-center rounded-full bg-green-700 text-white">
        <i class="ti ti-check text-[18px]"></i>
      </div>
      <h3 class="text-[14px] font-bold text-bimbel-text-hi">Pendaftaran berhasil</h3>
      <p class="mt-1 text-[12px] text-bimbel-text-mid">ID enrolment: {{ successId }}</p>
      <button
        type="button"
        class="mt-4 rounded-lg bg-bimbel-hero text-white text-[13px] font-bold px-4 py-2"
        @click="router.push({ name: 'parent.tutoring.bills' })"
      >Lihat tagihan</button>
    </div>

    <template v-else>
      <!-- 1. Stepper -->
      <div class="flex items-center gap-0 mb-3.5 mt-1">
        <template v-for="(label, idx) in stepLabels" :key="label">
          <div class="flex items-center gap-1.5 flex-shrink-0">
            <span
              class="grid h-[22px] w-[22px] place-items-center rounded-full text-[11px] font-bold"
              :class="
                step > (idx + 1)
                  ? 'bg-green-700 text-white'
                  : step === (idx + 1)
                  ? 'bg-bimbel-hero text-white'
                  : 'bg-bimbel-bg text-bimbel-text-mid'
              "
            >
              <i v-if="step > (idx + 1)" class="ti ti-check text-[12px]"></i>
              <template v-else>{{ idx + 1 }}</template>
            </span>
            <span
              class="text-[11px] hidden sm:inline"
              :class="
                step === (idx + 1)
                  ? 'font-bold text-bimbel-text-hi'
                  : step > (idx + 1)
                  ? 'text-bimbel-text-hi'
                  : 'text-bimbel-text-mid'
              "
            >{{ label }}</span>
          </div>
          <div
            v-if="idx < stepLabels.length - 1"
            class="flex-1 h-px mx-1.5"
            :class="step > (idx + 1) ? 'bg-green-700' : 'bg-bimbel-border-soft'"
          />
        </template>
      </div>

      <!-- 2. Step header -->
      <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
        {{ stepHeader }}
      </p>

      <!-- 3. Step body -->
      <!-- Step 1 — anak + program -->
      <template v-if="step === 1">
        <div class="mb-3">
          <p class="text-[11px] text-bimbel-text-mid mb-1">Pilih anak</p>
          <div class="grid gap-1.5 sm:grid-cols-2">
            <button
              v-for="c in children"
              :key="c.student_id"
              type="button"
              class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3 flex gap-2.5 items-center text-left"
              :class="studentId === c.student_id ? 'border-2 border-bimbel-hero p-[11px]' : ''"
              @click="studentId = c.student_id"
            >
              <span class="grid h-10 w-10 flex-shrink-0 place-items-center rounded-lg bg-bimbel-accent-dim text-bimbel-hero text-[13px] font-bold">
                {{ c.name[0]?.toUpperCase() ?? '?' }}
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-[13px] font-bold text-bimbel-text-hi truncate">{{ c.name }}</p>
                <p class="text-[11px] text-bimbel-text-mid truncate">{{ c.class_name || '—' }}</p>
              </div>
            </button>
          </div>
        </div>
        <p class="text-[11px] text-bimbel-text-mid mb-1">Pilih program</p>
        <button
          v-for="(p, idx) in programs"
          :key="p.id"
          type="button"
          class="w-full rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3 mb-1.5 flex gap-2.5 items-center text-left"
          :class="programId === p.id ? 'border-2 border-bimbel-hero p-[11px]' : ''"
          @click="programId = p.id"
        >
          <span
            class="grid h-10 w-10 flex-shrink-0 place-items-center rounded-lg"
            :class="
              packageTone(idx) === 'green'
                ? 'bg-bimbel-green-dim text-green-700'
                : packageTone(idx) === 'amber'
                ? 'bg-bimbel-amber-dim text-amber-700'
                : 'bg-bimbel-accent-dim text-bimbel-hero'
            "
          >
            <i class="ti ti-book-2 text-[18px]"></i>
          </span>
          <div class="min-w-0 flex-1">
            <p class="text-[13px] font-bold text-bimbel-text-hi truncate">{{ p.name }}</p>
            <p v-if="p.description" class="text-[11px] text-bimbel-text-mid truncate">{{ p.description }}</p>
          </div>
        </button>
      </template>

      <!-- Step 2 — pilih paket -->
      <template v-else-if="step === 2">
        <div v-if="!packages.length" class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-6 text-center text-[12px] text-bimbel-text-mid">
          Belum ada paket aktif untuk program ini.
        </div>
        <button
          v-for="(p, idx) in packages"
          :key="p.id"
          type="button"
          class="w-full rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3 mb-1.5 flex gap-2.5 items-center text-left"
          :class="packageId === p.id ? 'border-2 border-bimbel-hero p-[11px]' : ''"
          @click="packageId = p.id"
        >
          <span
            class="grid h-10 w-10 flex-shrink-0 place-items-center rounded-lg"
            :class="
              packageTone(idx) === 'green'
                ? 'bg-bimbel-green-dim text-green-700'
                : packageTone(idx) === 'amber'
                ? 'bg-bimbel-amber-dim text-amber-700'
                : 'bg-bimbel-accent-dim text-bimbel-hero'
            "
          >
            <i class="ti ti-package text-[18px]"></i>
          </span>
          <div class="min-w-0 flex-1">
            <p class="text-[13px] font-bold text-bimbel-text-hi truncate">{{ p.name }}</p>
            <p class="text-[11px] text-bimbel-text-mid truncate">{{ p.total_sessions ?? '–' }} sesi</p>
          </div>
          <span class="flex-shrink-0 text-[13px] font-bold text-bimbel-hero">
            {{ p.price != null ? formatRupiah(p.price) : '—' }}
          </span>
        </button>
      </template>

      <!-- Step 3 — mode bayar + voucher -->
      <template v-else-if="step === 3">
        <p class="text-[11px] text-bimbel-text-mid mb-1">Mode pembayaran</p>
        <button
          v-for="m in (selectedPackage?.billing_modes_allowed ?? ['PREPAID', 'MONTHLY'])"
          :key="m"
          type="button"
          class="w-full rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3 mb-1.5 flex gap-2.5 items-center text-left"
          :class="billingMode === m ? 'border-2 border-bimbel-hero p-[11px]' : ''"
          @click="billingMode = m"
        >
          <span class="grid h-10 w-10 flex-shrink-0 place-items-center rounded-lg bg-bimbel-accent-dim text-bimbel-hero">
            <i class="ti ti-wallet text-[18px]"></i>
          </span>
          <div class="min-w-0 flex-1">
            <p class="text-[13px] font-bold text-bimbel-text-hi truncate">
              {{ m === 'PREPAID' ? 'Bayar di muka' : m === 'MONTHLY' ? 'Cicil bulanan' : m === 'PER_SESSION' ? 'Per sesi' : m }}
            </p>
            <p class="text-[11px] text-bimbel-text-mid truncate">
              {{ m === 'PREPAID' ? 'Diskon maksimal' : m === 'MONTHLY' ? 'Ringan per bulan' : 'Bayar sesuai datang' }}
            </p>
          </div>
        </button>

        <div v-if="groups.length" class="mt-3">
          <p class="text-[11px] text-bimbel-text-mid mb-1">Kelompok (opsional)</p>
          <select
            v-model="groupId"
            class="w-full rounded-md bg-bimbel-bg px-3 py-2.5 text-[13px] text-bimbel-text-hi focus:outline-none"
          >
            <option value="">— biar admin yang menugaskan —</option>
            <option v-for="g in groups" :key="g.id" :value="g.id">
              {{ g.name }}<template v-if="g.tutor?.name"> · {{ g.tutor.name }}</template>
            </option>
          </select>
        </div>

        <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
          Kode voucher (opsional)
        </p>
        <div class="flex gap-1.5">
          <input
            v-model="voucherCode"
            type="text"
            placeholder="Masukkan kode"
            class="flex-1 rounded-md bg-bimbel-bg px-3 py-2 text-[13px] uppercase tracking-wider text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:outline-none"
          />
          <button
            type="button"
            class="rounded-md bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft px-3.5 py-2 text-[13px] font-bold"
            @click="tryVoucher"
          >Pakai</button>
        </div>
        <p v-if="voucherMessage" class="mt-1 text-[11px] text-bimbel-text-mid">{{ voucherMessage }}</p>
      </template>

      <!-- Step 4 — konfirmasi -->
      <template v-else>
        <div class="rounded-lg bg-bimbel-panel border border-bimbel-border-soft p-3 space-y-2">
          <div class="flex items-center justify-between text-[12px]">
            <span class="text-bimbel-text-mid">Anak</span>
            <span class="font-bold text-bimbel-text-hi">{{ selectedChild?.name ?? '—' }}</span>
          </div>
          <div class="flex items-center justify-between text-[12px]">
            <span class="text-bimbel-text-mid">Program</span>
            <span class="font-bold text-bimbel-text-hi">{{ selectedProgram?.name ?? '—' }}</span>
          </div>
          <div class="flex items-center justify-between text-[12px]">
            <span class="text-bimbel-text-mid">Paket</span>
            <span class="font-bold text-bimbel-text-hi">{{ selectedPackage?.name ?? '—' }}</span>
          </div>
          <div class="flex items-center justify-between text-[12px]">
            <span class="text-bimbel-text-mid">Mode</span>
            <span class="font-bold text-bimbel-text-hi">{{ billingMode }}</span>
          </div>
          <div v-if="selectedGroup" class="flex items-center justify-between text-[12px]">
            <span class="text-bimbel-text-mid">Kelompok</span>
            <span class="font-bold text-bimbel-text-hi">{{ selectedGroup.name }}</span>
          </div>
        </div>
        <div class="rounded-lg bg-bimbel-accent-dim p-3 mt-3">
          <div class="flex items-center justify-between text-[12px] text-bimbel-hero">
            <span>Subtotal</span>
            <span>{{ subtotal > 0 ? formatRupiah(subtotal) : '—' }}</span>
          </div>
          <div v-if="discount > 0" class="flex items-center justify-between text-[12px] text-bimbel-hero">
            <span>Diskon voucher</span>
            <span>− {{ formatRupiah(discount) }}</span>
          </div>
          <div class="mt-1 flex items-center justify-between text-[14px] font-extrabold text-bimbel-hero">
            <span>Total</span>
            <span>{{ formatRupiah(total) }}</span>
          </div>
        </div>
        <div v-if="errorMsg" class="rounded-md mt-3 bg-bimbel-red-dim text-red-700 px-3 py-2 text-[12px]">
          {{ errorMsg }}
        </div>
      </template>

      <!-- 4. CTA row -->
      <div class="flex gap-2 mt-3">
        <button
          type="button"
          class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft text-[13px] font-bold px-3.5 py-2.5"
          @click="step === 1 ? router.back() : back()"
        >Kembali</button>
        <button
          v-if="step < 4"
          type="button"
          :disabled="!canNext"
          class="flex-1 rounded-lg bg-bimbel-hero text-white text-[13px] font-bold px-3.5 py-2.5 disabled:opacity-50"
          @click="next"
        >{{ nextCtaLabel }}</button>
        <button
          v-else
          type="button"
          :disabled="saving"
          class="flex-1 rounded-lg bg-bimbel-hero text-white text-[13px] font-bold px-3.5 py-2.5 disabled:opacity-50"
          @click="submit"
        >{{ nextCtaLabel }}</button>
      </div>
    </template>
  </div>
</template>

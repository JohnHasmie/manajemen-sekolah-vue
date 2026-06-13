<!--
  ParentEnrollWizardView — wali 4-step enrollment wizard. Mockup
  parent_web_pages_create_update frame 2: stepper + paket grid + summary.
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
import NavIcon from '@/components/feature/NavIcon.vue';

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
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="DAFTAR PROGRAM"
      title="Daftarkan anak"
      :subtitle="`Langkah ${step} dari 4`"
      :stats="[]"
    />

    <div class="flex items-center gap-2 rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3">
      <template v-for="s in [1, 2, 3, 4]" :key="s">
        <div class="flex items-center gap-2">
          <span
            class="grid h-7 w-7 place-items-center rounded-full text-[12px] font-bold"
            :class="
              step === s
                ? 'bg-[#21afe6] text-white'
                : step > s
                ? 'bg-emerald-500 text-white'
                : 'bg-bimbel-panel border border-bimbel-border text-bimbel-text-mid'
            "
          >
            <NavIcon v-if="step > s" name="check-circle" :size="12" />
            <template v-else>{{ s }}</template>
          </span>
          <span class="hidden sm:inline text-[12px] font-semibold" :class="step === s ? 'text-bimbel-text-hi' : 'text-bimbel-text-mid'">
            {{ s === 1 ? 'Anak & program' : s === 2 ? 'Pilih paket' : s === 3 ? 'Voucher & mode' : 'Konfirmasi' }}
          </span>
        </div>
        <div v-if="s < 4" class="flex-1 h-px bg-bimbel-border-soft" />
      </template>
    </div>

    <div v-if="successId" class="rounded-2xl border border-emerald-500/40 bg-emerald-500/10 p-6 text-center">
      <NavIcon name="check-circle" :size="32" class="mx-auto text-emerald-600 dark:text-emerald-400" />
      <h3 class="mt-2 text-[15px] font-bold text-bimbel-text-hi">Pendaftaran berhasil</h3>
      <p class="mt-1 text-[12px] text-bimbel-text-mid">ID enrolment: {{ successId }}</p>
      <button
        type="button"
        class="mt-4 rounded-lg bg-[#21afe6] px-4 py-2 text-[13px] font-bold text-white hover:opacity-90"
        @click="router.push({ name: 'parent.tutoring.tagihan' })"
      >Lihat tagihan</button>
    </div>

    <div v-else class="grid gap-4 lg:grid-cols-5">
      <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-3 space-y-3">
        <!-- Step 1 -->
        <div v-if="step === 1" class="space-y-3">
          <div>
            <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Pilih anak</p>
            <div class="mt-1 grid gap-2 sm:grid-cols-2">
              <button
                v-for="c in children"
                :key="c.student_id"
                type="button"
                class="flex items-center gap-2 rounded-xl border px-3 py-2 text-left transition"
                :class="
                  studentId === c.student_id
                    ? 'border-[#21afe6] bg-[#21afe6]/10'
                    : 'border-bimbel-border-soft hover:border-bimbel-border'
                "
                @click="studentId = c.student_id"
              >
                <span class="grid h-8 w-8 place-items-center rounded-full bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4] text-[12px] font-bold">
                  {{ c.name[0]?.toUpperCase() ?? '?' }}
                </span>
                <div class="min-w-0">
                  <p class="truncate text-[13px] font-bold text-bimbel-text-hi">{{ c.name }}</p>
                  <p class="truncate text-[12px] text-bimbel-text-mid">{{ c.class_name }}</p>
                </div>
              </button>
            </div>
          </div>
          <div>
            <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Pilih program</p>
            <select v-model="programId" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none">
              <option value="">— pilih —</option>
              <option v-for="p in programs" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
          </div>
        </div>

        <!-- Step 2 -->
        <div v-else-if="step === 2" class="space-y-3">
          <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Paket tersedia</p>
          <div class="grid gap-2 sm:grid-cols-3">
            <button
              v-for="p in packages"
              :key="p.id"
              type="button"
              class="rounded-xl border p-3 text-left transition"
              :class="
                packageId === p.id
                  ? 'border-2 border-[#21afe6] bg-[#21afe6]/8 p-[11px]'
                  : 'border-bimbel-border-soft hover:border-bimbel-border'
              "
              @click="packageId = p.id"
            >
              <p class="text-[13px] font-bold text-bimbel-text-hi">{{ p.name }}</p>
              <p class="text-[12px] text-bimbel-text-mid">{{ p.total_sessions ?? '–' }} sesi</p>
              <p class="mt-2 text-[16px] font-extrabold text-bimbel-text-hi">{{ p.price != null ? formatRupiah(p.price) : '—' }}</p>
            </button>
          </div>
        </div>

        <!-- Step 3 -->
        <div v-else-if="step === 3" class="space-y-3">
          <div>
            <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Mode billing</p>
            <div class="mt-1 flex gap-1.5">
              <button
                v-for="m in selectedPackage?.billing_modes_allowed ?? ['PREPAID', 'MONTHLY']"
                :key="m"
                type="button"
                class="rounded-full border px-3 py-1.5 text-[12px] font-semibold"
                :class="
                  billingMode === m
                    ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
                    : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'
                "
                @click="billingMode = m"
              >{{ m === 'PREPAID' ? 'Bayar di muka' : m === 'MONTHLY' ? 'Cicil bulanan' : m === 'PER_SESSION' ? 'Per sesi' : m }}</button>
            </div>
          </div>
          <div v-if="groups.length">
            <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Pilih kelompok (opsional)</p>
            <select v-model="groupId" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none">
              <option value="">— biar admin yang menugaskan —</option>
              <option v-for="g in groups" :key="g.id" :value="g.id">
                {{ g.name }}<template v-if="g.tutor?.name"> · {{ g.tutor.name }}</template>
              </option>
            </select>
          </div>
          <div>
            <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Kode voucher</p>
            <div class="mt-1 flex gap-2">
              <input
                v-model="voucherCode"
                type="text"
                placeholder="Opsional"
                class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] uppercase tracking-wider text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
              />
              <button
                type="button"
                class="rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
                @click="tryVoucher"
              >Pakai</button>
            </div>
            <p v-if="voucherMessage" class="mt-1 text-[12px] text-bimbel-text-mid">{{ voucherMessage }}</p>
          </div>
        </div>

        <!-- Step 4 -->
        <div v-else class="space-y-2">
          <p class="text-[12px] font-bold text-bimbel-text-hi">Konfirmasi pendaftaran</p>
          <p class="text-[12px] text-bimbel-text-mid">
            Setelah pendaftaran tersimpan, tagihan otomatis dibuat sesuai mode billing yang dipilih.
          </p>
          <div v-if="errorMsg" class="rounded-lg bg-rose-500/10 px-3 py-2 text-[12px] text-rose-700 dark:text-rose-300">{{ errorMsg }}</div>
        </div>

        <div class="flex gap-2 pt-3 border-t border-bimbel-border-soft">
          <button
            type="button"
            class="rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
            @click="step === 1 ? router.back() : back()"
          >{{ step === 1 ? 'Batal' : 'Kembali' }}</button>
          <button
            v-if="step < 4"
            type="button"
            :disabled="!canNext"
            class="ml-auto rounded-lg bg-[#21afe6] px-4 py-2 text-[13px] font-bold text-white hover:opacity-90 disabled:opacity-50"
            @click="next"
          >Lanjut →</button>
          <button
            v-else
            type="button"
            :disabled="saving"
            class="ml-auto rounded-lg bg-emerald-600 px-4 py-2 text-[13px] font-bold text-white hover:opacity-90 disabled:opacity-50"
            @click="submit"
          >{{ saving ? 'Memproses…' : 'Daftarkan' }}</button>
        </div>
      </div>

      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-2 h-fit space-y-2">
        <h4 class="text-[13px] font-bold tracking-tight text-bimbel-text-hi">Ringkasan</h4>
        <dl class="space-y-1.5 text-[12px]">
          <div class="flex justify-between"><dt class="text-bimbel-text-mid">Anak</dt><dd class="font-bold text-bimbel-text-hi">{{ selectedChild?.name ?? '—' }}</dd></div>
          <div class="flex justify-between"><dt class="text-bimbel-text-mid">Program</dt><dd class="font-bold text-bimbel-text-hi">{{ selectedProgram?.name ?? '—' }}</dd></div>
          <div class="flex justify-between"><dt class="text-bimbel-text-mid">Paket</dt><dd class="font-bold text-bimbel-text-hi">{{ selectedPackage?.name ?? '—' }}</dd></div>
          <div class="flex justify-between"><dt class="text-bimbel-text-mid">Mode</dt><dd class="font-bold text-bimbel-text-hi">{{ billingMode }}</dd></div>
          <div v-if="selectedGroup" class="flex justify-between"><dt class="text-bimbel-text-mid">Kelompok</dt><dd class="font-bold text-bimbel-text-hi">{{ selectedGroup.name }}</dd></div>
          <div class="flex justify-between border-t border-bimbel-border-soft pt-1.5"><dt class="text-bimbel-text-mid">Subtotal</dt><dd>{{ subtotal > 0 ? formatRupiah(subtotal) : '—' }}</dd></div>
          <div v-if="discount > 0" class="flex justify-between text-emerald-700 dark:text-emerald-300"><dt>Diskon</dt><dd>− {{ formatRupiah(discount) }}</dd></div>
          <div class="flex justify-between border-t border-bimbel-border-soft pt-1.5"><dt class="font-bold text-bimbel-text-hi">Total</dt><dd class="text-[14px] font-extrabold text-bimbel-text-hi">{{ formatRupiah(total) }}</dd></div>
        </dl>
      </aside>
    </div>
  </div>
</template>

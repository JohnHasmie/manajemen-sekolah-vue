<!--
  AdminTutoringBillingSettingsView — toggle which billing modes the
  tenant offers + a default mode. Rebuilt on the tutoring shared
  components.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();
const loading = ref(true);
const saving = ref(false);

const allowPrepaid = ref(true);
const allowMonthly = ref(true);
const allowPerSession = ref(true);
const defaultMode = ref<string | null>(null);

// Payment account — surfaced on parent bill detail so wali knows
// where to transfer. All fields optional; UI groups by channel.
const bankName = ref('');
const bankAccountNumber = ref('');
const bankAccountHolder = ref('');
const qrisImageUrl = ref<string | null>(null);
const paymentInstructions = ref('');
const paymentGatewayEnabled = ref(false);
const paymentGatewayProvider = ref<string>('');
const paymentGatewayConfigured = ref(false);
const qrisUploading = ref(false);

const enabledModes = computed(() => {
  const m: string[] = [];
  if (allowPrepaid.value) m.push('PREPAID');
  if (allowMonthly.value) m.push('MONTHLY');
  if (allowPerSession.value) m.push('PER_SESSION');
  return m;
});

const MODE_KEYS: Record<string, string> = {
  PREPAID: 'tutoring.billing.prepaid',
  MONTHLY: 'tutoring.billing.monthly',
  PER_SESSION: 'tutoring.billing.perSession',
};
const modeLabel = (m: string) => (MODE_KEYS[m] ? t(MODE_KEYS[m]) : m);

async function load() {
  loading.value = true;
  try {
    const s = await TutoringService.getBillingSettings();
    allowPrepaid.value = s.allow_prepaid;
    allowMonthly.value = s.allow_monthly;
    allowPerSession.value = s.allow_per_session;
    defaultMode.value = s.default_mode ?? null;
    bankName.value = s.bank_name ?? '';
    bankAccountNumber.value = s.bank_account_number ?? '';
    bankAccountHolder.value = s.bank_account_holder ?? '';
    qrisImageUrl.value = s.qris_image_url ?? null;
    paymentInstructions.value = s.payment_instructions ?? '';
    paymentGatewayEnabled.value = !!s.payment_gateway_enabled;
    paymentGatewayProvider.value = s.payment_gateway_provider ?? '';
    paymentGatewayConfigured.value = !!s.payment_gateway_configured;
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.billing.loadFailed'),
    );
  } finally {
    loading.value = false;
  }
}

async function save() {
  if (defaultMode.value && !enabledModes.value.includes(defaultMode.value)) {
    defaultMode.value = null;
  }
  saving.value = true;
  try {
    await TutoringService.updateBillingSettings({
      allow_prepaid: allowPrepaid.value,
      allow_monthly: allowMonthly.value,
      allow_per_session: allowPerSession.value,
      default_mode: defaultMode.value,
      bank_name: bankName.value.trim() || null,
      bank_account_number: bankAccountNumber.value.trim() || null,
      bank_account_holder: bankAccountHolder.value.trim() || null,
      qris_image_url: qrisImageUrl.value,
      payment_instructions: paymentInstructions.value.trim() || null,
      payment_gateway_enabled: paymentGatewayEnabled.value,
      payment_gateway_provider:
        paymentGatewayProvider.value.trim() || null,
    });
    toast.success(t('tutoring.billing.saved'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.billing.saveFailed'),
    );
  } finally {
    saving.value = false;
  }
}

async function onQrisChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0];
  if (!file) return;
  qrisUploading.value = true;
  try {
    const { url } = await TutoringService.uploadQrisImage(file);
    qrisImageUrl.value = url;
    toast.success('QRIS terunggah. Klik Simpan untuk persistensi.');
  } catch (err) {
    toast.error(err instanceof Error ? err.message : String(err));
  } finally {
    qrisUploading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Pengaturan Billing"
      :title="t('tutoring.billing.title')"
      :meta="t('tutoring.billing.hint')"
    />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>

    <div v-else>

      <label
        v-for="cfg in [
          {
            v: allowPrepaid,
            set: (b: boolean) => (allowPrepaid = b),
            t: t('tutoring.billing.prepaid'),
            s: t('tutoring.billing.prepaidDesc'),
          },
          {
            v: allowMonthly,
            set: (b: boolean) => (allowMonthly = b),
            t: t('tutoring.billing.monthly'),
            s: t('tutoring.billing.monthlyDesc'),
          },
          {
            v: allowPerSession,
            set: (b: boolean) => (allowPerSession = b),
            t: t('tutoring.billing.perSession'),
            s: t('tutoring.billing.perSessionDesc'),
          },
        ]"
        :key="cfg.t"
        class="flex items-center justify-between gap-3 bg-bimbel-panel border border-bimbel-border-soft rounded-2xl px-4 py-3 mb-2 cursor-pointer"
      >
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-bimbel-text-hi">{{ cfg.t }}</span>
          <span class="block text-xs text-bimbel-text-mid mt-0.5">{{ cfg.s }}</span>
        </span>
        <input
          :checked="cfg.v"
          type="checkbox"
          class="h-5 w-5 accent-role-admin"
          @change="cfg.set(($event.target as HTMLInputElement).checked)"
        />
      </label>

      <TutoringSectionHeader :title="t('tutoring.billing.defaultMode')" />
      <select
        v-model="defaultMode"
        class="w-full rounded-lg border border-bimbel-border px-3 py-2.5 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
      >
        <option :value="null">{{ t('tutoring.billing.none') }}</option>
        <option v-for="m in enabledModes" :key="m" :value="m">
          {{ modeLabel(m) }}
        </option>
      </select>

      <!-- ── Rekening Bimbel ─────────────────────────────────────── -->
      <TutoringSectionHeader title="Rekening Bimbel" />
      <div class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl p-4 space-y-3">
        <p class="text-xs text-bimbel-text-mid">
          Ditampilkan ke wali di halaman detail tagihan sebagai tujuan transfer.
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <label class="block">
            <span class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Nama Bank</span>
            <input
              v-model="bankName"
              type="text"
              maxlength="80"
              placeholder="Mis. BCA, BRI, Mandiri"
              class="mt-1 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm"
            />
          </label>
          <label class="block">
            <span class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Nomor Rekening</span>
            <input
              v-model="bankAccountNumber"
              type="text"
              maxlength="40"
              placeholder="1234567890"
              class="mt-1 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm font-mono"
            />
          </label>
          <label class="block sm:col-span-2">
            <span class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Atas Nama</span>
            <input
              v-model="bankAccountHolder"
              type="text"
              maxlength="120"
              placeholder="Nama pemilik rekening"
              class="mt-1 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm"
            />
          </label>
        </div>
      </div>

      <!-- ── QRIS ─────────────────────────────────────────────────── -->
      <TutoringSectionHeader title="QRIS" />
      <div class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl p-4 space-y-3">
        <p class="text-xs text-bimbel-text-mid">
          Unggah gambar QRIS (PNG/JPG, maks 2MB). Wali bisa langsung scan dari detail tagihan.
        </p>
        <div class="flex items-start gap-4">
          <div
            v-if="qrisImageUrl"
            class="h-32 w-32 rounded-lg border border-bimbel-border bg-bimbel-bg overflow-hidden flex items-center justify-center shrink-0"
          >
            <img :src="qrisImageUrl" alt="QRIS" class="max-h-full max-w-full" />
          </div>
          <div
            v-else
            class="h-32 w-32 rounded-lg border-2 border-dashed border-bimbel-border bg-bimbel-bg flex items-center justify-center text-bimbel-text-lo shrink-0"
          >
            <NavIcon name="image" :size="32" />
          </div>
          <div class="flex-1 space-y-2">
            <input
              type="file"
              accept="image/png,image/jpeg"
              class="block w-full text-xs file:mr-3 file:rounded-md file:border-0 file:bg-bimbel-accent/10 file:text-bimbel-accent file:px-3 file:py-2 file:font-bold file:text-[12px] file:cursor-pointer"
              :disabled="qrisUploading"
              @change="onQrisChange"
            />
            <button
              v-if="qrisImageUrl"
              type="button"
              class="text-[12px] font-bold text-bimbel-red hover:underline"
              @click="qrisImageUrl = null"
            >
              Hapus QRIS
            </button>
            <p v-if="qrisUploading" class="text-[12px] text-bimbel-text-lo">Mengunggah…</p>
          </div>
        </div>
      </div>

      <!-- ── Instruksi Pembayaran ────────────────────────────────── -->
      <TutoringSectionHeader title="Instruksi Pembayaran" />
      <div class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl p-4 space-y-2">
        <p class="text-xs text-bimbel-text-mid">
          Bebas — mis. nomor e-wallet, cicilan, konfirmasi via WhatsApp.
        </p>
        <textarea
          v-model="paymentInstructions"
          rows="4"
          maxlength="2000"
          placeholder="Mis. Setelah transfer, kirim bukti ke 0812xxx via WhatsApp."
          class="w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm resize-none"
        />
      </div>

      <!-- ── Payment Gateway (placeholder) ───────────────────────── -->
      <TutoringSectionHeader title="Payment Gateway" />
      <div class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl p-4 space-y-3">
        <label class="flex items-center justify-between gap-3 cursor-pointer">
          <span class="min-w-0">
            <span class="block text-sm font-semibold text-bimbel-text-hi">Aktifkan payment gateway</span>
            <span class="block text-xs text-bimbel-text-mid mt-0.5">
              Integrasi Midtrans / Xendit. Kredensial dikonfigurasi via admin platform.
            </span>
          </span>
          <input
            v-model="paymentGatewayEnabled"
            type="checkbox"
            class="h-5 w-5 accent-role-admin"
          />
        </label>
        <div v-if="paymentGatewayEnabled" class="space-y-2">
          <label class="block">
            <span class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Provider</span>
            <select
              v-model="paymentGatewayProvider"
              class="mt-1 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm"
            >
              <option value="">— Pilih —</option>
              <option value="midtrans">Midtrans</option>
              <option value="xendit">Xendit</option>
            </select>
          </label>
          <p v-if="paymentGatewayConfigured" class="text-[12px] text-emerald-600 font-bold">
            ✓ Kredensial sudah dikonfigurasi.
          </p>
          <p v-else class="text-[12px] text-amber-600">
            Kredensial belum disetel. Hubungi admin platform.
          </p>
        </div>
      </div>

      <button
        :disabled="saving"
        class="mt-4 w-full rounded-lg bg-bimbel-accent hover:opacity-90 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="save"
      >
        {{ saving ? t('tutoring.common.saving') : t('tutoring.common.save') }}
      </button>
    </div>
  </div>
</template>

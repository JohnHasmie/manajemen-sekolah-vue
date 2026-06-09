<!--
  AdminTutoringBillingSettingsView — toggle which billing modes the bimbel
  offers (prepaid / monthly / per-session) + default mode. Web mirror of
  the Flutter `tutoring_billing_settings_screen.dart`. Server enforces
  "at least one mode" / "mode in use" — surfaced as toasts.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { BILLING_MODE_LABELS } from '@/types/tutoring';

const toast = useToast();
const loading = ref(true);
const saving = ref(false);

const allowPrepaid = ref(true);
const allowMonthly = ref(true);
const allowPerSession = ref(true);
const defaultMode = ref<string | null>(null);

const enabledModes = computed(() => {
  const m: string[] = [];
  if (allowPrepaid.value) m.push('PREPAID');
  if (allowMonthly.value) m.push('MONTHLY');
  if (allowPerSession.value) m.push('PER_SESSION');
  return m;
});

async function load() {
  loading.value = true;
  try {
    const s = await TutoringService.getBillingSettings();
    allowPrepaid.value = s.allow_prepaid;
    allowMonthly.value = s.allow_monthly;
    allowPerSession.value = s.allow_per_session;
    defaultMode.value = s.default_mode ?? null;
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat pengaturan.');
  } finally {
    loading.value = false;
  }
}

async function save() {
  // Keep default valid if its mode was switched off.
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
    });
    toast.success('Pengaturan billing tersimpan.');
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.');
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-2xl p-4">
    <h1 class="mb-4 text-lg font-bold text-slate-800">Pengaturan Billing</h1>

    <div v-if="loading" class="py-16 text-center text-slate-500">Memuat…</div>

    <div v-else class="space-y-4">
      <p class="text-sm text-slate-500">
        Minimal satu mode harus aktif. Mode yang sedang dipakai enrollment
        aktif tidak bisa dimatikan.
      </p>

      <label class="flex items-center justify-between rounded-xl border border-slate-200 p-3">
        <span>
          <span class="font-semibold text-slate-800">Paket Prabayar</span>
          <span class="block text-xs text-slate-500">Bayar di muka untuk N sesi.</span>
        </span>
        <input v-model="allowPrepaid" type="checkbox" class="h-5 w-5" />
      </label>

      <label class="flex items-center justify-between rounded-xl border border-slate-200 p-3">
        <span>
          <span class="font-semibold text-slate-800">SPP Bulanan</span>
          <span class="block text-xs text-slate-500">Tagihan tetap tiap bulan.</span>
        </span>
        <input v-model="allowMonthly" type="checkbox" class="h-5 w-5" />
      </label>

      <label class="flex items-center justify-between rounded-xl border border-slate-200 p-3">
        <span>
          <span class="font-semibold text-slate-800">Per Sesi</span>
          <span class="block text-xs text-slate-500">Tagih tiap pertemuan dihadiri.</span>
        </span>
        <input v-model="allowPerSession" type="checkbox" class="h-5 w-5" />
      </label>

      <div>
        <label class="mb-1 block text-sm font-semibold text-slate-700">
          Mode default (saran saat enroll)
        </label>
        <select
          v-model="defaultMode"
          class="w-full rounded-lg border border-slate-300 px-3 py-2"
        >
          <option :value="null">Tidak ada</option>
          <option v-for="m in enabledModes" :key="m" :value="m">
            {{ BILLING_MODE_LABELS[m] ?? m }}
          </option>
        </select>
      </div>

      <button
        :disabled="saving"
        class="w-full rounded-lg bg-indigo-900 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="save"
      >
        {{ saving ? 'Menyimpan…' : 'Simpan' }}
      </button>
    </div>
  </div>
</template>

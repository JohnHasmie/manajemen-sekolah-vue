<!--
  AdminMobileAppBroadcastView.vue — remedial action page for the
  "guru belum instal aplikasi mobile" gap surfaced by the Readiness
  check (backend MR-A). Reached by clicking "Perbaiki" on that lane
  item → readiness-nav routes to `admin.mobile-app-broadcast`.

  Server-side spacing: 10 detik per pesan (Fonnte anti-spam), rate limit
  1 batch/school/hour. Backend queues jobs with staggered `->delay()`
  so closing the tab does NOT stop the blast.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import {
  MobileAppBroadcastService,
  type BatchSummary,
  type MobileAppRecipient,
} from '@/services/mobile-app-broadcast.service';

const DEFAULT_TEMPLATE = `Halo {name}, aplikasi KamilEdu sudah tersedia untuk guru.

Silakan install & login supaya kamu dapat notifikasi presensi, nilai, dan pengumuman sekolah langsung di HP.

Android: https://play.google.com/store/apps/details?id=com.kamiledu.mobile

Terima kasih.`;

const loading = ref(true);
const recipients = ref<MobileAppRecipient[]>([]);
const excludedMissingPhone = ref(0);
const selected = ref<Set<string>>(new Set());
const message = ref(DEFAULT_TEMPLATE);
const submitting = ref(false);
const batches = ref<BatchSummary[]>([]);
const flash = ref<{ ok: boolean; message: string } | null>(null);

const selectedCount = computed(() => selected.value.size);
const allSelected = computed(
  () => recipients.value.length > 0 && selected.value.size === recipients.value.length,
);
const lastBatch = computed<BatchSummary | null>(
  () => (batches.value.length > 0 ? batches.value[0] : null),
);
const characterCount = computed(() => message.value.length);
const canSubmit = computed(
  () =>
    !submitting.value &&
    selectedCount.value > 0 &&
    message.value.trim().length >= 20 &&
    message.value.trim().length <= 1000,
);

async function loadRecipients() {
  loading.value = true;
  try {
    const res = await MobileAppBroadcastService.getRecipients();
    recipients.value = res.data;
    excludedMissingPhone.value = res.meta.excluded_missing_phone;
    // Default: pre-select all — the operator is here specifically to
    // blast everyone, and having to select-all every visit is friction.
    selected.value = new Set(res.data.map((r) => r.user_id));
  } finally {
    loading.value = false;
  }
}

async function loadBatches() {
  batches.value = await MobileAppBroadcastService.getBatches();
}

function toggle(userId: string) {
  const next = new Set(selected.value);
  next.has(userId) ? next.delete(userId) : next.add(userId);
  selected.value = next;
}

function toggleAll() {
  selected.value = allSelected.value
    ? new Set()
    : new Set(recipients.value.map((r) => r.user_id));
}

async function trigger() {
  if (!canSubmit.value) return;
  submitting.value = true;
  flash.value = null;
  try {
    const ids = Array.from(selected.value);
    const res = await MobileAppBroadcastService.trigger(message.value, ids);
    if (res.ok) {
      flash.value = {
        ok: true,
        message: `${res.data.queued} pesan dijadwalkan (jeda ${res.data.interval_seconds} detik antar pesan).`,
      };
      // Refresh so summary card + recipient list reflect the new
      // batch immediately — server-side dispatch is fire-and-forget.
      await Promise.all([loadBatches(), loadRecipients()]);
    } else {
      const retry = res.retryAfterSeconds
        ? ` Coba lagi dalam ${Math.ceil(res.retryAfterSeconds / 60)} menit.`
        : '';
      flash.value = { ok: false, message: res.error + retry };
    }
  } finally {
    submitting.value = false;
  }
}

function formatDateTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return '—';
  }
}

onMounted(async () => {
  await Promise.all([loadRecipients(), loadBatches()]);
});
</script>

<template>
  <div class="max-w-5xl mx-auto space-y-4 pb-8">
    <BrandPageHeader
      role="admin"
      kicker="Kesiapan Sekolah"
      title="Kirim WA install app ke guru"
      meta="Guru tanpa aplikasi mobile tidak menerima notifikasi presensi & nilai. Kirim WA reminder di sini."
    />

    <!-- Last-batch summary -->
    <div
      v-if="lastBatch"
      class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm flex flex-wrap items-center gap-4"
    >
      <div class="flex-1 min-w-[200px]">
        <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">
          Blast terakhir
        </p>
        <p class="text-sm text-slate-900 mt-1">
          {{ formatDateTime(lastBatch.started_at) }}
          <span class="text-slate-500">·</span>
          {{ lastBatch.total }} pesan
        </p>
      </div>
      <div class="flex flex-wrap gap-2 text-xs">
        <span class="px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700 font-bold">
          {{ lastBatch.delivered }} terkirim
        </span>
        <span
          v-if="lastBatch.failed > 0"
          class="px-2.5 py-1 rounded-full bg-rose-100 text-rose-700 font-bold"
        >
          {{ lastBatch.failed }} gagal
        </span>
        <span
          v-if="lastBatch.queued > 0"
          class="px-2.5 py-1 rounded-full bg-amber-100 text-amber-700 font-bold"
        >
          {{ lastBatch.queued }} dalam antrean
        </span>
      </div>
    </div>

    <!-- Template message -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm space-y-2">
      <div class="flex items-center justify-between">
        <label class="text-sm font-bold text-slate-900">
          Template pesan
        </label>
        <span
          class="text-xs font-mono"
          :class="characterCount > 1000 ? 'text-rose-600' : 'text-slate-400'"
        >
          {{ characterCount }} / 1000
        </span>
      </div>
      <textarea
        v-model="message"
        rows="7"
        class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none font-mono"
      />
      <p class="text-xs text-slate-500 flex items-center gap-1.5">
        <NavIcon name="info-circle" :size="12" />
        Placeholder <code class="text-slate-700">{name}</code> otomatis diganti nama guru.
      </p>
    </div>

    <!-- Recipient list -->
    <div class="bg-white border border-slate-100 rounded-2xl shadow-sm overflow-hidden">
      <div class="flex items-center justify-between p-4 border-b border-slate-100">
        <div>
          <p class="text-sm font-bold text-slate-900">
            Penerima
            <span class="text-slate-500 font-normal">({{ selectedCount }} / {{ recipients.length }} dipilih)</span>
          </p>
          <p v-if="excludedMissingPhone > 0" class="text-xs text-amber-700 mt-0.5">
            <NavIcon name="alert-circle" :size="12" class="inline" />
            {{ excludedMissingPhone }} guru lain tidak muncul karena belum punya nomor HP di data.
          </p>
        </div>
        <button
          type="button"
          class="text-xs font-bold text-brand-cobalt hover:underline"
          @click="toggleAll"
        >
          {{ allSelected ? 'Batal pilih semua' : 'Pilih semua' }}
        </button>
      </div>

      <div v-if="loading" class="p-6 text-center text-sm text-slate-500">
        Memuat daftar guru…
      </div>
      <div
        v-else-if="recipients.length === 0"
        class="p-6 text-center text-sm text-slate-500"
      >
        <NavIcon name="check-circle" :size="20" class="inline mb-2" />
        <p>Semua guru sudah punya aplikasi terpasang, atau belum ada guru yang punya nomor HP.</p>
      </div>
      <ul v-else class="divide-y divide-slate-100 max-h-[400px] overflow-y-auto">
        <li
          v-for="r in recipients"
          :key="r.user_id"
          class="flex items-center gap-3 p-3 hover:bg-slate-50 cursor-pointer"
          @click="toggle(r.user_id)"
        >
          <input
            type="checkbox"
            :checked="selected.has(r.user_id)"
            class="flex-none w-4 h-4 accent-brand-cobalt cursor-pointer"
            @click.stop="toggle(r.user_id)"
          />
          <div class="flex-1 min-w-0">
            <p class="text-sm font-bold text-slate-900 truncate">{{ r.name }}</p>
            <p class="text-xs text-slate-500 truncate">{{ r.email }}</p>
          </div>
          <span class="text-xs font-mono text-slate-500">
            {{ r.phone_masked }}
          </span>
        </li>
      </ul>
    </div>

    <!-- Action -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm space-y-3">
      <div class="flex items-center justify-between gap-3 flex-wrap">
        <div class="flex-1 min-w-0">
          <p class="text-sm font-bold text-slate-900">Siap kirim?</p>
          <p class="text-xs text-slate-500 mt-0.5">
            {{ selectedCount }} pesan akan dijadwalkan dengan jeda 10 detik.
            Total waktu: ~{{ Math.ceil((selectedCount * 10) / 60) }} menit.
            Kamu boleh tutup tab — pengiriman jalan di server.
          </p>
        </div>
        <button
          type="button"
          :disabled="!canSubmit"
          class="px-4 py-2 text-sm font-bold rounded-lg bg-brand-cobalt text-white hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center gap-2"
          @click="trigger"
        >
          <NavIcon name="brand-whatsapp" :size="16" />
          {{ submitting ? 'Menjadwalkan…' : `Kirim ${selectedCount} pesan` }}
        </button>
      </div>
      <p
        v-if="flash"
        class="text-xs px-3 py-2 rounded-lg"
        :class="flash.ok ? 'bg-emerald-50 text-emerald-800' : 'bg-rose-50 text-rose-800'"
      >
        {{ flash.message }}
      </p>
    </div>
  </div>
</template>

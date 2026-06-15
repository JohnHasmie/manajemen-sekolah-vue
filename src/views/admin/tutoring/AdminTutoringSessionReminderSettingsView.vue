<!--
  AdminTutoringSessionReminderSettingsView — bimbel admin sets which
  offsets the cron uses when sending reminders.

  Two tabs:
    - Sesi      → offsets in MINUTES before scheduled_at  (tutor + wali)
    - Tagihan   → offsets in DAYS before due_date         (wali only)

  Each tab keeps its own draft offset list + save/reset action. Cron
  reads each list per-tenant on every 5-minute tick.

  Empty lists are server-rejected — Save is disabled until at least
  one offset is picked.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const toast = useToast();
const tab = ref<'session' | 'bill'>('session');

// ── SESSION (minutes) ──────────────────────────────────────────
const sessionLoading = ref(true);
const sessionSaving = ref(false);
const sessionOffsets = ref<number[]>([]);
const sessionIsDefault = ref(false);
const sessionMax = ref(7 * 24 * 60);
const sessionCustomInput = ref<string>('');

const SESSION_PRESETS: { v: number; label: string }[] = [
  { v: 7 * 24 * 60, label: '1 minggu' },
  { v: 2 * 24 * 60, label: '2 hari' },
  { v: 1 * 24 * 60, label: '1 hari' },
  { v: 12 * 60, label: '12 jam' },
  { v: 6 * 60, label: '6 jam' },
  { v: 3 * 60, label: '3 jam' },
  { v: 60, label: '1 jam' },
  { v: 30, label: '30 menit' },
  { v: 15, label: '15 menit' },
  { v: 10, label: '10 menit' },
  { v: 5, label: '5 menit' },
];

function fmtMin(min: number): string {
  if (min % (24 * 60) === 0) {
    const d = min / (24 * 60);
    return d === 1 ? '1 hari' : `${d} hari`;
  }
  if (min % 60 === 0) return `${min / 60} jam`;
  return `${min} menit`;
}
const sessionSorted = computed(() => [...sessionOffsets.value].sort((a, b) => b - a));

async function loadSession() {
  sessionLoading.value = true;
  try {
    const res = await TutoringService.getSessionReminderOffsets();
    sessionOffsets.value = res.offsets_minutes;
    sessionIsDefault.value = res.is_default;
    sessionMax.value = res.max_offset_minutes;
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat pengingat sesi.');
  } finally {
    sessionLoading.value = false;
  }
}
function toggleSession(v: number) {
  const i = sessionOffsets.value.indexOf(v);
  if (i === -1) sessionOffsets.value.push(v);
  else sessionOffsets.value.splice(i, 1);
}
function addSessionCustom() {
  const n = parseInt(sessionCustomInput.value, 10);
  if (!Number.isFinite(n) || n < 1 || n > sessionMax.value) {
    toast.error(`Masukkan angka 1–${sessionMax.value} menit.`);
    return;
  }
  if (sessionOffsets.value.includes(n)) {
    toast.info(`${fmtMin(n)} sudah ada di daftar.`);
    return;
  }
  if (sessionOffsets.value.length >= 10) {
    toast.error('Maksimal 10 pengingat.');
    return;
  }
  sessionOffsets.value.push(n);
  sessionCustomInput.value = '';
}
function removeSession(v: number) {
  const i = sessionOffsets.value.indexOf(v);
  if (i !== -1) sessionOffsets.value.splice(i, 1);
}
async function saveSession() {
  if (sessionOffsets.value.length === 0) {
    toast.error('Minimal satu pengingat harus aktif.');
    return;
  }
  sessionSaving.value = true;
  try {
    const res = await TutoringService.updateSessionReminderOffsets(sessionOffsets.value);
    sessionOffsets.value = res.offsets_minutes;
    sessionIsDefault.value = res.is_default;
    toast.success('Pengingat sesi tersimpan.');
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.');
  } finally {
    sessionSaving.value = false;
  }
}
async function resetSession() {
  sessionOffsets.value = [1440, 60];
  await saveSession();
}

// ── BILL (days) ────────────────────────────────────────────────
const billLoading = ref(true);
const billSaving = ref(false);
const billOffsets = ref<number[]>([]);
const billIsDefault = ref(false);
const billMax = ref(30);
const billCustomInput = ref<string>('');

const BILL_PRESETS: { v: number; label: string }[] = [
  { v: 14, label: '2 minggu' },
  { v: 7, label: '1 minggu' },
  { v: 5, label: '5 hari' },
  { v: 3, label: '3 hari' },
  { v: 2, label: '2 hari' },
  { v: 1, label: '1 hari' },
  { v: 0, label: 'Hari H' },
];

function fmtDay(d: number): string {
  if (d === 0) return 'hari H';
  if (d === 1) return '1 hari sebelumnya';
  return `${d} hari sebelumnya`;
}
const billSorted = computed(() => [...billOffsets.value].sort((a, b) => b - a));

async function loadBill() {
  billLoading.value = true;
  try {
    const res = await TutoringService.getBillReminderOffsets();
    billOffsets.value = res.offsets_days;
    billIsDefault.value = res.is_default;
    billMax.value = res.max_offset_days;
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat pengingat tagihan.');
  } finally {
    billLoading.value = false;
  }
}
function toggleBill(v: number) {
  const i = billOffsets.value.indexOf(v);
  if (i === -1) billOffsets.value.push(v);
  else billOffsets.value.splice(i, 1);
}
function addBillCustom() {
  const n = parseInt(billCustomInput.value, 10);
  if (!Number.isFinite(n) || n < 0 || n > billMax.value) {
    toast.error(`Masukkan angka 0–${billMax.value} hari.`);
    return;
  }
  if (billOffsets.value.includes(n)) {
    toast.info(`${fmtDay(n)} sudah ada di daftar.`);
    return;
  }
  if (billOffsets.value.length >= 10) {
    toast.error('Maksimal 10 pengingat.');
    return;
  }
  billOffsets.value.push(n);
  billCustomInput.value = '';
}
function removeBill(v: number) {
  const i = billOffsets.value.indexOf(v);
  if (i !== -1) billOffsets.value.splice(i, 1);
}
async function saveBill() {
  if (billOffsets.value.length === 0) {
    toast.error('Minimal satu pengingat harus aktif.');
    return;
  }
  billSaving.value = true;
  try {
    const res = await TutoringService.updateBillReminderOffsets(billOffsets.value);
    billOffsets.value = res.offsets_days;
    billIsDefault.value = res.is_default;
    toast.success('Pengingat tagihan tersimpan.');
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.');
  } finally {
    billSaving.value = false;
  }
}
async function resetBill() {
  billOffsets.value = [3];
  await saveBill();
}

onMounted(() => {
  loadSession();
  loadBill();
});
</script>

<template>
  <div class="space-y-4 pb-12">
    <BrandPageHeader
      kicker="BIMBEL · PENGATURAN"
      title="Pengingat notifikasi"
      subtitle="Atur kapan tutor + wali menerima pengingat untuk sesi & tagihan. Cron memeriksa setiap 5 menit."
    />

    <!-- Tab bar -->
    <div class="flex gap-1 border-b border-bimbel-border-soft">
      <button
        type="button"
        class="px-4 py-2 text-[13px] font-bold border-b-2 transition-colors"
        :class="
          tab === 'session'
            ? 'border-bimbel-hero text-bimbel-hero'
            : 'border-transparent text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="tab = 'session'"
      >Pengingat sesi</button>
      <button
        type="button"
        class="px-4 py-2 text-[13px] font-bold border-b-2 transition-colors"
        :class="
          tab === 'bill'
            ? 'border-bimbel-hero text-bimbel-hero'
            : 'border-transparent text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="tab = 'bill'"
      >Pengingat tagihan</button>
    </div>

    <!-- SESSION TAB -->
    <template v-if="tab === 'session'">
      <div v-if="sessionLoading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>
      <template v-else>
        <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-[14px] font-bold text-bimbel-text-hi">Pengingat sesi aktif</h3>
            <span v-if="sessionIsDefault" class="text-[11px] font-bold uppercase tracking-wider bg-bimbel-amber-dim text-amber-700 px-2 py-0.5 rounded-full">Default</span>
          </div>
          <p class="text-[13px] text-bimbel-text-mid mb-3">
            {{ sessionSorted.length }} pengingat per sesi — dari yang paling jauh ke yang paling dekat dengan waktu sesi. Diterima oleh tutor + semua wali yang anak-nya enroll di kelompok.
          </p>
          <div v-if="sessionSorted.length" class="flex gap-2 flex-wrap">
            <div v-for="m in sessionSorted" :key="m" class="inline-flex items-center gap-1.5 rounded-full bg-bimbel-accent-dim text-bimbel-hero px-3 py-1.5 text-[13px] font-bold">
              {{ fmtMin(m) }}
              <button type="button" class="rounded-full hover:bg-bimbel-hero/15 p-0.5 -mr-1" aria-label="Hapus" @click="removeSession(m)"><NavIcon name="x" :size="13" /></button>
            </div>
          </div>
          <p v-else class="text-[13px] text-red-700">Belum ada pengingat. Tambahkan minimal satu sebelum menyimpan.</p>
        </section>

        <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
          <h3 class="text-[14px] font-bold text-bimbel-text-hi mb-3">Pilih dari preset</h3>
          <div class="flex gap-1.5 flex-wrap">
            <button v-for="p in SESSION_PRESETS" :key="p.v" type="button"
              class="rounded-full px-3 py-1.5 text-[13px] font-bold transition-colors"
              :class="sessionOffsets.includes(p.v) ? 'bg-bimbel-hero text-white' : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'"
              @click="toggleSession(p.v)"
            >{{ p.label }}</button>
          </div>
        </section>

        <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
          <h3 class="text-[14px] font-bold text-bimbel-text-hi mb-2">Tambah custom (menit)</h3>
          <p class="text-[13px] text-bimbel-text-mid mb-3">Range 1–{{ sessionMax }} menit. Maks 10 pengingat.</p>
          <div class="flex gap-2">
            <input v-model="sessionCustomInput" type="number" min="1" :max="sessionMax" placeholder="cth. 45"
              class="flex-1 rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:outline-none"
              @keydown.enter="addSessionCustom"
            />
            <button type="button" class="rounded-md bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft px-4 py-2 text-[13px] font-bold hover:bg-bimbel-border-soft" @click="addSessionCustom">Tambah</button>
          </div>
        </section>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft px-4 py-2.5 text-[13px]" @click="resetSession">Reset ke default</button>
          <button type="button" class="rounded-lg bg-bimbel-hero text-white px-4 py-2.5 text-[13px] font-bold disabled:opacity-50"
            :disabled="sessionSaving || sessionOffsets.length === 0" @click="saveSession">
            {{ sessionSaving ? 'Menyimpan…' : 'Simpan' }}
          </button>
        </div>
      </template>
    </template>

    <!-- BILL TAB -->
    <template v-else>
      <div v-if="billLoading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>
      <template v-else>
        <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-[14px] font-bold text-bimbel-text-hi">Pengingat tagihan aktif</h3>
            <span v-if="billIsDefault" class="text-[11px] font-bold uppercase tracking-wider bg-bimbel-amber-dim text-amber-700 px-2 py-0.5 rounded-full">Default</span>
          </div>
          <p class="text-[13px] text-bimbel-text-mid mb-3">
            Pengingat per tagihan yang dikirim jam 09:00 — wali menerima notifikasi pada hari-hari yang ditentukan sebelum tanggal jatuh tempo.
          </p>
          <div v-if="billSorted.length" class="flex gap-2 flex-wrap">
            <div v-for="d in billSorted" :key="d" class="inline-flex items-center gap-1.5 rounded-full bg-bimbel-accent-dim text-bimbel-hero px-3 py-1.5 text-[13px] font-bold">
              {{ fmtDay(d) }}
              <button type="button" class="rounded-full hover:bg-bimbel-hero/15 p-0.5 -mr-1" aria-label="Hapus" @click="removeBill(d)"><NavIcon name="x" :size="13" /></button>
            </div>
          </div>
          <p v-else class="text-[13px] text-red-700">Belum ada pengingat. Tambahkan minimal satu sebelum menyimpan.</p>
        </section>

        <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
          <h3 class="text-[14px] font-bold text-bimbel-text-hi mb-3">Pilih dari preset</h3>
          <div class="flex gap-1.5 flex-wrap">
            <button v-for="p in BILL_PRESETS" :key="p.v" type="button"
              class="rounded-full px-3 py-1.5 text-[13px] font-bold transition-colors"
              :class="billOffsets.includes(p.v) ? 'bg-bimbel-hero text-white' : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'"
              @click="toggleBill(p.v)"
            >{{ p.label }}</button>
          </div>
        </section>

        <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
          <h3 class="text-[14px] font-bold text-bimbel-text-hi mb-2">Tambah custom (hari)</h3>
          <p class="text-[13px] text-bimbel-text-mid mb-3">Range 0–{{ billMax }} hari. 0 = hari jatuh tempo. Maks 10 pengingat.</p>
          <div class="flex gap-2">
            <input v-model="billCustomInput" type="number" min="0" :max="billMax" placeholder="cth. 4"
              class="flex-1 rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:outline-none"
              @keydown.enter="addBillCustom"
            />
            <button type="button" class="rounded-md bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft px-4 py-2 text-[13px] font-bold hover:bg-bimbel-border-soft" @click="addBillCustom">Tambah</button>
          </div>
        </section>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft px-4 py-2.5 text-[13px]" @click="resetBill">Reset ke default</button>
          <button type="button" class="rounded-lg bg-bimbel-hero text-white px-4 py-2.5 text-[13px] font-bold disabled:opacity-50"
            :disabled="billSaving || billOffsets.length === 0" @click="saveBill">
            {{ billSaving ? 'Menyimpan…' : 'Simpan' }}
          </button>
        </div>
      </template>
    </template>
  </div>
</template>

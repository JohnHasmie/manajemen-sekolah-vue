<!--
  AdminTutoringSessionReminderSettingsView — bimbel admin sets which
  offsets the cron uses when reminding tutor + wali about an upcoming
  session. Offsets are minutes-before-scheduled_at.

  Presets cover the common cases (1 day / 12h / 1h / 30m / 10m); custom
  values up to 1 week (10080 min) can be added via the input row.
  Empty list isn't allowed — the validator on the server enforces
  min:1 length, so the page disables Save until at least one chip is
  picked.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const toast = useToast();
const loading = ref(true);
const saving = ref(false);
const offsets = ref<number[]>([]);
const isDefault = ref(false);
const maxOffset = ref(7 * 24 * 60);
const customInput = ref<string>('');

// Preset chips (label + minutes). Pick from the most common reminder
// distances; admin can still add anything else via the custom input.
const PRESETS: { minutes: number; label: string }[] = [
  { minutes: 7 * 24 * 60, label: '1 minggu' },
  { minutes: 2 * 24 * 60, label: '2 hari' },
  { minutes: 1 * 24 * 60, label: '1 hari' },
  { minutes: 12 * 60, label: '12 jam' },
  { minutes: 6 * 60, label: '6 jam' },
  { minutes: 3 * 60, label: '3 jam' },
  { minutes: 60, label: '1 jam' },
  { minutes: 30, label: '30 menit' },
  { minutes: 15, label: '15 menit' },
  { minutes: 10, label: '10 menit' },
  { minutes: 5, label: '5 menit' },
];

function fmt(min: number): string {
  if (min % (24 * 60) === 0) {
    const d = min / (24 * 60);
    return d === 1 ? '1 hari' : `${d} hari`;
  }
  if (min % 60 === 0) return `${min / 60} jam`;
  return `${min} menit`;
}

const sortedOffsets = computed(() => [...offsets.value].sort((a, b) => b - a));

async function load() {
  loading.value = true;
  try {
    const res = await TutoringService.getSessionReminderOffsets();
    offsets.value = res.offsets_minutes;
    isDefault.value = res.is_default;
    maxOffset.value = res.max_offset_minutes;
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat pengingat.');
  } finally {
    loading.value = false;
  }
}
onMounted(load);

function toggle(min: number) {
  const i = offsets.value.indexOf(min);
  if (i === -1) offsets.value.push(min);
  else offsets.value.splice(i, 1);
}
function isOn(min: number): boolean {
  return offsets.value.includes(min);
}

function addCustom() {
  const n = parseInt(customInput.value, 10);
  if (!Number.isFinite(n) || n < 1 || n > maxOffset.value) {
    toast.error(`Masukkan angka 1–${maxOffset.value} menit.`);
    return;
  }
  if (offsets.value.includes(n)) {
    toast.info(`${fmt(n)} sudah ada di daftar.`);
    return;
  }
  if (offsets.value.length >= 10) {
    toast.error('Maksimal 10 pengingat.');
    return;
  }
  offsets.value.push(n);
  customInput.value = '';
}

function remove(min: number) {
  const i = offsets.value.indexOf(min);
  if (i !== -1) offsets.value.splice(i, 1);
}

async function save() {
  if (offsets.value.length === 0) {
    toast.error('Minimal satu pengingat harus aktif.');
    return;
  }
  saving.value = true;
  try {
    const res = await TutoringService.updateSessionReminderOffsets(
      offsets.value,
    );
    offsets.value = res.offsets_minutes;
    isDefault.value = res.is_default;
    toast.success('Pengaturan pengingat tersimpan.');
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.');
  } finally {
    saving.value = false;
  }
}

async function resetToDefault() {
  // Wipe to defaults (24h + 1h) by setting offsets to those literals.
  offsets.value = [1440, 60];
  await save();
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <BrandPageHeader
      kicker="BIMBEL · PENGATURAN"
      title="Pengingat sesi"
      subtitle="Atur kapan tutor + wali menerima notifikasi sebelum sesi dimulai. Cron memeriksa setiap 5 menit."
    />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      Memuat…
    </div>

    <template v-else>
      <!-- Active offsets -->
      <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-[14px] font-bold text-bimbel-text-hi">Pengingat aktif</h3>
          <span
            v-if="isDefault"
            class="text-[11px] font-bold uppercase tracking-wider bg-bimbel-amber-dim text-amber-700 px-2 py-0.5 rounded-full"
          >Default</span>
        </div>
        <p class="text-[13px] text-bimbel-text-mid mb-3">
          {{ sortedOffsets.length }} pengingat akan dikirim per sesi —
          dari yang paling jauh ke yang paling dekat dengan waktu sesi.
        </p>
        <div v-if="sortedOffsets.length" class="flex gap-2 flex-wrap">
          <div
            v-for="m in sortedOffsets"
            :key="m"
            class="inline-flex items-center gap-1.5 rounded-full bg-bimbel-accent-dim text-bimbel-hero px-3 py-1.5 text-[13px] font-bold"
          >
            {{ fmt(m) }}
            <button
              type="button"
              class="rounded-full hover:bg-bimbel-hero/15 p-0.5 -mr-1"
              aria-label="Hapus"
              @click="remove(m)"
            ><NavIcon name="x" :size="13" /></button>
          </div>
        </div>
        <p v-else class="text-[13px] text-red-700">
          Belum ada pengingat. Tambahkan minimal satu sebelum menyimpan.
        </p>
      </section>

      <!-- Presets -->
      <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
        <h3 class="text-[14px] font-bold text-bimbel-text-hi mb-3">Pilih dari preset</h3>
        <div class="flex gap-1.5 flex-wrap">
          <button
            v-for="p in PRESETS"
            :key="p.minutes"
            type="button"
            class="rounded-full px-3 py-1.5 text-[13px] font-bold transition-colors"
            :class="
              isOn(p.minutes)
                ? 'bg-bimbel-hero text-white'
                : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
            "
            @click="toggle(p.minutes)"
          >{{ p.label }}</button>
        </div>
      </section>

      <!-- Custom input -->
      <section class="rounded-2xl bg-bimbel-panel border border-bimbel-border-soft p-4">
        <h3 class="text-[14px] font-bold text-bimbel-text-hi mb-2">Tambah custom</h3>
        <p class="text-[13px] text-bimbel-text-mid mb-3">
          Masukkan offset dalam <strong>menit</strong> (1–{{ maxOffset }}).
          Maks 10 pengingat total.
        </p>
        <div class="flex gap-2">
          <input
            v-model="customInput"
            type="number"
            min="1"
            :max="maxOffset"
            placeholder="cth. 45"
            class="flex-1 rounded-md bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:outline-none"
            @keydown.enter="addCustom"
          />
          <button
            type="button"
            class="rounded-md bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft px-4 py-2 text-[13px] font-bold hover:bg-bimbel-border-soft"
            @click="addCustom"
          >Tambah</button>
        </div>
      </section>

      <!-- Save -->
      <div class="flex justify-end gap-2 pt-2">
        <button
          type="button"
          class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft px-4 py-2.5 text-[13px]"
          @click="resetToDefault"
        >Reset ke default</button>
        <button
          type="button"
          class="rounded-lg bg-bimbel-hero text-white px-4 py-2.5 text-[13px] font-bold disabled:opacity-50"
          :disabled="saving || offsets.length === 0"
          @click="save"
        >{{ saving ? 'Menyimpan…' : 'Simpan' }}</button>
      </div>
    </template>
  </div>
</template>

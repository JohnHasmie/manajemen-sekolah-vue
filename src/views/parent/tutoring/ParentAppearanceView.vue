<!--
  ParentAppearanceView — wali Tampilan settings. 3 theme cards
  (Terang / Gelap / Otomatis) with literal preview swatches, plus
  auto-schedule time inputs and an info note pinned to bimbel scope.
  Still live-wires to `useBimbelThemeStore` so the page reflects mode
  changes immediately.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useBimbelThemeStore } from '@/stores/bimbel-theme';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const theme = useBimbelThemeStore();

const modes = [
  { id: 'light' as const, label: 'Terang', sub: 'Selalu terang' },
  { id: 'dark' as const, label: 'Gelap', sub: 'Selalu gelap' },
  { id: 'auto' as const, label: 'Otomatis', sub: 'Ikut jam' },
];

const lightStart = computed({
  get: () => `${String(theme.lightStartHour).padStart(2, '0')}:00`,
  set: (v: string) => {
    const h = Number.parseInt(v.split(':')[0] ?? '6', 10);
    theme.setLightStartHour(Number.isFinite(h) ? h : 6);
  },
});

const darkStart = computed({
  get: () =>
    `${String(theme.darkStartHour).padStart(2, '0')}:${String(theme.darkStartMinute).padStart(2, '0')}`,
  set: (v: string) => {
    const [hh, mm] = v.split(':').map((x) => Number.parseInt(x, 10));
    theme.setDarkStart(Number.isFinite(hh) ? hh : 18, Number.isFinite(mm) ? mm : 30);
  },
});

function swatchStyle(id: 'light' | 'dark' | 'auto') {
  if (id === 'light') return 'background:#f7faff;';
  if (id === 'dark') return 'background:#0f1419;';
  return 'background: linear-gradient(90deg, #f7faff 50%, #0f1419 50%);';
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · TAMPILAN"
      title="Tampilan"
      :subtitle="theme.autoHint ?? 'Pilih mode tampilan untuk halaman bimbel'"
      :stats="[]"
    />

    <!-- 1. Mode warna -->
    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      Mode warna
    </p>
    <div class="grid grid-cols-3 gap-2 mb-3">
      <button
        v-for="m in modes"
        :key="m.id"
        type="button"
        class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3 text-center cursor-pointer"
        :class="theme.mode === m.id ? 'border-2 border-bimbel-hero p-[11px]' : ''"
        @click="theme.setMode(m.id)"
      >
        <span
          class="block h-14 w-full rounded-md mb-2 border border-bimbel-border-soft"
          :style="swatchStyle(m.id)"
        />
        <p class="text-[12px] font-bold text-bimbel-text-hi">{{ m.label }}</p>
        <p class="text-[11px] text-bimbel-text-mid">{{ m.sub }}</p>
      </button>
    </div>

    <!-- 2. Jadwal otomatis -->
    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      Jadwal otomatis
    </p>
    <div class="grid grid-cols-2 gap-2.5 mb-3">
      <div>
        <p class="text-[11px] text-bimbel-text-mid mb-1">Jam terang mulai</p>
        <input
          v-model="lightStart"
          type="time"
          :disabled="theme.mode !== 'auto'"
          class="rounded-md bg-bimbel-bg px-3 py-1.5 text-[13px] font-mono text-bimbel-text-hi block w-full focus:outline-none disabled:opacity-50"
        />
      </div>
      <div>
        <p class="text-[11px] text-bimbel-text-mid mb-1">Jam gelap mulai</p>
        <input
          v-model="darkStart"
          type="time"
          :disabled="theme.mode !== 'auto'"
          class="rounded-md bg-bimbel-bg px-3 py-1.5 text-[13px] font-mono text-bimbel-text-hi block w-full focus:outline-none disabled:opacity-50"
        />
      </div>
    </div>

    <!-- 3. Info note -->
    <div class="rounded-md bg-bimbel-accent-dim p-2.5 flex gap-2.5 items-center">
      <i class="ti ti-info-circle text-[14px] text-bimbel-hero flex-shrink-0"></i>
      <p class="text-[11px] text-bimbel-hero">
        Pengaturan ini hanya berlaku untuk halaman Bimbel. Halaman sekolah pakai tema browser Anda.
      </p>
    </div>
  </div>
</template>

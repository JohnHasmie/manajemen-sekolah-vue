<!--
  ParentAppearanceView — wali Tampilan settings. 3 mode cards (Terang /
  Gelap / Otomatis) with literal preview swatches, time inputs for the
  auto schedule, and an info note pinned to bimbel scope. Live-wires to
  useBimbelThemeStore so the page reflects mode changes immediately.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useBimbelThemeStore } from '@/stores/bimbel-theme';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const theme = useBimbelThemeStore();

interface ModeOption {
  id: 'light' | 'dark' | 'auto';
  label: string;
  sub: string;
  preview: string;
}

const modes: ModeOption[] = [
  { id: 'light', label: 'Terang', sub: 'Selalu terang', preview: 'background:#f7faff;' },
  { id: 'dark', label: 'Gelap', sub: 'Selalu gelap', preview: 'background:#0f1419;' },
  { id: 'auto', label: 'Otomatis', sub: 'Ikut jam', preview: 'background:linear-gradient(90deg,#f7faff 50%,#0f1419 50%);' },
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
    const parts = v.split(':');
    const hh = Number.parseInt(parts[0] ?? '18', 10);
    const mm = Number.parseInt(parts[1] ?? '30', 10);
    theme.setDarkStart(Number.isFinite(hh) ? hh : 18, Number.isFinite(mm) ? mm : 30);
  },
});
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · TAMPILAN"
      title="Tampilan"
      :subtitle="theme.autoHint || 'Atur mode warna & jadwal otomatis'"
      :stats="[]"
    />

    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
      MODE WARNA
    </p>
    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="m in modes"
        :key="m.id"
        type="button"
        :class="[
          'rounded-md bg-bimbel-panel border text-center',
          theme.mode === m.id ? 'border-2 border-bimbel-hero p-[11px]' : 'border-bimbel-border-soft p-3',
        ]"
        @click="theme.setMode(m.id)"
      >
        <span
          class="block h-14 w-full rounded-md mb-2 border border-bimbel-border-soft"
          :style="m.preview"
        ></span>
        <p class="text-[12px] font-bold text-bimbel-text-hi">{{ m.label }}</p>
        <p class="text-[11px] text-bimbel-text-mid mt-0.5">{{ m.sub }}</p>
      </button>
    </div>

    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      JADWAL OTOMATIS
    </p>
    <div class="grid grid-cols-2 gap-2.5">
      <div>
        <label class="block text-[11px] text-bimbel-text-mid mb-1">Jam terang mulai</label>
        <input
          v-model="lightStart"
          type="time"
          class="rounded-md bg-bimbel-bg px-3 py-1.5 text-[13px] font-mono text-bimbel-text-hi w-full focus:outline-none"
        />
      </div>
      <div>
        <label class="block text-[11px] text-bimbel-text-mid mb-1">Jam gelap mulai</label>
        <input
          v-model="darkStart"
          type="time"
          class="rounded-md bg-bimbel-bg px-3 py-1.5 text-[13px] font-mono text-bimbel-text-hi w-full focus:outline-none"
        />
      </div>
    </div>

    <div class="rounded-md bg-bimbel-accent-dim p-2.5 flex gap-2.5 items-center mt-2">
      <NavIcon name="info-circle" :size="14" class="text-bimbel-hero flex-shrink-0" />
      <p class="text-[11px] text-bimbel-hero">
        Pengaturan ini hanya berlaku untuk halaman Bimbel. Halaman sekolah pakai tema browser Anda.
      </p>
    </div>
  </div>
</template>

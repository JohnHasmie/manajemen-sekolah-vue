<!--
  ParentAppearanceView — parent Appearance settings. 3 mode cards (Terang /
  Gelap / Otomatis) with literal preview swatches, time inputs for the
  auto schedule, and an info note pinned to bimbel scope. Live-wires to
  useTutoringThemeStore so the page reflects mode changes immediately.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useTutoringThemeStore } from '@/stores/tutoring-theme';

import ParentHomeHero from '@/components/feature/tutoring/ParentHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const theme = useTutoringThemeStore();

interface ModeOption {
  id: 'light' | 'dark' | 'auto';
  label: string;
  sub: string;
  preview: string;
}

const modes = computed<ModeOption[]>(() => [
  { id: 'light', label: t('wali.bimbel.appearance.mode_light_label'), sub: t('wali.bimbel.appearance.mode_light_sub'), preview: 'background:#f7faff;' },
  { id: 'dark', label: t('wali.bimbel.appearance.mode_dark_label'), sub: t('wali.bimbel.appearance.mode_dark_sub'), preview: 'background:#0f1419;' },
  { id: 'auto', label: t('wali.bimbel.appearance.mode_auto_label'), sub: t('wali.bimbel.appearance.mode_auto_sub'), preview: 'background:linear-gradient(90deg,#f7faff 50%,#0f1419 50%);' },
]);

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
    <ParentHomeHero
      :kicker="t('wali.bimbel.appearance.kicker')"
      :title="t('wali.bimbel.appearance.title')"
      :subtitle="theme.autoHint || t('wali.bimbel.appearance.default_subtitle')"
      :stats="[]"
    />

    <p class="text-[12px] tracking-[0.1em] text-tutoring-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
      {{ t('wali.bimbel.appearance.color_mode_heading') }}
    </p>
    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="m in modes"
        :key="m.id"
        type="button"
        :class="[
          'rounded-md bg-tutoring-panel border text-center',
          theme.mode === m.id ? 'border-2 border-tutoring-hero p-[11px]' : 'border-tutoring-border-soft p-3',
        ]"
        @click="theme.setMode(m.id)"
      >
        <span
          class="block h-14 w-full rounded-md mb-2 border border-tutoring-border-soft"
          :style="m.preview"
        ></span>
        <p class="text-[13px] font-bold text-tutoring-text-hi">{{ m.label }}</p>
        <p class="text-[12px] text-tutoring-text-mid mt-0.5">{{ m.sub }}</p>
      </button>
    </div>

    <p class="text-[12px] tracking-[0.1em] text-tutoring-text-lo font-bold uppercase mb-2 mt-3">
      {{ t('wali.bimbel.appearance.auto_schedule_heading') }}
    </p>
    <div class="grid grid-cols-2 gap-2.5">
      <div>
        <label class="block text-[12px] text-tutoring-text-mid mb-1">{{ t('wali.bimbel.appearance.light_start_label') }}</label>
        <input
          v-model="lightStart"
          type="time"
          class="rounded-md bg-tutoring-bg px-3 py-1.5 text-[14px] font-mono text-tutoring-text-hi w-full focus:outline-none"
        />
      </div>
      <div>
        <label class="block text-[12px] text-tutoring-text-mid mb-1">{{ t('wali.bimbel.appearance.dark_start_label') }}</label>
        <input
          v-model="darkStart"
          type="time"
          class="rounded-md bg-tutoring-bg px-3 py-1.5 text-[14px] font-mono text-tutoring-text-hi w-full focus:outline-none"
        />
      </div>
    </div>

    <div class="rounded-md bg-tutoring-accent-dim p-2.5 flex gap-2.5 items-center mt-2">
      <NavIcon name="info-circle" :size="14" class="text-tutoring-hero flex-shrink-0" />
      <p class="text-[12px] text-tutoring-hero">
        {{ t('wali.bimbel.appearance.info_note') }}
      </p>
    </div>
  </div>
</template>

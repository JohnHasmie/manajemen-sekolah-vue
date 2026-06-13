<!--
  ParentTampilanView — wali Tampilan & bahasa & notifikasi settings.
  Mockup parent_web_pages_account frame 4: 3 form sections.
  Live wires to useBimbelThemeStore so the page itself flips theme
  the moment a mode card is picked.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useBimbelThemeStore } from '@/stores/bimbel-theme';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const theme = useBimbelThemeStore();
const { locale, t } = useI18n();
const auth = useAuthStore();

const modes = [
  { id: 'light' as const, label: 'Terang', sub: 'Selalu terang' },
  { id: 'dark' as const, label: 'Gelap', sub: 'Selalu gelap' },
  { id: 'auto' as const, label: 'Otomatis', sub: 'Ikuti waktu' },
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

const notif = computed({
  get: () => ({
    reminder: localStorage.getItem('parent.notif.reminder') !== '0',
    bill: localStorage.getItem('parent.notif.bill') !== '0',
    grade: localStorage.getItem('parent.notif.grade') === '1',
    announce: localStorage.getItem('parent.notif.announce') !== '0',
    promo: localStorage.getItem('parent.notif.promo') === '1',
  }),
  set: () => {},
});

function toggle(key: string) {
  const cur = localStorage.getItem(`parent.notif.${key}`);
  const on = cur === '0' ? '1' : '0';
  localStorage.setItem(`parent.notif.${key}`, on);
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · TAMPILAN"
      title="Tampilan & bahasa"
      subtitle="Mode terang/gelap, bahasa, dan notifikasi"
      :stats="[]"
    />

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-3">
      <h4 class="text-[12.5px] font-bold tracking-tight text-bimbel-text-hi">Mode tampilan</h4>
      <div class="grid gap-2 sm:grid-cols-3">
        <button
          v-for="m in modes"
          :key="m.id"
          type="button"
          class="flex flex-col items-center gap-2 rounded-xl border p-3 transition"
          :class="
            theme.mode === m.id
              ? 'border-[#21afe6] bg-[#21afe6]/8'
              : 'border-bimbel-border-soft hover:border-bimbel-border'
          "
          @click="theme.setMode(m.id)"
        >
          <span
            class="h-9 w-16 rounded-md border"
            :style="
              m.id === 'light'
                ? 'background:#f7faff;border-color:#e2e8f0;'
                : m.id === 'dark'
                ? 'background:#0f1419;border-color:#2a3147;'
                : 'background:linear-gradient(90deg,#f7faff 50%,#0f1419 50%);border-color:#94a3b8;'
            "
          />
          <p class="text-[12px] font-bold text-bimbel-text-hi">{{ m.label }}</p>
          <p class="text-[10.5px] text-bimbel-text-mid">{{ m.sub }}</p>
        </button>
      </div>
      <p v-if="theme.autoHint" class="text-[11px] text-bimbel-text-mid">{{ theme.autoHint }}</p>
      <div v-if="theme.mode === 'auto'" class="grid gap-2 sm:grid-cols-2 pt-2 border-t border-bimbel-border-soft">
        <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
          <span class="text-[11.5px] text-bimbel-text-mid">Jam terang mulai</span>
          <input
            v-model="lightStart"
            type="time"
            class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-1.5 text-[12px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
          />
        </label>
        <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
          <span class="text-[11.5px] text-bimbel-text-mid">Jam gelap mulai</span>
          <input
            v-model="darkStart"
            type="time"
            class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-1.5 text-[12px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
          />
        </label>
      </div>
    </section>

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-3">
      <h4 class="text-[12.5px] font-bold tracking-tight text-bimbel-text-hi">Bahasa</h4>
      <div class="flex gap-2">
        <button
          type="button"
          class="rounded-full border px-3 py-1.5 text-[11.5px] font-semibold"
          :class="
            locale === 'id'
              ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
              : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'
          "
          @click="locale = 'id'"
        >Bahasa Indonesia</button>
        <button
          type="button"
          class="rounded-full border px-3 py-1.5 text-[11.5px] font-semibold"
          :class="
            locale === 'en'
              ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
              : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'
          "
          @click="locale = 'en'"
        >English</button>
      </div>
    </section>

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
      <h4 class="mb-2 text-[12.5px] font-bold tracking-tight text-bimbel-text-hi">Notifikasi</h4>
      <div
        v-for="row in [
          { id: 'reminder', name: 'Pengingat sesi', sub: 'H-1 dan 30 menit sebelum mulai' },
          { id: 'bill', name: 'Tagihan jatuh tempo', sub: '3 hari sebelum due date' },
          { id: 'grade', name: 'Nilai baru', sub: 'Saat tutor input nilai PR / quiz' },
          { id: 'announce', name: 'Pengumuman kelompok', sub: 'Dari tutor atau admin' },
          { id: 'promo', name: 'Promo & voucher', sub: 'Dari bimbel' },
        ]"
        :key="row.id"
        class="flex items-center justify-between border-t border-bimbel-border-soft py-2.5 first:border-t-0"
      >
        <div>
          <p class="text-[12.5px] font-bold text-bimbel-text-hi">{{ row.name }}</p>
          <p class="text-[11px] text-bimbel-text-mid">{{ row.sub }}</p>
        </div>
        <button
          type="button"
          class="h-5 w-9 rounded-full transition"
          :class="(notif as any)[row.id] ? 'bg-emerald-500' : 'bg-bimbel-border'"
          @click="toggle(row.id)"
        >
          <span
            class="block h-3.5 w-3.5 rounded-full bg-white transition"
            :class="(notif as any)[row.id] ? 'translate-x-[18px]' : 'translate-x-[2px]'"
          />
        </button>
      </div>
    </section>
  </div>
</template>

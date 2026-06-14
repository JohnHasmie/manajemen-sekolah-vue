<!--
  AdminTutoringAppearanceView — mode picker + bahasa + push toggles.
  Mockup admin_web_pages_account frame 2.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useBimbelThemeStore } from '@/stores/bimbel-theme';
import { useI18n } from 'vue-i18n';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';

const theme = useBimbelThemeStore();
const { locale } = useI18n();

const modes = [
  { id: 'light' as const, label: 'Terang', sub: 'Selalu terang' },
  { id: 'dark' as const, label: 'Gelap', sub: 'Selalu gelap' },
  { id: 'auto' as const, label: 'Otomatis', sub: 'Ikuti waktu' },
];

const notif = computed({
  get: () => ({
    leads: localStorage.getItem('admin.notif.leads') !== '0',
    bills: localStorage.getItem('admin.notif.bills') !== '0',
    tutor: localStorage.getItem('admin.notif.tutor') !== '0',
    proof: localStorage.getItem('admin.notif.proof') !== '0',
    daily: localStorage.getItem('admin.notif.daily') === '1',
  }),
  set: () => {},
});
function toggle(key: string) {
  const cur = localStorage.getItem(`admin.notif.${key}`);
  const on = cur === '0' ? '1' : '0';
  localStorage.setItem(`admin.notif.${key}`, on);
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="TAMPILAN"
      title="Tampilan & bahasa"
      subtitle="Mode terang/gelap + bahasa + notifikasi push"
      :stats="[]"
    />

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-3">
      <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">Mode tampilan</h4>
      <div class="grid gap-2 sm:grid-cols-3">
        <button
          v-for="m in modes"
          :key="m.id"
          type="button"
          class="flex flex-col items-center gap-2 rounded-xl border p-3 transition"
          :class="theme.mode === m.id ? 'border-bimbel-accent bg-bimbel-accent-dim' : 'border-bimbel-border-soft hover:border-bimbel-border'"
          @click="theme.setMode(m.id)"
        >
          <span
            class="h-9 w-16 rounded-md border"
            :style="m.id === 'light' ? 'background:#f7faff;border-color:#e2e8f0;' : m.id === 'dark' ? 'background:#0a1428;border-color:#2a3147;' : 'background:linear-gradient(90deg,#f7faff 50%,#0a1428 50%);border-color:#94a3b8;'"
          />
          <p class="text-[14px] font-bold text-bimbel-text-hi">{{ m.label }}</p>
          <p class="text-[13px] text-bimbel-text-mid">{{ m.sub }}</p>
        </button>
      </div>
      <p v-if="theme.autoHint" class="text-[14px] text-bimbel-text-mid">{{ theme.autoHint }}</p>
    </section>

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
      <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi mb-3">Bahasa</h4>
      <div class="flex gap-2">
        <button
          type="button"
          class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
          :class="locale === 'id' ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
          @click="locale = 'id'"
        >Bahasa Indonesia</button>
        <button
          type="button"
          class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
          :class="locale === 'en' ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
          @click="locale = 'en'"
        >English</button>
      </div>
    </section>

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
      <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Notifikasi push</h4>
      <div
        v-for="row in [
          { id: 'leads', name: 'Lead masuk', sub: 'WA / push langsung saat ada lead baru' },
          { id: 'bills', name: 'Tagihan overdue', sub: '7 hari setelah jatuh tempo' },
          { id: 'tutor', name: 'Tutor sakit / cuti', sub: 'Saat tutor request pengganti' },
          { id: 'proof', name: 'Bukti bayar masuk', sub: 'Perlu verifikasi manual' },
          { id: 'daily', name: 'Rangkuman harian', sub: 'Email setiap pagi 06:00' },
        ]"
        :key="row.id"
        class="flex items-center justify-between border-t border-bimbel-border-soft py-2.5 first:border-t-0"
      >
        <div>
          <p class="text-[14px] font-bold text-bimbel-text-hi">{{ row.name }}</p>
          <p class="text-[14px] text-bimbel-text-mid">{{ row.sub }}</p>
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

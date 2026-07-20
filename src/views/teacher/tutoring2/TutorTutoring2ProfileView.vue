<!--
  TutorTutoring2ProfileView.vue — settings hub for the tutor.
  Hub-style layout mirroring AdminTutoring2SettingsView: 5 clickable
  setting cards in a responsive grid. All actions except "Keluar" are
  stubbed until BE-8+ wires the real preference endpoints.
-->
<script setup lang="ts">
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useToast } from '@/composables/useToast';
import { useAuthStore } from '@/stores/auth';

const toast = useToast();
const auth = useAuthStore();

interface SettingCard {
  short: string;
  title: string;
  subtitle: string;
  action: () => void;
}

async function doLogout() {
  try {
    await auth.logout();
  } catch {
    toast.info('logout');
  }
}

const cards: SettingCard[] = [
  {
    short: 'AKN',
    title: 'Akun',
    subtitle: 'Ubah data pribadi & foto',
    action: () => toast.info('belum tersedia'),
  },
  {
    short: 'NTF',
    title: 'Notifikasi',
    subtitle: 'Preferensi push & email',
    action: () => toast.info('belum tersedia'),
  },
  {
    short: 'BHS',
    title: 'Bahasa',
    subtitle: 'Indonesia (default)',
    action: () => toast.info('belum tersedia'),
  },
  {
    short: 'TEM',
    title: 'Tampilan',
    subtitle: 'Auto light/dark (tutoring theme)',
    action: () => toast.info('belum tersedia'),
  },
  {
    short: 'KLR',
    title: 'Keluar',
    subtitle: 'Logout dari akun ini',
    action: doLogout,
  },
];
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      kicker="Tutor Bimbel"
      title="Profil"
      meta="Tutor Bimbel Cendekia"
    />

    <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
      <button
        v-for="c in cards"
        :key="c.title"
        type="button"
        class="flex items-center gap-3 rounded-3xl border border-slate-100 bg-white p-4 text-left shadow-sm transition hover:border-brand-cobalt hover:shadow-md"
        @click="c.action"
      >
        <span
          class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-cobalt/10 text-brand-cobalt text-xs font-bold uppercase"
        >
          {{ c.short }}
        </span>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-bold text-slate-900">{{ c.title }}</p>
          <p class="truncate text-2xs text-slate-500">{{ c.subtitle }}</p>
        </div>
        <span class="text-slate-300" aria-hidden="true">›</span>
      </button>
    </div>
  </div>
</template>

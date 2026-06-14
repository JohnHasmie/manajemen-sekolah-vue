<!--
  ParentMoreView — wali "Lainnya" hub. Grouped section headers
  (AKADEMIK ANAK / DAFTAR & PROMO / AKUN) with 3-up tile grids. Each
  tile is bimbel-panel + colored icon box + label + sub. Routes
  preserved via go(name).
-->
<script setup lang="ts">
import { useRouter } from 'vue-router';
import { computed } from 'vue';
import { useChildPicker } from '@/composables/useChildPicker';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const router = useRouter();
const { activeChildId } = useChildPicker();

const childId = computed(() => activeChildId.value);

function go(name: string) {
  const params = childId.value ? { studentId: childId.value } : undefined;
  router.push({ name, params });
}

type Tone = 'blue' | 'green' | 'amber' | 'purple' | 'coral' | 'neutral';

interface Tile {
  icon: string;
  label: string;
  sub: string;
  to: string;
  tone: Tone;
}

interface Section {
  title: string;
  tiles: Tile[];
}

const sections = computed<Section[]>(() => [
  {
    title: 'Akademik anak',
    tiles: [
      { icon: 'ti-chart-bar', label: 'Perkembangan', sub: 'Nilai & tren', to: 'parent.tutoring.progress', tone: 'blue' },
      { icon: 'ti-trophy', label: 'Peringkat', sub: 'Per kelompok', to: 'parent.tutoring.leaderboard', tone: 'amber' },
      { icon: 'ti-book-2', label: 'Aktivitas', sub: 'Tugas & ulangan', to: 'parent.tutoring.activities', tone: 'purple' },
    ],
  },
  {
    title: 'Daftar & promo',
    tiles: [
      { icon: 'ti-discount-2', label: 'Voucher', sub: 'Promo & kode', to: 'parent.tutoring.vouchers', tone: 'coral' },
      { icon: 'ti-user-plus', label: 'Daftar anak baru', sub: 'Ke bimbel ini', to: 'parent.tutoring.register-lead', tone: 'green' },
      { icon: 'ti-package', label: 'Daftar program', sub: 'Untuk anak terdaftar', to: 'parent.tutoring.enroll-new', tone: 'blue' },
    ],
  },
  {
    title: 'Akun',
    tiles: [
      { icon: 'ti-bell', label: 'Notifikasi', sub: 'Pengingat & info', to: 'parent.tutoring.notifications', tone: 'neutral' },
      { icon: 'ti-user', label: 'Profil', sub: 'Identitas & anak', to: 'parent.tutoring.profile', tone: 'neutral' },
      { icon: 'ti-sun', label: 'Tampilan', sub: 'Otomatis', to: 'parent.tutoring.appearance', tone: 'neutral' },
    ],
  },
]);

function toneClass(t: Tone): string {
  switch (t) {
    case 'blue': return 'bg-bimbel-accent-dim text-bimbel-hero';
    case 'green': return 'bg-bimbel-green-dim text-green-700';
    case 'amber': return 'bg-bimbel-amber-dim text-amber-700';
    case 'purple': return 'bg-[color-mix(in_srgb,#a855f7_16%,transparent)] text-purple-700';
    case 'coral': return 'bg-bimbel-red-dim text-red-700';
    case 'neutral':
    default: return 'bg-bimbel-bg text-bimbel-text-mid';
  }
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · LAINNYA"
      title="Lainnya"
      subtitle="Voucher, profil, notifikasi, & pengaturan"
      :stats="[]"
    />

    <div v-for="s in sections" :key="s.title">
      <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
        {{ s.title }}
      </p>
      <div class="grid grid-cols-3 gap-2">
        <button
          v-for="t in s.tiles"
          :key="t.label"
          type="button"
          class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3.5 text-center cursor-pointer hover:border-bimbel-hero/50"
          @click="go(t.to)"
        >
          <span
            class="mx-auto grid h-[38px] w-[38px] place-items-center rounded-lg mb-1.5"
            :class="toneClass(t.tone)"
          >
            <i class="ti text-[18px]" :class="t.icon"></i>
          </span>
          <p class="text-[12px] font-bold text-bimbel-text-hi truncate">{{ t.label }}</p>
          <p class="text-[10px] text-bimbel-text-mid mt-0.5 truncate">{{ t.sub }}</p>
        </button>
      </div>
    </div>
  </div>
</template>

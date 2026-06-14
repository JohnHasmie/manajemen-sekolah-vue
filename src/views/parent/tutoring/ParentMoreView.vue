<!--
  ParentMoreView — wali "Lainnya" hub. Three sections (AKADEMIK ANAK /
  DAFTAR & PROMO / AKUN) each rendered as a 3-up tile grid. Each tile is
  a bimbel-panel button with colored icon box, label, and sub. Routes
  preserved via go(name).
-->
<script setup lang="ts">
import { useRouter } from 'vue-router';
import { computed } from 'vue';
import { useChildPicker } from '@/composables/useChildPicker';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const { activeChildId } = useChildPicker();

const childId = computed(() => activeChildId.value);

interface Tile {
  label: string;
  sub: string;
  icon: string;
  iconCls?: string;
  route: string;
}

const academic: Tile[] = [
  { label: 'Perkembangan', sub: 'Nilai & tren', icon: 'chart-bar', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero', route: 'parent.tutoring.progress' },
  { label: 'Peringkat', sub: 'Per kelompok', icon: 'star', iconCls: 'bg-bimbel-amber-dim text-amber-700', route: 'parent.tutoring.leaderboard' },
  { label: 'Aktivitas', sub: 'Tugas & ulangan', icon: 'book', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero', route: 'parent.tutoring.activities' },
];

const funnel: Tile[] = [
  { label: 'Voucher', sub: 'Promo & kode', icon: 'discount', iconCls: 'bg-bimbel-red-dim text-red-700', route: 'parent.tutoring.vouchers' },
  { label: 'Daftar anak baru', sub: 'Ke bimbel ini', icon: 'user-plus', iconCls: 'bg-bimbel-green-dim text-green-700', route: 'parent.tutoring.register-lead' },
  { label: 'Daftar program', sub: 'Untuk anak terdaftar', icon: 'package', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero', route: 'parent.tutoring.enroll-new' },
];

const account: Tile[] = [
  { label: 'Notifikasi', sub: 'Pengingat & info', icon: 'bell', route: 'parent.tutoring.notifications' },
  { label: 'Profil', sub: 'Identitas & anak', icon: 'user', route: 'parent.tutoring.profile' },
  { label: 'Tampilan', sub: 'Otomatis', icon: 'sun', route: 'parent.tutoring.appearance' },
];

function go(name: string) {
  const params = childId.value ? { studentId: childId.value } : undefined;
  router.push({ name, params });
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

    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
      AKADEMIK ANAK
    </p>
    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="t in academic"
        :key="t.label"
        type="button"
        class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3.5 text-center"
        @click="go(t.route)"
      >
        <div class="w-[38px] h-[38px] rounded-lg mx-auto mb-1.5 grid place-items-center" :class="t.iconCls">
          <NavIcon :name="t.icon" :size="18" />
        </div>
        <p class="text-[12px] font-bold text-bimbel-text-hi">{{ t.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ t.sub }}</p>
      </button>
    </div>

    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      DAFTAR &amp; PROMO
    </p>
    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="t in funnel"
        :key="t.label"
        type="button"
        class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3.5 text-center"
        @click="go(t.route)"
      >
        <div class="w-[38px] h-[38px] rounded-lg mx-auto mb-1.5 grid place-items-center" :class="t.iconCls">
          <NavIcon :name="t.icon" :size="18" />
        </div>
        <p class="text-[12px] font-bold text-bimbel-text-hi">{{ t.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ t.sub }}</p>
      </button>
    </div>

    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      AKUN
    </p>
    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="t in account"
        :key="t.label"
        type="button"
        class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3.5 text-center"
        @click="go(t.route)"
      >
        <div class="w-[38px] h-[38px] rounded-lg mx-auto mb-1.5 grid place-items-center bg-bimbel-bg text-bimbel-text-hi">
          <NavIcon :name="t.icon" :size="18" />
        </div>
        <p class="text-[12px] font-bold text-bimbel-text-hi">{{ t.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ t.sub }}</p>
      </button>
    </div>
  </div>
</template>

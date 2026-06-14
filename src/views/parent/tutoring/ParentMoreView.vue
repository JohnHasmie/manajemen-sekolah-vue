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
const { children, activeChildId, setActive } = useChildPicker();

const childId = computed(() => activeChildId.value);

function initials(name?: string | null): string {
  if (!name) return '?';
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase() ?? '')
    .join('');
}

// Cycle a small palette so multi-child rows aren't all the same hue.
const CHIP_RAMP = [
  'bg-bimbel-accent-dim text-bimbel-hero',
  'bg-bimbel-green-dim text-green-700',
  'bg-bimbel-amber-dim text-amber-700',
  'bg-bimbel-red-dim text-red-700',
];
function chipClass(i: number): string {
  return CHIP_RAMP[i % CHIP_RAMP.length];
}

function pickChild(id: string) {
  setActive(id);
  router.push({ name: 'parent.tutoring.overview', params: { studentId: id } });
}

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

    <!-- ANAK SAYA — quick switch row, mirrors mobile parent_more_hub -->
    <template v-if="children.length > 0">
      <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
        ANAK SAYA
      </p>
      <div class="grid gap-2" :class="children.length > 1 ? 'sm:grid-cols-2' : 'grid-cols-1'">
        <button
          v-for="(c, i) in children"
          :key="c.student_id"
          type="button"
          class="rounded-lg bg-bimbel-panel border border-bimbel-border-soft p-3 flex items-center gap-2.5 text-left transition-colors"
          :class="c.student_id === activeChildId ? 'border-bimbel-hero ring-1 ring-bimbel-hero/30' : 'hover:border-bimbel-border'"
          @click="pickChild(c.student_id)"
        >
          <span
            class="w-9 h-9 rounded-full grid place-items-center text-[13px] font-bold flex-shrink-0"
            :class="chipClass(i)"
          >{{ initials(c.name) }}</span>
          <div class="min-w-0 flex-1">
            <p class="text-[14px] font-bold text-bimbel-text-hi truncate">{{ c.name }}</p>
            <p class="text-[12px] text-bimbel-text-mid truncate">{{ c.class_name || 'Kelas —' }}</p>
          </div>
          <span
            v-if="c.student_id === activeChildId"
            class="text-[10px] font-bold uppercase tracking-wider text-bimbel-hero flex-shrink-0"
          >Aktif</span>
          <NavIcon v-else name="chevron-right" :size="14" class="text-bimbel-text-mid flex-shrink-0" />
        </button>
      </div>
    </template>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
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
        <p class="text-[13px] font-bold text-bimbel-text-hi">{{ t.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ t.sub }}</p>
      </button>
    </div>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
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
        <p class="text-[13px] font-bold text-bimbel-text-hi">{{ t.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ t.sub }}</p>
      </button>
    </div>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
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
        <p class="text-[13px] font-bold text-bimbel-text-hi">{{ t.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ t.sub }}</p>
      </button>
    </div>
  </div>
</template>

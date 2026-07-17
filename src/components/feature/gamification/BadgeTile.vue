<!--
  BadgeTile.vue — single badge card, three visual states:
    earned   solid brand tint + trophy icon
    new      earned + "Baru!" ribbon (48h window)
    locked   grayscale with a lock icon + gated copy

  The catalog (labels + descriptions) is inlined here matching the
  backend registry, so a new badge won't show up client-side until
  its metadata is added in both places — deliberate: badge rollouts
  are commit-and-review events per the plan.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    code: string;
    /** 'earned' | 'new' | 'locked' */
    state?: 'earned' | 'new' | 'locked';
  }>(),
  { state: 'locked' },
);

const CATALOG: Record<string, { label: string; description: string; icon: string }> = {
  absen_pertama: { label: 'Absen Pertama', description: 'Selamat! Kamu absen untuk pertama kalinya.', icon: 'check-circle' },
  ayam_pagi: { label: 'Ayam Pagi', description: 'Datang lebih awal 5 hari kerja dalam sebulan.', icon: 'sunrise' },
  beruntun_10: { label: 'Beruntun 10 Hari', description: '10 hari kerja berturut-turut kamu aktif.', icon: 'flame' },
  beruntun_30: { label: 'Beruntun 30 Hari', description: 'Sebulan penuh hari kerja tanpa terputus.', icon: 'flame' },
  beruntun_90: { label: 'Beruntun 90 Hari', description: 'Satu semester penuh — luar biasa.', icon: 'flame' },
  bulan_penuh: { label: 'Bulan Penuh', description: 'Tepat waktu 20 hari kerja berturut-turut.', icon: 'trophy' },
  penilaian_rajin: { label: 'Penilaian Rajin', description: '10 penilaian dalam sebulan terakhir.', icon: 'edit-3' },
  rpp_rajin: { label: 'RPP Rajin', description: '4 RPP kamu kumpulkan dalam sebulan.', icon: 'file-text' },
  lima_puluh_koreksi: { label: '50 Koreksi', description: '50 tugas murid kamu koreksi dalam sebulan.', icon: 'check-circle' },
  level_5: { label: 'Level 5 Tercapai', description: 'Kamu mencapai Level 5 — Guru Bergerak.', icon: 'medal' },
  level_10: { label: 'Level 10 Tercapai', description: 'Kamu mencapai Level 10 — Guru Teladan.', icon: 'medal' },
  wali_tuntas: { label: 'Wali Tuntas', description: 'Semua murid wali kelas punya ≥1 nilai bulan ini.', icon: 'users' },
};

const meta = computed(() => CATALOG[props.code] ?? { label: props.code, description: '', icon: 'trophy' });

const toneClasses = computed(() => {
  switch (props.state) {
    case 'earned':
      return 'bg-white border-brand-cobalt/40 shadow-md';
    case 'new':
      return 'bg-gradient-to-br from-amber-50 to-orange-50 border-amber-300 shadow-md';
    case 'locked':
    default:
      return 'bg-slate-50 border-slate-200';
  }
});

const iconTone = computed(() => {
  switch (props.state) {
    case 'earned':
      return 'bg-brand-cobalt/10 text-brand-cobalt';
    case 'new':
      return 'bg-amber-500/20 text-amber-700';
    case 'locked':
    default:
      return 'bg-slate-200 text-slate-400';
  }
});
</script>

<template>
  <div class="rounded-2xl p-3 border relative" :class="toneClasses">
    <span
      v-if="state === 'new'"
      class="absolute -top-2 -right-2 text-3xs font-black uppercase tracking-widest text-white bg-amber-500 rounded-full px-2 py-0.5 shadow"
    >
      Baru!
    </span>
    <div class="flex items-center gap-2">
      <div
        class="w-10 h-10 rounded-xl grid place-items-center flex-shrink-0"
        :class="iconTone"
      >
        <NavIcon :name="state === 'locked' ? 'lock' : meta.icon" :size="20" />
      </div>
      <div class="min-w-0">
        <p
          class="text-2xs font-bold leading-tight"
          :class="state === 'locked' ? 'text-slate-400' : 'text-slate-900'"
        >
          {{ meta.label }}
        </p>
      </div>
    </div>
    <p
      class="text-3xs mt-2 leading-tight"
      :class="state === 'locked' ? 'text-slate-400' : 'text-slate-600'"
    >
      {{ meta.description }}
    </p>
  </div>
</template>

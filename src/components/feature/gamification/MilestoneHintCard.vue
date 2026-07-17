<!--
  MilestoneHintCard.vue — the "Langkah berikutnya" copy at the top
  of the Prestasi hub. Backend can shape this later (endpoint TBD);
  for now it derives directly from `unlocked_sources` — count the
  locked sources and craft an actionable message.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { UnlockedSourceEntry } from '@/services/teacher-progress.service';

const props = defineProps<{
  sources: Record<string, UnlockedSourceEntry>;
  currentStreak: number;
}>();

const lockedCount = computed(() => Object.values(props.sources).filter((s) => !s.unlocked).length);
const openCount = computed(() => Object.values(props.sources).filter((s) => s.unlocked).length);

const message = computed(() => {
  // Prioritize the encouragement path — a teacher on a streak sees a
  // "keep going" hint; a teacher with lots of locked sources sees the
  // path to unlock them.
  if (props.currentStreak >= 3 && lockedCount.value >= 3) {
    return {
      title: `Kamu absen ${props.currentStreak} hari beruntun 🎉`,
      sub: `Setelah admin menugaskan kelas ke kamu, ${lockedCount.value} sumber poin baru otomatis terbuka.`,
    };
  }
  if (lockedCount.value === 0) {
    return {
      title: 'Semua sumber poin sudah terbuka',
      sub: 'Sekarang kamu bisa dapat poin dari absensi, penilaian, RPP, aktivitas kelas, dan pengumuman.',
    };
  }
  if (openCount.value === 1) {
    return {
      title: 'Mulai dari absensi',
      sub: 'Absen tepat waktu adalah kebiasaan paling dasar — dapat 10 XP tiap hari kerja.',
    };
  }
  return {
    title: 'Coba selesaikan satu sumber baru hari ini',
    sub: `Setiap sumber terbuka menambah cara kamu naik level. ${lockedCount.value} sumber masih tergembok.`,
  };
});
</script>

<template>
  <div class="rounded-2xl p-4 bg-brand-cobalt/5 border border-brand-cobalt/20 flex items-start gap-3">
    <div class="w-10 h-10 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0">
      <NavIcon name="target" :size="20" />
    </div>
    <div class="min-w-0 flex-1">
      <p class="text-3xs font-bold text-brand-cobalt uppercase tracking-widest">Langkah berikutnya</p>
      <p class="text-sm font-bold text-slate-900 leading-snug mt-1">{{ message.title }}</p>
      <p class="text-2xs text-slate-600 mt-1 leading-tight">{{ message.sub }}</p>
    </div>
  </div>
</template>

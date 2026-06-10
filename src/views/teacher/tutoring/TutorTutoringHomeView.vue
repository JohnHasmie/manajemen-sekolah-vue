<!--
  TutorTutoringHomeView — tutor's home tab inside the BIMBEL tenant.

  Replaces the school teacher dashboard body when the active tenant is
  a tutoring center. The school dashboard's KPIs (RPP / E-Rapor /
  Kehadiran siswa kelas) read empty for a bimbel tenant and the quick
  actions point at modules that don't apply (Draft RPP / E-Rapor).
  This view ships the bimbel-native equivalents: tutor KPI strip +
  quick actions for Sesi / Buat Sesi / AI Generator.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import type { TutoringTutorStats } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';

const { t } = useI18n();
const router = useRouter();
const auth = useAuthStore();

const loading = ref(true);
const stats = ref<TutoringTutorStats | null>(null);

async function load() {
  loading.value = true;
  try {
    stats.value = await TutoringService.getTutorStats();
  } catch {/* non-fatal — page still works */}
  finally {
    loading.value = false;
  }
}
onMounted(load);

function hoursLabel(h: number): string {
  return h === Math.round(h) ? `${h}h` : `${h.toFixed(1)}h`;
}

const kpiCards = computed<KpiCard[]>(() => {
  const s = stats.value;
  if (!s) return [];
  return [
    {
      icon: 'calendar',
      label: 'Sesi hari ini',
      value: s.sessions_today,
      suffix: s.sessions_this_week > 0
        ? `${s.sessions_this_week} pekan ini`
        : undefined,
      tone: 'brand',
      accented: true,
    },
    {
      icon: 'clock',
      label: 'Jam pekan ini',
      value: hoursLabel(s.hours_this_week),
      tone: 'violet',
    },
    {
      icon: 'check-circle',
      label: 'Kehadiran 30h',
      value: s.attendance_rate == null ? '–' : `${s.attendance_rate}%`,
      tone: 'green',
    },
    {
      icon: 'users',
      label: 'Kelompok',
      value: s.groups,
      suffix: s.students > 0 ? `${s.students} siswa` : undefined,
      tone: 'amber',
    },
  ];
});

const quickActions = [
  {
    icon: 'calendar',
    title: t('tutoring.sessions.title'),
    sub: 'List + kalender mengajar',
    to: 'teacher.tutoring.sessions',
  },
  {
    icon: 'plus',
    title: 'Buat Sesi',
    sub: 'Jadwalkan pertemuan baru',
    to: 'teacher.tutoring.session-create',
  },
  {
    icon: 'sparkles',
    title: 'Generator Soal AI',
    sub: 'Try-out / latihan via AI',
    to: 'teacher.tutoring.tryout-generator',
  },
  {
    icon: 'calendar',
    title: 'Sesi Berulang',
    sub: 'Generate jadwal mingguan sekali klik',
    to: 'teacher.tutoring.recurring',
  },
  {
    icon: 'book',
    title: 'Aktivitas & Tugas',
    sub: 'Beri tugas / quiz ke kelompok',
    to: 'teacher.tutoring.activities',
  },
  {
    icon: 'book',
    title: 'Bahan Ajar',
    sub: 'Unggah materi PDF / link ke kelompok',
    to: 'teacher.tutoring.materials',
  },
  {
    icon: 'wallet',
    title: 'Penghasilan Saya',
    sub: 'Estimasi honor bulan ini',
    to: 'teacher.tutoring.earnings',
  },
] as const;
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="guru"
      kicker="Bimbel · Beranda"
      :title="auth.user?.name ? `Halo, ${auth.user.name}` : 'Halo, Tutor'"
      meta="Pantau sesi mengajar, kelompok, dan kehadiran"
      live-dot
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else>
      <KpiStripCards v-if="stats" :cards="kpiCards" />

      <TutoringSectionHeader title="Aksi Cepat" />
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <TutoringListTile
          v-for="a in quickActions"
          :key="a.title"
          :icon="a.icon"
          accent="tutor"
          :title="a.title"
          :subtitle="a.sub"
          :to="() => router.push({ name: a.to })"
        />
      </div>
    </template>
  </div>
</template>

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
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatRupiah } from '@/lib/format';

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
      icon: 'check-circle',
      label: 'Perlu nilai',
      value: s.pending_submissions,
      suffix: s.pending_submissions === 0
        ? 'Tidak ada antrean'
        : 'Tugas belum dinilai',
      tone: s.pending_submissions > 0 ? 'amber' : 'green',
    },
  ];
});

const nextSessionLabel = computed(() => {
  const ns = stats.value?.next_session;
  if (!ns?.scheduled_at) return '—';
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleString('id-ID', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
});

function goToAttendance() {
  const ns = stats.value?.next_session;
  if (!ns) return;
  router.push({
    name: 'teacher.tutoring.attendance',
    params: { sessionId: ns.id },
  });
}

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
  {
    icon: 'sun',
    title: 'Tampilan',
    sub: 'Mode terang / gelap / otomatis',
    to: 'teacher.tutoring.appearance',
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

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else>
      <!-- ── Pinned next session ─────────────────────────────────── -->
      <div
        v-if="stats?.next_session"
        class="rounded-xl border border-role-guru/25 bg-gradient-to-br from-role-guru/8 to-white p-4"
      >
        <div class="flex items-center justify-between">
          <span class="rounded-full bg-role-guru px-2 py-0.5 text-[9.5px] font-extrabold uppercase tracking-widest text-white">
            Sesi Berikutnya
          </span>
          <span class="text-xs font-bold text-bimbel-text-mid">{{ nextSessionLabel }}</span>
        </div>
        <h3 class="mt-2 text-base font-extrabold tracking-tight text-bimbel-text-hi">
          {{ stats.next_session.group_name || stats.next_session.topic || 'Sesi terjadwal' }}
        </h3>
        <p v-if="stats.next_session.program_name" class="text-xs text-bimbel-text-mid">
          {{ [
            stats.next_session.program_name,
            stats.next_session.room ? `Ruang ${stats.next_session.room}` : null,
            `${stats.next_session.duration_minutes} menit`,
          ].filter(Boolean).join(' · ') }}
        </p>
        <div class="mt-3 flex flex-wrap gap-2">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 rounded-lg bg-role-guru px-3.5 py-2 text-sm font-bold text-white hover:bg-role-guru/90"
            @click="goToAttendance"
          >
            <NavIcon name="check-circle" :size="14" />
            Catat Kehadiran
          </button>
          <a
            v-if="stats.next_session.meeting_url"
            :href="stats.next_session.meeting_url"
            target="_blank"
            rel="noopener"
            class="inline-flex items-center gap-1.5 rounded-lg border border-role-guru/40 px-3.5 py-2 text-sm font-bold text-role-guru hover:bg-role-guru/5"
          >
            <NavIcon name="link" :size="14" />
            Meet
          </a>
        </div>
      </div>

      <KpiStripCards v-if="stats" :cards="kpiCards" />

      <!-- ── Honor + rating preview strip ───────────────────────── -->
      <div v-if="stats" class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <div class="rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2.5">
          <div class="flex items-center gap-2">
            <NavIcon name="wallet" :size="16" class="text-role-guru" />
            <div class="min-w-0 flex-1">
              <div class="truncate text-sm font-extrabold tracking-tight text-bimbel-text-hi">
                {{ stats.month_earnings > 0 ? formatRupiah(stats.month_earnings) : 'Rp 0' }}
              </div>
              <div class="text-[10px] font-semibold uppercase tracking-wider text-bimbel-text-mid">
                Honor bulan ini
              </div>
              <div class="truncate text-[10px] text-bimbel-text-lo">
                {{ stats.month_sessions_done > 0
                  ? `${stats.month_sessions_done} sesi DONE`
                  : 'Belum ada sesi DONE' }}
              </div>
            </div>
          </div>
        </div>
        <div class="rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2.5">
          <div class="flex items-center gap-2">
            <NavIcon name="check-circle" :size="16" class="text-role-guru" />
            <div class="min-w-0 flex-1">
              <div class="truncate text-sm font-extrabold tracking-tight text-bimbel-text-hi">
                {{ stats.rating_avg == null ? '–' : stats.rating_avg.toFixed(1) }}
              </div>
              <div class="text-[10px] font-semibold uppercase tracking-wider text-bimbel-text-mid">
                Rating 30h
              </div>
              <div class="truncate text-[10px] text-bimbel-text-lo">
                {{ stats.rating_count === 0 ? 'Belum ada rating' : `${stats.rating_count} ulasan` }}
              </div>
            </div>
          </div>
        </div>
      </div>

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

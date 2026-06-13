<!--
  TutorTutoringHomeView — bimbel tutor Beranda.

  Layout mirrors mobile `tutor_beranda_screen.dart`:

    1. Greeting hero (navy, role-tier cyan) + 3-stat strip
       Kelas / Sesi mgg ini / Rating
    2. Sesi berikutnya — accent-stripe card with countdown chip
       (success-tinted if ≤ 24h away) + Catatan kehadiran CTA
    3. Kelas saya — 3-col gradient class cards (filtered to groups
       where tutor_user_id = me)
    4. 4 shortcuts row — Bahan Ajar / Soal AI / Rating / Sesi Berulang
    5. Honor ribbon — month_earnings (success tone, always shown)
    6. Yang baru feed — last 6 events from /tutoring/tutor-activity

  Light/dark is automatic via the `bimbel-light` / `bimbel-dark`
  wrapper class applied by AppShell from useBimbelThemeStore.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import type {
  TutoringTutorStats,
  TutoringGroup,
  TutoringFeedEvent,
} from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import TutorPrimaryCard from '@/components/feature/tutoring/TutorPrimaryCard.vue';
import TutorClassCard from '@/components/feature/tutoring/TutorClassCard.vue';
import TutorShortcutTile from '@/components/feature/tutoring/TutorShortcutTile.vue';
import TutorRibbon from '@/components/feature/tutoring/TutorRibbon.vue';
import TutorActivityRow from '@/components/feature/tutoring/TutorActivityRow.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatRupiah } from '@/lib/format';

const router = useRouter();
const auth = useAuthStore();

const loading = ref(true);
const stats = ref<TutoringTutorStats | null>(null);
const groups = ref<TutoringGroup[]>([]);
const feed = ref<TutoringFeedEvent[]>([]);

async function load() {
  loading.value = true;
  try {
    const [s, g, f] = await Promise.all([
      TutoringService.getTutorStats().catch(() => null),
      TutoringService.getAllGroups().catch(() => [] as TutoringGroup[]),
      TutoringService.getTutorActivity({ limit: 6 }).catch(
        () => [] as TutoringFeedEvent[],
      ),
    ]);
    stats.value = s;
    groups.value = g;
    feed.value = f;
  } finally {
    loading.value = false;
  }
}
onMounted(load);

// ── Greeting + first-name (no gender on User payload yet) ─────────
function timeGreeting(): string {
  const h = new Date().getHours();
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 19) return 'Selamat sore';
  return 'Selamat malam';
}

const firstName = computed(() => {
  const n = auth.user?.name || 'Tutor';
  return n.split(/\s+/)[0];
});

const subtitle = computed(() => {
  const kelas = myGroups.value.length;
  return kelas > 0 ? `Tutor · ${kelas} kelas aktif` : 'Tutor';
});

// ── 3-stat hero strip ─────────────────────────────────────────────
const heroStats = computed(() => {
  const s = stats.value;
  return [
    {
      label: 'Kelas',
      value: String(myGroups.value.length),
      hint: 'aktif',
    },
    {
      label: 'Sesi mgg ini',
      value: String(s?.sessions_this_week ?? 0),
      hint:
        s && s.sessions_today > 0
          ? `${s.sessions_today} hari ini`
          : undefined,
    },
    {
      label: 'Rating',
      value: s?.rating_avg == null ? '–' : s.rating_avg.toFixed(1),
      hint:
        s && s.rating_count > 0 ? `${s.rating_count} ulasan` : 'belum ada',
    },
  ];
});

// ── My groups filter ─────────────────────────────────────────────
const myGroups = computed(() =>
  groups.value.filter((g) => g.tutor_user_id === auth.user?.id),
);

const visibleGroups = computed(() => myGroups.value.slice(0, 6));

// ── Sesi berikutnya — countdown + tone ────────────────────────────
const nextSession = computed(() => stats.value?.next_session ?? null);

const nextSessionLabel = computed(() => {
  const ns = nextSession.value;
  if (!ns?.scheduled_at) return null;
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return null;
  return d.toLocaleString('id-ID', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
});

const nextSessionCountdown = computed(() => {
  const ns = nextSession.value;
  if (!ns?.scheduled_at) return null;
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return null;
  const diffMin = (d.valueOf() - Date.now()) / 60_000;
  if (diffMin < 0) return 'mulai';
  if (diffMin < 60) return `${Math.round(diffMin)} menit lagi`;
  const h = diffMin / 60;
  if (h < 24) return `${Math.round(h)} jam lagi`;
  return `${Math.round(h / 24)} hari lagi`;
});

const nextSessionTone = computed<'success' | 'brand'>(() => {
  const ns = nextSession.value;
  if (!ns?.scheduled_at) return 'brand';
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return 'brand';
  const diffH = (d.valueOf() - Date.now()) / 3_600_000;
  return diffH <= 24 ? 'success' : 'brand';
});

function goToAttendance() {
  const ns = nextSession.value;
  if (!ns) return;
  router.push({
    name: 'teacher.tutoring.attendance',
    params: { sessionId: ns.id },
  });
}

function goToClass(g: TutoringGroup) {
  router.push({ name: 'teacher.tutoring.class-detail', params: { groupId: g.id } });
}

// ── 4 shortcuts ───────────────────────────────────────────────────
const shortcuts = [
  { icon: 'book', label: 'Bahan Ajar', hint: 'PDF / link', to: 'teacher.tutoring.materials' },
  { icon: 'sparkles', label: 'Soal AI', hint: 'Try-out generator', to: 'teacher.tutoring.tryout-generator' },
  { icon: 'star', label: 'Rating', hint: 'Feedback siswa', to: 'teacher.tutoring.appearance' },
  { icon: 'calendar', label: 'Sesi Berulang', hint: 'Generate mingguan', to: 'teacher.tutoring.recurring' },
] as const;

function goToShortcut(name: string) {
  router.push({ name });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <div v-if="loading" class="py-16 text-center text-bimbel-text-mid">
      Memuat…
    </div>

    <template v-else>
      <!-- 1. Hero -->
      <TutorBerandaHero
        :greeting="timeGreeting()"
        :title="`Halo, ${firstName}`"
        :subtitle="subtitle"
        :stats="heroStats"
      />

      <!-- 2. Sesi berikutnya -->
      <TutorPrimaryCard
        v-if="nextSession"
        icon="calendar"
        kicker="SESI BERIKUTNYA"
        :title="nextSession.group_name || nextSession.topic || 'Sesi terjadwal'"
        :subtitle="[
          nextSession.program_name,
          nextSession.room ? `Ruang ${nextSession.room}` : null,
          nextSession.duration_minutes
            ? `${nextSession.duration_minutes} menit`
            : null,
        ].filter(Boolean).join(' · ') || undefined"
        :tone="nextSessionTone"
      >
        <template #meta>
          <span
            class="rounded-full px-2.5 py-1 text-[11px] font-extrabold tracking-tight"
            :class="
              nextSessionTone === 'success'
                ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-400'
                : 'bg-bimbel-accent-dim text-bimbel-accent'
            "
          >
            {{ nextSessionCountdown }}
          </span>
        </template>
        <p v-if="nextSessionLabel" class="text-bimbel-text-mid">
          <NavIcon name="clock" :size="13" class="inline -mt-0.5" />
          {{ nextSessionLabel }}
        </p>
        <template #actions>
          <button
            type="button"
            class="inline-flex items-center gap-1.5 rounded-lg bg-bimbel-accent px-3.5 py-2 text-sm font-bold text-white hover:opacity-90"
            @click="goToAttendance"
          >
            <NavIcon name="check-circle" :size="14" />
            Catat Kehadiran
          </button>
          <a
            v-if="nextSession.meeting_url"
            :href="nextSession.meeting_url"
            target="_blank"
            rel="noopener"
            class="inline-flex items-center gap-1.5 rounded-lg border border-bimbel-accent/40 px-3.5 py-2 text-sm font-bold text-bimbel-accent hover:bg-bimbel-accent-dim"
          >
            <NavIcon name="link" :size="14" />
            Meet
          </a>
        </template>
      </TutorPrimaryCard>

      <!-- 3. Kelas saya -->
      <div>
        <TutoringSectionHeader
          title="Kelas saya"
          :action-label="myGroups.length > 6 ? 'Lihat semua' : undefined"
          @action="router.push({ name: 'teacher.tutoring.classes' })"
        />
        <div
          v-if="visibleGroups.length"
          class="grid gap-3 grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
        >
          <TutorClassCard
            v-for="g in visibleGroups"
            :key="g.id"
            :identity-key="g.id"
            :name="g.name"
            :program="g.tutor?.name ? `Tutor: ${g.tutor.name}` : undefined"
            :meta="g.enrollments_count != null ? `${g.enrollments_count} siswa` : undefined"
            @click="goToClass(g)"
          />
        </div>
        <p v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-6 text-center text-sm text-bimbel-text-mid">
          Belum ada kelas — admin akan menugaskan Anda ke kelompok.
        </p>
      </div>

      <!-- 4. Shortcuts -->
      <div>
        <TutoringSectionHeader title="Akses cepat" />
        <div class="grid gap-2.5 grid-cols-2 lg:grid-cols-4">
          <TutorShortcutTile
            v-for="sc in shortcuts"
            :key="sc.label"
            :icon="sc.icon"
            :label="sc.label"
            :hint="sc.hint"
            @click="goToShortcut(sc.to)"
          />
        </div>
      </div>

      <!-- 5. Honor ribbon -->
      <TutorRibbon
        v-if="stats"
        icon="wallet"
        label="HONOR BULAN INI"
        :value="formatRupiah(stats.month_earnings)"
        :hint="
          stats.month_sessions_done > 0
            ? `${stats.month_sessions_done} sesi DONE`
            : 'Belum ada sesi DONE'
        "
        tone="success"
        clickable
        @click="router.push({ name: 'teacher.tutoring.earnings' })"
      />

      <!-- 6. Yang baru -->
      <div>
        <TutoringSectionHeader title="Yang baru" />
        <div v-if="feed.length" class="space-y-2">
          <TutorActivityRow
            v-for="(e, i) in feed"
            :key="i"
            :type="e.type"
            :title="e.title"
            :subtitle="e.subtitle"
            :occurred-at="e.occurred_at"
          />
        </div>
        <p
          v-else
          class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-6 text-center text-sm text-bimbel-text-mid"
        >
          Belum ada aktivitas di 14 hari terakhir.
        </p>
      </div>
    </template>
  </div>
</template>

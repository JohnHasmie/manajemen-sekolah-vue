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
  wrapper class applied by AppShell from useTutoringThemeStore.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
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

const { t } = useI18n();
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
  if (h < 11) return t('tutor.bimbel.home.greeting_morning');
  if (h < 15) return t('tutor.bimbel.home.greeting_afternoon');
  if (h < 19) return t('tutor.bimbel.home.greeting_evening');
  return t('tutor.bimbel.home.greeting_night');
}

const firstName = computed(() => {
  const n = auth.user?.name || t('tutor.bimbel.home.tutor_fallback_name');
  return n.split(/\s+/)[0];
});

const subtitle = computed(() => {
  const kelas = myGroups.value.length;
  return kelas > 0
    ? t('tutor.bimbel.home.subtitle_tutor_active_classes', { count: kelas })
    : t('tutor.bimbel.home.subtitle_tutor');
});

// ── 3-stat hero strip ─────────────────────────────────────────────
const heroStats = computed(() => {
  const s = stats.value;
  return [
    {
      label: t('tutor.bimbel.home.stat_classes'),
      value: String(myGroups.value.length),
      hint: t('tutor.bimbel.home.stat_classes_hint'),
    },
    {
      label: t('tutor.bimbel.home.stat_sessions_week'),
      value: String(s?.sessions_this_week ?? 0),
      hint:
        s && s.sessions_today > 0
          ? `${s.sessions_today} ${t('tutor.bimbel.home.stat_sessions_today_suffix')}`
          : undefined,
    },
    {
      label: t('tutor.bimbel.home.stat_rating'),
      value: s?.rating_avg == null ? '–' : s.rating_avg.toFixed(1),
      hint:
        s && s.rating_count > 0
          ? `${s.rating_count} ${t('tutor.bimbel.home.stat_rating_reviews_suffix')}`
          : t('tutor.bimbel.home.stat_rating_none'),
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
  if (diffMin < 0) return t('tutor.bimbel.home.countdown_starting');
  if (diffMin < 60) return t('tutor.bimbel.home.countdown_minutes', { n: Math.round(diffMin) });
  const h = diffMin / 60;
  if (h < 24) return t('tutor.bimbel.home.countdown_hours', { n: Math.round(h) });
  return t('tutor.bimbel.home.countdown_days', { n: Math.round(h / 24) });
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
// Synced with mobile (lib/.../tutor_home_screen.dart) after the
// quick-action shuffle: Sesi Berulang slot replaced with Pengumuman so
// the most common tutor task ("kirim info ke kelompok") is one tap
// away. Sesi Berulang stays available from Lainnya → MENGAJAR.
// Rating now goes to the actual ratings route (was mistakenly wired
// to appearance).
const shortcuts = computed(() => [
  { icon: 'book', label: t('tutor.bimbel.home.shortcut_materials_label'), hint: t('tutor.bimbel.home.shortcut_materials_hint'), to: 'teacher.tutoring.materials' },
  { icon: 'sparkles', label: t('tutor.bimbel.home.shortcut_ai_label'), hint: t('tutor.bimbel.home.shortcut_ai_hint'), to: 'teacher.tutoring.tryout-generator' },
  { icon: 'star', label: t('tutor.bimbel.home.shortcut_rating_label'), hint: t('tutor.bimbel.home.shortcut_rating_hint'), to: 'teacher.tutoring.ratings' },
  { icon: 'megaphone', label: t('tutor.bimbel.home.shortcut_announcements_label'), hint: t('tutor.bimbel.home.shortcut_announcements_hint'), to: 'teacher.tutoring.announcements' },
]);

function goToShortcut(name: string) {
  router.push({ name });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <div v-if="loading" class="py-16 text-center text-bimbel-text-mid">
      {{ t('tutor.bimbel.home.loading') }}
    </div>

    <template v-else>
      <!-- 1. Hero -->
      <TutorBerandaHero
        :greeting="timeGreeting()"
        :title="t('tutor.bimbel.home.title_hello', { name: firstName })"
        :subtitle="subtitle"
        :stats="heroStats"
      />

      <!-- 2. Sesi berikutnya -->
      <TutorPrimaryCard
        v-if="nextSession"
        icon="calendar"
        :kicker="t('tutor.bimbel.home.primary_kicker')"
        :title="nextSession.group_name || nextSession.topic || t('tutor.bimbel.home.primary_title_fallback')"
        :subtitle="[
          nextSession.program_name,
          nextSession.room ? `${t('tutor.bimbel.home.primary_room_prefix')} ${nextSession.room}` : null,
          nextSession.duration_minutes
            ? `${nextSession.duration_minutes} ${t('tutor.bimbel.home.primary_duration_suffix')}`
            : null,
        ].filter(Boolean).join(' · ') || undefined"
        :tone="nextSessionTone"
      >
        <template #meta>
          <span
            class="rounded-full px-2.5 py-1 text-[12px] font-extrabold tracking-tight"
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
            {{ t('tutor.bimbel.home.btn_attendance') }}
          </button>
          <a
            v-if="nextSession.meeting_url"
            :href="nextSession.meeting_url"
            target="_blank"
            rel="noopener"
            class="inline-flex items-center gap-1.5 rounded-lg border border-bimbel-accent/40 px-3.5 py-2 text-sm font-bold text-bimbel-accent hover:bg-bimbel-accent-dim"
          >
            <NavIcon name="link" :size="14" />
            {{ t('tutor.bimbel.home.btn_meet') }}
          </a>
        </template>
      </TutorPrimaryCard>

      <!-- 3. Kelas saya -->
      <div>
        <TutoringSectionHeader
          :title="t('tutor.bimbel.home.section_classes')"
          :action-label="myGroups.length > 6 ? t('tutor.bimbel.home.view_all') : undefined"
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
            :program="g.tutor?.name ? `${t('tutor.bimbel.home.class_tutor_prefix')}: ${g.tutor.name}` : undefined"
            :meta="g.enrollments_count != null ? `${g.enrollments_count} ${t('tutor.bimbel.home.class_students_suffix')}` : undefined"
            @click="goToClass(g)"
          />
        </div>
        <p v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-6 text-center text-sm text-bimbel-text-mid">
          {{ t('tutor.bimbel.home.classes_empty') }}
        </p>
      </div>

      <!-- 4. Shortcuts -->
      <div>
        <TutoringSectionHeader :title="t('tutor.bimbel.home.section_shortcuts')" />
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
        :label="t('tutor.bimbel.home.ribbon_label')"
        :value="formatRupiah(stats.month_earnings)"
        :hint="
          stats.month_sessions_done > 0
            ? t('tutor.bimbel.home.ribbon_hint_sessions', { count: stats.month_sessions_done })
            : t('tutor.bimbel.home.ribbon_hint_empty')
        "
        tone="success"
        clickable
        @click="router.push({ name: 'teacher.tutoring.earnings' })"
      />

      <!-- 6. Yang baru -->
      <div>
        <TutoringSectionHeader :title="t('tutor.bimbel.home.section_feed')" />
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
          {{ t('tutor.bimbel.home.feed_empty') }}
        </p>
      </div>
    </template>
  </div>
</template>

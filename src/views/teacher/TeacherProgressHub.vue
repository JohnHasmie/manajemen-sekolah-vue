<!--
  TeacherProgressHub.vue — /teacher/gamification

  3 tabs (Ringkasan / Badge / Peringkat) inside a shared shell.

  Data flow: on mount fetch /teacher/gamification/me once → drives
  Ringkasan + Badge tab. Peringkat tab lazy-loads its own data (with
  a cohort dropdown) so a teacher never pays that query cost on the
  initial paint of the hub.

  Every fetch is wrapped in try/catch — a 402 from a school losing
  the sub mid-session shows a warm empty state, not a stack trace.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import LevelXpRing from '@/components/feature/gamification/LevelXpRing.vue';
import StreakFlameKpi from '@/components/feature/gamification/StreakFlameKpi.vue';
import WeeklyPointsChart from '@/components/feature/gamification/WeeklyPointsChart.vue';
import SignalSourceGrid from '@/components/feature/gamification/SignalSourceGrid.vue';
import BadgeTile from '@/components/feature/gamification/BadgeTile.vue';
import LeaderboardRow from '@/components/feature/gamification/LeaderboardRow.vue';
import CohortPillGroup from '@/components/feature/gamification/CohortPillGroup.vue';
import MilestoneHintCard from '@/components/feature/gamification/MilestoneHintCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import {
  TeacherProgressService,
  type PersonalPayload,
  type LeaderboardResponse,
  type Cohort,
  type TeacherAction,
} from '@/services/teacher-progress.service';
import { useToast } from '@/composables/useToast';

const toast = useToast();
const router = useRouter();
const { t } = useI18n();

// Backend Lane-A `target_route` hints are snake_case keys that don't
// exist as literal Vue route names — the mapping is intentional so the
// backend contract stays agnostic to the FE router shape. Mirrors the
// same mapper used inside AdminReadinessView; the teacher slice deals
// with a different set of routes (the ones each quest-earning inbox
// item deep-links into), so the map lives here rather than being
// pulled up into a shared helper for now.
const ROUTE_MAP: Record<string, string> = {
  teacher_attendance: 'teacher.attendance',
  teacher_rpp: 'teacher.lesson-plans',
  teacher_grade_input: 'teacher.grades',
  teacher_report_cards: 'teacher.report-cards',
  teacher_recommendations: 'teacher.recommendations',
};

function mapRouteName(key: string): string | null {
  const mapped = ROUTE_MAP[key];
  if (!mapped) {
    // eslint-disable-next-line no-console
    console.warn(`[TeacherProgressHub] Unmapped target_route: ${key}`);
    return null;
  }
  return mapped;
}

// Icon glyph per action type — SVG lucide names already registered in
// NavIcon.vue (file-clock was the one new addition in this slice). Any
// action type the backend adds that isn't listed here falls back to
// the neutral bell icon so the row still renders.
const ACTION_ICONS: Record<string, string> = {
  missed_presensi: 'calendar-check',
  rpp_needs_revision: 'book',
  grades_overdue: 'clipboard',
  report_card_draft_deadline: 'file-clock',
  recommendation_reply_unread: 'mail',
};

function actionIconName(type: string): string {
  return ACTION_ICONS[type] ?? 'bell';
}

type Tab = 'summary' | 'badges' | 'leaderboard';
const activeTab = ref<Tab>('summary');
const TAB_LABELS: Record<Tab, string> = {
  summary: 'Ringkasan',
  badges: 'Badge',
  leaderboard: 'Peringkat',
};

const personal = ref<PersonalPayload | null>(null);
const personalError = ref<string | null>(null);

const leaderboard = ref<LeaderboardResponse | null>(null);
const leaderboardError = ref<string | null>(null);
const cohort = ref<Cohort>('general');
const period = ref<'week' | 'month'>('week');

const savingSetting = ref(false);

// Full catalog codes — used to compute earned vs locked in the Badge
// tab. Match backend BadgeCatalog::classes() order.
const ALL_BADGE_CODES: string[] = [
  'absen_pertama',
  'ayam_pagi',
  'beruntun_10',
  'beruntun_30',
  'beruntun_90',
  'bulan_penuh',
  'penilaian_rajin',
  'rpp_rajin',
  'lima_puluh_koreksi',
  'level_5',
  'level_10',
  'wali_tuntas',
];

async function loadPersonal() {
  personalError.value = null;
  try {
    personal.value = await TeacherProgressService.getMe();
  } catch (e: any) {
    personalError.value = e?.response?.status === 402
      ? 'Modul Prestasi belum aktif untuk sekolah ini.'
      : 'Gagal memuat data. Coba refresh.';
  }
}

async function loadLeaderboard() {
  leaderboardError.value = null;
  try {
    leaderboard.value = await TeacherProgressService.getLeaderboard({
      period: period.value,
      cohort: cohort.value,
    });
  } catch (e: any) {
    leaderboardError.value = e?.response?.status === 402
      ? 'Modul belum aktif — peringkat tidak tersedia.'
      : 'Gagal memuat peringkat.';
  }
}

async function toggleHide() {
  if (!personal.value) return;
  const nextValue = !personal.value.hide_from_leaderboard;
  savingSetting.value = true;
  try {
    const res = await TeacherProgressService.updateSetting({ hide_from_leaderboard: nextValue });
    personal.value.hide_from_leaderboard = res.hide_from_leaderboard;
    toast.success(res.hide_from_leaderboard ? 'Nama disembunyikan dari peringkat.' : 'Nama tampil di peringkat.');
  } catch {
    toast.error('Gagal menyimpan pengaturan. Coba lagi.');
  } finally {
    savingSetting.value = false;
  }
}

// Teacher-fusion follow-on: "Aksi hari ini" quest tiles on the
// Ringkasan tab. Sourced from personal.actions (backend MR !487).
// Absent key → older backend, `actionItems` stays empty and the whole
// card renders its "Semua tuntas" state.
const actionItems = computed<TeacherAction[]>(
  () => personal.value?.actions ?? [],
);

const totalXpAvailable = computed<number>(() =>
  actionItems.value.reduce(
    (sum, action) =>
      typeof action.xp_reward === 'number' ? sum + action.xp_reward : sum,
    0,
  ),
);

function onActionTap(action: TeacherAction): void {
  const name = mapRouteName(action.target_route);
  if (!name) return;
  router.push({
    name,
    params: action.target_params as Record<string, string>,
  });
}

// earned badges — sourced from personal.earned_badges (backend MR 4b).
// Absent key → all locked (older backends). Same catalog + rendering,
// just gains the earned/new colouring when the backend delivers.
const earnedByCode = computed<Record<string, { is_new: boolean }>>(() => {
  const list = personal.value?.earned_badges ?? [];
  const out: Record<string, { is_new: boolean }> = {};
  for (const b of list) {
    out[b.code] = { is_new: b.is_new };
  }
  return out;
});

function badgeState(code: string): 'earned' | 'new' | 'locked' {
  const hit = earnedByCode.value[code];
  if (!hit) return 'locked';
  return hit.is_new ? 'new' : 'earned';
}

// Choose which cohorts to show in the switcher — hide staff option
// for teacher-shaped users; keep all otherwise.
const availableCohorts = computed<Cohort[]>(() => ['general', 'subject', 'homeroom']);

// Empty-state copy for the Peringkat tab — cohort-aware so a general
// teacher sees a welcoming "kamu pertama" nudge and a wali kelas sees
// a message oriented to their own week's activity. Keeps the plain
// "belum ada" bare-string out of the UI (Wave 1 warm-empty pattern).
const cohortEmptyTitle = computed<string>(() => {
  if (cohort.value === 'general') return 'Belum ada peringkat minggu ini';
  if (cohort.value === 'homeroom') return 'Belum ada wali kelas aktif minggu ini';
  return 'Belum ada guru mapel aktif minggu ini';
});

const cohortEmptyHint = computed<string>(() => {
  if (cohort.value === 'general') {
    return 'Absen tepat waktu besok pagi — kamu bisa jadi orang pertama yang tampil di sini.';
  }
  if (period.value === 'month') {
    return 'Coba lihat "Minggu ini" — periode bulanan baru mulai jalan begitu ada aktivitas cukup.';
  }
  return 'Peringkat dihitung dari poin minggu ini. Setelah kamu atau rekan sekelompok absen tepat waktu, peringkat akan otomatis tampil.';
});

function switchTab(tab: Tab) {
  activeTab.value = tab;
  if (tab === 'leaderboard' && !leaderboard.value) {
    void loadLeaderboard();
  }
}

onMounted(() => {
  void loadPersonal();
});
</script>

<template>
  <div class="pb-10">
    <BrandPageHeader
      role="teacher"
      kicker="Prestasi & Gamifikasi"
      title="Prestasi Saya"
      meta="Lacak level, streak, badge, dan peringkat kamu."
    />

    <div class="px-4 sm:px-6 pt-6 relative z-10 space-y-6 max-w-4xl mx-auto">
      <!-- Empty / error state — full-width warm card. -->
      <div
        v-if="personalError"
        class="rounded-2xl p-6 bg-amber-50 border border-amber-200 text-amber-800 flex items-start gap-3"
      >
        <NavIcon name="alert-circle" :size="20" />
        <p class="text-sm font-bold">{{ personalError }}</p>
      </div>

      <template v-else-if="personal">
        <!-- Tab strip — sits cleanly in the content area below the
             brand header (previous `-mt-6` yanked it up into the
             header's rounded bottom edge, producing a "colliding"
             half-in / half-out visual on prod). Full-width pill row
             so the tabs feel like a proper page control instead of
             a floating chip. -->
        <div class="flex bg-slate-100 rounded-xl p-1 w-full sm:w-auto sm:inline-flex">
          <button
            v-for="tab in (['summary', 'badges', 'leaderboard'] as Tab[])"
            :key="tab"
            type="button"
            class="flex-1 sm:flex-none px-4 py-2 rounded-lg text-sm font-bold transition"
            :class="activeTab === tab
              ? 'bg-white text-brand-cobalt shadow-sm'
              : 'text-slate-600 hover:text-slate-800'"
            @click="switchTab(tab)"
          >
            {{ TAB_LABELS[tab] }}
          </button>
        </div>

        <!-- ─── Ringkasan tab ─── -->
        <section v-if="activeTab === 'summary'" class="space-y-6">
          <!-- Aksi hari ini — teacher-fusion follow-on. The quest lane
               that mirrors the teacher priority inbox: each item that
               maps to an XP-earning activity source shows its +XP
               reward pill, unmapped ones render neutral. Tap → the
               same deep-link the inbox uses. Empty state renders a
               soft green tuntas tile so the section never looks
               broken. -->
          <div
            class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 border-l-4 border-l-brand-cobalt"
          >
            <header class="flex items-start justify-between gap-3 mb-3">
              <div class="flex items-center gap-2 min-w-0 flex-wrap">
                <span
                  class="w-2 h-2 rounded-full bg-brand-cobalt flex-shrink-0"
                  aria-hidden="true"
                ></span>
                <h3 class="text-sm font-black text-slate-900 tracking-tight">
                  {{ t('teacher.progress.actions.header') }}
                </h3>
                <span
                  v-if="actionItems.length > 0"
                  class="text-3xs font-black px-2 py-0.5 rounded-full bg-red-50 text-red-700"
                >
                  {{ actionItems.length }}
                </span>
                <p class="text-2xs text-slate-500 font-bold w-full sm:w-auto">
                  {{ t('teacher.progress.actions.sub') }}
                </p>
              </div>
              <span
                v-if="totalXpAvailable > 0"
                class="text-2xs font-black text-brand-cobalt flex-shrink-0 whitespace-nowrap"
              >
                {{ t('teacher.progress.actions.xpAvailable', { xp: totalXpAvailable }) }}
              </span>
            </header>

            <div
              v-if="actionItems.length === 0"
              class="rounded-xl border border-emerald-100 bg-emerald-50 p-4 flex items-center gap-3"
            >
              <span
                class="w-9 h-9 rounded-full bg-emerald-100 text-emerald-600 grid place-items-center flex-shrink-0"
              >
                <NavIcon name="check-circle" :size="18" />
              </span>
              <p class="text-sm font-bold text-emerald-800">
                {{ t('teacher.progress.actions.allClear') }}
              </p>
            </div>

            <ul v-else class="space-y-2.5">
              <li
                v-for="action in actionItems"
                :key="action.id"
                class="flex items-start gap-3 p-3 rounded-xl border border-slate-100 hover:border-brand-cobalt/30 hover:shadow-sm transition-all"
              >
                <span
                  class="w-8 h-8 rounded-lg grid place-items-center flex-shrink-0"
                  :class="action.xp_reward !== null
                    ? 'bg-brand-cobalt/10 text-brand-cobalt'
                    : 'bg-slate-100 text-slate-500'"
                >
                  <NavIcon :name="actionIconName(action.type)" :size="16" />
                </span>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-bold text-slate-900 truncate">
                    {{ action.label }}
                  </p>
                  <p class="text-2xs text-slate-500 mt-0.5 line-clamp-1">
                    {{ action.subtitle }}
                  </p>
                </div>
                <span
                  v-if="action.xp_reward !== null"
                  class="inline-flex items-center gap-1 text-3xs font-black px-2 py-1 rounded-full bg-brand-cobalt/10 text-brand-cobalt flex-shrink-0 self-center"
                >
                  <NavIcon name="plus" :size="10" />
                  {{ t('teacher.progress.actions.xpChip', { xp: action.xp_reward }) }}
                </span>
                <button
                  type="button"
                  class="text-2xs font-black uppercase tracking-widest px-3 py-1.5 rounded-lg transition-colors flex items-center gap-1 flex-shrink-0 self-center"
                  :class="mapRouteName(action.target_route)
                    ? 'bg-brand-cobalt/10 text-brand-cobalt hover:bg-brand-cobalt/20'
                    : 'bg-slate-100 text-slate-400 cursor-not-allowed'"
                  :disabled="!mapRouteName(action.target_route)"
                  @click="onActionTap(action)"
                >
                  {{ t('common.open') }}
                  <NavIcon name="arrow-right" :size="12" />
                </button>
              </li>
            </ul>
          </div>

          <MilestoneHintCard
            :sources="personal.unlocked_sources"
            :current-streak="personal.streak_current"
          />

          <!-- Level ring + Streak + XP tiles -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 flex items-center gap-4">
              <LevelXpRing
                :level="personal.level"
                :level-title="personal.level_title"
                :xp-in-level="personal.xp_in_level"
                :xp-for-next-level="personal.xp_for_next_level"
                size="lg"
              />
              <div class="min-w-0">
                <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
                  {{ personal.xp_in_level }} / {{ personal.xp_in_level + personal.xp_for_next_level }} XP
                </p>
                <p class="text-sm font-black text-slate-900 mt-1">Menuju Level {{ personal.level + 1 }}</p>
                <p class="text-2xs text-slate-500 mt-1">Total {{ personal.total_xp }} XP kumulatif</p>
              </div>
            </div>

            <StreakFlameKpi
              :current="personal.streak_current"
              :longest="personal.streak_longest"
            />

            <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
              <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Hari ini</p>
              <p class="text-2xl font-black text-slate-900 leading-none mt-2">
                {{ personal.xp_today }}<span class="text-sm text-slate-500 font-bold ml-1">XP</span>
              </p>
              <p class="text-2xs text-slate-500 mt-1">
                Minggu ini: <span class="font-bold text-slate-700">{{ personal.xp_this_week }} XP</span>
              </p>
            </div>
          </div>

          <!-- Chart -->
          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
            <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Aktivitas XP</p>
            <WeeklyPointsChart :points="personal.weekly_chart" />
          </div>

          <!-- Sumber poin -->
          <div>
            <p class="text-2xs font-bold text-slate-700 uppercase tracking-widest mb-3">Sumber poin</p>
            <SignalSourceGrid :sources="personal.unlocked_sources" />
          </div>
        </section>

        <!-- ─── Badge tab ─── -->
        <section v-else-if="activeTab === 'badges'" class="space-y-6">
          <div>
            <p class="text-2xs font-bold text-slate-700 uppercase tracking-widest mb-3">
              Semua badge ({{ ALL_BADGE_CODES.length }})
            </p>
            <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
              <BadgeTile
                v-for="code in ALL_BADGE_CODES"
                :key="code"
                :code="code"
                :state="badgeState(code)"
              />
            </div>
            <p class="text-2xs text-slate-500 mt-4">
              Badge terkunci akan tampil aktif begitu kamu memenuhi syaratnya. Yang bertanda "Baru!" adalah pencapaian dalam 48 jam terakhir.
            </p>
          </div>
        </section>

        <!-- ─── Peringkat tab ─── -->
        <section v-else-if="activeTab === 'leaderboard'" class="space-y-4">
          <div class="flex flex-wrap items-center gap-3">
            <CohortPillGroup
              v-model="cohort"
              :available="availableCohorts"
              @update:modelValue="loadLeaderboard"
            />
            <select
              v-model="period"
              class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-2xs font-bold text-slate-700"
              @change="loadLeaderboard"
            >
              <option value="week">Minggu ini</option>
              <option value="month">Bulan ini</option>
            </select>
          </div>

          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-3">
            <div v-if="leaderboardError" class="text-2xs text-amber-700 p-3">{{ leaderboardError }}</div>
            <div v-else-if="!leaderboard" class="text-2xs text-slate-500 p-3">Memuat peringkat…</div>
            <!-- Warm empty state — matches the "warm empty" pattern used
                 across the app (Wave 1 UX). A brand-new school hits this
                 the very first time they open Peringkat; a plain "belum
                 ada" reads as broken. Icon + one-line reason + tiny nudge
                 keeps the guru oriented. -->
            <div v-else-if="leaderboard.data.length === 0" class="p-8 text-center">
              <div class="w-14 h-14 rounded-2xl bg-slate-100 text-slate-400 grid place-items-center mx-auto">
                <NavIcon name="trophy" :size="24" />
              </div>
              <p class="mt-3 text-sm font-bold text-slate-800">
                {{ cohortEmptyTitle }}
              </p>
              <p class="mt-1 text-2xs text-slate-500 leading-relaxed max-w-sm mx-auto">
                {{ cohortEmptyHint }}
              </p>
            </div>
            <div v-else class="space-y-1">
              <LeaderboardRow v-for="entry in leaderboard.data" :key="entry.teacher_id ?? entry.user_id ?? entry.position" :entry="entry" />
            </div>
          </div>

          <!-- Hide-name toggle -->
          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 flex items-center justify-between gap-3">
            <div>
              <p class="text-sm font-bold text-slate-900">Sembunyikan nama saya</p>
              <p class="text-2xs text-slate-500 mt-1">Kamu tetap bisa lihat peringkat + posisi sendiri; guru lain tidak lihat nama kamu di daftar.</p>
            </div>
            <button
              type="button"
              class="rounded-xl px-3 py-2 text-xs font-bold transition"
              :class="personal.hide_from_leaderboard
                ? 'bg-slate-800 text-white hover:bg-slate-700'
                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'"
              :disabled="savingSetting"
              @click="toggleHide"
            >
              {{ personal.hide_from_leaderboard ? 'Disembunyikan' : 'Tampil' }}
            </button>
          </div>
        </section>
      </template>
    </div>
  </div>
</template>

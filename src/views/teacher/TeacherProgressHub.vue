<!--
  TeacherProgressHub.vue — /teacher/prestasi

  3 tabs (Ringkasan / Badge / Peringkat) inside a shared shell.

  Data flow: on mount fetch /teacher/prestasi/saya once → drives
  Ringkasan + Badge tab. Peringkat tab lazy-loads its own data (with
  a cohort dropdown) so a teacher never pays that query cost on the
  initial paint of the hub.

  Every fetch is wrapped in try/catch — a 402 from a school losing
  the sub mid-session shows a warm empty state, not a stack trace.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import LevelXpRing from '@/components/feature/prestasi/LevelXpRing.vue';
import StreakFlameKpi from '@/components/feature/prestasi/StreakFlameKpi.vue';
import WeeklyPointsChart from '@/components/feature/prestasi/WeeklyPointsChart.vue';
import SignalSourceGrid from '@/components/feature/prestasi/SignalSourceGrid.vue';
import BadgeTile from '@/components/feature/prestasi/BadgeTile.vue';
import LeaderboardRow from '@/components/feature/prestasi/LeaderboardRow.vue';
import CohortPillGroup from '@/components/feature/prestasi/CohortPillGroup.vue';
import MilestoneHintCard from '@/components/feature/prestasi/MilestoneHintCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import {
  TeacherProgressService,
  type PersonalPayload,
  type LeaderboardResponse,
  type Cohort,
} from '@/services/teacher-progress.service';
import { useToast } from '@/composables/useToast';

const toast = useToast();

type Tab = 'ringkasan' | 'badge' | 'peringkat';
const activeTab = ref<Tab>('ringkasan');

const personal = ref<PersonalPayload | null>(null);
const personalError = ref<string | null>(null);

const leaderboard = ref<LeaderboardResponse | null>(null);
const leaderboardError = ref<string | null>(null);
const cohort = ref<Cohort>('guru_baru');
const periode = ref<'minggu' | 'bulan'>('minggu');

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
    personal.value = await TeacherProgressService.getPersonal();
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
      periode: periode.value,
      kelompok: cohort.value,
    });
  } catch (e: any) {
    leaderboardError.value = e?.response?.status === 402
      ? 'Modul belum aktif — peringkat tidak tersedia.'
      : 'Gagal memuat peringkat.';
  }
}

async function toggleHide() {
  if (!personal.value) return;
  const nextValue = !personal.value.sembunyi_dari_peringkat;
  savingSetting.value = true;
  try {
    const res = await TeacherProgressService.updateSetting({ sembunyi_dari_peringkat: nextValue });
    personal.value.sembunyi_dari_peringkat = res.sembunyi_dari_peringkat;
    toast.success(res.sembunyi_dari_peringkat ? 'Nama disembunyikan dari peringkat.' : 'Nama tampil di peringkat.');
  } catch {
    toast.error('Gagal menyimpan pengaturan. Coba lagi.');
  } finally {
    savingSetting.value = false;
  }
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

// Choose which cohorts to show in the switcher — hide staf option
// for teacher-shaped users; keep all otherwise.
const availableCohorts = computed<Cohort[]>(() => ['guru_baru', 'guru_mapel', 'wali_kelas']);

// Empty-state copy for the Peringkat tab — cohort-aware so a guru
// baru sees a welcoming "kamu pertama" nudge and a wali kelas sees
// a message oriented to their own week's activity. Keeps the plain
// "belum ada" bare-string out of the UI (Wave 1 warm-empty pattern).
const cohortEmptyTitle = computed<string>(() => {
  if (cohort.value === 'guru_baru') return 'Belum ada peringkat minggu ini';
  if (cohort.value === 'wali_kelas') return 'Belum ada wali kelas aktif minggu ini';
  return 'Belum ada guru mapel aktif minggu ini';
});

const cohortEmptyHint = computed<string>(() => {
  if (cohort.value === 'guru_baru') {
    return 'Absen tepat waktu besok pagi — kamu bisa jadi orang pertama yang tampil di sini.';
  }
  if (periode.value === 'bulan') {
    return 'Coba lihat "Minggu ini" — periode bulanan baru mulai jalan begitu ada aktivitas cukup.';
  }
  return 'Peringkat dihitung dari poin minggu ini. Setelah kamu atau rekan sekelompok absen tepat waktu, peringkat akan otomatis tampil.';
});

function switchTab(tab: Tab) {
  activeTab.value = tab;
  if (tab === 'peringkat' && !leaderboard.value) {
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

    <div class="px-4 sm:px-6 -mt-6 relative z-10 space-y-6 max-w-4xl mx-auto">
      <!-- Empty / error state — full-width warm card. -->
      <div
        v-if="personalError"
        class="rounded-2xl p-6 bg-amber-50 border border-amber-200 text-amber-800 flex items-start gap-3"
      >
        <NavIcon name="alert-circle" :size="20" />
        <p class="text-sm font-bold">{{ personalError }}</p>
      </div>

      <template v-else-if="personal">
        <!-- Tab strip -->
        <div class="inline-flex bg-slate-100 rounded-xl p-1">
          <button
            v-for="tab in ['ringkasan', 'badge', 'peringkat'] as Tab[]"
            :key="tab"
            type="button"
            class="px-4 py-2 rounded-lg text-sm font-bold capitalize transition"
            :class="activeTab === tab
              ? 'bg-white text-brand-cobalt shadow-sm'
              : 'text-slate-600'"
            @click="switchTab(tab)"
          >
            {{ tab }}
          </button>
        </div>

        <!-- ─── Ringkasan tab ─── -->
        <section v-if="activeTab === 'ringkasan'" class="space-y-6">
          <MilestoneHintCard
            :sources="personal.sumber_terbuka"
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
            <SignalSourceGrid :sources="personal.sumber_terbuka" />
          </div>
        </section>

        <!-- ─── Badge tab ─── -->
        <section v-else-if="activeTab === 'badge'" class="space-y-6">
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
        <section v-else-if="activeTab === 'peringkat'" class="space-y-4">
          <div class="flex flex-wrap items-center gap-3">
            <CohortPillGroup
              v-model="cohort"
              :available="availableCohorts"
              @update:modelValue="loadLeaderboard"
            />
            <select
              v-model="periode"
              class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-2xs font-bold text-slate-700"
              @change="loadLeaderboard"
            >
              <option value="minggu">Minggu ini</option>
              <option value="bulan">Bulan ini</option>
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
              <LeaderboardRow v-for="entry in leaderboard.data" :key="entry.teacher_id ?? entry.user_id ?? entry.posisi" :entry="entry" />
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
              :class="personal.sembunyi_dari_peringkat
                ? 'bg-slate-800 text-white hover:bg-slate-700'
                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'"
              :disabled="savingSetting"
              @click="toggleHide"
            >
              {{ personal.sembunyi_dari_peringkat ? 'Disembunyikan' : 'Tampil' }}
            </button>
          </div>
        </section>
      </template>
    </div>
  </div>
</template>

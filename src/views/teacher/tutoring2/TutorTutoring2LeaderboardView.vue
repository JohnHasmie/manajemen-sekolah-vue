<!--
  TutorTutoring2LeaderboardView.vue — the tutor-facing "Peringkat"
  screen (CLEAN-2 Phase 2 · greenfield replacement for
  `teacher/tutoring/TutorLeaderboardView.vue`).

  Route: /teacher/tutoring2/leaderboard
  Endpoints:
    GET /tutoring-v2/learning-groups                    — scope picker
    GET /tutoring-v2/learning-groups/{groupId}/leaderboard

  Rank rendering (podium 1..3 + rank 4..N table, gold/silver/bronze
  ring + medal tokens, `anyStreak` column gating) is copied verbatim
  from AdminTutoring2LeaderboardView so the SAME student renders
  identically whether an admin or their tutor is looking. If you change
  the ring/medal/score formatting here, change it there too.

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. ROW ANCHOR. v1 keyed rows by `student_id`; v2 rows are keyed by
     `enrollment_id` (FK to `bimbel_enrollments.id`) — matching the
     admin view. `avg_score` is a 0..100 normalised percentage with a
     server-side dense `rank`, so the view no longer derives rank from
     array position the way v1's `rankColor(idx)` did.

  2. DROPPED: the attendance column. v1's leaderboard row carried
     `attendance_rate`, which drove both the per-row subtitle
     ("82% kehadiran") and the "Partisipasi" KPI tile. The v2
     LeaderboardResponse has no attendance field at all
     (LeaderboardController returns enrollment/student/avg_score/
     assessments_taken/rank). Rather than fake it from a second
     endpoint, the subtitle now shows the student number and the KPI
     strip matches the admin one. See V2_GAPS.

  3. DROPPED: the "my groups only" filter. v1 narrowed the picker with
     `groups.filter(g => g.tutor_user_id === auth.user.id)` because the
     v1 group payload carried the tutor's USER id. v2's
     BimbelLearningGroup carries `tutor_id` (a `teachers.id`) and no v2
     route hands the client its own `teachers.id`, so there is nothing
     to compare against. The picker therefore lists every group the
     caller may view — the same behaviour the sibling tutor views
     already ship. See V2_GAPS.

  4. DROPPED: the "Per Program" tab. The screen was copied verbatim from
     AdminTutoring2LeaderboardView (see dec3437e), which brought the
     admin's program scope along with it — the v1 predecessor tutor
     screen never had one. It could not work here and must not:

       a. UNREACHABLE. `ProgramController::index` authorizes
          `tutoring.program.view`, which
          `PermissionCatalog::tutorTutoringDefaults()` does not grant.
          The only backfill migration
          (2026_08_07_140000_grant_program_view_to_parent_roles) is
          PARENT-only on tutoring-center tenants. So
          GET /tutoring-v2/programs 403s for a default tutor and the tab
          could never populate.

       b. GRANTING THE KEY WAS REJECTED. `LeaderboardController` scopes a
          program board by `e.program_id` alone, with NO tutor predicate,
          so a program board spans other tutors' groups. Granting the
          ability would open a cross-tutor data leak.

     Do not re-add the tab to "fix" the 403.

  The Kelompok scope chip opens a <FilterFacetPickerModal>, the same
  per-facet picker the admin twin and the Kelompok Belajar screen use. It
  previously CYCLED one entry per click (`pickNextScope()` advanced by
  modulo), which is tolerable at 3 kelompok and unreachable at 30 — and
  every click re-fired the leaderboard endpoint on the way past.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { LeaderboardRow } from '@/types/tutoring2/leaderboard';

const { t } = useI18n();

const groupId = ref<string>('');

const groupOptions = ref<Array<{ id: string; name: string }>>([]);
const scopeLoaded = ref(false);

// Visibility of the per-facet scope picker.
const showScopePicker = ref(false);

/**
 * Kelompok, fetched once so the scope chip can auto-select the first
 * entry — otherwise the screen renders an "empty" state that is really
 * just "nothing picked yet".
 *
 * The rejection is SWALLOWED on purpose, and that is load-bearing: this
 * runs INSIDE the <AsyncView> loader, so an error escaping here puts the
 * whole page into its error state. A tutor whose kelompok list is
 * ability-gated off should get the ordinary empty board and a disabled
 * chip, not a red page.
 *
 * That property arrived with the scope picker as `Promise.allSettled`
 * over [listGroups, listPrograms] — it had to be tolerant because the
 * two lists were independent and either could 403 on its own. The
 * program scope is gone (header note 4), leaving ONE promise, and
 * `allSettled` over a single promise is just a settled-tuple ceremony
 * around a try/catch. Same contract, less machinery.
 *
 * `scopeLoaded` is latched only on success, so an <AsyncView> retry can
 * still recover a transient failure. A `finally` would latch it either
 * way and make the first failure permanent for the life of the
 * component.
 */
async function loadScopeOptions() {
  if (scopeLoaded.value) return;
  let items: Array<{ id: string; name: string }>;
  try {
    const res = await TutoringBimbelService.listGroups({ per_page: 50 });
    items = res.items.map((it) => ({ id: it.id, name: it.name }));
  } catch {
    return;
  }
  groupOptions.value = items;
  if (!groupId.value && groupOptions.value.length > 0) {
    groupId.value = groupOptions.value[0].id;
  }
  scopeLoaded.value = true;
}

const { state, reload } = useDataRefresh(async () => {
  await loadScopeOptions();
  if (!groupId.value) return [] as LeaderboardRow[];
  const res = await TutoringLeaderboardService.getGroup(groupId.value, {
    limit: 100,
  });
  return res.items;
});

watch(groupId, () => reload());

// The pickable kelompok.
const scopeOptions = computed<FacetOption[]>(() =>
  groupOptions.value.map((o) => ({ key: o.id, label: o.name })),
);

const rows = computed<LeaderboardRow[]>(() =>
  state.value.status === 'content' ? (state.value.data as LeaderboardRow[]) : [],
);

const podium = computed(() => rows.value.filter((r) => r.rank <= 3));
const tail = computed(() => rows.value.filter((r) => r.rank > 3));

const anyStreak = computed(() =>
  rows.value.some((r) => typeof r.streak_days === 'number' && r.streak_days! > 0),
);

const kpiCards = computed<KpiCard[]>(() => {
  const items = rows.value;
  const withScore = items.filter((r) => r.assessments_taken > 0);
  const avg =
    withScore.length > 0
      ? withScore.reduce((s, r) => s + r.avg_score, 0) / withScore.length
      : 0;
  const top = items[0];
  const median =
    items.length > 0
      ? items[Math.min(items.length - 1, Math.floor(items.length / 2))].avg_score
      : 0;
  return [
    {
      icon: 'users',
      label: t('tutoring2.tutor.leaderboard.kpiParticipants'),
      value: String(items.length),
    },
    {
      icon: 'bar-chart',
      label: t('tutoring2.tutor.leaderboard.kpiAverage'),
      value: formatScore(avg),
    },
    {
      icon: 'trophy',
      label: t('tutoring2.tutor.leaderboard.kpiTop'),
      value: top ? formatScore(top.avg_score) : '—',
      tone: 'amber',
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.tutor.leaderboard.kpiMedian'),
      value: formatScore(median),
    },
  ];
});

// Kept byte-identical to AdminTutoring2LeaderboardView.formatScore —
// the server rounds to 1 dp and both views mirror that on aggregates.
function formatScore(n: number): string {
  if (!Number.isFinite(n) || n <= 0) return '0';
  return (Math.round(n * 10) / 10).toFixed(1);
}

// Podium chrome — same gold / silver / bronze tokens as the admin view.
function podiumRingClass(rank: number): string {
  if (rank === 1) return 'ring-amber-400/60';
  if (rank === 2) return 'ring-slate-300';
  return 'ring-amber-700/50';
}
function podiumMedalClass(rank: number): string {
  if (rank === 1) return 'bg-amber-500 text-white';
  if (rank === 2) return 'bg-slate-400 text-white';
  return 'bg-amber-800 text-white';
}
function medalLabel(rank: number): string {
  return `#${rank}`;
}

function activeScopeLabel(): string {
  const hit = groupOptions.value.find((o) => o.id === groupId.value);
  return hit ? hit.name : t('tutoring2.common.notAvailable');
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.leaderboard.title')"
      :meta="
        state.status === 'content'
          ? t('tutoring2.tutor.leaderboard.meta', { count: rows.length })
          : t('tutoring2.common.loading')
      "
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <!-- Scope chip: opens the kelompok picker. The ONLY chip here —
             the board has exactly one scope. -->
        <AppFilterChip
          :label="t('tutoring2.common.group')"
          :value="activeScopeLabel()"
          icon-name="book"
          :active="true"
          :disabled="scopeOptions.length === 0"
          :title="
            scopeOptions.length === 0
              ? t('tutoring2.common.filterNoOptions')
              : undefined
          "
          @click="showScopePicker = true"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.tutor.leaderboard.emptyTitle')"
      :empty-description="t('tutoring2.tutor.leaderboard.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <!-- Podium: rank 1..3. Order 2-1-3 on desktop so the champion
             sits in the center; collapses to plain 1-2-3 on mobile. -->
        <div v-if="podium.length > 0" class="grid grid-cols-1 gap-3 md:grid-cols-3">
          <div
            v-for="row in podium"
            :key="row.enrollment_id"
            :class="[
              'rounded-3xl border border-slate-100 bg-white shadow-sm p-4 flex items-center gap-3 ring-2',
              podiumRingClass(row.rank),
              row.rank === 1 ? 'md:order-2' : row.rank === 2 ? 'md:order-1' : 'md:order-3',
            ]"
          >
            <div
              :class="[
                'flex-none w-12 h-12 rounded-2xl grid place-items-center font-bold text-lg',
                podiumMedalClass(row.rank),
              ]"
              :aria-label="medalLabel(row.rank)"
            >
              {{ row.rank }}
            </div>
            <div class="min-w-0 flex-1">
              <div class="font-bold text-slate-900 truncate">
                {{ row.student_name }}
              </div>
              <div class="text-2xs text-slate-500 truncate">
                {{ row.student_number ?? '—' }}
              </div>
              <div v-if="anyStreak" class="text-2xs text-amber-700 mt-1">
                {{
                  t('tutoring2.tutor.leaderboard.streak', {
                    days: row.streak_days ?? 0,
                  })
                }}
              </div>
            </div>
            <div class="text-right">
              <div class="text-lg font-bold text-slate-900">
                {{ formatScore(row.avg_score) }}
              </div>
              <div class="text-2xs text-slate-500">
                {{
                  t('tutoring2.common.metaAssessments', {
                    count: row.assessments_taken,
                  })
                }}
              </div>
            </div>
          </div>
        </div>

        <!-- Rank 4..N table -->
        <div
          v-if="tail.length > 0"
          class="rounded-3xl border border-slate-100 bg-white shadow-sm mt-4 overflow-x-auto"
        >
          <table class="w-full text-sm">
            <thead>
              <tr
                class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400"
              >
                <th class="px-4 py-3 font-bold w-16">
                  {{ t('tutoring2.tutor.leaderboard.colRank') }}
                </th>
                <th class="px-4 py-3 font-bold">
                  {{ t('tutoring2.common.name') }}
                </th>
                <th class="px-4 py-3 font-bold">
                  {{ t('tutoring2.tutor.leaderboard.colAverage') }}
                </th>
                <th class="px-4 py-3 font-bold">
                  {{ t('tutoring2.tutor.leaderboard.colAssessments') }}
                </th>
                <th v-if="anyStreak" class="px-4 py-3 font-bold">
                  {{ t('tutoring2.tutor.leaderboard.colStreak') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in tail"
                :key="row.enrollment_id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">#{{ row.rank }}</td>
                <td class="px-4 py-3 text-slate-700">
                  <div class="font-bold text-slate-900">{{ row.student_name }}</div>
                  <div class="text-2xs text-slate-500">
                    {{ row.student_number ?? '—' }}
                  </div>
                </td>
                <td class="px-4 py-3 text-slate-700">{{ formatScore(row.avg_score) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ row.assessments_taken }}</td>
                <td v-if="anyStreak" class="px-4 py-3 text-slate-600">
                  {{ row.streak_days ?? 0 }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>
  </div>

  <!-- Scope picker. It writes groupId; the watcher above does the
       reload, so nothing calls it here.
       The scope is REQUIRED (no kelompok = no board), hence no "Semua"
       reset row — that row could only ever blank the page. -->
  <FilterFacetPickerModal
    v-if="showScopePicker"
    :title="t('tutoring2.common.group')"
    :options="scopeOptions"
    :selected="groupId"
    hide-all-reset
    @close="showScopePicker = false"
    @apply="(v) => (groupId = v)"
  />
</template>

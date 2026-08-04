<!--
  AdminTutoring2LeaderboardView.vue — greenfield "Peringkat" screen.

  Two tabs:
    • Per Kelompok — /learning-groups/{groupId}/leaderboard
    • Per Program  — /programs/{programId}/leaderboard

  Same composition contract as the other admin/tutoring2 views:
  BrandPageHeader → KpiStripCards → PageFilterToolbar (tab chips +
  scope chip) → AsyncView → podium card (top-3) + rank 4..N table.

  MVP note: `streak_days` is not yet emitted by BE-21 — the type has
  it as optional. The podium/table hide the streak line/column when
  every row is missing it.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { LeaderboardRow } from '@/types/tutoring2/leaderboard';

const { t } = useI18n();

type Tab = 'group' | 'program';

const tab = ref<Tab>('group');
const groupId = ref<string>('');
const programId = ref<string>('');
const assessmentId = ref<string>(''); // '' = all published

// The list of pickable groups / programs is fetched once (cheap) so
// the scope chip can auto-select the first item if the admin never
// picked one — otherwise every tab switch would render an "empty"
// state that isn't really empty.
const groupOptions = ref<Array<{ id: string; name: string }>>([]);
const programOptions = ref<Array<{ id: string; name: string }>>([]);
const scopeLoaded = ref(false);

async function loadScopeOptions() {
  if (scopeLoaded.value) return;
  try {
    const [g, p] = await Promise.all([
      TutoringBimbelService.listGroups({ per_page: 50 }),
      TutoringBimbelService.listPrograms({ per_page: 50 }),
    ]);
    groupOptions.value = g.items.map((it) => ({ id: it.id, name: it.name }));
    programOptions.value = p.items.map((it) => ({ id: it.id, name: it.name }));
    if (!groupId.value && groupOptions.value.length > 0) {
      groupId.value = groupOptions.value[0].id;
    }
    if (!programId.value && programOptions.value.length > 0) {
      programId.value = programOptions.value[0].id;
    }
  } finally {
    scopeLoaded.value = true;
  }
}

const { state, reload } = useDataRefresh(async () => {
  await loadScopeOptions();
  const scope = tab.value === 'group' ? groupId.value : programId.value;
  if (!scope) return [] as LeaderboardRow[];
  const query = {
    assessment_id: assessmentId.value || undefined,
    limit: 100,
  };
  const res =
    tab.value === 'group'
      ? await TutoringLeaderboardService.getGroup(scope, query)
      : await TutoringLeaderboardService.getProgram(scope, query);
  return res.items;
});

watch([tab, groupId, programId, assessmentId], () => reload());
useAcademicYearWatcher(reload);

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
  const participants = items.length;
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
      label: t('tutoring2.admin.leaderboard.kpiParticipants'),
      value: String(participants),
    },
    {
      icon: 'bar-chart',
      label: t('tutoring2.admin.leaderboard.kpiAverage'),
      value: formatScore(avg),
    },
    {
      icon: 'trophy',
      label: t('tutoring2.admin.leaderboard.kpiTop'),
      value: top ? formatScore(top.avg_score) : '—',
    },
    {
      icon: 'circle-check',
      label: t('tutoring2.admin.leaderboard.kpiMedian'),
      value: formatScore(median),
    },
  ];
});

function formatScore(n: number): string {
  if (!Number.isFinite(n) || n <= 0) return '0';
  // Server rounds to 1 dp; mirror that on client aggregates.
  return (Math.round(n * 10) / 10).toFixed(1);
}

function truncateId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.length > 8 ? id.slice(0, 8) : id;
}

// Podium chrome: gold / silver / bronze color tokens.
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
  const list = tab.value === 'group' ? groupOptions.value : programOptions.value;
  const currentId = tab.value === 'group' ? groupId.value : programId.value;
  const hit = list.find((o) => o.id === currentId);
  return hit ? hit.name : t('tutoring2.common.notAvailable');
}

function pickNextScope() {
  const list = tab.value === 'group' ? groupOptions.value : programOptions.value;
  if (list.length === 0) return;
  const currentId = tab.value === 'group' ? groupId.value : programId.value;
  const idx = list.findIndex((o) => o.id === currentId);
  const next = list[(idx + 1) % list.length].id;
  if (tab.value === 'group') groupId.value = next;
  else programId.value = next;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.leaderboard.title')"
      :meta="
        state.status === 'content'
          ? t('tutoring2.admin.leaderboard.meta', { count: rows.length })
          : t('tutoring2.common.loading')
      "
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <!-- Tab chips: Per Kelompok vs Per Program -->
        <AppFilterChip
          :label="t('tutoring2.admin.leaderboard.tabLabel')"
          :value="
            tab === 'group'
              ? t('tutoring2.admin.leaderboard.tabGroup')
              : t('tutoring2.admin.leaderboard.tabProgram')
          "
          icon-name="users"
          :active="true"
          @click="tab = tab === 'group' ? 'program' : 'group'"
        />
        <!-- Scope chip: click to cycle to the next group / program -->
        <AppFilterChip
          :label="
            tab === 'group'
              ? t('tutoring2.common.group')
              : t('tutoring2.common.program')
          "
          :value="activeScopeLabel()"
          icon-name="book"
          :active="true"
          @click="pickNextScope()"
        />
        <!-- Optional narrow-to-one-assessment chip -->
        <AppFilterChip
          :label="t('tutoring2.admin.leaderboard.assessmentLabel')"
          :value="assessmentId ? truncateId(assessmentId) : t('tutoring2.common.all')"
          icon-name="clipboard-list"
          :active="!!assessmentId"
          @click="assessmentId = ''"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.leaderboard.emptyTitle')"
      :empty-description="t('tutoring2.admin.leaderboard.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <!-- Podium: rank 1..3, gold/silver/bronze rings. Order 2-1-3
             on desktop so the champion sits in the center; on mobile
             it collapses to a plain 1-2-3 column. -->
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
                  t('tutoring2.admin.leaderboard.streak', {
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
                  t('tutoring2.admin.leaderboard.metaAssessments', {
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
          class="rounded-3xl border border-slate-100 bg-white shadow-sm mt-4"
        >
          <table class="w-full text-sm">
            <thead>
              <tr
                class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400"
              >
                <th class="px-4 py-3 font-bold w-16">
                  {{ t('tutoring2.admin.leaderboard.colRank') }}
                </th>
                <th class="px-4 py-3 font-bold">
                  {{ t('tutoring2.common.name') }}
                </th>
                <th class="px-4 py-3 font-bold">
                  {{ t('tutoring2.admin.leaderboard.colAverage') }}
                </th>
                <th class="px-4 py-3 font-bold">
                  {{ t('tutoring2.admin.leaderboard.colAssessments') }}
                </th>
                <th v-if="anyStreak" class="px-4 py-3 font-bold">
                  {{ t('tutoring2.admin.leaderboard.colStreak') }}
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
</template>

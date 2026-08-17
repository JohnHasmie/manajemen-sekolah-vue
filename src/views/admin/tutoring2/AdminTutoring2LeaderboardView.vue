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

  The Kelompok/Program scope chip and the Penilaian chip each open a
  <FilterFacetPickerModal> — the same per-facet picker the Kelompok
  Belajar screen uses. The scope chip previously CYCLED one entry per
  click (fine at 3 groups, unusable at 30) and the Penilaian chip was
  inert: its handler only ever reset `assessmentId` to '' and no list
  of assessments was loaded anywhere in this file, so nothing could
  ever set it. It also rendered a raw id fragment for a state that was
  unreachable.
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
import {
  TutoringBimbelService,
  type BimbelAssessment,
} from '@/services/tutoring-bimbel.service';
import type { LeaderboardRow } from '@/types/tutoring2/leaderboard';

const { t } = useI18n();

type Tab = 'group' | 'program';

/** A pickable leaderboard scope. `program_id` is carried for GROUPS
 *  only — it is what scopes the assessment list below. */
interface ScopeOption {
  id: string;
  name: string;
  program_id?: string;
}

const tab = ref<Tab>('group');
const groupId = ref<string>('');
const programId = ref<string>('');
const assessmentId = ref<string>(''); // '' = all published

// The list of pickable groups / programs is fetched once (cheap) so
// the scope chip can auto-select the first item if the admin never
// picked one — otherwise every tab switch would render an "empty"
// state that isn't really empty.
const groupOptions = ref<ScopeOption[]>([]);
const programOptions = ref<ScopeOption[]>([]);
const scopeLoaded = ref(false);

/** Published assessments the CURRENT scope can be ranked on. */
const assessments = ref<BimbelAssessment[]>([]);

// Per-facet picker visibility.
const showScopePicker = ref(false);
const showAssessmentPicker = ref(false);

/**
 * Groups + programs, tolerantly: the two lists are independent, so one
 * endpoint failing (or being ability-gated off) must not blank the
 * other chip — and must not take the whole page to its error state,
 * which is what the previous `Promise.all` did from inside the loader.
 *
 * `scopeLoaded` is only latched when BOTH settled without rejecting,
 * so an <AsyncView> retry can still recover a transient failure.
 */
async function loadScopeOptions() {
  if (scopeLoaded.value) return;
  const [g, p] = await Promise.allSettled([
    TutoringBimbelService.listGroups({ per_page: 200 }),
    TutoringBimbelService.listPrograms({ per_page: 200 }),
  ]);
  if (g.status === 'fulfilled') {
    groupOptions.value = g.value.items.map((it) => ({
      id: it.id,
      name: it.name,
      program_id: it.program_id,
    }));
  }
  if (p.status === 'fulfilled') {
    programOptions.value = p.value.items.map((it) => ({
      id: it.id,
      name: it.name,
    }));
  }
  if (!groupId.value && groupOptions.value.length > 0) {
    groupId.value = groupOptions.value[0].id;
  }
  if (!programId.value && programOptions.value.length > 0) {
    programId.value = programOptions.value[0].id;
  }
  if (g.status === 'fulfilled' && p.status === 'fulfilled') {
    scopeLoaded.value = true;
  }
}

/**
 * The Penilaian options for the scope that is currently selected —
 * never every assessment in the tenant.
 *
 * `published: true` because the leaderboard aggregates scores only
 * where `bimbel_assessments.published_at IS NOT NULL`; a draft in the
 * picker would be a control that reliably returns an empty board.
 *
 * Per PROGRAM the narrowing is exact (`program_id`). Per KELOMPOK it
 * cannot be, because the endpoint scopes by the ENROLLMENT's group
 * while a program-wide assessment (`learning_group_id` null) is still
 * scored for that group's students. Filtering on `learning_group_id`
 * alone would silently drop those, so we ask for the group's PROGRAM
 * and keep the rows that belong to this group or to no group at all —
 * i.e. exactly the set that can produce rows here, with the sibling
 * groups' own assessments left out.
 */
async function loadAssessmentOptions() {
  const scopeId = tab.value === 'group' ? groupId.value : programId.value;
  if (!scopeId) {
    assessments.value = [];
    return;
  }
  try {
    if (tab.value === 'program') {
      const { items } = await TutoringBimbelService.listAssessments({
        per_page: 200,
        published: true,
        program_id: scopeId,
      });
      assessments.value = items;
      return;
    }
    const group = groupOptions.value.find((o) => o.id === scopeId);
    if (!group?.program_id) {
      // Group list still in flight / row archived away: the group-only
      // filter is narrower than we'd like but never wrong.
      const { items } = await TutoringBimbelService.listAssessments({
        per_page: 200,
        published: true,
        learning_group_id: scopeId,
      });
      assessments.value = items;
      return;
    }
    const { items } = await TutoringBimbelService.listAssessments({
      per_page: 200,
      published: true,
      program_id: group.program_id,
    });
    assessments.value = items.filter(
      (a) => !a.learning_group_id || a.learning_group_id === scopeId,
    );
  } catch {
    // One dead endpoint disables this chip only — the scope chip and
    // the board itself stay usable.
    assessments.value = [];
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

/**
 * A scope change re-scopes the Penilaian list. The picked assessment
 * is dropped with it: an assessment belongs to ONE group/program, so
 * carrying it across would query the new board through a filter that
 * cannot match — an empty leaderboard under an active-looking chip.
 *
 * Clearing it here (rather than after the refetch lands) keeps this to
 * a single reload: both refs change inside one flush, so the watcher
 * below still fires once.
 */
watch([tab, groupId, programId], () => {
  assessmentId.value = '';
  void loadAssessmentOptions();
});

watch([tab, groupId, programId, assessmentId], () => reload());

const scopeOptions = computed<FacetOption[]>(() =>
  (tab.value === 'group' ? groupOptions.value : programOptions.value).map(
    (o) => ({ key: o.id, label: o.name }),
  ),
);

const assessmentOptions = computed<FacetOption[]>(() =>
  assessments.value.map((a) => ({
    key: a.id,
    label: a.title,
    meta:
      [a.kind_label ?? a.kind, formatShortDate(a.assessment_date)]
        .filter((part) => part && part !== '—')
        .join(' · ') || undefined,
  })),
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

/**
 * Last-resort label for an id whose row is not in the loaded list —
 * options still in flight, or the row archived away. Ugly but honest;
 * "—" on a chip that is visibly ACTIVE would read as "no filter", which
 * is the failure this toolbar just came out of.
 */
function truncateId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.length > 8 ? id.slice(0, 8) : id;
}

function formatShortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
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

function applyScope(id: string) {
  if (tab.value === 'group') groupId.value = id;
  else programId.value = id;
}

/** What the Penilaian chip reads: the assessment's TITLE, or "Semua"
 *  for the all-published default. Never a raw id. */
function assessmentChipValue(): string {
  if (!assessmentId.value) return t('tutoring2.common.all');
  return (
    assessments.value.find((a) => a.id === assessmentId.value)?.title ??
    truncateId(assessmentId.value)
  );
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
        <!-- Scope chip: opens the group / program picker -->
        <AppFilterChip
          :label="
            tab === 'group'
              ? t('tutoring2.common.group')
              : t('tutoring2.common.program')
          "
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
        <!-- Optional narrow-to-one-assessment chip -->
        <AppFilterChip
          :label="t('tutoring2.admin.leaderboard.assessmentLabel')"
          :value="assessmentChipValue()"
          icon-name="clipboard-list"
          :active="!!assessmentId"
          :disabled="assessmentOptions.length === 0"
          :title="
            assessmentOptions.length === 0
              ? t('tutoring2.common.filterNoOptions')
              : undefined
          "
          @click="showAssessmentPicker = true"
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

  <!-- Per-facet pickers. Each writes its ref; the watchers above do the
       reload, so nothing calls it here. -->
  <!-- The scope is REQUIRED (no group/program = no board), so this one
       has no "Semua" reset row. -->
  <FilterFacetPickerModal
    v-if="showScopePicker"
    :title="
      tab === 'group'
        ? t('tutoring2.common.group')
        : t('tutoring2.common.program')
    "
    :options="scopeOptions"
    :selected="tab === 'group' ? groupId : programId"
    hide-all-reset
    @close="showScopePicker = false"
    @apply="(v) => applyScope(v)"
  />
  <FilterFacetPickerModal
    v-if="showAssessmentPicker"
    :title="t('tutoring2.admin.leaderboard.assessmentLabel')"
    :subtitle="activeScopeLabel()"
    :options="assessmentOptions"
    :selected="assessmentId"
    :all-label="t('tutoring2.common.all')"
    @close="showAssessmentPicker = false"
    @apply="(v) => { assessmentId = v; }"
  />
</template>

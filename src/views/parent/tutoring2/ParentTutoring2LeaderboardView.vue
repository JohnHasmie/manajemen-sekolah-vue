<!--
  ParentTutoring2LeaderboardView.vue — the wali's view of one child's
  standing (CLEAN-2 Phase 2 · greenfield replacement for the legacy
  `parent/tutoring/ParentLeaderboardView.vue`).

  Route: /parent/tutoring2/leaderboard/:studentId
  Endpoints (all `/tutoring-v2/*`):
    GET /tutoring-v2/enrollments?student_id=                 — scope options
    GET /tutoring-v2/learning-groups/{groupId}/leaderboard   — per-group rank
    GET /tutoring-v2/programs/{programId}/leaderboard        — per-program rank

  Child scope: `:studentId` route param, same mechanism as every other
  parent/tutoring2 view. The child's groups/programs come from their own
  enrollments (the wali-readable `tutoring.enrollment.view_own` path) —
  no admin-only group index is touched.

  Visual contract: podium (rank 1..3) + rank-4..N table are kept
  structurally identical to AdminTutoring2LeaderboardView so the same
  ranking reads the same way to staff and to a parent. `formatScore`,
  `podiumRingClass` and `podiumMedalClass` are deliberate copies of that
  view's helpers — if you retune the medal palette there, retune it here.
  The only parent-specific addition is the "anak saya" highlight card and
  the `isChild` row emphasis.

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. v1 discovered the child's groups through
     `GET /tutoring/students/{id}/parent-class-meta`
     (TutoringService.getWaliClassMeta). v2 has no such route; the group
     list is derived from `/tutoring-v2/enrollments?student_id=` instead,
     which is the same information minus the legacy per-group attendance /
     next-session / unread-announcement roll-up. Those extra fields are a
     genuine v2 gap — see V2_GAPS in the MR description.
  2. The v1 leaderboard score was a COMPOSITE (0.5 × attendance + 0.5 ×
     score). BE-21 is pure score: `AVG(score / max_score * 100)` over
     PUBLISHED, GRADED assessments, dense-ranked. So the numbers here will
     legitimately differ from the legacy screen. The legacy "X dari 24
     sesi" line derived from `attendance_rate` is NOT ported because v2's
     leaderboard row carries no attendance at all; it shows
     `assessments_taken` instead, which is what the row actually averages.
  3. The legacy per-row "+2 / -1" movement delta was FABRICATED
     client-side (`const delta = isMe ? 2 : cycle === 0 ? 1 : …`) — the v1
     API never returned a delta either. It is dropped rather than
     re-invented. Restoring it needs a backend route that snapshots
     historical ranks (e.g. `GET /tutoring-v2/learning-groups/{id}/
     leaderboard/history`).
  4. v2 adds a per-PROGRAM roll-up the legacy view never had; it is
     surfaced as a second tab.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { LeaderboardRow } from '@/types/tutoring2/leaderboard';

const { t } = useI18n();
const route = useRoute();

const studentId = String(route.params.studentId ?? '');

type Tab = 'group' | 'program';

const tab = ref<Tab>('group');
const groupId = ref('');
const programId = ref('');

interface ScopeOption {
  id: string;
  name: string;
}

// Scope options are derived once from the child's enrollments. Kept in
// refs (not in the AsyncView payload) so switching tabs doesn't refetch
// them — mirrors `loadScopeOptions` in AdminTutoring2LeaderboardView.
const groupOptions = ref<ScopeOption[]>([]);
const programOptions = ref<ScopeOption[]>([]);
const scopeLoaded = ref(false);

async function loadScopeOptions() {
  if (scopeLoaded.value || !studentId) return;
  const { items } = await TutoringBimbelService.listEnrollments({
    student_id: studentId,
    per_page: 100,
  });
  const groups = new Map<string, ScopeOption>();
  const programs = new Map<string, ScopeOption>();
  for (const e of items) {
    if (e.learning_group_id) {
      groups.set(e.learning_group_id, {
        id: e.learning_group_id,
        name: e.learning_group_name ?? `${t('tutoring2.common.groupPrefix')} ${e.learning_group_id.slice(0, 8)}`,
      });
    }
    programs.set(e.program_id, {
      id: e.program_id,
      name: e.program_name ?? `${t('tutoring2.common.program')} ${e.program_id.slice(0, 8)}`,
    });
  }
  groupOptions.value = [...groups.values()];
  programOptions.value = [...programs.values()];
  if (!groupId.value && groupOptions.value.length > 0) {
    groupId.value = groupOptions.value[0].id;
  }
  if (!programId.value && programOptions.value.length > 0) {
    programId.value = programOptions.value[0].id;
  }
  scopeLoaded.value = true;
}

const { state, reload } = useDataRefresh<LeaderboardRow[]>(async () => {
  await loadScopeOptions();
  const scope = tab.value === 'group' ? groupId.value : programId.value;
  if (!scope) return [];
  const res =
    tab.value === 'group'
      ? await TutoringLeaderboardService.getGroup(scope, { limit: 100 })
      : await TutoringLeaderboardService.getProgram(scope, { limit: 100 });
  return res.items;
});

watch([tab, groupId, programId], () => {
  void reload();
});

const rows = computed<LeaderboardRow[]>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as LeaderboardRow[] | undefined) ?? [])
    : [],
);

const podium = computed(() => rows.value.filter((r) => r.rank <= 3));
const tail = computed(() => rows.value.filter((r) => r.rank > 3));

// ── The child's own row ──────────────────────────────────────────
const childRow = computed<LeaderboardRow | null>(
  () => rows.value.find((r) => r.student_id === studentId) ?? null,
);

function isChild(row: LeaderboardRow): boolean {
  return row.student_id === studentId;
}

/**
 * Points to the next rank up, or null when the child is already #1 (or
 * absent from the board). Computed from real `avg_score` values — the
 * legacy view's movement delta was invented and is not reproduced.
 */
const gapToNextRank = computed<number | null>(() => {
  const me = childRow.value;
  if (!me || me.rank <= 1) return null;
  const above = rows.value
    .filter((r) => r.rank < me.rank)
    .reduce<LeaderboardRow | null>(
      (best, r) => (best === null || r.rank > best.rank ? r : best),
      null,
    );
  if (!above) return null;
  const diff = above.avg_score - me.avg_score;
  return diff > 0 ? Math.round(diff * 10) / 10 : null;
});

// ── KPIs ─────────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const me = childRow.value;
  const scored = rows.value.filter((r) => r.assessments_taken > 0);
  const boardAverage =
    scored.length > 0
      ? scored.reduce((sum, r) => sum + r.avg_score, 0) / scored.length
      : 0;
  return [
    {
      icon: 'trophy',
      label: t('tutoring2.parent.leaderboard.kpiRank'),
      value: me ? `#${me.rank}` : '—',
      tone: 'amber',
      accented: true,
    },
    {
      icon: 'chart-bar',
      label: t('tutoring2.parent.leaderboard.kpiScore'),
      value: me ? formatScore(me.avg_score) : '—',
      tone: 'brand',
    },
    {
      icon: 'users',
      label: t('tutoring2.parent.leaderboard.kpiBoardAverage'),
      value: formatScore(boardAverage),
    },
    {
      icon: 'clipboard-list',
      label: t('tutoring2.parent.leaderboard.kpiAssessments'),
      value: String(me?.assessments_taken ?? 0),
      tone: 'green',
    },
  ];
});

const metaLabel = computed(() =>
  state.value.status === 'loading'
    ? t('tutoring2.common.loading')
    : t('tutoring2.parent.leaderboard.meta', {
        scope: activeScopeLabel(),
        count: rows.value.length,
      }),
);

// ── Scope chips ──────────────────────────────────────────────────
function activeScopeLabel(): string {
  const list = tab.value === 'group' ? groupOptions.value : programOptions.value;
  const currentId = tab.value === 'group' ? groupId.value : programId.value;
  return list.find((o) => o.id === currentId)?.name ?? t('tutoring2.common.notAvailable');
}

function cycleScope() {
  const list = tab.value === 'group' ? groupOptions.value : programOptions.value;
  if (list.length === 0) return;
  const currentId = tab.value === 'group' ? groupId.value : programId.value;
  const idx = list.findIndex((o) => o.id === currentId);
  const next = list[(idx + 1) % list.length].id;
  if (tab.value === 'group') groupId.value = next;
  else programId.value = next;
}

// ── Formatting — kept identical to AdminTutoring2LeaderboardView ──
function formatScore(n: number): string {
  if (!Number.isFinite(n) || n <= 0) return '0';
  // Server rounds to 1 dp; mirror that on client aggregates.
  return (Math.round(n * 10) / 10).toFixed(1);
}

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
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.leaderboard.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.parent.leaderboard.tabLabel')"
          :value="
            tab === 'group'
              ? t('tutoring2.parent.leaderboard.tabGroup')
              : t('tutoring2.parent.leaderboard.tabProgram')
          "
          icon-name="users"
          :active="true"
          @click="tab = tab === 'group' ? 'program' : 'group'"
        />
        <AppFilterChip
          :label="tab === 'group' ? t('tutoring2.common.group') : t('tutoring2.common.program')"
          :value="activeScopeLabel()"
          icon-name="book"
          :active="true"
          @click="cycleScope()"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="4"
      :empty-title="t('tutoring2.parent.leaderboard.emptyTitle')"
      :empty-description="t('tutoring2.parent.leaderboard.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <!-- "Anak saya" highlight — the one thing the admin view has no
             equivalent for. Hidden entirely when the child has no graded
             assessment on this scope, rather than showing a fake #0. -->
        <div
          v-if="childRow"
          class="rounded-3xl border border-brand-azure/20 bg-brand-azure/5 p-4"
        >
          <p class="text-2xs font-bold uppercase tracking-wide text-brand-azure">
            {{ t('tutoring2.parent.leaderboard.childLabel', { name: childRow.student_name }) }}
          </p>
          <div class="mt-1 flex items-end justify-between gap-3">
            <div>
              <p class="text-3xl font-black leading-none text-brand-azure">
                #{{ childRow.rank }}
                <span class="text-sm font-normal text-brand-azure/70">
                  {{ t('tutoring2.parent.leaderboard.ofTotal', { total: rows.length }) }}
                </span>
              </p>
              <p v-if="gapToNextRank !== null" class="mt-1 text-2xs text-brand-azure/80">
                {{
                  t('tutoring2.parent.leaderboard.gapToNext', {
                    rank: childRow.rank - 1,
                    diff: gapToNextRank,
                  })
                }}
              </p>
            </div>
            <div class="text-right">
              <p class="text-2xs uppercase tracking-wide text-brand-azure/70">
                {{ t('tutoring2.parent.leaderboard.kpiScore') }}
              </p>
              <p class="text-xl font-black leading-tight text-brand-azure">
                {{ formatScore(childRow.avg_score) }}
              </p>
              <p class="text-2xs text-brand-azure/80">
                {{
                  t('tutoring2.parent.leaderboard.metaAssessments', {
                    count: childRow.assessments_taken,
                  })
                }}
              </p>
            </div>
          </div>
        </div>

        <!-- Podium: rank 1..3 (2-1-3 on desktop so #1 sits centre). -->
        <div v-if="podium.length > 0" class="mt-4 grid grid-cols-1 gap-3 md:grid-cols-3">
          <div
            v-for="row in podium"
            :key="row.enrollment_id"
            :class="[
              'flex items-center gap-3 rounded-3xl border border-slate-100 bg-white p-4 shadow-sm ring-2',
              podiumRingClass(row.rank),
              row.rank === 1 ? 'md:order-2' : row.rank === 2 ? 'md:order-1' : 'md:order-3',
            ]"
          >
            <div
              :class="[
                'grid h-12 w-12 flex-none place-items-center rounded-2xl text-lg font-bold',
                podiumMedalClass(row.rank),
              ]"
            >
              {{ row.rank }}
            </div>
            <div class="min-w-0 flex-1">
              <div class="truncate font-bold text-slate-900">
                {{ row.student_name }}
                <span
                  v-if="isChild(row)"
                  class="ml-1 rounded-full bg-brand-azure px-1.5 py-px align-middle text-3xs font-bold text-white"
                >
                  {{ t('tutoring2.parent.leaderboard.childBadge') }}
                </span>
              </div>
              <div class="truncate text-2xs text-slate-500">
                {{ row.student_number ?? '—' }}
              </div>
            </div>
            <div class="text-right">
              <div class="text-lg font-bold text-slate-900">
                {{ formatScore(row.avg_score) }}
              </div>
              <div class="text-2xs text-slate-500">
                {{
                  t('tutoring2.parent.leaderboard.metaAssessments', {
                    count: row.assessments_taken,
                  })
                }}
              </div>
            </div>
          </div>
        </div>

        <!-- Rank 4..N -->
        <div
          v-if="tail.length > 0"
          class="mt-4 rounded-3xl border border-slate-100 bg-white shadow-sm"
        >
          <table class="w-full text-sm">
            <thead>
              <tr
                class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400"
              >
                <th class="w-16 px-4 py-3 font-bold">
                  {{ t('tutoring2.parent.leaderboard.colRank') }}
                </th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.name') }}</th>
                <th class="px-4 py-3 font-bold">
                  {{ t('tutoring2.parent.leaderboard.colAverage') }}
                </th>
                <th class="px-4 py-3 font-bold">
                  {{ t('tutoring2.parent.leaderboard.colAssessments') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in tail"
                :key="row.enrollment_id"
                :class="[
                  'border-b border-slate-100 last:border-0',
                  isChild(row) ? 'bg-brand-azure/5' : 'hover:bg-slate-50',
                ]"
              >
                <td class="px-4 py-3 font-bold text-slate-900">#{{ row.rank }}</td>
                <td class="px-4 py-3 text-slate-700">
                  <div class="font-bold text-slate-900">
                    {{ row.student_name }}
                    <span
                      v-if="isChild(row)"
                      class="ml-1 rounded-full bg-brand-azure px-1.5 py-px align-middle text-3xs font-bold text-white"
                    >
                      {{ t('tutoring2.parent.leaderboard.childBadge') }}
                    </span>
                  </div>
                  <div class="text-2xs text-slate-500">{{ row.student_number ?? '—' }}</div>
                </td>
                <td class="px-4 py-3 text-slate-700">{{ formatScore(row.avg_score) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ row.assessments_taken }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

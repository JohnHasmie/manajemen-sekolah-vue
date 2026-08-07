<!--
  ParentTutoring2ProgressView.vue — one child's score trend (CLEAN-2
  Phase 2 · greenfield replacement for the legacy
  `parent/tutoring/ParentProgressView.vue`).

  Route: /parent/tutoring2/progress/:studentId
  Endpoints (all `/tutoring-v2/*`):
    GET /tutoring-v2/enrollments?student_id=          — child's programs
    GET /tutoring-v2/assessments?published=true       — wali-scoped, drafts hidden
    GET /tutoring-v2/assessments/{id}/scores          — wali-scoped rows
    GET /tutoring-v2/programs/{id}/leaderboard        — peer-average baseline

  Child scope: `:studentId` route param, same mechanism as every other
  parent/tutoring2 view.

  Distinct from ParentTutoring2ReportCardView (a rapor scaffold) — this
  page is the per-assessment score history, not a term report.

  ⚠️ DROP AND DOCUMENT — the legacy view's data source does not exist in v2.

    v1 read ONE aggregate route, `GET /tutoring/students/{id}/progress`
    (TutoringService.getProgress), which returned `{ summary.overall.average,
    trend: { [subjectName]: number[] } }`. There is NO progress route
    anywhere in the `Route::prefix('tutoring-v2')` group — checked the
    whole block. A backend `GET /tutoring-v2/students/{id}/progress`
    would restore the legacy shape in a single call.

    What is rebuilt here from routes that DO exist: the child's real
    per-assessment scores, normalised to a 0..100 percentage
    (`score / max_score * 100`, the same normalisation BE-21 uses), from
    the wali-readable assessments + scores pair. The chart plots those
    real points against `assessment_date` — nothing is stubbed.

    What is DROPPED, and why:
      • The legacy `STUB_CHILD` / `STUB_AVG` hardcoded arrays
        ([70,73,75,…]) that drew a fake ascending line whenever the API
        returned no trend. That was invented data presented as the
        child's progress; it is gone, and an honest "not enough graded
        assessments yet" note takes its place.
      • The legacy KPI strip's three permanently-"—" tiles (attendance,
        assignments, sessions/month). Those were never wired to anything.
        Attendance already has its own real screen
        (ParentTutoring2AttendanceView).
      • Per-MAPEL breakdown. Bimbel has no subject dimension —
        `bimbel_assessments` hangs off a PROGRAM, not a mata pelajaran.
        The filter is therefore per-program, which is the real axis.
      • The legacy per-period group-average SERIES. BE-21's leaderboard
        returns one overall average per participant, not a time series,
        so the peer baseline here is a single CONSTANT line labelled as
        such ("rata-rata peserta program"), computed from real
        leaderboard rows. It is deliberately NOT drawn as a fake curve.
        A per-period peer average needs a backend aggregate.

  PERFORMANCE NOTE: v2 has no bulk "scores for student X" route, so the
  score lookup costs one request per published assessment, capped at
  MAX_SCORE_LOOKUPS. A backend `GET /tutoring-v2/students/{id}/scores`
  would collapse it to one call.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();

const studentId = String(route.params.studentId ?? '');

/** See the PERFORMANCE NOTE in the file header. */
const MAX_SCORE_LOOKUPS = 40;

/** One graded assessment for this child. */
interface ScorePoint {
  assessmentId: string;
  title: string;
  programId: string;
  programName: string;
  /** `YYYY-MM-DD` or null when the tutor left the date blank. */
  date: string | null;
  score: number;
  maxScore: number;
  /** `score / maxScore * 100`, 1 dp — same normalisation as BE-21. */
  percent: number;
  /** Passing mark on the same 0..100 scale, when the assessment sets one. */
  kkmPercent: number | null;
}

interface ProgressPayload {
  points: ScorePoint[];
  programs: Array<{ id: string; name: string }>;
  /** programId → mean of every participant's overall average (0..100). */
  peerAverageByProgram: Record<string, number>;
}

const { state, reload } = useDataRefresh<ProgressPayload>(async () => {
  const empty: ProgressPayload = { points: [], programs: [], peerAverageByProgram: {} };
  if (!studentId) return empty;

  const { items: enrollments } = await TutoringBimbelService.listEnrollments({
    student_id: studentId,
    per_page: 100,
  });
  if (enrollments.length === 0) return empty;

  // Only THIS child's enrollment rows may claim a score — the backend
  // scopes `/scores` to every student the wali is linked to, which for a
  // multi-child wali is a superset.
  const ownEnrollmentIds = new Set(enrollments.map((e) => e.id));

  const programNameById = new Map<string, string>();
  for (const e of enrollments) {
    programNameById.set(
      e.program_id,
      e.program_name ?? `${t('tutoring2.common.program')} ${e.program_id.slice(0, 8)}`,
    );
  }

  // `published: true` is belt-and-braces — AssessmentController already
  // forces `published_at IS NOT NULL` for the wali's `_view_own` scope.
  const { items: assessments } = await TutoringBimbelService.listAssessments({
    published: true,
    per_page: 100,
  });
  const relevant = assessments
    .filter((a) => programNameById.has(a.program_id) && a.max_score > 0)
    .slice(0, MAX_SCORE_LOOKUPS);

  const scoreLists = await Promise.all(
    relevant.map((a) => TutoringBimbelService.listScores(a.id)),
  );

  const points: ScorePoint[] = [];
  relevant.forEach((a, i) => {
    const mine = scoreLists[i].items.find(
      (row) => ownEnrollmentIds.has(row.enrollment_id) && row.score != null,
    );
    if (!mine || mine.score == null) return;
    points.push({
      assessmentId: a.id,
      title: a.title,
      programId: a.program_id,
      programName: programNameById.get(a.program_id) ?? '—',
      date: a.assessment_date ?? null,
      score: mine.score,
      maxScore: a.max_score,
      percent: Math.round((mine.score / a.max_score) * 1000) / 10,
      kkmPercent:
        a.kkm != null ? Math.round((a.kkm / a.max_score) * 1000) / 10 : null,
    });
  });

  // Oldest → newest so the chart reads left-to-right. Undated rows sink
  // to the end (they can't be placed on a time axis).
  points.sort((x, y) => {
    if (x.date === null && y.date === null) return 0;
    if (x.date === null) return 1;
    if (y.date === null) return -1;
    return x.date.localeCompare(y.date);
  });

  // Peer baseline — real leaderboard rows, one constant per program.
  const programIds = [...programNameById.keys()];
  const boards = await Promise.all(
    programIds.map((id) => TutoringLeaderboardService.getProgram(id, { limit: 100 })),
  );
  const peerAverageByProgram: Record<string, number> = {};
  programIds.forEach((id, i) => {
    const scored = boards[i].items.filter((r) => r.assessments_taken > 0);
    if (scored.length === 0) return;
    peerAverageByProgram[id] =
      scored.reduce((sum, r) => sum + r.avg_score, 0) / scored.length;
  });

  return {
    points,
    programs: programIds.map((id) => ({
      id,
      name: programNameById.get(id) ?? id,
    })),
    peerAverageByProgram,
  };
});

const payload = computed<ProgressPayload | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as ProgressPayload | undefined) ?? null)
    : null,
);

const allPoints = computed<ScorePoint[]>(() => payload.value?.points ?? []);
const programs = computed(() => payload.value?.programs ?? []);

// ── Program filter ('' = every program) ──────────────────────────
const programFilter = ref('');

const visiblePoints = computed<ScorePoint[]>(() =>
  programFilter.value === ''
    ? allPoints.value
    : allPoints.value.filter((p) => p.programId === programFilter.value),
);

function cycleProgram() {
  const order = ['', ...programs.value.map((p) => p.id)];
  const i = order.indexOf(programFilter.value);
  programFilter.value = order[(i + 1) % order.length] ?? '';
}

const programChipValue = computed(() => {
  if (programFilter.value === '') return t('tutoring2.common.all');
  return (
    programs.value.find((p) => p.id === programFilter.value)?.name ??
    t('tutoring2.common.notAvailable')
  );
});

// ── KPIs — every tile is derived from real scores ────────────────
const averagePercent = computed<number | null>(() => {
  const list = visiblePoints.value;
  if (list.length === 0) return null;
  return list.reduce((sum, p) => sum + p.percent, 0) / list.length;
});

const kpiCards = computed<KpiCard[]>(() => {
  const list = visiblePoints.value;
  const highest = list.length > 0 ? Math.max(...list.map((p) => p.percent)) : null;
  const lowest = list.length > 0 ? Math.min(...list.map((p) => p.percent)) : null;
  return [
    {
      icon: 'chart-bar',
      label: t('tutoring2.parent.progress.kpiAverage'),
      value: formatPercent(averagePercent.value),
      tone: 'brand',
      accented: true,
    },
    {
      icon: 'award',
      label: t('tutoring2.parent.progress.kpiHighest'),
      value: formatPercent(highest),
      tone: 'green',
    },
    {
      icon: 'trending-down',
      label: t('tutoring2.parent.progress.kpiLowest'),
      value: formatPercent(lowest),
      tone: 'amber',
    },
    {
      icon: 'clipboard-list',
      label: t('tutoring2.parent.progress.kpiGraded'),
      value: String(list.length),
    },
  ];
});

const metaLabel = computed(() =>
  state.value.status === 'loading'
    ? t('tutoring2.common.loading')
    : t('tutoring2.parent.progress.meta', { count: visiblePoints.value.length }),
);

// ── Chart ────────────────────────────────────────────────────────
// Fixed 0..100 domain: every point is already a percentage, so an
// auto-scaled axis would make a 55 look like a 95 on a low-score run.
const CHART_WIDTH = 600;
const CHART_HEIGHT = 80;
const PLOT_LEFT = 20;
const PLOT_RIGHT = 580;
const PLOT_TOP = 8;
const PLOT_BOTTOM = 72;

/** Datable points only — an undated score can't sit on a time axis. */
const chartPoints = computed<ScorePoint[]>(() =>
  visiblePoints.value.filter((p) => p.date !== null),
);

const canRenderChart = computed(() => chartPoints.value.length >= 2);

function yFor(percent: number): number {
  const clamped = Math.min(100, Math.max(0, percent));
  return PLOT_BOTTOM - (clamped / 100) * (PLOT_BOTTOM - PLOT_TOP);
}

function xFor(index: number, total: number): number {
  if (total <= 1) return PLOT_LEFT;
  return PLOT_LEFT + (index * (PLOT_RIGHT - PLOT_LEFT)) / (total - 1);
}

const childPolyline = computed(() => {
  const list = chartPoints.value;
  return list
    .map((p, i) => `${xFor(i, list.length).toFixed(1)},${yFor(p.percent).toFixed(1)}`)
    .join(' ');
});

/**
 * Constant peer baseline for the current filter. With one program
 * selected it is that program's leaderboard mean; with "all" selected it
 * is the mean of the child's programs' means. Null when no leaderboard
 * row exists — the baseline is then simply not drawn, rather than faked.
 */
const peerAverage = computed<number | null>(() => {
  const map = payload.value?.peerAverageByProgram ?? {};
  if (programFilter.value !== '') return map[programFilter.value] ?? null;
  const values = Object.values(map);
  if (values.length === 0) return null;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
});

const peerBaselineY = computed<number | null>(() =>
  peerAverage.value === null ? null : yFor(peerAverage.value),
);

/** First / middle / last date, formatted in LOCAL time. */
const chartAxisLabels = computed<Array<{ x: number; label: string }>>(() => {
  const list = chartPoints.value;
  if (list.length === 0) return [];
  const indices = [...new Set([0, Math.floor((list.length - 1) / 2), list.length - 1])];
  return indices.map((i) => ({
    x: xFor(i, list.length),
    label: formatMonthLabel(list[i].date),
  }));
});

// ── Formatting ───────────────────────────────────────────────────
function formatPercent(value: number | null): string {
  if (value === null || !Number.isFinite(value)) return '—';
  return (Math.round(value * 10) / 10).toFixed(1);
}

/**
 * `YYYY-MM-DD` → "Agu 2026". Parsed from LOCAL date parts —
 * `new Date('2026-08-01')` is UTC midnight and renders as July for any
 * negative-offset viewer.
 */
function formatMonthLabel(ymd: string | null): string {
  if (!ymd) return '—';
  const [y, m] = ymd.split('-');
  if (!y || !m) return ymd;
  return new Date(Number(y), Number(m) - 1, 1).toLocaleDateString('id-ID', {
    month: 'short',
    year: 'numeric',
  });
}

function formatFullDate(ymd: string | null): string {
  if (!ymd) return t('tutoring2.common.notAvailable');
  const [y, m, d] = ymd.split('-');
  if (!y || !m || !d) return ymd;
  return new Date(Number(y), Number(m) - 1, Number(d)).toLocaleDateString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

/**
 * KKM-relative tone. `kkm` is the assessment's own passing mark, so this
 * is a real pass/fail signal rather than an invented grade band. With no
 * KKM set the row stays neutral — we do not guess a threshold.
 */
function scoreTone(point: ScorePoint): StatusBadgeTone {
  if (point.kkmPercent === null) return 'neutral';
  return point.percent >= point.kkmPercent ? 'success' : 'danger';
}

function scoreLabel(point: ScorePoint): string {
  if (point.kkmPercent === null) return t('tutoring2.parent.progress.noKkm');
  return point.percent >= point.kkmPercent
    ? t('tutoring2.parent.progress.passed')
    : t('tutoring2.parent.progress.belowKkm');
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.progress.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-if="programs.length > 1" :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.program')"
          :value="programChipValue"
          icon-name="book"
          :active="programFilter !== ''"
          @click="cycleProgram()"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.parent.progress.emptyTitle')"
      :empty-description="t('tutoring2.parent.progress.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <p
          v-if="visiblePoints.length === 0"
          class="rounded-3xl border border-slate-100 bg-white px-4 py-8 text-center text-sm text-slate-500 shadow-sm"
        >
          {{ t('tutoring2.parent.progress.noGradedYet') }}
        </p>

        <template v-else>
          <!-- Trend chart. Real points only; no stub series. -->
          <section class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
            <h2 class="text-sm font-bold text-slate-900">
              {{ t('tutoring2.parent.progress.chartTitle') }}
            </h2>

            <p v-if="!canRenderChart" class="mt-3 text-2xs text-slate-500">
              {{ t('tutoring2.parent.progress.chartNeedsMorePoints') }}
            </p>

            <template v-else>
              <svg
                :viewBox="`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`"
                preserveAspectRatio="none"
                class="mt-3 h-28 w-full"
                role="img"
                :aria-label="t('tutoring2.parent.progress.chartTitle')"
              >
                <!-- Peer baseline: a CONSTANT, not a series (see header). -->
                <line
                  v-if="peerBaselineY !== null"
                  :x1="PLOT_LEFT"
                  :x2="PLOT_RIGHT"
                  :y1="peerBaselineY"
                  :y2="peerBaselineY"
                  stroke="#94a3b8"
                  stroke-width="1"
                  stroke-dasharray="4,3"
                />
                <polyline
                  :points="childPolyline"
                  fill="none"
                  stroke="#185FA5"
                  stroke-width="2"
                />
                <text
                  v-for="(tick, i) in chartAxisLabels"
                  :key="i"
                  :x="tick.x"
                  :y="CHART_HEIGHT - 2"
                  font-size="9"
                  fill="#94a3b8"
                >
                  {{ tick.label }}
                </text>
              </svg>

              <div class="mt-2 flex flex-wrap justify-between gap-2 text-2xs text-slate-500">
                <span class="inline-flex items-center gap-1.5">
                  <span class="inline-block h-0.5 w-3 bg-[#185FA5]"></span>
                  {{ t('tutoring2.parent.progress.legendChild') }}
                </span>
                <span v-if="peerAverage !== null" class="inline-flex items-center gap-1.5">
                  <span class="inline-block h-0.5 w-3 bg-slate-400"></span>
                  {{
                    t('tutoring2.parent.progress.legendPeer', {
                      value: formatPercent(peerAverage),
                    })
                  }}
                </span>
              </div>
            </template>
          </section>

          <!-- Per-assessment rows (newest first — the inverse of the
               chart, which reads oldest → newest). -->
          <div class="mt-4 rounded-3xl border border-slate-100 bg-white shadow-sm">
            <ul class="divide-y divide-slate-100">
              <li
                v-for="point in [...visiblePoints].reverse()"
                :key="point.assessmentId"
                class="flex items-center gap-3 px-4 py-3"
              >
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-bold text-slate-900">{{ point.title }}</p>
                  <p class="truncate text-2xs text-slate-500">
                    {{ point.programName }}
                    <span class="mx-1 text-slate-300">·</span>
                    {{ formatFullDate(point.date) }}
                  </p>
                </div>
                <StatusBadge :label="scoreLabel(point)" :tone="scoreTone(point)" uppercase />
                <div class="w-16 flex-none text-right">
                  <p class="text-lg font-black leading-none text-brand-azure">
                    {{ point.score }}
                  </p>
                  <p class="mt-0.5 text-2xs text-slate-400">/ {{ point.maxScore }}</p>
                </div>
              </li>
            </ul>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>

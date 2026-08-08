<!--
  ParentTutoring2ProgressView.vue — one child's score trend (greenfield
  replacement for the legacy `parent/tutoring/ParentProgressView.vue`).

  Route: /parent/tutoring2/progress/:studentId
  Endpoint: GET /tutoring-v2/students/{id}/progress   — ONE call

  Child scope: `:studentId` route param, same mechanism as every other
  parent/tutoring2 view.

  Distinct from ParentTutoring2ReportCardView (a rapor scaffold) — this
  page is the per-assessment score history, not a term report.

  HISTORY — why this file used to look very different:

    v2 originally had no progress route, so this view rebuilt the payload
    in the browser: enrollments, then every assessment, then ONE scores
    call PER ASSESSMENT, capped at 40 lookups to stop it running away.
    The backend route now exists and returns the whole payload in two
    queries, with the publish gate applied server-side — so an unfinished
    mark cannot reach a wali even briefly.

    Everything the server sends is final. In particular:
      • `points` arrive oldest-first and already exclude drafts. Do not
        re-sort or re-filter for those reasons.
      • `kkm_percent` is ALREADY rescaled onto the 0..100 percentage
        scale. The raw `kkm` lives on the assessment's own scale (an
        assessment out of 200 has a KKM out of 200), so re-deriving it
        client-side is how pass/fail ends up rendered backwards.
      • `peer_average_by_program` is the mean across every participant's
        published scores — a finer baseline than the leaderboard
        average-of-averages it replaced, where one assessment counted as
        much as twenty.

  STILL NOT AVAILABLE, deliberately not faked:
    • A per-period peer average SERIES. The server returns one constant
      per programme, so the baseline is drawn as a single labelled line
      ("rata-rata peserta program"), never as an invented curve.
    • Per-MAPEL breakdown. Bimbel has no subject dimension —
      `bimbel_assessments` hang off a PROGRAM, not a mata pelajaran, so
      the filter is per-program, which is the real axis.

  Also gone for good, from the legacy view: the STUB_CHILD / STUB_AVG
  hardcoded arrays ([70,73,75,…]) that drew a fake ascending line
  whenever the API returned nothing. That was invented data presented as
  a real child's progress. An honest "not enough graded assessments yet"
  note takes its place.
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
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();

const studentId = String(route.params.studentId ?? '');

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
  /**
   * programId → mean percentage across every participant's PUBLISHED
   * scores in that programme (0..100), computed server-side.
   *
   * This is a finer baseline than the leaderboard average it replaces:
   * the leaderboard means an average-of-averages, so a participant with
   * one assessment counted as much as one with twenty.
   */
  peerAverageByProgram: Record<string, number>;
}

// `ProgressPayload | null` — see the note in the sibling Activities view.
// useDataRefresh's `isEmpty()` recognises only null/undefined/empty-array,
// so returning an object with zero points made AsyncView render its
// content branch over nothing instead of the empty state. That was true
// of this view before the endpoint swap too; fixed here while in the file.
const { state, reload } = useDataRefresh<ProgressPayload | null>(async () => {
  if (!studentId) return null;

  // ONE request. This used to fetch enrollments, then every assessment,
  // then one scores call PER ASSESSMENT — capped at 40 so it could not
  // run away. See the file header for what that cost.
  const progress = await TutoringStudentsService.getProgress(studentId);
  if (progress.points.length === 0) return null;

  return {
    // Already oldest-first and already filtered to published assessments
    // by the server, so neither is re-done here.
    points: progress.points
      // A point with no percent had max_score 0 — it cannot be placed on
      // a 0..100 axis, and the server sends null rather than guessing.
      .filter((p): p is typeof p & { percent: number } => p.percent !== null)
      .map((p) => ({
        assessmentId: p.assessment_id,
        title: p.title,
        programId: p.program_id,
        programName: p.program_name ?? t('tutoring2.common.notAvailable'),
        date: p.date,
        score: p.score,
        maxScore: p.max_score,
        percent: p.percent,
        // Already rescaled onto 0..100 by the server. Do NOT re-derive
        // from a raw kkm — the raw value is on the assessment's own
        // scale, and comparing it to a percent inverts pass/fail.
        kkmPercent: p.kkm_percent,
      })),
    programs: progress.programs,
    peerAverageByProgram: progress.peer_average_by_program,
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

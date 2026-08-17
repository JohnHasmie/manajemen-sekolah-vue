<!--
  ParentTutoring2AssessmentsView.vue — Wali grades for one child.

  Composition:
    1. BrandPageHeader (role="parent") — with meta line.
    2. KpiStripCards          — Rata-rata / Tertinggi / Dinilai / Peringkat.
    3. AsyncView              — rounded-3xl surface with divide-y rows.
    4. Primary Button block   — "Unduh rapor bimbel (PDF)".

  ── What this replaces ──

  The screen listed every published assessment in the TENANT and derived
  all of its numbers from `max_score`, which is the mark an assessment
  is out of — not a mark anyone scored:

      Rata-rata  = mean of max_score across assessments
      Tertinggi  = the largest max_score
      row cell   = `max_score / max_score`

  That last one rendered as "100 / 100" on every row, so a wali was
  shown their child scoring full marks on everything, including
  assessments the child had never sat.

  `GET /tutoring-v2/students/{id}/progress` has existed since BE-24 and
  answers exactly this screen: one point per PUBLISHED, SCORED
  assessment for THIS child, plus a summary. It applies the publish gate
  server-side, so an unfinished mark cannot reach a wali.

  ── What it no longer claims ──

  Rows are the child's graded assessments, so an assessment with no mark
  is absent rather than shown at full marks. `Peringkat` stays "—": rank
  needs the leaderboard, and this screen does not fetch it — an empty
  cell is honest where a number would not be.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type { ProgressPoint, StudentProgress } from '@/types/tutoring2/progress';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const studentId = String(route.params.studentId ?? '');

// ── Data ──────────────────────────────────────────────────────────
const { state, reload } = useDataRefresh<StudentProgress>(async () => {
  if (!studentId) {
    throw new Error('studentId is required');
  }
  return TutoringStudentsService.getProgress(studentId);
});
useAcademicYearWatcher(reload);

const progress = computed<StudentProgress | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value as { data?: StudentProgress }).data ?? null)
    : null,
);

/** The child's graded assessments, newest first. */
const points = computed<ProgressPoint[]>(() => {
  const list = progress.value?.points ?? [];
  // The server returns oldest-first for the trend line; a wali reading
  // a list wants the most recent mark at the top.
  return [...list].sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));
});

// ── KPIs ─────────────────────────────────────────────────────────
// Straight from the server's summary — real marks, not the values the
// assessments were out of.
const kpiCards = computed<KpiCard[]>(() => {
  const s = progress.value?.summary;
  const num = (n: number | null | undefined) =>
    n == null ? '—' : String(Math.round(n));
  return [
    {
      icon: 'chart-bar',
      label: t('tutoring2.parent.assessments.kpiAverage'),
      value: num(s?.average),
      tone: 'brand',
    },
    {
      icon: 'award',
      label: t('tutoring2.parent.assessments.kpiHighest'),
      value: num(s?.highest),
      tone: 'green',
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.parent.assessments.kpiCompleted'),
      // Graded, not "exists in the tenant".
      value: s == null ? '—' : String(s.graded_count),
    },
    {
      // Rank needs the leaderboard, which this screen does not call.
      // "—" is the honest answer; a number here would be invented.
      icon: 'star',
      label: t('tutoring2.parent.assessments.kpiRank'),
      value: '—',
      tone: 'violet',
    },
  ];
});

const metaLabel = computed(() => {
  if (state.value.status === 'loading') return t('tutoring2.common.loading');
  const s = progress.value?.summary;
  return t('tutoring2.parent.assessments.meta', {
    avg: s?.average == null ? '—' : String(Math.round(s.average)),
    count: s?.graded_count ?? points.value.length,
  });
});

// ── Helpers ──────────────────────────────────────────────────────
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

/**
 * Pass/fail against the assessment's OWN kkm when it has one. An
 * assessment with no threshold gets a neutral chip rather than being
 * judged against a number nobody set.
 */
function kkmTone(p: ProgressPoint): StatusBadgeTone {
  if (p.kkm_percent == null || p.percent == null) return 'neutral';
  return p.percent >= p.kkm_percent ? 'success' : 'danger';
}

function kkmLabel(p: ProgressPoint): string {
  if (p.kkm_percent == null || p.percent == null) {
    return t('tutoring2.common.noKkm');
  }
  return p.percent >= p.kkm_percent
    ? t('tutoring2.status.passed')
    : t('tutoring2.status.failed');
}

// ── Navigation ───────────────────────────────────────────────────
function openReportCard() {
  router.push({ name: 'parent.tutoring2.report-card', params: { studentId } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.assessments.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.parent.assessments.emptyTitle')"
      @retry="reload"
    >
      <template #default>
        <div
          class="rounded-3xl border border-slate-100 bg-white shadow-sm divide-y divide-slate-100"
        >
          <div
            v-for="p in points"
            :key="p.assessment_id"
            class="flex items-center gap-3 px-4 py-3"
          >
            <div class="min-w-0 flex-1 space-y-1.5">
              <div class="flex items-center gap-2 flex-wrap">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ p.title }}
                </p>
                <StatusBadge
                  v-if="p.program_name"
                  :label="p.program_name"
                  tone="info"
                  uppercase
                />
                <StatusBadge
                  :label="kkmLabel(p)"
                  :tone="kkmTone(p)"
                  uppercase
                />
              </div>
              <p class="text-2xs text-slate-500">
                {{ formatShortDate(p.date) }}
              </p>
            </div>

            <div class="shrink-0 text-right">
              <p
                class="text-2xl font-black text-brand-azure leading-none tabular-nums"
              >
                {{ p.score }}
              </p>
              <p class="text-2xs uppercase tracking-wide text-slate-400 mt-1">
                / {{ p.max_score }}
              </p>
            </div>
          </div>
        </div>
      </template>
    </AsyncView>

    <Button variant="primary" block @click="openReportCard">
      {{ t('tutoring2.parent.assessments.downloadReport') }}
    </Button>
  </div>
</template>

<!--
  ParentTutoring2AssessmentsView.vue — Wali grades for one child (WEB-5).

  Composition:
    1. BrandPageHeader (role="parent") — with meta line.
    2. KpiStripCards          — Rata-rata / Tertinggi / Dikerjakan / Peringkat.
    3. AsyncView              — rounded-3xl surface with divide-y rows.
    4. Primary Button block   — "Unduh rapor bimbel (PDF)".

  Parent sees only PUBLISHED assessments. MVP: no student-scoped scores
  API yet; the list shows every published assessment for the tenant. Row
  score cell is a placeholder derived from max_score.

  // TODO WEB-5+ swap to /tutoring2/parent/assessments/:studentId to
  //             filter to child-specific scores.
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
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelAssessment,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
// Wired in per the tutoring2 view contract; used by the future save flow
// when we swap to /tutoring2/parent/assessments/:studentId.
useToast();

const studentId = String(route.params.studentId ?? '');

// ── Data ──────────────────────────────────────────────────────────
// TODO WEB-5+ swap to /tutoring2/parent/assessments/:studentId to
//             filter to child-specific scores.
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listAssessments({
    per_page: 50,
    published: true,
  });
  return items;
});
useAcademicYearWatcher(reload);

const items = computed<BimbelAssessment[]>(() => {
  return state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as BimbelAssessment[] | undefined) ?? [])
    : [];
});

// ── KPIs (placeholder aggregations from max_score) ────────────────
const avgScore = computed<number>(() => {
  const list = items.value;
  if (list.length === 0) return 0;
  const sum = list.reduce((acc, a) => acc + (a.max_score ?? 0), 0);
  return Math.round(sum / list.length);
});
const maxScore = computed<number>(() => {
  const list = items.value;
  if (list.length === 0) return 0;
  return Math.max(...list.map((a) => a.max_score ?? 0));
});

const kpiCards = computed<KpiCard[]>(() => {
  return [
    { icon: 'chart-bar', label: t('tutoring2.parent.assessments.kpiAverage'), value: avgScore.value > 0 ? String(avgScore.value) : '—', tone: 'brand' },
    { icon: 'award', label: t('tutoring2.parent.assessments.kpiHighest'), value: maxScore.value > 0 ? String(maxScore.value) : '—', tone: 'green' },
    { icon: 'check-circle', label: t('tutoring2.parent.assessments.kpiCompleted'), value: String(items.value.length) },
    { icon: 'star', label: t('tutoring2.parent.assessments.kpiRank'), value: '—', tone: 'violet' },
  ];
});

const metaLabel = computed(() =>
  state.value.status === 'loading'
    ? t('tutoring2.common.loading')
    // TODO WEB-5+ once /parent/assessments/:studentId ships, replace avg
    //             placeholder with the actual child's rolling average.
    : t('tutoring2.parent.assessments.meta', {
        avg: avgScore.value > 0 ? String(avgScore.value) : '—',
        count: items.value.length,
      }),
);

// ── Helpers ──────────────────────────────────────────────────────
function formatShortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

function publishedTone(a: BimbelAssessment): StatusBadgeTone {
  return a.published_at ? 'success' : 'neutral';
}
function publishedLabel(a: BimbelAssessment): string {
  return a.published_at
    ? t('tutoring2.status.published')
    : t('tutoring2.status.draft');
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
      <!-- TODO i18n key: tutoring2.parent.assessments.emptyDesc -->
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm divide-y divide-slate-100">
          <div
            v-for="a in items"
            :key="a.id"
            class="flex items-center gap-3 px-4 py-3"
          >
            <div class="min-w-0 flex-1 space-y-1.5">
              <div class="flex items-center gap-2 flex-wrap">
                <p class="truncate text-sm font-bold text-slate-900">{{ a.title }}</p>
                <StatusBadge
                  :label="a.kind_label ?? a.kind"
                  tone="info"
                  uppercase
                />
                <StatusBadge
                  :label="publishedLabel(a)"
                  :tone="publishedTone(a)"
                  uppercase
                />
              </div>
              <p class="text-2xs text-slate-500">
                {{ formatShortDate(a.assessment_date) }}
              </p>
            </div>

            <div class="shrink-0 text-right">
              <p class="text-2xl font-black text-brand-azure leading-none">
                {{ a.max_score ?? '—' }}
              </p>
              <p class="text-2xs uppercase tracking-wide text-slate-400 mt-1">
                / {{ a.max_score ?? '—' }}
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

<!--
  StudentTutoring2ResultView.vue — Siswa hasil try-out (WEB-5 MVP).

  Route: /student/tutoring2/assessments/:id/result.

  Composition contract (mirrors WEB-5 exemplar):
    1. BrandPageHeader        — role="student".
    2. KpiStripCards          — 3 tiles (Skor / Peringkat / Benar).
    3. AsyncView              — state machine on listScores().
       Default slot renders a rounded-3xl surface with stacked CTAs.

  MVP note: BE-5 `listScores` returns every enrollment's row for the
  assessment but does NOT tell us which one belongs to the current
  student. We pick the first row as a placeholder so the KPI strip +
  action panel render — the "current-student" filter lands with WEB-5+.
-->
<script setup lang="ts">
// TODO WEB-5+ derive the current-user student_id and filter to their score row
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { TutoringScoreRow } from '@/types/tutoring-bimbel';

const { t } = useI18n();
const route = useRoute();

const assessmentId = (route.params.id as string) ?? '';

const { state, reload } = useDataRefresh<TutoringScoreRow[]>(async () => {
  const { items } = await TutoringBimbelService.listScores(assessmentId);
  return items;
});

const allRows = computed<TutoringScoreRow[]>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value as { status: string; data?: TutoringScoreRow[] }).data ?? [])
    : [],
);

// TODO WEB-5+ derive the current-user student_id and filter to their score row
const myRow = computed<TutoringScoreRow | null>(() => allRows.value[0] ?? null);

const kpiCards = computed<KpiCard[]>(() => {
  const row = myRow.value;
  const n = allRows.value.length;
  return [
    {
      icon: 'chart-bar',
      label: t('tutoring2.student.result.kpiScore'),
      value: row?.score != null ? String(row.score) : '—',
      tone: 'green',
    },
    {
      icon: 'trending-up',
      label: t('tutoring2.student.result.kpiRank'),
      value: n > 0 ? `1/${n}` : '—',
      tone: 'brand',
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.student.result.kpiCorrect'),
      value: '—',
      tone: 'slate',
    },
  ];
});

</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.result.title')"
      :meta="t('tutoring2.student.result.meta')"
    />

    <KpiStripCards :cards="kpiCards" :lg-cols="3" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="2"
      :empty-title="t('tutoring2.student.result.emptyTitle')"
      @retry="reload"
    >
      <template #default>
      </template>
    </AsyncView>
  </div>
</template>

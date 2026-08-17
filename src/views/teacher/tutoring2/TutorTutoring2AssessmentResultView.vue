<!--
  TutorTutoring2AssessmentResultView.vue — Hasil try-out (WEB-4).

  Read-only leaderboard for a single assessment. Reuses the same
  `listScores` endpoint as the score-entry view but renders the rows
  sorted by score desc (nulls last), with a rank number and a "Juara"
  StatusBadge on rank 1.

  Route: /teacher/tutoring2/assessments/:id/result.

  Composition contract mirrors the WEB-4 exemplar:
    1. BrandPageHeader        — role="teacher".
    2. KpiStripCards          — 3 tiles (Terisi / Rata / Tertinggi).
    3. AsyncView              — state machine.
       Default slot renders a rounded-3xl surface with a divide-y list.
    4. "Bagikan ke wali" stub Button (toast — belum tersedia).
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { TutoringScoreRow } from '@/types/tutoring-bimbel';

const { t } = useI18n();
const route = useRoute();

const assessmentId = (route.params.id as string) ?? '';

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listScores(assessmentId);
  return items;
});

const allRows = computed<TutoringScoreRow[]>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value as { status: string; data?: TutoringScoreRow[] }).data ?? [])
    : [],
);

/** Rows sorted by score DESC, nulls last. */
const sortedRows = computed<TutoringScoreRow[]>(() => {
  return [...allRows.value].sort((a, b) => {
    if (a.score == null && b.score == null) return 0;
    if (a.score == null) return 1;
    if (b.score == null) return -1;
    return b.score - a.score;
  });
});

const kpiCards = computed<KpiCard[]>(() => {
  const scored = allRows.value.filter((r) => r.score !== null);
  const avg = scored.length > 0
    ? Math.round(scored.reduce((sum, r) => sum + (r.score ?? 0), 0) / scored.length)
    : 0;
  const max = scored.length > 0
    ? Math.max(...scored.map((r) => r.score ?? 0))
    : 0;
  return [
    { icon: 'clipboard', label: t('tutoring2.tutor.result.kpiSubmitted'), value: String(scored.length), tone: 'brand' },
    { icon: 'chart-bar', label: t('tutoring2.tutor.result.kpiAverage'), value: String(avg), tone: 'brand' },
    { icon: 'trending-up', label: t('tutoring2.tutor.result.kpiHighest'), value: String(max), tone: 'green' },
  ];
});

/**
 * Last-resort label. Every row used to show this instead of a name —
 * the note here even said `student_name` was "already on the row",
 * and kept the id anyway to match the score-entry view, which was
 * itself showing ids. BE !775 makes the score wire carry
 * `student_name`, and the score-entry view was fixed in !1172, so the
 * reason to keep hex here is gone.
 */
function truncateId(id: string, len = 8): string {
  if (!id) return '—';
  return id.length > len ? id.slice(0, len) : id;
}

const metaLabel = computed(() =>
  t('tutoring2.tutor.result.meta', { count: allRows.value.length }),
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.result.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :lg-cols="3" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="6"
      :empty-title="t('tutoring2.tutor.result.emptyTitle')"
      empty-description="Skor akan muncul di sini setelah tutor menginput nilai."
      @retry="reload"
    >
      <!-- TODO i18n key: empty-description "Skor akan muncul di sini setelah tutor menginput nilai." -->
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="(row, idx) in sortedRows"
              :key="row.enrollment_id"
              class="flex items-center gap-3 px-4 py-3"
            >
              <div class="w-8 shrink-0 text-center">
                <span class="text-sm font-bold text-slate-500">{{ idx + 1 }}</span>
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ row.student_name || truncateId(row.student_id) }}
                </p>
                <p
                  v-if="row.student_number"
                  class="truncate text-2xs text-slate-500"
                >
                  NIS {{ row.student_number }}
                </p>
              </div>
              <StatusBadge
                v-if="idx === 0 && row.score !== null"
                :label="t('tutoring2.status.champion')"
                tone="success"
                uppercase
              />
              <span class="text-[20px] font-bold text-slate-900">
                {{ row.score ?? '—' }}
              </span>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

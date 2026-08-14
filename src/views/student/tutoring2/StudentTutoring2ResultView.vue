<!--
  StudentTutoring2ResultView.vue — Siswa hasil try-out (WEB-5 MVP).

  Route: /student/tutoring2/assessments/:id/result.

  Composition contract (mirrors WEB-5 exemplar):
    1. BrandPageHeader        — role="student".
    2. KpiStripCards          — 3 tiles (Skor / Peringkat / Benar).
    3. AsyncView              — state machine on listScores().
       Default slot renders a rounded-3xl surface with stacked CTAs.

  The rank is real. It used to read `1/${n}` — literally rank one, for
  every student, on every assessment, where n was the row count. The
  dense rank now comes from
  `GET /programs/{pid}/leaderboard?assessment_id={id}`, matched to this
  student by `student_id`, and renders "—" when they are not in the
  returned slice. The leaderboard is capped, and absence from a capped
  list is not evidence of position.

  The old note here claimed `listScores` returns every enrollment's row
  and cannot say which is ours. That stopped being true when the
  endpoint gained `_view_own` scoping: a siswa gets their own row and
  no one else's, so `rows[0]` IS theirs. The row also carries
  `student_id` now, which is what finds it on the leaderboard.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import Button from '@/components/ui/Button.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';
import type { TutoringScoreRow } from '@/types/tutoring-bimbel';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const assessmentId = (route.params.id as string) ?? '';

// Dense rank for this student on this assessment, and the size of the
// ranked field. Both null until resolved, and null is rendered as "—"
// rather than as a number.
const myRank = ref<number | null>(null);
const rankedTotal = ref<number | null>(null);

const { state, reload } = useDataRefresh<TutoringScoreRow[]>(async () => {
  const { items } = await TutoringBimbelService.listScores(assessmentId);

  // The rank decorates a score; a leaderboard that 403s or 404s must
  // not blank the score the student came here for.
  myRank.value = null;
  rankedTotal.value = null;
  const mine = items[0];
  if (mine?.student_id) {
    try {
      const assessment = await TutoringBimbelService.getAssessment(assessmentId);
      const board = await TutoringLeaderboardService.getProgram(assessment.program_id, {
        assessment_id: assessmentId,
        limit: 100,
      });
      rankedTotal.value = board.items.length;
      myRank.value = board.items.find((r) => r.student_id === mine.student_id)?.rank ?? null;
    } catch {
      // Leave both null — "belum tersedia" is true, and truer than a
      // number we could not read.
    }
  }

  return items;
});

const allRows = computed<TutoringScoreRow[]>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value as { status: string; data?: TutoringScoreRow[] }).data ?? [])
    : [],
);

// Own-scoped by the backend, so the first row IS this student's.
const myRow = computed<TutoringScoreRow | null>(() => allRows.value[0] ?? null);

const kpiCards = computed<KpiCard[]>(() => {
  const row = myRow.value;
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
      value:
        myRank.value == null
          ? '—'
          : rankedTotal.value == null
            ? `${myRank.value}`
            : `${myRank.value}/${rankedTotal.value}`,
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


/**
 * The siswa leaderboard. This button existed from the start, wired to a
 * `notAvailable` toast, and was removed in !1163 because nothing was
 * behind it. `Tutoring2LeaderboardView` is that destination.
 */
function openLeaderboard() {
  router.push({ name: 'student.tutoring2.leaderboard' });
}
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
        <!-- "Lihat pembahasan" is NOT back: there is still no question or
             solution storage anywhere, which is why the assessment runner
             was removed too. This one is back because the leaderboard
             view now exists. -->
        <div class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
          <Button variant="primary" block @click="openLeaderboard">
            {{ t('tutoring2.student.result.viewLeaderboard') }}
          </Button>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

<!--
  StudentTutoring2AssessmentsView.vue — Siswa try-out / latihan list (WEB-6).

  Composition:
    1. BrandPageHeader        — role="student".
    2. KpiStripCards          — Dikerjakan / Belum dikerjakan / Rata-rata / Peringkat.
    3. AsyncView              — rounded-3xl surface with divide-y rows.

  Backend filter: `published: true` — the student only sees assessments
  the tutor has released. No FAB (students don't author assessments).

  MVP note: real "sudah dikerjakan" state requires a per-student score
  lookup which the current endpoint doesn't expose. Until then the row
  status alternates purely for visual effect and every row uses the
  "Kerjakan" CTA.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
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
import {
  TutoringBimbelService,
  type BimbelAssessment,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();

// ── Data ──────────────────────────────────────────────────────────
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

// ── KPIs ─────────────────────────────────────────────────────────
// MVP: no per-student score endpoint yet — use even/odd on the current
// page as a placeholder split between "Dikerjakan" and "Belum dikerjakan".
const kpiCards = computed<KpiCard[]>(() => {
  const list = items.value;
  const total = list.length;
  const done = list.filter((_, i) => i % 2 === 0).length;
  const pending = total - done;
  return [
    { icon: 'check-circle', label: t('tutoring2.student.assessments.kpiCompleted'), value: String(done), tone: 'green' },
    { icon: 'clock', label: t('tutoring2.student.assessments.kpiPending'), value: String(pending), tone: 'amber' },
    { icon: 'chart-bar', label: t('tutoring2.student.assessments.kpiAverage'), value: '—', tone: 'brand' },
    { icon: 'award', label: t('tutoring2.student.assessments.kpiRank'), value: '—', tone: 'violet' },
  ];
});

// ── Helpers ──────────────────────────────────────────────────────
function formatShortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

// MVP placeholder — see file header note.
function completedTone(idx: number): StatusBadgeTone {
  return idx % 2 === 0 ? 'success' : 'warning';
}
function completedLabel(idx: number): string {
  return idx % 2 === 0
    ? t('tutoring2.status.done')
    : t('tutoring2.common.notAvailable');
}

const metaLabel = computed(() =>
  state.value.status === 'loading'
    ? t('tutoring2.common.loading')
    : t('tutoring2.student.assessments.meta', { count: items.value.length }),
);

// ── Navigation ───────────────────────────────────────────────────
function takeAssessment(id: string) {
  router.push({ name: 'student.tutoring2.take-assessment', params: { id } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.assessments.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.student.assessments.emptyTitle')"
      :empty-description="t('tutoring2.student.assessments.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm divide-y divide-slate-100">
          <div
            v-for="(a, idx) in items"
            :key="a.id"
            class="p-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="min-w-0 flex-1 space-y-1.5">
              <div class="flex items-center gap-2 flex-wrap">
                <p class="font-bold text-slate-900 truncate">{{ a.title }}</p>
                <StatusBadge
                  :label="a.kind_label ?? a.kind"
                  tone="info"
                  uppercase
                />
                <StatusBadge
                  :label="completedLabel(idx)"
                  :tone="completedTone(idx)"
                  uppercase
                />
              </div>
              <p class="text-2xs text-slate-500">
                {{ formatShortDate(a.assessment_date) }}
                <span class="mx-1 text-slate-300">•</span>
                {{ t('tutoring2.common.metaParticipants', { count: a.scores_count ?? 0 }) }}
              </p>
            </div>

            <div class="flex items-center gap-2 shrink-0">
              <Button variant="primary" size="sm" @click="takeAssessment(a.id)">
                {{ t('tutoring2.student.assessments.doNow') }}
              </Button>
            </div>
          </div>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

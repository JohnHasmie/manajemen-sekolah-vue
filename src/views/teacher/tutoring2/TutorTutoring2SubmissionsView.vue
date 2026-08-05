<!--
  TutorTutoring2SubmissionsView.vue — tutor Submissions grader
  (WEB-13, wires BE-23 SubmissionController).

  Route: /teacher/tutoring2/submissions?activity_id={id}

  Loads submissions for an activity, shows student name, submitted
  timestamp, an attachment link when present, and inline editable
  score + client-only feedback field. Save fires POST
  /submissions/{id}/grade — optimistic update on the row + toast on
  success. A bulk-grade toolbar pre-fills empty grade inputs with the
  same value ("Berikan nilai yang sama").

  Ability: `tutoring.score.manage` is checked before render — falls
  back to a soft empty state if the tutor is view-only.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { useMeStore } from '@/stores/me';
import { ActivitiesService } from '@/services/tutoring2/activities';
import { SubmissionsService } from '@/services/tutoring2/submissions';
import type { Activity, Submission } from '@/types/tutoring2/activity';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();
const me = useMeStore();

// BE-23 grade endpoint (`POST /submissions/{id}/grade`) authorizes
// on `tutoring.activity.manage` — grading a submission is part of
// the "manage activities" surface, not the assessment-scores one.
// The WEB-13 brief said `tutoring.score.manage`; we followed the
// backend contract instead. Tutor bimbel defaults hold both, so
// the same tutors keep grading access.
const canGrade = computed(() => me.can('tutoring.activity.manage'));

const activityId = computed(() => String(route.query.activity_id ?? ''));

// ── Data (activity meta + submission list, in parallel) ──────────
const activity = ref<Activity | null>(null);

const { state, reload } = useDataRefresh(async () => {
  if (!activityId.value) {
    return { rows: [] as SubmissionRow[] };
  }
  const [act, list] = await Promise.all([
    ActivitiesService.get(activityId.value),
    SubmissionsService.listByActivity(activityId.value, { per_page: 200 }),
  ]);
  activity.value = act;
  return {
    rows: list.items.map<SubmissionRow>((s) => ({
      ...s,
      _scoreInput: s.score ?? null,
      _feedbackInput: '',
      _dirty: false,
      _saving: false,
    })),
  };
});

onMounted(async () => {
  if (!activityId.value) {
    // Nothing to grade — route back to the activities list.
    router.replace({ name: 'teacher.tutoring2.activities' });
    return;
  }
  await reload();
});

interface SubmissionRow extends Submission {
  _scoreInput: number | null;
  _feedbackInput: string;
  _dirty: boolean;
  _saving: boolean;
}

const rows = computed<SubmissionRow[]>(() => {
  if (state.value.status === 'content' || state.value.status === 'empty') {
    const data = (state.value.data as { rows?: SubmissionRow[] } | undefined) ?? { rows: [] };
    return data.rows ?? [];
  }
  return [];
});

const kpiCards = computed<KpiCard[]>(() => {
  const items = rows.value;
  const submitted = items.filter((r) => r.status === 'submitted').length;
  const graded = items.filter((r) => r.status === 'graded').length;
  const drafts = items.filter((r) => r.status === 'draft').length;
  return [
    { icon: 'inbox', label: t('tutoring2.tutor.submissions.kpiTotal'), value: String(items.length) },
    { icon: 'clock', label: t('tutoring2.tutor.submissions.kpiSubmitted'), value: String(submitted), tone: 'brand' },
    { icon: 'check-circle', label: t('tutoring2.tutor.submissions.kpiGraded'), value: String(graded), tone: 'green' },
    { icon: 'edit', label: t('tutoring2.tutor.submissions.kpiDrafts'), value: String(drafts), tone: 'amber' },
  ];
});

// ── Bulk grade toolbar ───────────────────────────────────────────
const bulkScore = ref<number | null>(null);

function applyBulk() {
  if (bulkScore.value === null || bulkScore.value === undefined) return;
  for (const r of rows.value) {
    if (r._scoreInput === null || r._scoreInput === undefined) {
      r._scoreInput = bulkScore.value;
      r._dirty = true;
    }
  }
  toast.info(t('tutoring2.tutor.submissions.bulkApplied'));
}

// ── Per-row grade save (inline) ──────────────────────────────────
function onScoreInput(row: SubmissionRow, val: string) {
  const n = val === '' ? null : Number(val);
  row._scoreInput = Number.isFinite(n as number) ? (n as number) : null;
  row._dirty = true;
}

function onFeedbackInput(row: SubmissionRow, val: string) {
  row._feedbackInput = val;
  row._dirty = true;
}

async function saveRow(row: SubmissionRow) {
  if (!canGrade.value) {
    toast.error(t('tutoring2.tutor.submissions.noGradeAbility'));
    return;
  }
  if (row._saving) return;
  const max = activity.value?.max_points ?? null;
  if (row._scoreInput !== null && max !== null && row._scoreInput > max) {
    toast.error(t('tutoring2.tutor.submissions.scoreOverMax', { max }));
    return;
  }
  row._saving = true;
  const previousStatus = row.status;
  const previousScore = row.score;
  // Optimistic: reflect the change immediately.
  row.status = 'graded';
  row.score = row._scoreInput;
  try {
    const updated = await SubmissionsService.grade(row.id, {
      score: row._scoreInput,
      feedback: row._feedbackInput || null,
    });
    row.status = updated.status;
    row.score = updated.score ?? null;
    row.graded_at = updated.graded_at ?? row.graded_at;
    row._dirty = false;
    toast.success(t('tutoring2.tutor.submissions.saved'));
  } catch (e) {
    // Rollback optimistic update.
    row.status = previousStatus;
    row.score = previousScore;
    toast.error((e as Error).message || t('tutoring2.tutor.submissions.saveError'));
  } finally {
    row._saving = false;
  }
}

function statusTone(s: Submission['status']): 'success' | 'warning' | 'neutral' | 'info' {
  switch (s) {
    case 'graded':
      return 'success';
    case 'submitted':
      return 'info';
    case 'draft':
      return 'warning';
    default:
      return 'neutral';
  }
}

function statusLabel(s: Submission['status']): string {
  return t(`tutoring2.tutor.submissions.status.${s}`);
}

function formatDate(iso?: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('id-ID', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function goBack() {
  router.push({ name: 'teacher.tutoring2.activities' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="activity?.title ?? t('tutoring2.tutor.submissions.title')"
      :meta="state.status === 'loading'
        ? t('tutoring2.common.loading')
        : t('tutoring2.tutor.submissions.meta', { count: rows.length })"
    />

    <Button variant="ghost" size="sm" @click="goBack">← {{ t('tutoring2.common.back') }}</Button>

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <!-- Bulk grade toolbar -->
    <div v-if="canGrade" class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm flex items-center gap-3 flex-wrap">
      <span class="text-xs font-bold text-slate-500 uppercase tracking-wide">
        {{ t('tutoring2.tutor.submissions.bulkTitle') }}
      </span>
      <input
        v-model.number="bulkScore"
        type="number"
        min="0"
        :max="activity?.max_points ?? 1000"
        :placeholder="t('tutoring2.tutor.submissions.bulkPlaceholder')"
        class="w-24 rounded-xl border border-slate-200 px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
      />
      <Button variant="secondary" size="sm" :disabled="bulkScore === null" @click="applyBulk">
        {{ t('tutoring2.tutor.submissions.bulkApply') }}
      </Button>
      <span class="text-2xs text-slate-500">
        {{ t('tutoring2.tutor.submissions.bulkHint') }}
      </span>
    </div>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="6"
      :empty-title="t('tutoring2.tutor.submissions.emptyTitle')"
      :empty-description="t('tutoring2.tutor.submissions.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div v-if="rows.length === 0" class="rounded-3xl border border-slate-100 bg-white p-6 text-center text-sm text-slate-500 shadow-sm">
          {{ t('tutoring2.tutor.submissions.emptyDesc') }}
        </div>
        <div v-else class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead class="bg-slate-50">
                <tr class="text-left text-2xs font-bold uppercase tracking-wide text-slate-500">
                  <th class="px-4 py-3">{{ t('tutoring2.common.student') }}</th>
                  <th class="px-4 py-3">{{ t('tutoring2.common.status') }}</th>
                  <th class="px-4 py-3">{{ t('tutoring2.tutor.submissions.submittedAt') }}</th>
                  <th class="px-4 py-3">{{ t('tutoring2.tutor.submissions.attachment') }}</th>
                  <th class="px-4 py-3 w-32">{{ t('tutoring2.common.maxScore') }}</th>
                  <th class="px-4 py-3">{{ t('tutoring2.tutor.submissions.feedback') }}</th>
                  <th class="px-4 py-3 w-24"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr v-for="row in rows" :key="row.id" class="hover:bg-slate-50">
                  <td class="px-4 py-3 min-w-[160px]">
                    <p class="font-bold text-slate-900 truncate">{{ row.student_name ?? row.student_id ?? row.enrollment_id.slice(0, 8) }}</p>
                    <p v-if="row.body" class="text-2xs text-slate-500 truncate max-w-xs">
                      {{ row.body }}
                    </p>
                  </td>
                  <td class="px-4 py-3">
                    <StatusBadge :label="row.status_label ?? statusLabel(row.status)" :tone="statusTone(row.status)" uppercase />
                  </td>
                  <td class="px-4 py-3 text-2xs text-slate-500 whitespace-nowrap">
                    {{ formatDate(row.submitted_at) }}
                  </td>
                  <td class="px-4 py-3">
                    <a
                      v-if="row.attachment_url"
                      :href="row.attachment_url"
                      target="_blank"
                      rel="noopener"
                      class="text-brand-cobalt underline text-xs"
                    >
                      {{ t('tutoring2.tutor.submissions.open') }}
                    </a>
                    <span v-else class="text-2xs text-slate-400">—</span>
                  </td>
                  <td class="px-4 py-3">
                    <input
                      :value="row._scoreInput ?? ''"
                      type="number"
                      min="0"
                      :max="activity?.max_points ?? 1000"
                      class="w-24 rounded-xl border border-slate-200 px-2 py-1.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
                      :disabled="!canGrade"
                      @input="onScoreInput(row, ($event.target as HTMLInputElement).value)"
                    />
                    <span v-if="activity?.max_points" class="text-2xs text-slate-400 ml-1">/{{ activity.max_points }}</span>
                  </td>
                  <td class="px-4 py-3 min-w-[200px]">
                    <textarea
                      :value="row._feedbackInput"
                      rows="1"
                      class="w-full rounded-xl border border-slate-200 px-2 py-1.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
                      :placeholder="t('tutoring2.tutor.submissions.feedbackPlaceholder')"
                      :disabled="!canGrade"
                      @input="onFeedbackInput(row, ($event.target as HTMLTextAreaElement).value)"
                    />
                  </td>
                  <td class="px-4 py-3">
                    <Button
                      variant="primary"
                      size="sm"
                      :disabled="!canGrade || !row._dirty"
                      :loading="row._saving"
                      @click="saveRow(row)"
                    >
                      {{ t('tutoring2.common.save') }}
                    </Button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

<!--
  ParentTutoring2ActivitiesView.vue — the wali's feed of one child's
  tugas / kuis / materi baca (CLEAN-2 Phase 2 · greenfield replacement
  for the legacy `parent/tutoring/ParentActivitiesView.vue`).

  Route: /parent/tutoring2/activities/:studentId
  Endpoints (all `/tutoring-v2/*`):
    GET /tutoring-v2/enrollments?student_id=          — the child's groups
    GET /tutoring-v2/learning-groups/{id}/activities   — per-group feed
    GET /tutoring-v2/activities/{id}/submissions       — wali-scoped rows

  Child scope: `:studentId` route param, exactly like
  ParentTutoring2AttendanceView / ParentTutoring2AssessmentsView. The
  wali reaches it from ParentTutoring2PickChildView. No new picker
  mechanism is invented here.

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. v1 called `GET /tutoring/activities`, a TENANT-WIDE index with no
     student scoping, and overlaid `GET /tutoring/activity-submissions
     ?student_id=`. v2 has NO tenant-wide activity index and NO
     student-feed route (checked the whole `Route::prefix('tutoring-v2')`
     group: the only activity index is
     `/learning-groups/{groupId}/activities`). So the feed is rebuilt
     from the child's own learning groups. Practical effect: activities
     belonging to a group the child is NOT enrolled in no longer show —
     which is the correct behaviour, but it IS a behaviour change from
     v1, where a parent saw every activity in the tenant.
  2. Activity kinds changed with the module: v1 `ASSIGNMENT | EXAM |
     MATERIAL`; v2 `tugas | kuis | materi_baca` (see `ActivityKind`).
     The filter chip enumerates `ACTIVITY_KINDS` so a fourth kind is a
     one-line change on both sides.
  3. v1 submission statuses were `ASSIGNED | LATE | MISSED | SUBMITTED |
     GRADED`. v2 has only `draft | submitted | graded` — there is no
     server-side "late"/"missed" state, so the legacy red LATE pill is
     NOT ported. Lateness is derived purely client-side from `due_at`
     for a row that has no submission at all, and is rendered as a
     separate "belum dikumpulkan" pseudo-status (see `rowTone`).
  4. Drafts are invisible to a wali by construction — ActivityController
     adds `whereNotNull('published_at')` for anyone without
     `tutoring.activity.manage`. No client-side draft filter needed.

  PERFORMANCE NOTE: v2 has no bulk "submissions for student X" route, so
  the submission overlay costs one request per activity. Capped at
  MAX_SUBMISSION_LOOKUPS rows (the ones the parent actually sees first);
  older activities render without the overlay rather than firing an
  unbounded fan-out. A backend `GET /tutoring-v2/students/{id}/submissions`
  would collapse this to a single call.
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
import { ActivitiesService } from '@/services/tutoring2/activities';
import { SubmissionsService } from '@/services/tutoring2/submissions';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import {
  ACTIVITY_KINDS,
  type Activity,
  type ActivityKind,
  type Submission,
} from '@/types/tutoring2/activity';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();

/** Child scope — same mechanism as every other parent/tutoring2 view. */
const studentId = String(route.params.studentId ?? '');

/** See the PERFORMANCE NOTE in the file header. */
const MAX_SUBMISSION_LOOKUPS = 30;

interface ActivityRow {
  activity: Activity;
  /** null = the child has no submission row for this activity yet. */
  submission: Submission | null;
}

/**
 * Sort: overdue first (most recently overdue at the top), then
 * upcoming (soonest first), then rows with no deadline. Mirrors the
 * legacy ordering so the page still answers "what is late?" first.
 */
function compareByDue(a: Activity, b: Activity): number {
  const av = a.due_at ? new Date(a.due_at).valueOf() : null;
  const bv = b.due_at ? new Date(b.due_at).valueOf() : null;
  if (av === null && bv === null) return 0;
  if (av === null) return 1;
  if (bv === null) return -1;
  const now = Date.now();
  const aPast = av < now;
  const bPast = bv < now;
  if (aPast && !bPast) return -1;
  if (!aPast && bPast) return 1;
  return Math.abs(av - now) - Math.abs(bv - now);
}

const { state, reload } = useDataRefresh<ActivityRow[]>(async () => {
  if (!studentId) return [];

  const { items: enrollments } = await TutoringBimbelService.listEnrollments({
    student_id: studentId,
    per_page: 100,
  });

  // Only the child's OWN enrollment ids may claim a submission row —
  // the backend scopes the submissions index to every student the wali
  // is linked to, which for a multi-child wali is a superset.
  const ownEnrollmentIds = new Set(enrollments.map((e) => e.id));

  const groupIds = [
    ...new Set(
      enrollments
        .map((e) => e.learning_group_id)
        .filter((id): id is string => Boolean(id)),
    ),
  ];
  if (groupIds.length === 0) return [];

  const perGroup = await Promise.all(
    groupIds.map((id) => ActivitiesService.listByGroup(id, { per_page: 50 })),
  );
  const activities = perGroup.flatMap((r) => r.items).sort(compareByDue);

  const overlayTargets = activities.slice(0, MAX_SUBMISSION_LOOKUPS);
  const submissionLists = await Promise.all(
    overlayTargets.map((a) =>
      SubmissionsService.listByActivity(a.id, { per_page: 50 }),
    ),
  );

  const byActivityId = new Map<string, Submission>();
  for (const list of submissionLists) {
    for (const s of list.items) {
      if (ownEnrollmentIds.has(s.enrollment_id)) byActivityId.set(s.activity_id, s);
    }
  }

  return activities.map((activity) => ({
    activity,
    submission: byActivityId.get(activity.id) ?? null,
  }));
});

const rows = computed<ActivityRow[]>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as ActivityRow[] | undefined) ?? [])
    : [],
);

// ── Filters ───────────────────────────────────────────────────────
// '' = every kind; 'pending' is a cross-kind filter for "not handed in
// or not graded yet", which is what a wali opens this page to find.
type KindFilter = '' | 'pending' | ActivityKind;

const kindFilter = ref<KindFilter>('');

function isPending(row: ActivityRow): boolean {
  // No submission row at all, or one the tutor hasn't graded.
  return row.submission === null || row.submission.status !== 'graded';
}

const visibleRows = computed<ActivityRow[]>(() => {
  const f = kindFilter.value;
  if (f === '') return rows.value;
  if (f === 'pending') return rows.value.filter(isPending);
  return rows.value.filter((r) => r.activity.kind === f);
});

function cycleKind() {
  const order: KindFilter[] = ['', 'pending', ...ACTIVITY_KINDS];
  const i = order.indexOf(kindFilter.value);
  kindFilter.value = order[(i + 1) % order.length] ?? '';
}

// ── KPIs ─────────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const all = rows.value;
  const pending = all.filter(isPending).length;
  const graded = all.filter((r) => r.submission?.status === 'graded').length;
  const overdue = all.filter((r) => {
    if (r.submission !== null) return false;
    const days = daysUntilDue(r.activity);
    return days !== null && days < 0;
  }).length;
  return [
    {
      icon: 'clipboard',
      label: t('tutoring2.parent.activities.kpiTotal'),
      value: String(all.length),
    },
    {
      icon: 'clock',
      label: t('tutoring2.parent.activities.kpiPending'),
      value: String(pending),
      tone: 'amber',
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.parent.activities.kpiGraded'),
      value: String(graded),
      tone: 'green',
    },
    {
      icon: 'x-circle',
      label: t('tutoring2.parent.activities.kpiOverdue'),
      value: String(overdue),
      tone: 'red',
    },
  ];
});

const metaLabel = computed(() =>
  state.value.status === 'loading'
    ? t('tutoring2.common.loading')
    : t('tutoring2.parent.activities.meta', { count: visibleRows.value.length }),
);

// ── Labels + tones ───────────────────────────────────────────────
function kindLabel(kind: ActivityKind | string): string {
  switch (kind) {
    case 'tugas':
      return t('tutoring2.parent.activities.kindTugas');
    case 'kuis':
      return t('tutoring2.parent.activities.kindKuis');
    case 'materi_baca':
      return t('tutoring2.parent.activities.kindMateriBaca');
    default:
      return String(kind);
  }
}

const kindChipValue = computed(() => {
  const f = kindFilter.value;
  if (f === '') return t('tutoring2.common.all');
  if (f === 'pending') return t('tutoring2.parent.activities.filterPending');
  return kindLabel(f);
});

/**
 * Submission status → tone. The three real backend statuses are kept
 * byte-identical to `statusTone` in TutorTutoring2SubmissionsView so a
 * submission reads the same colour to the tutor and to the wali. If you
 * change one, change both.
 *
 * The `null` branch is a PARENT-ONLY pseudo-status ("belum dikumpulkan")
 * — there is no such value on the wire, so it can't disagree with a
 * sibling view. Overdue-and-unsubmitted goes danger, otherwise neutral.
 */
function rowTone(row: ActivityRow): StatusBadgeTone {
  const s = row.submission?.status;
  switch (s) {
    case 'graded':
      return 'success';
    case 'submitted':
      return 'info';
    case 'draft':
      return 'warning';
    default: {
      const days = daysUntilDue(row.activity);
      return days !== null && days < 0 ? 'danger' : 'neutral';
    }
  }
}

function rowStatusLabel(row: ActivityRow): string {
  const s = row.submission?.status;
  if (s === 'graded') {
    const score = row.submission?.score;
    return score == null
      ? t('tutoring2.parent.activities.statusGraded')
      : t('tutoring2.parent.activities.statusScore', {
          score,
          max: row.activity.max_points ?? 100,
        });
  }
  if (s === 'submitted') return t('tutoring2.parent.activities.statusSubmitted');
  if (s === 'draft') return t('tutoring2.parent.activities.statusDraft');
  const days = daysUntilDue(row.activity);
  if (days === null) return t('tutoring2.parent.activities.statusNoDue');
  if (days < 0)
    return t('tutoring2.parent.activities.statusOverdueDays', { days: Math.abs(days) });
  return t('tutoring2.parent.activities.statusDueInDays', { days });
}

/**
 * Whole days between now and `due_at`, or null when open-ended.
 * Built from local `Date` arithmetic — never `toISOString().slice(...)`,
 * which is UTC and shifts a WIB user back a day before 07:00.
 */
function daysUntilDue(activity: Activity): number | null {
  if (!activity.due_at) return null;
  const due = new Date(activity.due_at);
  if (Number.isNaN(due.valueOf())) return null;
  return Math.ceil((due.valueOf() - Date.now()) / 86_400_000);
}

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

function subtitle(row: ActivityRow): string {
  const parts: string[] = [kindLabel(row.activity.kind)];
  const group = row.activity.learning_group_name;
  if (group) parts.push(group);
  parts.push(
    row.activity.due_at
      ? `${t('tutoring2.common.dueDate')} ${formatShortDate(row.activity.due_at)}`
      : t('tutoring2.parent.activities.statusNoDue'),
  );
  return parts.join(' · ');
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.activities.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.kind')"
          :value="kindChipValue"
          icon-name="clipboard-list"
          :active="kindFilter !== ''"
          @click="cycleKind()"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.parent.activities.emptyTitle')"
      :empty-description="t('tutoring2.parent.activities.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <p
          v-if="visibleRows.length === 0"
          class="rounded-3xl border border-slate-100 bg-white px-4 py-8 text-center text-sm text-slate-500 shadow-sm"
        >
          {{ t('tutoring2.parent.activities.noMatch') }}
        </p>

        <div v-else class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="row in visibleRows"
              :key="row.activity.id"
              class="flex items-center gap-3 px-4 py-3"
            >
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ row.activity.title }}
                </p>
                <p class="truncate text-2xs text-slate-500">{{ subtitle(row) }}</p>
              </div>
              <StatusBadge
                :label="rowStatusLabel(row)"
                :tone="rowTone(row)"
                uppercase
              />
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

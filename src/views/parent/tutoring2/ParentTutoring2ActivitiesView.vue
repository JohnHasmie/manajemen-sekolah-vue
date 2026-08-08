<!--
  ParentTutoring2ActivitiesView.vue — the wali's feed of one child's
  tugas / kuis / materi baca (greenfield replacement for the legacy
  `parent/tutoring/ParentActivitiesView.vue`).

  Route: /parent/tutoring2/activities/:studentId
  Endpoint: GET /tutoring-v2/students/{id}/submissions   — ONE call/page

  Child scope: `:studentId` route param, exactly like
  ParentTutoring2AttendanceView / ParentTutoring2AssessmentsView. The
  wali reaches it from ParentTutoring2PickChildView.

  HISTORY — the bug this file used to have:

    v2 had no student-centric route, so this view rebuilt the feed in the
    browser: enrollments, then one activities call per learning group,
    then ONE submissions call PER ACTIVITY — capped at the first 30.

    That cap was not a performance trade, it was a CORRECTNESS BUG. Past
    row 30 every activity arrived with `submission: null`, and null here
    is not "unknown": `rowTone` renders it as the pseudo-status "belum
    dikumpulkan". A child who handed their work in on time was shown to
    their parent as delinquent, with nothing on screen saying the data
    had been truncated. The per-group `per_page: 50` dropped activities
    outright on the same basis.

    The fan-out also pulled SIBLINGS' submissions — scores and answer
    bodies — into the browser, because the submissions index is scoped to
    every student the wali is linked to, and the view filtered that
    superset in JS. The server now resolves ownership, so only the
    requested child's rows are ever sent.

  WHAT THE SERVER GUARANTEES, so do not re-implement it here:
    • `submission` is always present, explicitly null when absent.
    • Drafts are already excluded — ActivityController's publish gate
      applies to anyone without `tutoring.activity.manage`.
    • `meta.summary` counts the WHOLE set, not the page, which is why the
      KPI tiles read from it rather than from the loaded rows.

  CONTRACT DIFFERENCES vs the legacy v1 view — still true:

  1. v1 called `GET /tutoring/activities`, a TENANT-WIDE index with no
     student scoping. The v2 feed is the child's own enrolled groups, so
     activities from a group the child is NOT in no longer appear. That
     is the correct behaviour, but it IS a change from v1.
  2. Activity kinds changed with the module: v1 `ASSIGNMENT | EXAM |
     MATERIAL`; v2 `tugas | kuis | materi_baca` (see `ActivityKind`).
     The filter chip enumerates `ACTIVITY_KINDS`, so a fourth kind is a
     one-line change on both sides.
  3. v1 submission statuses were `ASSIGNED | LATE | MISSED | SUBMITTED |
     GRADED`. v2 has only `draft | submitted | graded` — there is no
     server-side "late"/"missed", so the legacy red LATE pill is not
     ported. Lateness is derived client-side from `due_at` for a row with
     no submission, and rendered as the "belum dikumpulkan" pseudo-status.
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
import { SubmissionsService } from '@/services/tutoring2/submissions';
import {
  ACTIVITY_KINDS,
  type Activity,
  type ActivityKind,
  type StudentActivityRow,
  type StudentSubmissionsSummary,
} from '@/types/tutoring2/activity';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();

/** Child scope — same mechanism as every other parent/tutoring2 view. */
const studentId = String(route.params.studentId ?? '');

/**
 * Rows per request. The server answers in a flat number of queries, so
 * this is a transport size, not a fan-out budget — and PAGE_LIMIT below
 * bounds the walk rather than silently truncating the numbers.
 */
const PER_PAGE = 200;

/** Walk at most this many pages (PER_PAGE * PAGE_LIMIT rows). */
const PAGE_LIMIT = 5;

/** The view's own row type is the wire row — no remapping needed. */
type ActivityRow = StudentActivityRow;

interface Worklist {
  rows: ActivityRow[];
  /** Counts across the WHOLE set, even when the walk stopped early. */
  summary: StudentSubmissionsSummary;
  /** True when PAGE_LIMIT cut the walk short — the LIST is partial. */
  truncated: boolean;
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

const EMPTY_SUMMARY: StudentSubmissionsSummary = {
  total: 0,
  missing: 0,
  submitted: 0,
  graded: 0,
  pending: 0,
};

// `Worklist | null`, not `Worklist`, and the null matters: useDataRefresh
// decides `status: 'empty'` via `isEmpty()`, which only recognises null,
// undefined, or an EMPTY ARRAY. This loader returns an object, so a
// worklist with zero rows would count as `content` and AsyncView would
// render its content branch over nothing — the "belum ada aktivitas"
// empty state would never appear for a newly enrolled child.
const { state, reload } = useDataRefresh<Worklist | null>(async () => {
  if (!studentId) return null;

  // One request per page, and each row already carries THIS child's own
  // submission. See the file header for the bug the old fan-out caused.
  const first = await SubmissionsService.listByStudent(studentId, {
    per_page: PER_PAGE,
  });

  // Genuinely nothing to show — hand back null so AsyncView renders its
  // empty state rather than an empty content branch.
  if (first.total === 0) return null;

  const rows = [...first.items];
  const pages = Math.min(first.lastPage, PAGE_LIMIT);
  for (let page = 2; page <= pages; page++) {
    const next = await SubmissionsService.listByStudent(studentId, {
      per_page: PER_PAGE,
      page,
    });
    rows.push(...next.items);
  }

  return {
    rows: rows.sort((a, b) => compareByDue(a.activity, b.activity)),
    // Straight from the server, so the KPI tiles describe every activity
    // even in the (unreached in practice) case where the walk stopped.
    summary: first.summary,
    truncated: first.lastPage > PAGE_LIMIT,
  };
});

const worklist = computed<Worklist | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as Worklist | undefined) ?? null)
    : null,
);

const rows = computed<ActivityRow[]>(() => worklist.value?.rows ?? []);
const summary = computed<StudentSubmissionsSummary>(
  () => worklist.value?.summary ?? EMPTY_SUMMARY,
);
const isTruncated = computed(() => worklist.value?.truncated ?? false);

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
  // total / pending / graded come from meta.summary, which the server
  // computes over the WHOLE set. They were previously counted from the
  // loaded rows, which meant the tiles inherited the fan-out's cap and
  // under-reported alongside it.
  const s = summary.value;
  // Overdue is the one tile with no server-side counterpart: it needs
  // due_at compared against the viewer's own clock. Derived from loaded
  // rows, so it is exact unless `isTruncated` — the template says so.
  const overdue = rows.value.filter((r) => {
    if (r.submission !== null) return false;
    const days = daysUntilDue(r.activity);
    return days !== null && days < 0;
  }).length;
  return [
    {
      icon: 'clipboard',
      label: t('tutoring2.parent.activities.kpiTotal'),
      value: String(s.total),
    },
    {
      icon: 'clock',
      label: t('tutoring2.parent.activities.kpiPending'),
      value: String(s.pending),
      tone: 'amber',
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.parent.activities.kpiGraded'),
      value: String(s.graded),
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

    <!--
      A partial list must never look complete. The KPI tiles above stay
      exact (they read meta.summary, which the server computes over the
      whole set), but the scrollable list below stops at PAGE_LIMIT
      pages, so say so rather than letting the parent assume they have
      seen everything. Unreachable for any realistic child; the previous
      version of this screen truncated silently, which is the failure
      this notice exists to prevent.
    -->
    <p
      v-if="isTruncated"
      class="rounded-lg bg-amber-50 px-md py-sm text-2xs text-amber-800 dark:bg-amber-950/40 dark:text-amber-200"
    >
      {{ t('tutoring2.parent.activities.truncated', { shown: rows.length, total: summary.total }) }}
    </p>

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

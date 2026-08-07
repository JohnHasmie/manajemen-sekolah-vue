<!--
  ParentTutoring2SessionsView.vue — one child's bimbel session ledger
  (CLEAN-2 Phase 2 · greenfield replacement for the legacy
  `parent/tutoring/ParentSessionsView.vue`).

  Route: /parent/tutoring2/sessions/:studentId
  Endpoints:
    GET /tutoring-v2/enrollments?student_id=…  — resolve the child's
                                                 learning group(s)
    GET /tutoring-v2/sessions?learning_group_id=…&from=&to=
                                               — that group's sessions

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. There is NO child-scoped schedule route in v2. The legacy view
     called `GET /tutoring/schedule?student_id=…` (v1-only, ungated,
     being retired). v2 sessions are addressed by LEARNING GROUP, so we
     do the two-hop the Flutter app does for the same screen: read the
     child's enrollments to get `learning_group_id`, then list each
     group's sessions and merge. If BE later ships
     `GET /tutoring-v2/students/{id}/schedule` this collapses to one
     call — reported under V2_GAPS.

  2. Sorted NEWEST-FIRST (the legacy view sorted ascending). Day groups
     descend too, so "hari ini" sits at the top and history runs down.

  3. The legacy calendar toggle (<SessionsCalendar>) is NOT ported. That
     component's props are typed against the legacy `TutoringSession`
     shape from `@/types/tutoring`, and importing it here would pin the
     very type tree CLEAN-2 exists to delete. This is a UI simplification,
     not a missing backend capability: a v2-typed calendar can be added
     later against the same `BimbelSession[]` this view already holds.

  4. Attendance ("hadir / alpa") is deliberately absent. v1 denormalised
     an `attended` flag onto each schedule row; the v2 SessionResource
     does not carry it, and per-student attendance lives behind
     `GET /tutoring-v2/sessions/{id}/attendance` (one call per session —
     an N-request fan-out this list must not do). The wali's attendance
     history already has its own screen:
     `parent.tutoring2.attendance`. Rows here show SESSION status only.

  Ability note: a wali holds `tutoring.session.view` and
  `tutoring.enrollment.view_own`, so both calls above are legitimately
  reachable — the enrollment index scopes itself to owned children
  server-side. We do NOT call `/learning-groups` (gated on
  `tutoring.group.view`, which a wali lacks); group display names come
  denormalised on the session + enrollment resources instead.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import SegmentedControl, {
  type SegmentOption,
} from '@/components/filters/SegmentedControl.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { toLocalYmd } from '@/lib/local-date';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();

/** Child scope — same mechanism as ParentTutoring2AttendanceView. */
const studentId = computed(() => String(route.params.studentId ?? ''));

// Fetch window, mirroring the legacy view: a month of history plus two
// months ahead. Wide enough for "kapan sesi berikutnya" without pulling
// a year of rows onto a phone.
const WINDOW_PAST_DAYS = 30;
const WINDOW_FUTURE_DAYS = 60;

/**
 * Day offset built from LOCAL calendar parts — never
 * `toISOString().slice(0,10)`, which is UTC and hands a WIB user the
 * previous day for the first 7 hours.
 */
function localYmdOffset(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return toLocalYmd(d);
}

// Side-channel display data the session rows don't carry: which child
// this is, and how many enrollments backed the fetch.
const childName = ref<string | null>(null);
const groupCount = ref(0);

const { state, reload } = useDataRefresh<BimbelSession[]>(async () => {
  const sid = studentId.value;
  childName.value = null;
  groupCount.value = 0;
  if (!sid) return [];

  // Hop 1 — the child's enrollments (server scopes to owned children).
  const { items: enrollments } = await TutoringBimbelService.listEnrollments({
    student_id: sid,
    per_page: 100,
  });
  childName.value = enrollments.find((e) => e.student_name)?.student_name ?? null;

  const groupIds = [
    ...new Set(
      enrollments
        .map((e) => e.learning_group_id)
        .filter((id): id is string => Boolean(id)),
    ),
  ];
  groupCount.value = groupIds.length;
  if (groupIds.length === 0) return [];

  // Hop 2 — sessions per group, in parallel, bounded by the window.
  const from = localYmdOffset(-WINDOW_PAST_DAYS);
  const to = localYmdOffset(WINDOW_FUTURE_DAYS);
  const pages = await Promise.all(
    groupIds.map((id) =>
      TutoringBimbelService.listSessions({
        learning_group_id: id,
        from,
        to,
        per_page: 100,
      }),
    ),
  );
  return pages.flatMap((p) => p.items);
});

// The route param is the only input to the loader, so re-run on change.
watch(studentId, () => {
  void reload();
});

const allSessions = computed<BimbelSession[]>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as BimbelSession[] | undefined) ?? [])
    : [],
);

// ── Group filter ──────────────────────────────────────────────────
// A child can sit in several groups (e.g. Matematika + Bahasa Inggris).
// Replaces the legacy "subject" chips, which read `subject` off a v1-only
// denormalised field; v2 gives us `learning_group_name` instead.
const ALL_GROUPS = 'all';
const groupFilter = ref<string>(ALL_GROUPS);

function groupLabel(s: BimbelSession): string {
  return s.learning_group_name ?? `${t('tutoring2.common.group')} ${s.learning_group_id.slice(0, 8)}`;
}

const groupOptions = computed<SegmentOption[]>(() => {
  const seen = new Map<string, string>();
  for (const s of allSessions.value) {
    if (!seen.has(s.learning_group_id)) seen.set(s.learning_group_id, groupLabel(s));
  }
  return [
    { key: ALL_GROUPS, label: t('tutoring2.common.all') },
    ...[...seen.entries()].map(([key, label]) => ({ key, label })),
  ];
});

// Reset a stale selection when the child (and therefore the group set)
// changes, otherwise the list silently renders empty.
watch(allSessions, () => {
  if (
    groupFilter.value !== ALL_GROUPS &&
    !allSessions.value.some((s) => s.learning_group_id === groupFilter.value)
  ) {
    groupFilter.value = ALL_GROUPS;
  }
});

// ── Filter + sort (newest first) ──────────────────────────────────
const visibleSessions = computed<BimbelSession[]>(() => {
  const list =
    groupFilter.value === ALL_GROUPS
      ? [...allSessions.value]
      : allSessions.value.filter((s) => s.learning_group_id === groupFilter.value);
  // ISO-8601 strings from the same timezone sort lexicographically.
  return list.sort((a, b) => b.starts_at.localeCompare(a.starts_at));
});

// ── Day grouping (descending, matching the sort above) ────────────
interface DayGroup {
  key: string;
  label: string;
  items: BimbelSession[];
}

function dayKey(d: Date): string {
  // Local calendar parts — see the toLocalYmd rationale above.
  return toLocalYmd(d);
}

function dayLabel(d: Date): string {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  const start = new Date(d);
  start.setHours(0, 0, 0, 0);

  const dateText = d.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
  });
  if (start.getTime() === today.getTime()) {
    return t('tutoring2.parent.sessions.dayToday', { date: dateText });
  }
  if (start.getTime() === tomorrow.getTime()) {
    return t('tutoring2.parent.sessions.dayTomorrow', { date: dateText });
  }
  return dateText;
}

const dayGroups = computed<DayGroup[]>(() => {
  const map = new Map<string, DayGroup>();
  for (const s of visibleSessions.value) {
    const d = new Date(s.starts_at);
    if (Number.isNaN(d.getTime())) continue;
    const key = dayKey(d);
    let g = map.get(key);
    if (!g) {
      g = { key, label: dayLabel(d), items: [] };
      map.set(key, g);
    }
    g.items.push(s);
  }
  return [...map.values()];
});

// ── KPIs ──────────────────────────────────────────────────────────
function startOfWeek(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - d.getDay());
  return d;
}

const kpiCards = computed<KpiCard[]>(() => {
  const list = allSessions.value;
  const weekStart = startOfWeek().getTime();
  const weekEnd = weekStart + 7 * 86_400_000;
  const now = new Date();
  const thisWeek = list.filter((s) => {
    const ms = new Date(s.starts_at).getTime();
    return !Number.isNaN(ms) && ms >= weekStart && ms < weekEnd;
  }).length;
  const thisMonth = list.filter((s) => {
    const d = new Date(s.starts_at);
    return (
      !Number.isNaN(d.getTime()) &&
      d.getFullYear() === now.getFullYear() &&
      d.getMonth() === now.getMonth()
    );
  }).length;
  const done = list.filter((s) => s.status === 'done').length;
  const upcoming = list.filter(
    (s) => s.status === 'scheduled' && new Date(s.starts_at).getTime() >= Date.now(),
  ).length;
  return [
    {
      icon: 'calendar',
      label: t('tutoring2.common.thisWeek'),
      value: String(thisWeek),
      tone: 'brand',
    },
    {
      icon: 'calendar-check',
      label: t('tutoring2.common.thisMonth'),
      value: String(thisMonth),
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.parent.sessions.kpiDone'),
      value: String(done),
      tone: 'green',
    },
    {
      icon: 'clock',
      label: t('tutoring2.parent.sessions.kpiUpcoming'),
      value: String(upcoming),
      tone: 'amber',
    },
  ];
});

const metaLabel = computed(() => {
  if (state.value.status === 'loading') return t('tutoring2.common.loading');
  return t('tutoring2.parent.sessions.meta', {
    child: childName.value ?? t('tutoring2.common.student'),
    groups: groupCount.value,
    count: visibleSessions.value.length,
  });
});

// ── Formatting + status ───────────────────────────────────────────
function formatTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
}

function durationMinutes(s: BimbelSession): number | null {
  const start = new Date(s.starts_at).getTime();
  const end = new Date(s.ends_at).getTime();
  if (Number.isNaN(start) || Number.isNaN(end) || end <= start) return null;
  return Math.round((end - start) / 60_000);
}

function subtitle(s: BimbelSession): string {
  return (
    [s.tutor_name, s.room].filter(Boolean).join(' · ') ||
    t('tutoring2.common.noRoom')
  );
}

function statusLabel(status: BimbelSession['status']): string {
  switch (status) {
    case 'done':
      return t('tutoring2.status.done');
    case 'in_progress':
      return t('tutoring2.status.inProgress');
    case 'cancelled':
      return t('tutoring2.status.cancelled');
    case 'scheduled':
      return t('tutoring2.status.scheduled');
  }
}

/**
 * Session-status → tone. Kept byte-identical to `sessionTone` in
 * TutorTutoring2SessionsView and `statusPillTone` in
 * AdminTutoring2ScheduleView so one session reads the same colour to
 * wali, tutor and admin. If you change one, change all three.
 *
 * (Note the sibling ParentTutoring2AttendanceView maps these same four
 * values differently on purpose — there they stand in for PRESENCE
 * buckets, not for the session's own lifecycle.)
 */
function statusTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'done':
      return 'success';
    case 'in_progress':
      return 'info';
    case 'scheduled':
      return 'neutral';
    case 'cancelled':
      return 'danger';
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.sessions.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <SegmentedControl
      v-if="groupOptions.length > 2"
      v-model="groupFilter"
      :options="groupOptions"
    />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.parent.sessions.emptyTitle')"
      :empty-description="t('tutoring2.parent.sessions.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="space-y-4">
          <section v-for="g in dayGroups" :key="g.key">
            <p class="mb-1.5 text-2xs font-bold uppercase tracking-wide text-slate-400">
              {{ g.label }}
            </p>
            <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
              <ul class="divide-y divide-slate-100">
                <li
                  v-for="s in g.items"
                  :key="s.id"
                  class="flex items-center gap-3 px-4 py-3"
                >
                  <div class="w-16 shrink-0">
                    <p class="text-sm font-bold text-slate-900 tabular-nums">
                      {{ formatTime(s.starts_at) }}
                    </p>
                    <p class="text-2xs text-slate-500">
                      <template v-if="durationMinutes(s) != null">
                        {{
                          t('tutoring2.parent.sessions.durationMinutes', {
                            count: durationMinutes(s),
                          })
                        }}
                      </template>
                      <template v-else>—</template>
                    </p>
                  </div>
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-sm font-bold text-slate-900">
                      {{ groupLabel(s) }}
                    </p>
                    <p class="truncate text-2xs text-slate-500">{{ subtitle(s) }}</p>
                  </div>
                  <StatusBadge
                    :label="statusLabel(s.status)"
                    :tone="statusTone(s.status)"
                    uppercase
                  />
                </li>
              </ul>
            </div>
          </section>

          <!--
            `dayGroups` can be empty while the fetch itself returned rows
            (the group filter hid them all), so AsyncView's own empty
            branch never fires here.
          -->
          <p
            v-if="dayGroups.length === 0"
            class="rounded-3xl border border-slate-100 bg-white px-4 py-8 text-center text-sm text-slate-500 shadow-sm"
          >
            {{ t('tutoring2.parent.sessions.filterEmpty') }}
          </p>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

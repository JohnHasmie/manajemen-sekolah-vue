<!--
  AdminTutoring2ActivityReportView.vue — greenfield "Laporan Aktivitas"
  admin screen (WEB-15). Reads `GET /tutoring-v2/admin/reports/activity`
  and exposes:

    - Date-range picker (from / to). Defaults to the last 30 days,
      computed via toLocalYmd() so we don't drift a day at midnight WIB.
    - "Unduh PDF" — jumps to the BE-28 PDF endpoint via window.open,
      cookie-auth carries the SPA session.
    - "Unduh CSV" — client-side CSV via csvFrom + downloadCsv.
    - KPI strip with the totals across the range.
    - Table: date, sessions_scheduled, sessions_completed,
      sessions_cancelled, attendance_marked_count.

  Ability gate on the route is `dashboard.admin.view` — same key the
  backend controller uses.

  ── Row → that day's sessions ────────────────────────────────────────

  A report row is a CALENDAR DAY, not an activity: `ActivityReportRow`
  is `{date, sessions_*, attendance_marked_count}` and carries no id of
  any kind, because `AdminReportController::activityRows` groups by
  `starts_at::date`. So there is no "this activity's detail" to open —
  the only thing the row identifies is the day, and the drill-in is
  therefore "the sessions ON that day", from which the existing session
  detail is one more click away.

  Until now every `<tr>` carried `hover:bg-slate-50` and no handler
  whatsoever, so the whole table advertised itself as clickable and none
  of it was. That is almost certainly what was actually reported. The
  hover now travels WITH the handler, so it is honest per row — a day
  with zero sessions, and a reader without the destination's ability,
  both render flat and inert rather than lighting up under the cursor
  and then doing nothing.

  ── Why the gate is `tutoring.session.view`, not this page's key ─────

  The two do not nest. This report authorizes on `dashboard.admin.view`
  (`AdminReportController::activity`); the destination list authorizes
  on `tutoring.session.view` (`SessionController::index`). The latter is
  held by tutor / wali / siswa as well as admin, and a staff tier can
  hold one without the other, so "they got this far" proves nothing
  about the next screen. Gate on where the click LANDS.

  ── The date is passed through verbatim ─────────────────────────────

  `r.date` is already the `YYYY-MM-DD` the backend bucketed on. It is
  handed to the query untouched — no `new Date(...)`, no
  `toISOString().slice(0, 10)` — so there is no instant for a timezone
  to shift. The exclusive-end arithmetic the sessions endpoint needs
  (`starts_at < to`) is done once, on the receiving side, through
  `addDays()`. See AdminTutoring2ScheduleView.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { toLocalYmd } from '@/lib/local-date';
import {
  csvFrom,
  downloadCsv,
  TutoringReportsService,
} from '@/services/tutoring2/reports';
import type { ActivityReportRow } from '@/types/tutoring2/report';

const { t } = useI18n();
const router = useRouter();

// ── Drill-in gate ────────────────────────────────────────────────────
// Read off the /me snapshot (scoped by X-Active-Role) via useMe().can —
// never `roles[].permission_keys`, which is unscoped and exists only for
// the role switcher.
const { can } = useMe();
const canViewSessions = computed(() => can('tutoring.session.view'));

// ── Range state ───────────────────────────────────────────────────────
// Defaults to [today-29d, today] = 30 calendar days inclusive. Using
// toLocalYmd() avoids the UTC-slice bug documented in local-date.ts.
const today = new Date();
const startOfRange = new Date(today);
startOfRange.setDate(startOfRange.getDate() - 29);
const from = ref<string>(toLocalYmd(startOfRange));
const to = ref<string>(toLocalYmd(today));

// ── Data ──────────────────────────────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  const res = await TutoringReportsService.getActivityReport({
    from: from.value,
    to: to.value,
  });
  return res.rows;
});

watch([from, to], () => {
  if (from.value && to.value && from.value <= to.value) reload();
});

const rows = computed<ActivityReportRow[]>(() =>
  state.value.status === 'content' ? (state.value.data as ActivityReportRow[]) : [],
);

// ── KPI totals across the range ──────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const list = rows.value;
  const totalScheduled = list.reduce((s, r) => s + r.sessions_scheduled, 0);
  const totalCompleted = list.reduce((s, r) => s + r.sessions_completed, 0);
  const totalCancelled = list.reduce((s, r) => s + r.sessions_cancelled, 0);
  const totalAttendance = list.reduce((s, r) => s + r.attendance_marked_count, 0);
  return [
    {
      icon: 'calendar',
      label: t('tutoring2.admin.reports.activity.kpiScheduled'),
      value: String(totalScheduled),
    },
    {
      icon: 'circle-check',
      label: t('tutoring2.admin.reports.activity.kpiCompleted'),
      value: String(totalCompleted),
      tone: totalCompleted > 0 ? 'green' : undefined,
    },
    {
      icon: 'x',
      label: t('tutoring2.admin.reports.activity.kpiCancelled'),
      value: String(totalCancelled),
      tone: totalCancelled > 0 ? 'red' : undefined,
    },
    {
      icon: 'users',
      label: t('tutoring2.admin.reports.activity.kpiAttendance'),
      value: String(totalAttendance),
    },
  ];
});

// ── Row → that day's sessions ────────────────────────────────────────

/**
 * Whether THIS row can be opened.
 *
 * Two independent reasons a row cannot, and the affordance has to match
 * BOTH — a row that lights up under the cursor and then does nothing is
 * the defect this screen is being fixed for, and it does not stop being
 * one just because the reason changed:
 *
 *   1. No sessions that day. `sessions_scheduled` counts ANY session in
 *      the day's bucket regardless of lifecycle state (completed and
 *      cancelled are subsets of it), so zero here means the destination
 *      list would be genuinely empty. Sending a reader to an empty
 *      screen is a worse answer than the row simply not being a link.
 *   2. No `tutoring.session.view`. See the docblock: this page's own
 *      `dashboard.admin.view` does not imply it.
 */
function canOpenDay(row: ActivityReportRow): boolean {
  return canViewSessions.value && row.sessions_scheduled > 0;
}

/**
 * Opens the admin session list, narrowed to this row's day.
 *
 * `date` travels as the raw `YYYY-MM-DD` off the wire — see the
 * docblock for why nothing here builds a Date.
 *
 * Guarded rather than merely un-bound in the template: `canOpenDay`
 * decides both the handler and the affordance from one place, so the
 * two cannot drift into a row that looks inert but still navigates on
 * an Enter keypress.
 */
function openDay(row: ActivityReportRow) {
  if (!canOpenDay(row)) return;
  router.push({
    name: 'admin.tutoring2.schedule',
    query: { date: row.date },
  });
}

/** The row's own explanation of why it is (or is not) a link. */
function rowTitle(row: ActivityReportRow): string {
  if (canOpenDay(row)) return t('tutoring2.admin.reports.activity.openDay');
  if (row.sessions_scheduled === 0) {
    return t('tutoring2.admin.reports.activity.noSessionsThatDay');
  }
  return t('tutoring2.admin.reports.activity.openDayForbidden');
}

// ── Downloads ────────────────────────────────────────────────────────
function downloadPdf() {
  const url = TutoringReportsService.buildActivityReportPdfUrl({
    from: from.value,
    to: to.value,
  });
  // window.open in a new tab so the current view stays put and the
  // print dialog opens over an empty page (nicer UX than replacing the
  // admin view with a raw PDF viewer).
  window.open(url, '_blank', 'noopener');
}

function exportCsv() {
  const csv = csvFrom(rows.value as unknown as Record<string, unknown>[], [
    { key: 'date', header: t('tutoring2.common.date') },
    { key: 'sessions_scheduled', header: t('tutoring2.admin.reports.activity.colScheduled') },
    { key: 'sessions_completed', header: t('tutoring2.admin.reports.activity.colCompleted') },
    { key: 'sessions_cancelled', header: t('tutoring2.admin.reports.activity.colCancelled') },
    { key: 'attendance_marked_count', header: t('tutoring2.admin.reports.activity.colAttendance') },
  ]);
  downloadCsv(csv, `laporan-aktivitas-${from.value}_${to.value}.csv`);
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.reports.activity.title')"
      :meta="
        state.status === 'content'
          ? t('tutoring2.admin.reports.meta', { count: rows.length })
          : t('tutoring2.common.loading')
      "
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <!--
      Custom range + download toolbar. PageFilterToolbar isn't quite
      the right shape here (no #actions slot; search doesn't apply to
      a rollup report) so we compose the section inline while keeping
      the same "white card, thin slate border, rounded" look.
    -->
    <section class="bg-white border border-slate-200 rounded-2xl p-3">
      <div class="flex items-center gap-2 flex-wrap">
        <label class="inline-flex items-center gap-2 text-sm font-medium text-slate-600">
          <span>{{ t('tutoring2.admin.reports.from') }}</span>
          <input
            v-model="from"
            type="date"
            class="rounded-xl border border-slate-200 px-3 py-2 text-sm"
          />
        </label>
        <label class="inline-flex items-center gap-2 text-sm font-medium text-slate-600">
          <span>{{ t('tutoring2.admin.reports.to') }}</span>
          <input
            v-model="to"
            type="date"
            class="rounded-xl border border-slate-200 px-3 py-2 text-sm"
          />
        </label>
        <span class="flex-1"></span>
        <Button variant="secondary" size="sm" @click="exportCsv">
          {{ t('tutoring2.admin.reports.downloadCsv') }}
        </Button>
        <Button variant="primary" size="sm" @click="downloadPdf">
          {{ t('tutoring2.admin.reports.downloadPdf') }}
        </Button>
      </div>
    </section>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.reports.activity.emptyTitle')"
      :empty-description="t('tutoring2.admin.reports.activity.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.date') }}</th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.activity.colScheduled') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.activity.colCompleted') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.activity.colCancelled') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.activity.colAttendance') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <!--
                The affordance is conditional on `canOpenDay(r)`, not
                blanket: cursor, hover, focus ring, `tabindex` and
                `role="link"` all appear together or not at all. Keyboard
                reachability comes with them because a `<tr>` is not
                focusable on its own and the row is the only control
                here — same shape as AdminTutoring2ScheduleView's row.
              -->
              <tr
                v-for="r in rows"
                :key="r.date"
                data-testid="activity-row"
                :data-can-open="canOpenDay(r) ? 'true' : 'false'"
                :tabindex="canOpenDay(r) ? 0 : undefined"
                :role="canOpenDay(r) ? 'link' : undefined"
                :aria-label="canOpenDay(r) ? t('tutoring2.admin.reports.activity.openDay') : undefined"
                :title="rowTitle(r)"
                class="border-b border-slate-100 last:border-0"
                :class="
                  canOpenDay(r)
                    ? 'cursor-pointer hover:bg-slate-50 focus:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-cobalt'
                    : ''
                "
                @click="openDay(r)"
                @keydown.enter.prevent="openDay(r)"
                @keydown.space.prevent="openDay(r)"
              >
                <td class="px-4 py-3 font-semibold text-slate-900">{{ r.date }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.sessions_scheduled }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.sessions_completed }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.sessions_cancelled }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.attendance_marked_count }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

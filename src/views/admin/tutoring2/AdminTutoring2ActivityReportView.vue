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
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { toLocalYmd } from '@/lib/local-date';
import {
  csvFrom,
  downloadCsv,
  TutoringReportsService,
} from '@/services/tutoring2/reports';
import type { ActivityReportRow } from '@/types/tutoring2/report';

const { t } = useI18n();

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
              <tr
                v-for="r in rows"
                :key="r.date"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
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

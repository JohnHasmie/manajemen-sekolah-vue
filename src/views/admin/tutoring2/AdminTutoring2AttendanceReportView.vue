<!--
  AdminTutoring2AttendanceReportView.vue — greenfield "Laporan Kehadiran"
  admin screen (WEB-15). Reads
  `GET /tutoring-v2/admin/reports/attendance` and renders one row per
  enrollment across the picked range.

  Columns: student_name, program_name, sessions_planned, hadir, izin,
  sakit, alpa, attendance_rate (rendered as %).
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
import type { AttendanceReportRow } from '@/types/tutoring2/report';

const { t } = useI18n();

const today = new Date();
const startOfRange = new Date(today);
startOfRange.setDate(startOfRange.getDate() - 29);
const from = ref<string>(toLocalYmd(startOfRange));
const to = ref<string>(toLocalYmd(today));

const { state, reload } = useDataRefresh(async () => {
  const res = await TutoringReportsService.getAttendanceReport({
    from: from.value,
    to: to.value,
  });
  return res.rows;
});

watch([from, to], () => {
  if (from.value && to.value && from.value <= to.value) reload();
});

const rows = computed<AttendanceReportRow[]>(() =>
  state.value.status === 'content' ? (state.value.data as AttendanceReportRow[]) : [],
);

// ── KPI totals ────────────────────────────────────────────────────────
// Roll-up rate is a MICRO-average across all attendance rows (not a
// mean of per-enrollment rates) — a student with 20 sessions weighs
// more than one with 2. Matches how the BE renders the same metric
// in AdminStatsController.
const kpiCards = computed<KpiCard[]>(() => {
  const list = rows.value;
  const totalStudents = list.length;
  const sumHadir = list.reduce((s, r) => s + r.hadir, 0);
  const sumMarked = list.reduce((s, r) => s + r.hadir + r.izin + r.sakit + r.alpa, 0);
  const overallRate = sumMarked > 0 ? Math.round((sumHadir / sumMarked) * 100) : 0;
  const totalPlanned = list.reduce((s, r) => s + r.sessions_planned, 0);
  return [
    {
      icon: 'users',
      label: t('tutoring2.admin.reports.attendance.kpiStudents'),
      value: String(totalStudents),
    },
    {
      icon: 'calendar',
      label: t('tutoring2.admin.reports.attendance.kpiPlanned'),
      value: String(totalPlanned),
    },
    {
      icon: 'circle-check',
      label: t('tutoring2.admin.reports.attendance.kpiHadir'),
      value: String(sumHadir),
      tone: sumHadir > 0 ? 'green' : undefined,
    },
    {
      icon: 'chart-bar',
      label: t('tutoring2.admin.reports.attendance.kpiRate'),
      value: `${overallRate}%`,
      tone: overallRate >= 80 ? 'green' : overallRate >= 60 ? 'amber' : 'red',
    },
  ];
});

function pctLabel(rate: number): string {
  return `${Math.round(rate * 100)}%`;
}

function downloadPdf() {
  const url = TutoringReportsService.buildAttendanceReportPdfUrl({
    from: from.value,
    to: to.value,
  });
  window.open(url, '_blank', 'noopener');
}

function exportCsv() {
  // Emit rate as a plain integer percent for Excel readability, keeping
  // the raw decimal accessible via the JSON endpoint if anyone needs it.
  const csvRows = rows.value.map((r) => ({
    student_name: r.student_name,
    program_name: r.program_name,
    sessions_planned: r.sessions_planned,
    hadir: r.hadir,
    izin: r.izin,
    sakit: r.sakit,
    alpa: r.alpa,
    attendance_rate_pct: Math.round(r.attendance_rate * 100),
  }));
  const csv = csvFrom(csvRows, [
    { key: 'student_name', header: t('tutoring2.common.student') },
    { key: 'program_name', header: t('tutoring2.common.program') },
    { key: 'sessions_planned', header: t('tutoring2.admin.reports.attendance.colPlanned') },
    { key: 'hadir', header: t('tutoring2.admin.reports.attendance.colHadir') },
    { key: 'izin', header: t('tutoring2.admin.reports.attendance.colIzin') },
    { key: 'sakit', header: t('tutoring2.admin.reports.attendance.colSakit') },
    { key: 'alpa', header: t('tutoring2.admin.reports.attendance.colAlpa') },
    { key: 'attendance_rate_pct', header: t('tutoring2.admin.reports.attendance.colRate') },
  ]);
  downloadCsv(csv, `laporan-kehadiran-${from.value}_${to.value}.csv`);
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.reports.attendance.title')"
      :meta="
        state.status === 'content'
          ? t('tutoring2.admin.reports.meta', { count: rows.length })
          : t('tutoring2.common.loading')
      "
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

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
      :empty-title="t('tutoring2.admin.reports.attendance.emptyTitle')"
      :empty-description="t('tutoring2.admin.reports.attendance.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.student') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.attendance.colPlanned') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.attendance.colHadir') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.attendance.colIzin') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.attendance.colSakit') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.attendance.colAlpa') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.attendance.colRate') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in rows"
                :key="r.enrollment_id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-semibold text-slate-900">{{ r.student_name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ r.program_name }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.sessions_planned }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.hadir }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.izin }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.sakit }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.alpa }}</td>
                <td class="px-4 py-3 text-right font-semibold text-slate-900">
                  {{ pctLabel(r.attendance_rate) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

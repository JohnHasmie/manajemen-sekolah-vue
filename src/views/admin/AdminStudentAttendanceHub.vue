<!--
  AdminStudentAttendanceHub.vue — admin · Kehadiran Siswa hub (Wave 4 IA merge).

  Thin parent wrapper hosting the dashboard + its two former sibling screens
  under one tabbed view (mirrors the AdminFinanceView parent-route + child-tabs
  pattern):

    Tab "Ringkasan" → admin.student-attendance        (AdminAttendanceDashboardView)
    Tab "Laporan"   → admin.student-attendance.report (AdminAttendanceReportView)
    Tab "Detail"    → admin.student-attendance.detail (AdminAttendanceDetailView)

  STRUCTURAL CHOICE (documented in commit body): the report and detail screens
  each carry independent, query-param-driven state (dates, class_id, subject_id,
  attendance_id…) and cross-navigate to one another AND to detail via named
  routes + query. The dashboard likewise pushes to report/detail with query
  payloads (new-session wizard, "lihat laporan"). Collapsing all three into one
  component with a local `tab` ref would fight over — and drop — those query
  params. So instead of forcing one view, we keep the three EXISTING routes and
  their names intact and host them as <router-view> children under this wrapper.
  Every router.push({ name, query }) between them keeps working verbatim.

  The grade-level heatmap (admin.student-attendance.grade-level/:tingkat) is a
  parametric drill-down, NOT a sibling tab — it stays a standalone route and is
  reached from the dashboard's tingkat cards, untouched.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

interface Tab {
  key: 'summary' | 'report';
  label: string;
  icon: string;
  route: string;
}

const TABS = computed<Tab[]>(() => [
  { key: 'summary', label: t('hubs.studentAttendance.tab_summary'), icon: 'bar-chart', route: 'admin.student-attendance' },
  { key: 'report', label: t('hubs.studentAttendance.tab_report'), icon: 'file-text', route: 'admin.student-attendance.report' },
]);

const activeTab = computed<'summary' | 'report' | 'detail'>(() => {
  const name = String(route.name ?? '');
  if (name.includes('report')) return 'report';
  if (name.includes('detail')) return 'detail';
  return 'summary';
});

function goTab(tab: Tab) {
  if (activeTab.value === tab.key) return;
  router.push({ name: tab.route });
}
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- Tab nav (hidden on detail view) -->
    <nav
      v-if="activeTab !== 'detail'"
      class="bg-white border border-slate-200 rounded-2xl p-1.5 flex items-center gap-1 overflow-x-auto"
      role="tablist"
    >
      <button
        v-for="tab in TABS"
        :key="tab.key"
        type="button"
        role="tab"
        :aria-selected="activeTab === tab.key"
        class="flex-1 inline-flex items-center justify-center gap-2 px-3 py-2 rounded-xl text-[12px] font-bold transition-all"
        :class="
          activeTab === tab.key
            ? 'bg-role-admin text-white shadow'
            : 'text-slate-500 hover:text-slate-900 hover:bg-slate-50'
        "
        @click="goTab(tab)"
      >
        <NavIcon :name="tab.icon" :size="13" />
        {{ tab.label }}
      </button>
    </nav>

    <!-- Active tab body -->
    <router-view />
  </div>
</template>

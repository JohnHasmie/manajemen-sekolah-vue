<!--
  TeacherMyAttendanceHub.vue — Presensi Saya hub (Wave 4 IA merge).

  Thin parent wrapper that hosts the two former sibling screens under one
  tabbed view (mirrors the AdminFinanceView parent-route + child-tabs pattern):

    Tab "Presensi" → *.my-attendance         (TeacherCheckInView)
    Tab "Riwayat"  → *.my-attendance.history (TeacherAttendanceHistoryView)

  Both child components stay 100% intact — this wrapper only renders a tab bar
  above <router-view>. The check-in screen's "lihat riwayat" push and the
  history screen's "back" push keep working unchanged because the route names /
  paths are preserved. Pure reorganization, no behavior change.

  ROLE-SHARED (F3): this exact hub is mounted under BOTH the teacher subtree
  (`teacher.my-attendance*`) and the staff subtree (`staff.my-attendance*`).
  The underlying /teacher-attendance endpoints are staff-aware server-side
  (Phase C), so the same check-in + history screens serve staff unchanged.
  The tab route names and the active-tab tint are derived from the current
  route so no per-role duplicate wrapper is needed.
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
  key: 'check-in' | 'history';
  label: string;
  icon: string;
  route: string;
}

// Staff vs teacher context — drives which subtree's route names the tabs
// point at, and the active-tab tint (teacher teal vs staff amber).
const isStaffContext = computed(() =>
  String(route.name ?? '').startsWith('staff'),
);
const routePrefix = computed(() =>
  isStaffContext.value ? 'staff' : 'teacher',
);

const TABS = computed<Tab[]>(() => [
  { key: 'check-in', label: t('hubs.myAttendance.tab_check_in'), icon: 'camera', route: `${routePrefix.value}.my-attendance` },
  { key: 'history', label: t('hubs.myAttendance.tab_history'), icon: 'clock', route: `${routePrefix.value}.my-attendance.history` },
]);

const activeTab = computed<Tab['key']>(() => {
  const name = String(route.name ?? '');
  if (name.includes('history')) return 'history';
  return 'check-in';
});

function goTab(tab: Tab) {
  if (activeTab.value === tab.key) return;
  router.push({ name: tab.route });
}
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- Tab nav -->
    <nav
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
            ? isStaffContext
              ? 'bg-role-staff text-white shadow'
              : 'bg-role-teacher text-white shadow'
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

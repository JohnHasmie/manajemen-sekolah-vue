<!--
  AdminAnnouncementsHub.vue — admin · Pengumuman hub (Wave 4 IA merge).

  Thin parent wrapper that hosts the two former sibling screens under one
  tabbed view (mirrors the AdminFinanceView parent-route + child-tabs pattern):

    Tab "Daftar"   → admin.announcements          (AdminAnnouncementView)
    Tab "Kalender" → admin.announcements.calendar (AdminAnnouncementCalendarView)

  Both child components stay 100% intact — this wrapper only renders a tab bar
  above <router-view>. Every existing cross-navigation between the two screens
  (the in-list "Kalender" button, the calendar's "back" button) keeps working
  because the route names are unchanged. Pure reorganization, no behavior change.
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
  key: 'list' | 'calendar';
  label: string;
  icon: string;
  route: string;
}

const TABS = computed<Tab[]>(() => [
  { key: 'list', label: t('hubs.announcements.tab_list'), icon: 'list', route: 'admin.announcements' },
  { key: 'calendar', label: t('hubs.announcements.tab_calendar'), icon: 'calendar', route: 'admin.announcements.calendar' },
]);

const activeTab = computed<Tab['key']>(() => {
  const name = String(route.name ?? '');
  if (name.includes('calendar')) return 'calendar';
  return 'list';
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

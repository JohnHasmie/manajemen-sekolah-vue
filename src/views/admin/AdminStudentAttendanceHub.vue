<script setup lang="ts">
/**
 * Admin · Kehadiran Siswa hub — 3-tab redesign (mockup §01-05).
 *
 *   Harian     · per-student per-day roster from QR gate + card + selfie
 *                self-check-in, plus a "Belum absen" reminder card.
 *   Per Mapel  · session-per-row rekap (redesign of the old "Laporan Sesi"),
 *                with a "Belum diinput guru" reminder card.
 *   Rekap &   · monthly per-student calendar grid + Pusat Export.
 *   Laporan
 *
 * The three former standalone routes (`admin.student-attendance` /
 * `.report` / `.grade-level`) still resolve — but as thin wrappers that
 * flip this hub's `tab` state. Session-detail (`admin.student-attendance.detail`)
 * stays as its own route so the deep-link doesn't render the hub chrome
 * around a fullscreen editor.
 */
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

import HarianTab from '@/views/admin/attendance/HarianTab.vue';
import PerMapelTab from '@/views/admin/attendance/PerMapelTab.vue';
import RekapTab from '@/views/admin/attendance/RekapTab.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

type TabKey = 'harian' | 'per-mapel' | 'rekap';

const TABS: readonly { key: TabKey; label: string; icon: string; kicker: string }[] = [
  { key: 'harian', label: 'Harian', icon: 'calendar', kicker: 'Kehadiran · Harian' },
  { key: 'per-mapel', label: 'Per Mapel', icon: 'book', kicker: 'Kehadiran · Per Mapel' },
  { key: 'rekap', label: 'Rekap & Laporan', icon: 'bar-chart', kicker: 'Kehadiran · Rekap Bulanan' },
];

/** Route → tab map. Old route names still resolve here for backwards-
 * compat with anywhere that pushes them by name (Dashboard, Report, etc.).
 * The new URL uses ?tab=. */
function tabForRoute(): TabKey {
  const q = String(route.query.tab ?? '').toLowerCase();
  if (q === 'harian' || q === 'per-mapel' || q === 'rekap') return q;
  const name = String(route.name ?? '');
  if (name === 'admin.student-attendance.report') return 'per-mapel';
  if (name === 'admin.student-attendance.grade-level') return 'rekap';
  return 'harian';
}

const tab = ref<TabKey>(tabForRoute());
watch(() => route.fullPath, () => (tab.value = tabForRoute()));

function setTab(next: TabKey) {
  tab.value = next;
  void router.replace({ name: 'admin.student-attendance', query: { tab: next } });
}

const activeKicker = computed(() => TABS.find((t) => t.key === tab.value)?.kicker ?? '');
const todayLabel = computed(() =>
  new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }),
);
</script>

<template>
  <div class="space-y-md pb-2">
    <BrandPageHeader
      role="admin"
      :kicker="activeKicker"
      :title="t('nav.attendance')"
      :meta="todayLabel"
      :live-dot="tab === 'harian'"
    />

    <!-- 3-tab bar -->
    <nav
      class="bg-white border border-slate-200 rounded-2xl p-1.5 flex items-center gap-1 overflow-x-auto"
      role="tablist"
      aria-label="Kehadiran Siswa tabs"
    >
      <button
        v-for="opt in TABS"
        :key="opt.key"
        type="button"
        class="inline-flex items-center gap-2 rounded-xl px-3.5 py-2 text-[12px] font-semibold transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-role-admin/30"
        :class="tab === opt.key ? 'bg-role-admin text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50'"
        :aria-selected="tab === opt.key"
        role="tab"
        @click="setTab(opt.key)"
      >
        <NavIcon :name="opt.icon" :size="15" />
        {{ opt.label }}
      </button>
    </nav>

    <!-- Tab body -->
    <HarianTab v-if="tab === 'harian'" />
    <PerMapelTab v-else-if="tab === 'per-mapel'" />
    <RekapTab v-else-if="tab === 'rekap'" />
  </div>
</template>

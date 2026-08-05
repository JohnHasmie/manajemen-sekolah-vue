<!--
  ParentTutoring2HomeView.vue — Wali bimbel dashboard (WEB-5 exemplar).

  Composition: BrandPageHeader (role="parent") with a tenant-switch
  banner rendered inside the gradient area (the mockup calls it a
  "SchoolPill" — reuses the AppShell topbar equivalent inline).
  All display copy sourced via `t('tutoring2.parent.…')`.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringBimbelService, type BimbelEnrollment } from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();

// MVP: children derived from unique student_id across the parent's
// visible enrollments (backend filters by parent membership on the
// child student rows). TODO WEB-5+ swap to a real /tutoring2/parent/children
// endpoint once it exists.
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({ per_page: 100 });
  return items;
});
useAcademicYearWatcher(reload);

interface ChildRow {
  student_id: string;
  student_name?: string | null;
  student_number?: string | null;
  active_count: number;
  outstanding: number;
}

const children = computed<ChildRow[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  const byStudent = new Map<string, ChildRow>();
  for (const e of items) {
    const row = byStudent.get(e.student_id) ?? {
      student_id: e.student_id,
      student_name: e.student_name,
      student_number: e.student_number,
      active_count: 0,
      outstanding: 0,
    };
    if (e.status === 'active' || e.status === 'trial') row.active_count += 1;
    byStudent.set(e.student_id, row);
  }
  return [...byStudent.values()];
});

const kpiCards = computed<KpiCard[]>(() => {
  return [
    { icon: 'calendar', label: t('tutoring2.parent.home.kpiSessionsWeek'), value: '—' },
    { icon: 'user-check', label: t('tutoring2.parent.home.kpiAttendance'), value: '—', tone: 'green' },
    { icon: 'chart-bar', label: t('tutoring2.parent.home.kpiScoreAvg'), value: '—' },
    { icon: 'cash', label: t('tutoring2.parent.home.kpiOutstanding'), value: '0', tone: 'brand' },
  ];
});

function statusTone(active: number): StatusBadgeTone {
  return active > 0 ? 'success' : 'neutral';
}

function shortId(id: string): string {
  return id.slice(0, 8);
}

function openChild(id: string) {
  router.push({ name: 'parent.tutoring2.attendance', params: { studentId: id } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.home.title')"
    >
      <template #meta>
        <button
          type="button"
          class="mt-2 inline-flex items-center gap-2 rounded-full bg-white/15 px-3 py-1 text-2xs font-bold text-white hover:bg-white/25"
        >
          {{ t('tutoring2.parent.home.tenant') }}: Bimbel Cendekia
          <span class="rounded-full bg-white/90 px-2 py-0.5 text-2xs font-bold text-brand-azure-deep">{{ t('tutoring2.parent.home.switchTenant') }}</span>
        </button>
      </template>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="2"
      :empty-title="t('tutoring2.parent.home.emptyTitle')"
      :empty-description="t('tutoring2.parent.home.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <header class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
            <h3 class="text-sm font-bold text-slate-900">{{ t('tutoring2.parent.home.pickChild') }}</h3>
          </header>
          <ul class="divide-y divide-slate-100">
            <li
              v-for="c in children"
              :key="c.student_id"
              class="flex cursor-pointer items-center gap-3 px-4 py-3 hover:bg-slate-50"
              @click="openChild(c.student_id)"
            >
              <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-azure/10 text-xs font-bold uppercase text-brand-azure">
                {{ (c.student_name ?? c.student_id).slice(0, 2).toUpperCase() }}
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">{{ c.student_name ?? `${t('tutoring2.common.studentId')} ${shortId(c.student_id)}` }}</p>
                <p class="truncate text-2xs text-slate-500">
                  {{ c.active_count }} {{ t('tutoring2.common.metaEnrollments', { count: c.active_count }).replace(String(c.active_count), '').trim() }}
                </p>
              </div>
              <StatusBadge :label="c.active_count > 0 ? t('tutoring2.status.active') : t('tutoring2.status.paused')" :tone="statusTone(c.active_count)" uppercase />
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

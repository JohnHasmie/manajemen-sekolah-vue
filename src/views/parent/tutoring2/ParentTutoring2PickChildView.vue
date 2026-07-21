<!--
  ParentTutoring2PickChildView.vue — Wali picks a linked child (WEB-5).

  Composition:
    1. BrandPageHeader (role="parent") — no meta line.
    2. AsyncView → rounded-3xl surface with divide-y child rows.

  MVP: no dedicated /parent/children endpoint yet; children are derived
  from unique student_id across TutoringBimbelService.listEnrollments
  (same pattern as ParentTutoring2HomeView). TODO WEB-5+ swap to a real
  /tutoring2/parent/children endpoint once BE ships it.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();

// MVP: derive children from unique student_id in enrollments — parent
// only sees rows whose students they are linked to (backend enforces).
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({ per_page: 100 });
  return items;
});
useAcademicYearWatcher(reload);

interface ChildRow {
  student_id: string;
  active_count: number;
}

const children = computed<ChildRow[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  const byStudent = new Map<string, ChildRow>();
  for (const e of items) {
    const row = byStudent.get(e.student_id) ?? { student_id: e.student_id, active_count: 0 };
    if (e.status === 'active' || e.status === 'trial') row.active_count += 1;
    byStudent.set(e.student_id, row);
  }
  return [...byStudent.values()];
});

function openChild(studentId: string) {
  router.push({ name: 'parent.tutoring2.attendance', params: { studentId } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.pickChild.title')"
    />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="3"
      :empty-title="t('tutoring2.parent.pickChild.emptyTitle')"
      :empty-description="t('tutoring2.parent.pickChild.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="c in children"
              :key="c.student_id"
              class="flex cursor-pointer items-center gap-3 px-4 py-3 hover:bg-slate-50"
              @click="openChild(c.student_id)"
            >
              <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-azure/10 text-xs font-bold uppercase text-brand-azure">
                {{ c.student_id.slice(0, 2).toUpperCase() }}
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ t('tutoring2.common.studentId') }} {{ c.student_id.slice(0, 8) }}
                </p>
                <p class="truncate text-2xs text-slate-500">
                  {{ t('tutoring2.common.metaActiveEnrolls', { count: c.active_count }) }}
                </p>
              </div>
              <span class="text-slate-300">›</span>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

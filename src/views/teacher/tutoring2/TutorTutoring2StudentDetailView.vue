<!--
  TutorTutoring2StudentDetailView.vue — a single student's enrollments,
  reached from TutorTutoring2StudentsView. Bimbel doesn't yet expose a
  student profile endpoint, so the detail page currently shows the same
  enrollment rows filtered to one `student_id`, plus stub CTAs for the
  "catatan ke wali" / row-detail flows.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();

const studentId = computed(() => String(route.params.id ?? ''));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({
    per_page: 20,
    student_id: studentId.value,
  });
  return items;
});
useAcademicYearWatcher(reload);

const enrollments = computed<BimbelEnrollment[]>(() =>
  state.value.status === 'content'
    ? (state.value.data as BimbelEnrollment[])
    : state.value.status === 'empty'
      ? []
      : [],
);

const activeEnrollmentCount = computed(
  () => enrollments.value.filter((e) => e.status === 'active').length,
);

function shortId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}

function statusPillTone(status: BimbelEnrollment['status']): StatusBadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    case 'trial':
      return 'warning';
    case 'paused':
      return 'neutral';
    case 'graduated':
      return 'info';
    case 'withdrawn':
      return 'neutral';
    default:
      return 'neutral';
  }
}

</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.studentDetail.title')"
      :meta="shortId(studentId)"
    />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="4"
      :empty-title="t('tutoring2.tutor.studentDetail.emptyTitle')"
      empty-description="Siswa ini belum terdaftar di program apapun."
      empty-icon="inbox"
      @retry="reload"
    >
      <!-- TODO i18n key: empty-description "Siswa ini belum terdaftar di program apapun." -->
      <template #default>
        <!-- Info card -->
        <section class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
          <p class="text-2xs font-bold uppercase tracking-widest text-slate-400">
            {{ t('tutoring2.common.studentId') }}
          </p>
          <p class="mt-1 text-lg font-bold text-slate-900">
            {{ shortId(studentId) }}
          </p>
          <p class="mt-2 text-2xs text-slate-500">
            {{ t('tutoring2.common.metaActiveEnrolls', { count: activeEnrollmentCount }) }}
          </p>
        </section>

        <!-- Pendaftaran list -->
        <section class="mt-md">
          <h2 class="text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">
            {{ t('tutoring2.tutor.studentDetail.sectionEnrollments') }}
          </h2>
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm divide-y divide-slate-100">
            <!-- A row, not a button. It used to be clickable and answer
                 "Belum tersedia" — there is no enrollment detail view on
                 this surface, so the affordance was the whole bug. -->
            <div
              v-for="e in enrollments"
              :key="e.id"
              class="w-full flex items-center gap-3 px-4 py-3 text-left first:rounded-t-3xl last:rounded-b-3xl"
            >
              <span
                class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-cobalt/10 text-brand-cobalt text-xs font-bold uppercase"
                aria-hidden="true"
              >
                {{ shortId(e.program_id).slice(0, 2) }}
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-sm font-bold text-slate-900 truncate">
                  {{ shortId(e.program_id) }}
                </p>
                <p class="text-2xs text-slate-500 mt-0.5">
                  {{ e.billing_mode_label ?? e.billing_mode }}
                </p>
              </div>
              <StatusBadge
                :label="e.status_label ?? t(`tutoring2.status.${e.status}`)"
                :tone="statusPillTone(e.status)"
              />
            </div>
          </div>
        </section>

        <!-- Footer CTA -->
        <div class="mt-md">
        </div>
      </template>
    </AsyncView>
  </div>
</template>

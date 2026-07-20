<!--
  TutorTutoring2StudentDetailView.vue — a single student's enrollments,
  reached from TutorTutoring2StudentsView. Bimbel doesn't yet expose a
  student profile endpoint, so the detail page currently shows the same
  enrollment rows filtered to one `student_id`, plus stub CTAs for the
  "catatan ke wali" / row-detail flows.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';

import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const route = useRoute();
const toast = useToast();

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

function openEnrollment(_e: BimbelEnrollment) {
  toast.info('detail pendaftaran belum tersedia');
}

function sendNoteToParent() {
  toast.info('belum tersedia');
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      kicker="Tutor Bimbel"
      title="Detail Siswa"
      :meta="shortId(studentId)"
    />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="4"
      empty-title="Belum ada pendaftaran"
      empty-description="Siswa ini belum terdaftar di program apapun."
      empty-icon="inbox"
      @retry="reload"
    >
      <template #default>
        <!-- Info card -->
        <section class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
          <p class="text-2xs font-bold uppercase tracking-widest text-slate-400">
            ID siswa
          </p>
          <p class="mt-1 text-lg font-bold text-slate-900">
            {{ shortId(studentId) }}
          </p>
          <p class="mt-2 text-2xs text-slate-500">
            {{ activeEnrollmentCount }} pendaftaran aktif
          </p>
        </section>

        <!-- Pendaftaran list -->
        <section class="mt-md">
          <h2 class="text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">
            Pendaftaran
          </h2>
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm divide-y divide-slate-100">
            <button
              v-for="e in enrollments"
              :key="e.id"
              type="button"
              class="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-slate-50 first:rounded-t-3xl last:rounded-b-3xl transition-colors"
              @click="openEnrollment(e)"
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
                :label="e.status_label ?? e.status"
                :tone="statusPillTone(e.status)"
              />
              <span class="text-slate-300 ml-1" aria-hidden="true">›</span>
            </button>
          </div>
        </section>

        <!-- Footer CTA -->
        <div class="mt-md">
          <Button variant="secondary" block @click="sendNoteToParent">
            Kirim catatan ke wali
          </Button>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

<!--
  TutorTutoring2StudentsView.vue — greenfield bimbel tutor "Siswa saya".

  Bimbel has no dedicated /students endpoint yet, so this MVP derives
  the tutor's siswa list from `/tutoring-v2/enrollments` (same trick
  AdminTutoring2StudentsView uses). One row per unique `student_id`
  aggregated from the enrollments payload.

  Shape:
    1. BrandPageHeader (teacher gradient)
    2. KpiStripCards — 3 tiles (Total, Aktif, Trial)

  A fourth tile read "Tunggakan: 0" — hardcoded, so every tutor was told
  all of their students were up to date. Removed rather than wired: the
  tutor role holds no `tutoring.bill.*` ability, and the bills endpoint
  403s anyone without one, so no query could fill it.
    3. PageFilterToolbar + AppFilterChip — Status + Program
    4. AsyncView → rounded-3xl surface with divide-y student rows
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';

import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

// TODO WEB-4+ swap to /tutoring-v2/tutor/students filtered to the tutor's own groups

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'active' | 'trial' | 'paused' | 'withdrawn' | 'graduated'
const programFilter = ref<string>(''); // nominal — '' | 'linked'

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({
    per_page: 200,
    status: statusFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, statusFilter, programFilter], () => reload());

// ── Derive unique students ──────────────────────────────────────────
interface StudentRow {
  student_id: string;
  program_count: number;
  has_active: boolean;
  has_trial: boolean;
  primary_status: BimbelEnrollment['status'];
  primary_status_label?: string;
}

const enrollments = computed<BimbelEnrollment[]>(() =>
  state.value.status === 'content'
    ? (state.value.data as BimbelEnrollment[])
    : state.value.status === 'empty'
      ? []
      : [],
);

const studentRows = computed<StudentRow[]>(() => {
  const byStudent = new Map<string, StudentRow>();
  for (const e of enrollments.value) {
    const existing = byStudent.get(e.student_id);
    if (!existing) {
      byStudent.set(e.student_id, {
        student_id: e.student_id,
        program_count: 1,
        has_active: e.status === 'active',
        has_trial: e.status === 'trial',
        primary_status: e.status,
        primary_status_label: e.status_label,
      });
    } else {
      existing.program_count += 1;
      if (e.status === 'active') {
        existing.has_active = true;
        // Promote 'active' to primary if primary isn't already active.
        if (existing.primary_status !== 'active') {
          existing.primary_status = 'active';
          existing.primary_status_label = e.status_label;
        }
      } else if (e.status === 'trial') {
        existing.has_trial = true;
        if (existing.primary_status !== 'active') {
          existing.primary_status = 'trial';
          existing.primary_status_label = e.status_label;
        }
      }
    }
  }
  const rows = Array.from(byStudent.values());
  const needle = debouncedSearch.value.trim().toLowerCase();
  if (!needle) return rows;
  return rows.filter((r) => r.student_id.toLowerCase().includes(needle));
});

const uniqueStudentCount = computed(
  () => new Set(enrollments.value.map((e) => e.student_id)).size,
);

const kpiCards = computed<KpiCard[]>(() => {
  const items = enrollments.value;
  const unique = new Set(items.map((e) => e.student_id));
  const activeStudents = new Set(
    items.filter((e) => e.status === 'active').map((e) => e.student_id),
  );
  const trialStudents = new Set(
    items.filter((e) => e.status === 'trial').map((e) => e.student_id),
  );
  return [
    { icon: 'users', label: t('tutoring2.tutor.students.kpiTotal'), value: String(unique.size), tone: 'brand' },
    { icon: 'circle-check', label: t('tutoring2.tutor.students.kpiActive'), value: String(activeStudents.size), tone: 'green' },
    {
      icon: 'sparkles',
      label: t('tutoring2.tutor.students.kpiTrial'),
      value: String(trialStudents.size),
      tone: trialStudents.size > 0 ? 'amber' : 'slate',
    },
  ];
});

function statusPillTone(row: StudentRow): StatusBadgeTone {
  if (row.has_active) return 'success';
  if (row.has_trial) return 'warning';
  switch (row.primary_status) {
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

function statusPillLabel(row: StudentRow): string {
  if (row.has_active) return t('tutoring2.status.active');
  if (row.has_trial) return t('tutoring2.status.trial');
  return row.primary_status_label ?? t(`tutoring2.status.${row.primary_status}`);
}

function shortId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}

function openStudent(row: StudentRow) {
  router.push({
    name: 'teacher.tutoring2.student-detail',
    params: { id: row.student_id },
  });
}

function toggleStatus() {
  const cycle: Array<'' | 'active' | 'trial' | 'paused' | 'withdrawn' | 'graduated'> = [
    '',
    'active',
    'trial',
    'paused',
    'withdrawn',
    'graduated',
  ];
  const idx = cycle.indexOf(statusFilter.value as (typeof cycle)[number]);
  statusFilter.value = cycle[(idx + 1) % cycle.length];
}

function toggleProgram() {
  programFilter.value = programFilter.value ? '' : 'linked';
  if (programFilter.value === 'linked') {
    // TODO i18n key: 'Filter program tersambung — MVP: nominal'
    toast.info('Filter program tersambung — MVP: nominal');
  }
}

const statusChipLabel = computed(() => {
  switch (statusFilter.value) {
    case 'active':
      return t('tutoring2.status.active');
    case 'trial':
      return t('tutoring2.status.trial');
    case 'paused':
      return t('tutoring2.status.paused');
    case 'withdrawn':
      return t('tutoring2.status.withdrawn');
    case 'graduated':
      return t('tutoring2.status.graduated');
    default:
      return t('tutoring2.common.all');
  }
});

const headerMeta = computed(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? t('tutoring2.tutor.students.meta', { count: uniqueStudentCount.value })
    : t('tutoring2.common.loading'),
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.students.title')"
      :meta="headerMeta"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.tutor.students.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusChipLabel"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="toggleStatus"
        />
        <AppFilterChip
          :label="t('tutoring2.common.program')"
          :value="programFilter ? t('tutoring2.common.connected') : t('tutoring2.common.all')"
          icon-name="book"
          :active="!!programFilter"
          @click="toggleProgram"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="6"
      :empty-title="t('tutoring2.tutor.students.emptyTitle')"
      empty-description="Siswa akan muncul di sini setelah admin mendaftarkan mereka ke grup Anda."
      empty-icon="users"
      @retry="reload"
    >
      <!-- TODO i18n key: empty-description for tutor students -->
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm divide-y divide-slate-100">
          <button
            v-for="row in studentRows"
            :key="row.student_id"
            type="button"
            class="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-slate-50 first:rounded-t-3xl last:rounded-b-3xl transition-colors"
            @click="openStudent(row)"
          >
            <span
              class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-cobalt/10 text-brand-cobalt text-xs font-bold uppercase"
              aria-hidden="true"
            >
              {{ shortId(row.student_id).slice(0, 2) }}
            </span>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-bold text-slate-900 truncate">
                {{ shortId(row.student_id) }}
              </p>
              <p class="text-2xs text-slate-500 mt-0.5">
                {{ t('tutoring2.common.metaProgramsActive', { count: row.program_count }) }}
              </p>
            </div>
            <StatusBadge
              :label="statusPillLabel(row)"
              :tone="statusPillTone(row)"
            />
            <span class="text-slate-300 ml-1" aria-hidden="true">›</span>
          </button>
        </div>
      </template>
    </AsyncView>
  </div>
</template>

<!--
  AdminTutoring2SiswaView.vue — greenfield "Siswa" list.

  Bimbel doesn't have its own students table (reuses the shared
  `students` row). For the WEB-3 MVP we derive the siswa list by
  grouping the enrollments feed by `student_id` — good enough to
  show who's enrolled, how many active programs each student has,
  and their billing snapshot.

  Mirrors AdminTutoring2ProgramsView shape:
    1. `BrandPageHeader`
    2. `KpiStripCards` — 4 tiles
    3. `PageFilterToolbar` + `AppFilterChip`s
    4. `AsyncView` → white rounded-3xl table card
    5. Floating "+ Tambah siswa" CTA.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

// TODO WEB-3+ swap to a proper /tutoring-v2/students endpoint once BE exposes it; for now derived from enrollments

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'active' | 'trial' | 'withdrawn'
const programFilter = ref<string>(''); // '' | program_id
const waliFilter = ref<string>(''); // nominal for MVP — '' | 'linked'

const { t } = useI18n();

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({
    per_page: 200,
    status: statusFilter.value || undefined,
    program_id: programFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, statusFilter, programFilter, waliFilter], () => reload());
useAcademicYearWatcher(reload);

// Derived: one row per unique student_id, keeping the most-recent enrollment
// as the "primary" snapshot and counting how many active programs they have.
interface StudentRow {
  student_id: string;
  program_id: string;
  billing_mode: BimbelEnrollment['billing_mode'];
  billing_mode_label?: string;
  status: BimbelEnrollment['status'];
  status_label?: string;
  remaining_sessions?: number | null;
  total_sessions_snapshot?: number | null;
  active_programs: number;
}

const studentRows = computed<StudentRow[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  const byStudent = new Map<string, StudentRow>();
  for (const e of items) {
    const existing = byStudent.get(e.student_id);
    if (!existing) {
      byStudent.set(e.student_id, {
        student_id: e.student_id,
        program_id: e.program_id,
        billing_mode: e.billing_mode,
        billing_mode_label: e.billing_mode_label,
        status: e.status,
        status_label: e.status_label,
        remaining_sessions: e.remaining_sessions,
        total_sessions_snapshot: e.total_sessions_snapshot,
        active_programs: e.status === 'active' ? 1 : 0,
      });
    } else if (e.status === 'active') {
      existing.active_programs += 1;
    }
  }
  const rows = Array.from(byStudent.values());
  const needle = debouncedSearch.value.trim().toLowerCase();
  if (!needle) return rows;
  return rows.filter((r) => r.student_id.toLowerCase().includes(needle));
});

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  const unique = new Set(items.map((e) => e.student_id)).size;
  const aktif = items.filter((e) => e.status === 'active').length;
  const trial = items.filter((e) => e.status === 'trial').length;
  const lulusKeluar = items.filter((e) => e.status === 'graduated' || e.status === 'withdrawn').length;
  return [
    { icon: 'users', label: t('tutoring2.admin.students.kpiTotal'), value: String(unique) },
    { icon: 'circle-check', label: t('tutoring2.admin.students.kpiActive'), value: String(aktif) },
    { icon: 'sparkles', label: t('tutoring2.admin.students.kpiTrial'), value: String(trial), tone: trial > 0 ? 'amber' : undefined },
    { icon: 'log-out', label: t('tutoring2.admin.students.kpiGraduated'), value: String(lulusKeluar) },
  ];
});

const uniqueStudentCount = computed(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  return new Set(items.map((e) => e.student_id)).size;
});

const activeEnrollmentCount = computed(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  return items.filter((e) => e.status === 'active').length;
});

function statusPillTone(status: BimbelEnrollment['status']): StatusBadgeTone {
  switch (status) {
    case 'active': return 'success';
    case 'trial': return 'warning';
    case 'paused': return 'neutral';
    case 'graduated': return 'info';
    case 'withdrawn': return 'neutral';
  }
}

function statusLabel(status: BimbelEnrollment['status']): string {
  return t(`tutoring2.status.${status}`);
}

function shortId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.students.title')"
      :meta="state.status === 'content'
        ? `${uniqueStudentCount} ${t('tutoring2.common.student').toLowerCase()} · ${activeEnrollmentCount} ${t('tutoring2.admin.students.kpiActive').toLowerCase()}`
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.students.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'active'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.program')"
          :value="programFilter ? shortId(programFilter) : t('tutoring2.common.all')"
          icon-name="book"
          :active="!!programFilter"
          @click="programFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.student_')"
          :value="waliFilter || t('tutoring2.common.all')"
          icon-name="user"
          :active="!!waliFilter"
          @click="waliFilter = waliFilter ? '' : 'linked'"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.students.emptyTitle')"
      :empty-description="t('tutoring2.admin.students.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.name') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.billingMode') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.remainingQuota') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in studentRows"
                :key="r.student_id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <!-- TODO WEB-3+ join with students.name once /tutoring-v2/students exposes it -->
                <td class="px-4 py-3 font-bold text-slate-900">{{ shortId(r.student_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ shortId(r.program_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ r.billing_mode_label ?? r.billing_mode }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="r.status_label ?? statusLabel(r.status)" :tone="statusPillTone(r.status)" uppercase />
                </td>
                <td class="px-4 py-3 text-slate-600">
                  {{ r.remaining_sessions ?? '—' }}<span class="text-slate-400"> / {{ r.total_sessions_snapshot ?? '—' }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.students.newCta') }}
    </button>
  </div>
</template>

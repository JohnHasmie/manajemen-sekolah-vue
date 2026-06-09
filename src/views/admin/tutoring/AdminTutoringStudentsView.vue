<!--
  AdminTutoringStudentsView — list of bimbel students (derived from
  active enrollments). Uses the school-pattern chrome (BrandPageHeader
  + KpiStripCards + PageFilterToolbar) so it visually matches the rest
  of the app.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutoringProgram, TutoringStudentRow } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const rows = ref<TutoringStudentRow[]>([]);
const programs = ref<TutoringProgram[]>([]);
const programId = ref<string>(''); // '' = Semua program
const search = ref('');
const showProgramPicker = ref(false);

const activeProgramLabel = computed(() =>
  programId.value === ''
    ? t('tutoring.students.filterAll')
    : programs.value.find((p) => p.id === programId.value)?.name ?? '—',
);

const MODE_KEYS: Record<string, string> = {
  PREPAID: 'tutoring.billing.prepaid',
  MONTHLY: 'tutoring.billing.monthly',
  PER_SESSION: 'tutoring.billing.perSession',
};
const modeLabel = (m: string) => (MODE_KEYS[m] ? t(MODE_KEYS[m]) : m);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getAdminStudents({
      program_id: programId.value || undefined,
      search: search.value.trim() || undefined,
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.students.empty'));
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await load();
  try {
    programs.value = await TutoringService.getPrograms();
  } catch {/* non-fatal */}
});

watch(programId, load);

function openDetail(r: TutoringStudentRow) {
  router.push({
    name: 'parent.tutoring.overview',
    params: { studentId: r.student_id },
    query: { name: r.student_name },
  });
}

function pickProgram(id: string) {
  programId.value = id;
  showProgramPicker.value = false;
}

// Client-side aggregates for the KPI strip (no extra round-trip).
const totalOutstanding = computed(() =>
  rows.value.reduce((s, r) => s + (r.unpaid_total ?? 0), 0),
);
const unpaidStudents = computed(() =>
  rows.value.filter((r) => (r.unpaid_count ?? 0) > 0).length,
);
const avgAttendance = computed(() => {
  const withRate = rows.value.filter((r) => r.attendance_rate != null);
  if (withRate.length === 0) return null;
  return Math.round(
    withRate.reduce((s, r) => s + (r.attendance_rate ?? 0), 0) / withRate.length,
  );
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'users',
    label: t('tutoring.students.title'),
    value: rows.value.length,
    suffix: 'siswa',
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'layers',
    label: 'Program aktif',
    value: programs.value.filter((p) => p.is_active !== false).length,
    tone: 'violet',
  },
  {
    icon: 'check-circle',
    label: t('tutoring.students.attendance'),
    value: avgAttendance.value == null ? '–' : `${avgAttendance.value}%`,
    tone: 'green',
  },
  {
    icon: 'wallet',
    label: t('tutoring.students.outstanding'),
    value: formatRupiah(totalOutstanding.value),
    suffix: unpaidStudents.value > 0 ? `${unpaidStudents.value} siswa` : undefined,
    tone: totalOutstanding.value > 0 ? 'amber' : 'green',
  },
]);

let searchTimer: ReturnType<typeof setTimeout> | null = null;
function onSearch(v: string) {
  search.value = v;
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(load, 300);
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Siswa"
      :title="t('tutoring.students.title')"
      :meta="`${rows.length} siswa terdaftar`"
    />

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar
      :search="search"
      search-placeholder="Cari nama siswa…"
      @update:search="onSearch"
    >
      <template #chips>
        <AppFilterChip
          label="Program"
          :value="activeProgramLabel"
          icon-name="layers"
          tone="violet"
          @click="showProgramPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('tutoring.students.empty')"
      icon="users"
    />
    <div
      v-else
      class="bg-white border border-slate-100 rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-slate-500">
          <tr class="border-b border-slate-200">
            <th class="text-left font-bold px-3 py-2.5">Siswa</th>
            <th class="text-left font-bold px-3 py-2.5">Program · Paket</th>
            <th class="text-left font-bold px-3 py-2.5">Mode</th>
            <th class="text-left font-bold px-3 py-2.5">{{ t('tutoring.students.attendance') }}</th>
            <th class="text-right font-bold px-3 py-2.5">{{ t('tutoring.students.outstanding') }}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="r in rows"
            :key="r.student_id"
            class="border-b border-slate-100 last:border-0 hover:bg-slate-50 cursor-pointer"
            @click="openDetail(r)"
          >
            <td class="px-3 py-3 font-semibold text-slate-900">{{ r.student_name }}</td>
            <td class="px-3 py-3 text-slate-700">
              {{ [r.program_name, r.package_name].filter(Boolean).join(' · ') || '—' }}
            </td>
            <td class="px-3 py-3"><TutoringStatusPill :label="modeLabel(r.billing_mode)" tone="neutral" /></td>
            <td class="px-3 py-3 text-slate-700">
              {{ r.attendance_rate == null ? '—' : r.attendance_rate + '%' }}
            </td>
            <td class="px-3 py-3 text-right">
              <span v-if="r.unpaid_count === 0" class="text-slate-400">—</span>
              <span v-else class="font-semibold text-status-danger">
                {{ formatRupiah(r.unpaid_total) }}
              </span>
            </td>
            <td class="px-3 py-3 text-right">
              <NavIcon name="chevron-right" :size="14" class="text-slate-400" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Modal
      v-if="showProgramPicker"
      title="Filter Program"
      @close="showProgramPicker = false"
    >
      <ul class="space-y-1">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': programId === '' }"
            @click="pickProgram('')"
          >
            {{ t('tutoring.students.filterAll') }}
          </button>
        </li>
        <li v-for="p in programs" :key="p.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': programId === p.id }"
            @click="pickProgram(p.id)"
          >
            {{ p.name }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>

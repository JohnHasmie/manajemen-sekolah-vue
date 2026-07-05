<!--
  AdminAttendanceTingkatHeatmapView.vue — admin per-tingkat heatmap.

  Web port of Flutter's `AdminTingkatHeatmapScreen` (Mockup #12).
  Route: `/admin/attendance/tingkat/:tingkat`

  Layout:
    1. Back chevron → dashboard
    2. BrandPageHeader (admin) — kicker + title "Heatmap Tingkat N" + meta
    3. Days segmented (30 / 60 / 90)
    4. Legend strip — Hadir / Izin / Sakit / Alpa / Libur
    5. Search input
    6. Student cards — InitialsAvatar + name/NIS + monthly pct + alert + cells row

  Each cell is colored by status. Hover/tap shows the date.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { AttendanceService } from '@/services/attendance.service';
import type {
  HeatmapCellState,
  StudentHeatmapEntry,
  StudentHeatmapResponse,
} from '@/types/attendance';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const tingkat = computed(() => Number(route.params.tingkat ?? 0));

type DaysOption = 30 | 60 | 90;
const days = ref<DaysOption>(30);

const DAYS_OPTIONS = computed<{ key: string; label: string }[]>(() => [
  { key: '30', label: t('admin.sekolah.attendance_tingkat_heatmap.days_30') },
  { key: '60', label: t('admin.sekolah.attendance_tingkat_heatmap.days_60') },
  { key: '90', label: t('admin.sekolah.attendance_tingkat_heatmap.days_90') },
]);

const data = ref<StudentHeatmapResponse | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const search = ref('');

async function load() {
  if (!tingkat.value) return;
  isLoading.value = true;
  error.value = null;
  try {
    data.value = await AttendanceService.getStudentHeatmap({
      tingkat: tingkat.value,
      days: days.value,
    });
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
useAcademicYearWatcher(load);

watch(days, () => void load());

function onDaysChange(v: string) {
  days.value = Number(v) as DaysOption;
}

const filteredStudents = computed<StudentHeatmapEntry[]>(() => {
  const list = data.value?.students ?? [];
  const q = search.value.trim().toLowerCase();
  if (!q) return list;
  return list.filter(
    (s) =>
      s.name.toLowerCase().includes(q) ||
      (s.student_number ?? '').toLowerCase().includes(q),
  );
});

const state = computed<AsyncState<StudentHeatmapEntry[]>>(() => {
  if (isLoading.value && !data.value) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filteredStudents.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredStudents.value };
});

// Mirror Flutter's AttendancePalette colors.
const CELL_COLORS: Record<HeatmapCellState, string> = {
  present: '#10B981',
  excused: '#3B82F6',
  sick: '#F59E0B',
  alpha: '#EF4444',
  holiday: '#CBD5E1',
  none: '#F1F5F9',
};

const CELL_LABEL = computed<Record<HeatmapCellState, string>>(() => ({
  present: t('admin.sekolah.attendance_tingkat_heatmap.cell_present'),
  excused: t('admin.sekolah.attendance_tingkat_heatmap.cell_excused'),
  sick: t('admin.sekolah.attendance_tingkat_heatmap.cell_sick'),
  alpha: t('admin.sekolah.attendance_tingkat_heatmap.cell_alpha'),
  holiday: t('admin.sekolah.attendance_tingkat_heatmap.cell_holiday'),
  none: t('admin.sekolah.attendance_tingkat_heatmap.cell_none'),
}));

// Compute cell width based on days so wide rows still fit.
const cellWidthClass = computed(() => {
  if (days.value === 90) return 'min-w-[8px] max-w-[12px]';
  if (days.value === 60) return 'min-w-[10px] max-w-[16px]';
  return 'min-w-[14px] max-w-[20px]';
});

function cellDateLabel(entry: StudentHeatmapEntry, cellIdx: number): string {
  // start_date + cellIdx days.
  if (!data.value?.start_date) return '';
  const [y, m, d] = data.value.start_date.split('-').map(Number);
  const dt = new Date(y, (m ?? 1) - 1, (d ?? 1) + cellIdx);
  const iso = `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`;
  const status = CELL_LABEL.value[entry.cells[cellIdx]];
  return `${iso} — ${status}`;
}

function goBack() {
  router.push({ name: 'admin.attendance' });
}

const headerMeta = computed(() => {
  if (!data.value) return '';
  return t('admin.sekolah.attendance_tingkat_heatmap.header_meta', {
    count: data.value.students.length,
    startDate: data.value.start_date,
    endDate: data.value.end_date,
  });
});

const headerTitle = computed(() =>
  t('admin.sekolah.attendance_tingkat_heatmap.header_title', { tingkat: tingkat.value }),
);
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('admin.sekolah.attendance_tingkat_heatmap.back_to_dashboard') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.attendance_tingkat_heatmap.header_kicker')"
      :title="headerTitle"
      :meta="headerMeta"
      :live-dot="false"
    >
      <SegmentedControl
        :model-value="String(days)"
        :options="DAYS_OPTIONS"
        size="sm"
        @update:model-value="onDaysChange"
      />
    </BrandPageHeader>

    <!-- Legend -->
    <section class="bg-white border border-slate-200 rounded-2xl px-3 py-2 flex items-center gap-3 flex-wrap text-2xs">
      <span
        v-for="(label, state_) in CELL_LABEL"
        :key="state_"
        class="inline-flex items-center gap-1.5"
      >
        <span
          class="w-3 h-3 rounded-sm"
          :style="{ backgroundColor: CELL_COLORS[state_ as HeatmapCellState] }"
        ></span>
        <span class="text-slate-600 font-bold">{{ label }}</span>
      </span>
    </section>

    <!-- Search -->
    <section class="bg-white border border-slate-200 rounded-2xl p-3">
      <div class="inline-flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 w-full max-w-md">
        <NavIcon name="search" :size="13" class="text-slate-400" />
        <input
          v-model="search"
          type="search"
          :placeholder="t('admin.sekolah.attendance_tingkat_heatmap.search_placeholder')"
          class="bg-transparent border-0 outline-none flex-1 text-[12px] font-medium text-slate-900 placeholder:text-slate-400"
        />
      </div>
    </section>

    <AsyncView
      :state="state"
      :empty-title="t('admin.sekolah.attendance_tingkat_heatmap.empty_title')"
      :empty-description="t('admin.sekolah.attendance_tingkat_heatmap.empty_description')"
      empty-icon="users"
      @retry="load"
    >
      <template #default>
        <ul class="space-y-2">
          <li
            v-for="s in filteredStudents"
            :key="s.id"
            class="bg-white border border-slate-200 rounded-2xl p-3"
            :class="s.alert ? 'border-amber-300' : ''"
          >
            <header class="flex items-center gap-3 mb-2">
              <InitialsAvatar
                :name="s.name || '?'"
                :size="36"
                :color="s.alert ? '#DC2626' : '#143068'"
                :border-radius="10"
              />
              <div class="flex-1 min-w-0">
                <p class="text-[13px] font-bold text-slate-900 truncate">{{ s.name }}</p>
                <p class="text-3xs text-slate-500 truncate">
                  <template v-if="s.student_number">{{ t('admin.sekolah.attendance_tingkat_heatmap.nis_label', { nis: s.student_number }) }}</template>
                  <template v-else>{{ t('admin.sekolah.attendance_tingkat_heatmap.no_nis') }}</template>
                  {{ t('admin.sekolah.attendance_tingkat_heatmap.present_summary', { present: s.present_days, total: s.total_days }) }}
                </p>
                <p
                  v-if="s.alert_copy"
                  class="text-3xs font-bold text-amber-700 mt-0.5"
                >
                  {{ s.alert_copy }}
                </p>
              </div>
              <div class="text-right flex-shrink-0">
                <p
                  class="text-[15px] font-black tabular-nums"
                  :class="{
                    'text-emerald-700': s.monthly_pct >= 90,
                    'text-emerald-600': s.monthly_pct >= 80 && s.monthly_pct < 90,
                    'text-amber-700': s.monthly_pct >= 75 && s.monthly_pct < 80,
                    'text-red-700': s.monthly_pct < 75,
                  }"
                >
                  {{ s.monthly_pct.toFixed(0) }}%
                </p>
                <p class="text-4xs text-slate-400 font-bold uppercase tracking-widest">
                  {{ t('admin.sekolah.attendance_tingkat_heatmap.monthly') }}
                </p>
              </div>
            </header>

            <!-- Cells row -->
            <div class="flex flex-wrap gap-0.5">
              <span
                v-for="(cell, idx) in s.cells"
                :key="idx"
                class="h-4 rounded-sm flex-1"
                :class="cellWidthClass"
                :style="{ backgroundColor: CELL_COLORS[cell] }"
                :title="cellDateLabel(s, idx)"
              ></span>
            </div>
          </li>
        </ul>
      </template>
    </AsyncView>
  </div>
</template>

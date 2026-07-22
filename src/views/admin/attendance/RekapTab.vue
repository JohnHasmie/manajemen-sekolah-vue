<script setup lang="ts">
/**
 * Kehadiran Siswa · Rekap & Laporan (mockup §05) — monthly per-student
 * calendar grid + Pusat Export + Perlu-perhatian rail.
 *
 * Data: existing `AttendanceService.getStudentHeatmap` with a month
 * end-date and a ~30-day window; cells are rendered from the response's
 * per-day `HeatmapCellState` (present / excused / sick / alpha / holiday
 * / none), weekends dimmed. Export dispatches through the existing
 * `AttendanceService.downloadMonthlyReport` — no new BE.
 */
import { computed, onMounted, ref, watch } from 'vue';
import { AttendanceService } from '@/services/attendance.service';
import type { StudentHeatmapResponse, StudentHeatmapEntry, HeatmapCellState } from '@/types/attendance';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useMeStore } from '@/stores/me';
import { useToast } from '@/composables/useToast';

import NavIcon from '@/components/feature/NavIcon.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';

const me = useMeStore();
const ayStore = useAcademicYearStore();
const toast = useToast();

const canExport = computed(() => me.can('attendance.student.export'));

// month picker (YYYY-MM)
const month = ref(`${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}`);
const classId = ref<string>('');
const search = ref('');
const view = ref<'kalender' | 'heatmap'>('kalender');
const scope = ref<'monthly' | 'daily' | 'per_mapel'>('monthly');
const lingkup = ref<'class' | 'grade' | 'school'>('class');
const format = ref<'xlsx' | 'pdf' | 'csv'>('xlsx');

const loading = ref(false);
const errorMsg = ref<string | null>(null);
const heatmap = ref<StudentHeatmapResponse | null>(null);
const exportBusy = ref(false);

// End-date of the selected month (or today if the month is the current one)
const endDate = computed(() => {
  const [y, m] = month.value.split('-').map(Number) as [number, number];
  const today = new Date();
  if (y === today.getFullYear() && m === today.getMonth() + 1) {
    return today.toISOString().slice(0, 10);
  }
  return new Date(y, m, 0).toISOString().slice(0, 10);
});

const monthDays = computed(() => {
  const [y, m] = month.value.split('-').map(Number) as [number, number];
  return new Date(y, m, 0).getDate();
});
const monthName = computed(() => {
  const [y, m] = month.value.split('-').map(Number) as [number, number];
  return new Date(y, m - 1, 1).toLocaleDateString('id-ID', { month: 'long', year: 'numeric' });
});

function isWeekend(day: number): boolean {
  const [y, m] = month.value.split('-').map(Number) as [number, number];
  const g = new Date(y, m - 1, day).getDay();
  return g === 0 || g === 6;
}

const workdays = computed(() => {
  let n = 0;
  for (let d = 1; d <= monthDays.value; d++) if (!isWeekend(d)) n++;
  return n;
});

const filteredStudents = computed<StudentHeatmapEntry[]>(() => {
  const arr = heatmap.value?.students ?? [];
  const q = search.value.trim().toLowerCase();
  if (!q) return arr;
  return arr.filter(
    (s) => s.name.toLowerCase().includes(q) || (s.student_number ?? '').toLowerCase().includes(q),
  );
});

const kpiAvg = computed(() => {
  const arr = heatmap.value?.students ?? [];
  if (!arr.length) return null;
  const sum = arr.reduce((s, x) => s + x.monthly_pct, 0);
  return Math.round(sum / arr.length);
});
const kpiAlfa = computed(() => {
  const arr = heatmap.value?.students ?? [];
  return arr.reduce((s, x) => s + Math.max(0, x.total_days - x.present_days), 0);
});
const kpiPerluPerhatian = computed(
  () => (heatmap.value?.students ?? []).filter((s) => s.total_days - s.present_days > 3).length,
);
const perluPerhatianList = computed(() =>
  (heatmap.value?.students ?? [])
    .map((s) => ({ ...s, alfa: s.total_days - s.present_days }))
    .filter((s) => s.alfa > 3)
    .sort((a, b) => b.alfa - a.alfa)
    .slice(0, 3),
);

/** Map an offset (index into cells[]) back to a day-of-month within the
 * month.value grid. The heatmap endpoint returns cells indexed by day
 * across the requested window ending at end_date, so we align by end-of-
 * window and walk backwards. */
function cellsByDay(entry: StudentHeatmapEntry): Record<number, HeatmapCellState> {
  const map: Record<number, HeatmapCellState> = {};
  if (!heatmap.value) return map;
  const end = new Date(heatmap.value.end_date);
  const total = entry.cells.length;
  for (let i = 0; i < total; i++) {
    const d = new Date(end);
    d.setDate(d.getDate() - (total - 1 - i));
    const [y, m] = month.value.split('-').map(Number) as [number, number];
    if (d.getFullYear() === y && d.getMonth() + 1 === m) {
      map[d.getDate()] = entry.cells[i]!;
    }
  }
  return map;
}

const CELL_COLOR: Record<HeatmapCellState, string> = {
  present: '#059669',
  excused: '#0284c7',
  sick: '#d97706',
  alpha: '#dc2626',
  holiday: '#e2e8f0',
  none: 'transparent',
};

const CELL_LETTER: Record<HeatmapCellState, string> = {
  present: '',
  excused: 'I',
  sick: 'S',
  alpha: 'A',
  holiday: '',
  none: '',
};

async function load() {
  loading.value = true;
  errorMsg.value = null;
  try {
    heatmap.value = await AttendanceService.getStudentHeatmap({
      class_id: classId.value || undefined,
      end_date: endDate.value,
      days: 31,
      academic_year_id: ayStore.selectedYearId ?? undefined,
    });
  } catch (e) {
    errorMsg.value = (e as Error)?.message ?? 'Gagal memuat rekap.';
  } finally {
    loading.value = false;
  }
}

async function exportReport() {
  if (!canExport.value || exportBusy.value) return;
  exportBusy.value = true;
  try {
    const [y, m] = month.value.split('-').map(Number) as [number, number];
    const ok = await AttendanceService.downloadMonthlyReport({
      class_id: classId.value,
      class_name: '',
      academic_year_name: ayStore.selectedYear?.year ?? '',
      academic_year_id: ayStore.selectedYearId ?? undefined,
      year: y,
      month: m,
    });
    if (ok) {
      toast.success('Rekap XLSX telah diunduh.');
    } else {
      toast.error('Export gagal — coba lagi.');
    }
  } catch {
    toast.error('Export gagal — periksa koneksi.');
  } finally {
    exportBusy.value = false;
  }
}

function stepMonth(delta: number) {
  const [y, m] = month.value.split('-').map(Number) as [number, number];
  const d = new Date(y, m - 1 + delta, 1);
  month.value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

onMounted(() => void load());
watch([month, classId], () => void load());
useAcademicYearWatcher(() => void load());
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- Toolbar -->
    <div class="flex flex-wrap items-center gap-2">
      <div class="inline-flex rounded-lg border border-slate-200 bg-white overflow-hidden">
        <button type="button" class="px-2 py-2 text-slate-500 hover:bg-slate-50" @click="stepMonth(-1)" aria-label="Bulan sebelumnya">
          <NavIcon name="chevron-left" :size="14" />
        </button>
        <input v-model="month" type="month" class="border-l border-r border-slate-200 px-3 py-2 text-[12px] font-semibold text-slate-900 focus:outline-none tabular-nums" />
        <button type="button" class="px-2 py-2 text-slate-500 hover:bg-slate-50" @click="stepMonth(1)" aria-label="Bulan berikutnya">
          <NavIcon name="chevron-right" :size="14" />
        </button>
      </div>
      <label class="flex-1 min-w-[200px] flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-[12px] text-slate-500">
        <NavIcon name="search" :size="14" />
        <input v-model="search" type="text" placeholder="Cari siswa / NIS…" class="flex-1 border-0 outline-none bg-transparent text-slate-900 placeholder:text-slate-400" />
      </label>
      <SegmentedControl
        v-model="view as unknown as string"
        :options="[
          { key: 'kalender', label: 'Kalender siswa' },
          { key: 'heatmap', label: 'Heatmap kelas' },
        ]"
      />
    </div>

    <!-- KPI strip -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-emerald-500" />Rata kehadiran
        </div>
        <div class="text-[24px] font-bold text-emerald-700 tabular-nums">
          {{ kpiAvg != null ? kpiAvg + '%' : '—' }}
        </div>
        <div class="text-[11px] text-slate-500 mt-0.5">{{ monthName }}</div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-[color:var(--role-admin,#143068)]" />Hari efektif
        </div>
        <div class="text-[24px] font-bold text-slate-900 tabular-nums">{{ workdays }}</div>
        <div class="text-[11px] text-slate-500 mt-0.5">tanpa akhir pekan</div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-red-500" />Perlu perhatian
        </div>
        <div class="text-[24px] font-bold text-red-700 tabular-nums">{{ kpiPerluPerhatian }}</div>
        <div class="text-[11px] text-slate-500 mt-0.5">alfa &gt; 3 hari</div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-amber-500" />Total alfa
        </div>
        <div class="text-[24px] font-bold text-amber-700 tabular-nums">{{ kpiAlfa }}</div>
        <div class="text-[11px] text-slate-500 mt-0.5">se-kelas · bulan ini</div>
      </div>
    </div>

    <!-- Body: calendar + right rail -->
    <div class="grid grid-cols-1 lg:grid-cols-[1fr_336px] gap-4">
      <div class="rounded-2xl border border-slate-200 bg-white shadow-card overflow-hidden">
        <div class="flex items-center gap-2 px-4 py-3.5 border-b border-slate-100">
          <h4 class="text-[13.5px] font-bold text-slate-900">Rekap kehadiran · {{ monthName }}</h4>
          <span class="text-[11px] text-slate-400 font-semibold">
            {{ filteredStudents.length }} siswa × {{ workdays }} hari
          </span>
        </div>
        <div v-if="loading" class="p-10 text-center text-slate-400 text-sm">Memuat rekap…</div>
        <div v-else-if="errorMsg" class="p-6 text-sm text-red-600 border-l-4 border-red-500 bg-red-50 m-4 rounded">{{ errorMsg }}</div>
        <div v-else-if="filteredStudents.length === 0" class="p-10 text-center text-slate-400 text-sm">
          Belum ada data — pilih kelas dan bulan.
        </div>
        <template v-else>
          <div class="overflow-x-auto">
            <table class="w-full text-[11px] border-separate" style="border-spacing:0">
              <thead>
                <tr>
                  <th class="text-left px-3 py-2 sticky left-0 bg-slate-50 z-10 min-w-[158px] border-b border-slate-100">Siswa</th>
                  <th
                    v-for="d in monthDays"
                    :key="`h-${d}`"
                    class="w-[22px] text-center text-[9px] font-bold py-2 border-b border-slate-100"
                    :class="isWeekend(d) ? 'text-slate-300 bg-slate-100/40' : 'text-slate-400 bg-slate-50'"
                  >{{ d }}</th>
                  <th class="px-3 py-2 text-right text-[9px] font-bold uppercase text-slate-400 bg-slate-50 border-b border-slate-100 sticky right-0 whitespace-nowrap">
                    Hadir · Alfa
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="s in filteredStudents" :key="s.id">
                  <td class="px-3 py-1.5 sticky left-0 bg-white z-10 border-b border-slate-100">
                    <div class="font-semibold text-slate-900 text-[11px] truncate">{{ s.name }}</div>
                    <div class="text-[9.5px] text-slate-400 font-semibold">NIS {{ s.student_number ?? '—' }}</div>
                  </td>
                  <td
                    v-for="d in monthDays"
                    :key="`c-${s.id}-${d}`"
                    class="w-[22px] h-[24px] border-b border-slate-100"
                    :class="isWeekend(d) ? 'bg-slate-100/40' : ''"
                  >
                    <span
                      v-if="cellsByDay(s)[d] && cellsByDay(s)[d] !== 'none'"
                      class="w-[15px] h-[15px] rounded mx-auto grid place-items-center text-[8px] font-bold text-white"
                      :style="{ background: CELL_COLOR[cellsByDay(s)[d]!] }"
                    >{{ CELL_LETTER[cellsByDay(s)[d]!] }}</span>
                  </td>
                  <td class="px-3 py-1.5 text-right text-[11px] tabular-nums bg-white border-b border-slate-100 sticky right-0 whitespace-nowrap">
                    <span class="font-bold text-slate-900">{{ s.monthly_pct }}%</span>
                    ·
                    <span :class="s.total_days - s.present_days > 3 ? 'text-red-700 font-bold' : 'text-slate-400'">
                      {{ s.total_days - s.present_days }}A
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="flex flex-wrap gap-3.5 px-4 py-3 border-t border-slate-100 text-[10.5px] text-slate-500 font-semibold">
            <span class="inline-flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded-sm bg-emerald-500" />Hadir</span>
            <span class="inline-flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded-sm bg-amber-500" />Terlambat (T)</span>
            <span class="inline-flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded-sm bg-sky-500" />Izin (I)</span>
            <span class="inline-flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded-sm bg-amber-600" />Sakit (S)</span>
            <span class="inline-flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded-sm bg-red-500" />Alfa (A)</span>
            <span class="inline-flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded-sm bg-slate-200" />Libur / akhir pekan</span>
          </div>
        </template>
      </div>

      <!-- Right rail: export center + perlu perhatian -->
      <div class="flex flex-col gap-4">
        <div class="rounded-2xl border border-slate-200 bg-white shadow-card p-4">
          <h4 class="text-[13px] font-bold text-slate-900">Pusat export</h4>
          <div class="text-[11px] text-slate-500 mb-3.5 font-medium">Satu tempat untuk semua laporan.</div>

          <div class="mb-3">
            <div class="text-[9.5px] font-bold uppercase tracking-[.08em] text-slate-400 mb-1.5">Cakupan</div>
            <div class="flex gap-1.5 flex-wrap">
              <button
                v-for="opt in [{k:'monthly',l:'Rekap bulanan'},{k:'daily',l:'Harian (gerbang)'},{k:'per_mapel',l:'Per mapel'}]"
                :key="opt.k"
                type="button"
                class="text-[11px] font-semibold px-2.5 py-1.5 rounded-lg border"
                :class="scope === opt.k ? 'bg-role-admin text-white border-transparent' : 'border-slate-200 text-slate-600'"
                @click="scope = opt.k as typeof scope"
              >{{ opt.l }}</button>
            </div>
          </div>
          <div class="mb-3">
            <div class="text-[9.5px] font-bold uppercase tracking-[.08em] text-slate-400 mb-1.5">Lingkup</div>
            <div class="flex gap-1.5 flex-wrap">
              <button v-for="opt in [{k:'class',l:'Per kelas'},{k:'grade',l:'Per tingkat'},{k:'school',l:'Se-sekolah'}]" :key="opt.k" type="button" class="text-[11px] font-semibold px-2.5 py-1.5 rounded-lg border" :class="lingkup === opt.k ? 'bg-role-admin-soft text-role-admin border-transparent' : 'border-slate-200 text-slate-600'" @click="lingkup = opt.k as typeof lingkup">{{ opt.l }}</button>
            </div>
          </div>
          <div class="mb-3">
            <div class="text-[9.5px] font-bold uppercase tracking-[.08em] text-slate-400 mb-1.5">Format</div>
            <div class="flex gap-1.5 flex-wrap">
              <button v-for="opt in [{k:'xlsx',l:'XLSX'},{k:'pdf',l:'PDF rapor'},{k:'csv',l:'CSV'}]" :key="opt.k" type="button" class="text-[11px] font-semibold px-2.5 py-1.5 rounded-lg border" :class="format === opt.k ? 'bg-role-admin text-white border-transparent' : 'border-slate-200 text-slate-600'" @click="format = opt.k as typeof format">{{ opt.l }}</button>
            </div>
          </div>

          <button
            type="button"
            class="w-full flex items-center justify-center gap-2 bg-role-admin text-white text-[12.5px] font-semibold py-2.5 rounded-lg disabled:opacity-50"
            :disabled="!canExport || exportBusy || !classId"
            @click="exportReport"
          >
            <NavIcon name="download" :size="16" />
            {{ exportBusy ? 'Menyiapkan…' : `Export · Rekap ${monthName}` }}
          </button>
          <div v-if="!canExport" class="mt-1.5 text-center text-[10.5px] text-slate-400 font-medium">
            Hanya admin dengan izin export yang bisa mengunduh.
          </div>
          <div v-else-if="!classId" class="mt-1.5 text-center text-[10.5px] text-slate-400 font-medium">
            Pilih kelas dulu untuk export bulanan.
          </div>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white shadow-card p-4">
          <div class="flex items-center gap-2.5 mb-2.5">
            <span class="w-9.5 h-9.5 rounded-[11px] bg-red-100 text-red-700 font-bold text-[14px] grid place-items-center" style="width:38px;height:38px">
              {{ kpiPerluPerhatian }}
            </span>
            <div>
              <h4 class="text-[13px] font-bold text-slate-900">Perlu perhatian</h4>
              <div class="text-[11px] text-slate-500 font-medium">alfa lebih dari 3 hari bulan ini</div>
            </div>
          </div>
          <div v-if="perluPerhatianList.length === 0" class="text-center text-slate-400 text-[12px] py-3">
            Belum ada siswa yang perlu perhatian 🎉
          </div>
          <div v-else class="flex flex-col gap-1">
            <div v-for="s in perluPerhatianList" :key="s.id" class="flex items-center gap-2.5 text-[11.5px] py-1">
              <span class="w-6.5 h-6.5 rounded-lg grid place-items-center bg-red-100 text-red-700 font-bold text-[10px]" style="width:26px;height:26px">
                {{ s.name.split(' ').filter(Boolean).slice(0, 2).map(w => w[0]?.toUpperCase()).join('') }}
              </span>
              <span class="font-semibold text-slate-900 truncate flex-1">{{ s.name }}</span>
              <span class="text-[10px] text-red-700 font-bold">{{ s.alfa }} alfa</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

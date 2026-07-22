<script setup lang="ts">
/**
 * Kehadiran Siswa · Per Mapel (mockup §04) — redesign of the old
 * "Laporan Sesi" view. One row per session (mapel × kelas × JP) with the
 * teacher who recorded it, a % kehadiran bar, and a Terisi / Pending
 * status pill. Right rail carries the "Belum diinput guru" reminder card
 * + a "Mapel kehadiran terendah" insight strip.
 *
 * Data: existing `AttendanceService.getAdminSummary` + `getStudentTimeseries`
 * — no new backend endpoint needed. The session-detail drawer opens via
 * the existing `admin.student-attendance.detail` route (unchanged).
 */
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { AttendanceService } from '@/services/attendance.service';
import type { AdminAttendanceSummary } from '@/types/attendance';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import NavIcon from '@/components/feature/NavIcon.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';

const router = useRouter();

const date = ref<string>(new Date().toISOString().slice(0, 10));
const search = ref('');
const filter = ref<'all' | 'filled' | 'pending'>('all');

const loading = ref(false);
const errorMsg = ref<string | null>(null);
const rows = ref<AdminAttendanceSummary[]>([]);

const filtered = computed<AdminAttendanceSummary[]>(() => {
  const q = search.value.trim().toLowerCase();
  return rows.value.filter((r) => {
    // "pending" = a session with no recorded rows yet — we approximate as
    // total_students > 0 and present + absent all zero. The BE returns
    // percentage=null for those.
    const isPending = r.percentage == null || (r.present === 0 && r.absent === 0 && r.total_students > 0);
    if (filter.value === 'filled' && isPending) return false;
    if (filter.value === 'pending' && !isPending) return false;
    if (!q) return true;
    return (
      r.subject_name.toLowerCase().includes(q) ||
      r.class_name.toLowerCase().includes(q) ||
      (r.teacher_name ?? '').toLowerCase().includes(q)
    );
  });
});

const kpiTotal = computed(() => rows.value.length);
const kpiFilled = computed(() => rows.value.filter((r) => r.percentage != null).length);
const kpiPending = computed(() => kpiTotal.value - kpiFilled.value);
const kpiAvg = computed(() => {
  const filled = rows.value.filter((r) => r.percentage != null);
  if (filled.length === 0) return null;
  return Math.round(filled.reduce((s, r) => s + (r.percentage ?? 0), 0) / filled.length);
});

const pendingRows = computed(() =>
  rows.value.filter((r) => r.percentage == null || (r.present === 0 && r.absent === 0)).slice(0, 4),
);

// Aggregate lowest-attendance mapels for the insight strip
const lowestMapel = computed(() => {
  const bySubject = new Map<string, { name: string; total: number; sum: number }>();
  for (const r of rows.value) {
    if (r.percentage == null) continue;
    const cur = bySubject.get(r.subject_id) ?? { name: r.subject_name, total: 0, sum: 0 };
    cur.total += 1;
    cur.sum += r.percentage;
    bySubject.set(r.subject_id, cur);
  }
  return Array.from(bySubject.values())
    .map((x) => ({ name: x.name, pct: Math.round(x.sum / x.total) }))
    .sort((a, b) => a.pct - b.pct)
    .slice(0, 4);
});

async function load() {
  loading.value = true;
  errorMsg.value = null;
  try {
    const res = await AttendanceService.getAdminSummary({
      date_start: date.value,
      date_end: date.value,
      per_page: 200,
    });
    rows.value = res.items;
  } catch (e) {
    errorMsg.value = (e as Error)?.message ?? 'Gagal memuat sesi.';
  } finally {
    loading.value = false;
  }
}

function stepDate(delta: number) {
  const d = new Date(date.value);
  d.setDate(d.getDate() + delta);
  date.value = d.toISOString().slice(0, 10);
}

function fmtDate(iso: string): string {
  return new Date(iso).toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

function openDetail(row: AdminAttendanceSummary) {
  void router.push({
    name: 'admin.student-attendance.detail',
    query: {
      class_id: row.class_id,
      subject_id: row.subject_id,
      date: row.date,
      ...(row.lesson_hour_id ? { lesson_hour_id: row.lesson_hour_id } : {}),
      ...(row.teacher_id ? { teacher_id: row.teacher_id, teacher_name: row.teacher_name ?? '' } : {}),
      ...(row.id ? { attendance_id: row.id } : {}),
    },
  });
}

function pctColor(pct: number): string {
  if (pct >= 90) return 'bg-emerald-500';
  if (pct >= 80) return 'bg-amber-500';
  return 'bg-red-500';
}

function pctInk(pct: number): string {
  if (pct >= 90) return 'text-emerald-700';
  if (pct >= 80) return 'text-amber-700';
  return 'text-red-700';
}

function teacherInitials(name: string | null | undefined): string {
  if (!name) return '?';
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

onMounted(() => void load());
watch(date, () => void load());
useAcademicYearWatcher(() => void load());
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- Toolbar -->
    <div class="flex flex-wrap items-center gap-2">
      <div class="inline-flex rounded-lg border border-slate-200 bg-white overflow-hidden">
        <button type="button" class="px-2 py-2 text-slate-500 hover:bg-slate-50" @click="stepDate(-1)" aria-label="Sebelumnya">
          <NavIcon name="chevron-left" :size="14" />
        </button>
        <input v-model="date" type="date" class="border-l border-r border-slate-200 px-3 py-2 text-[12px] font-semibold text-slate-900 focus:outline-none tabular-nums" />
        <button type="button" class="px-2 py-2 text-slate-500 hover:bg-slate-50" @click="stepDate(1)" aria-label="Berikutnya">
          <NavIcon name="chevron-right" :size="14" />
        </button>
      </div>
      <label class="flex-1 min-w-[220px] flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-[12px] text-slate-500">
        <NavIcon name="search" :size="14" />
        <input v-model="search" type="text" placeholder="Cari kelas / mapel / guru…" class="flex-1 border-0 outline-none bg-transparent text-slate-900 placeholder:text-slate-400" />
      </label>
      <SegmentedControl
        v-model="filter as unknown as string"
        :options="[
          { key: 'all', label: 'Semua' },
          { key: 'filled', label: 'Terisi' },
          { key: 'pending', label: 'Pending' },
        ]"
      />
    </div>

    <!-- KPI strip: 4 cards -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-[color:var(--role-admin,#143068)]" />Total sesi
        </div>
        <div class="text-[24px] font-bold text-slate-900 tabular-nums">{{ kpiTotal }}</div>
        <div class="text-[11px] text-slate-500 mt-0.5">hari ini</div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-emerald-500" />Sudah diinput
        </div>
        <div class="text-[24px] font-bold text-emerald-700 tabular-nums">{{ kpiFilled }}</div>
        <div class="text-[11px] text-slate-500 mt-0.5">
          {{ kpiTotal ? Math.round((kpiFilled / kpiTotal) * 100) : 0 }}% terisi
        </div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-amber-500" />Belum diinput
        </div>
        <div class="text-[24px] font-bold text-amber-700 tabular-nums">{{ kpiPending }}</div>
        <div class="text-[11px] text-slate-500 mt-0.5">guru belum menandai</div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-sky-500" />Rata hadir
        </div>
        <div class="text-[24px] font-bold text-sky-700 tabular-nums">
          {{ kpiAvg != null ? kpiAvg + '%' : '—' }}
        </div>
        <div class="text-[11px] text-slate-500 mt-0.5">sesi terisi</div>
      </div>
    </div>

    <!-- Body -->
    <div class="grid grid-cols-1 lg:grid-cols-[1fr_336px] gap-4">
      <div class="rounded-2xl border border-slate-200 bg-white shadow-card overflow-hidden">
        <div class="flex items-center gap-2 px-4 py-3.5 border-b border-slate-100">
          <h4 class="text-[13.5px] font-bold text-slate-900">Sesi presensi · {{ fmtDate(date) }}</h4>
          <span class="text-[11px] text-slate-400 font-semibold">{{ filtered.length }} sesi</span>
        </div>
        <div v-if="loading" class="p-10 text-center text-slate-400 text-sm">Memuat sesi…</div>
        <div v-else-if="errorMsg" class="p-6 text-sm text-red-600 border-l-4 border-red-500 bg-red-50 m-4 rounded">{{ errorMsg }}</div>
        <div v-else-if="filtered.length === 0" class="p-10 text-center text-slate-400 text-sm">Tidak ada sesi yang cocok.</div>
        <template v-else>
          <div class="hidden md:grid grid-cols-[1fr_74px_140px_150px_92px] gap-2.5 px-4 py-2 text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 bg-slate-50 border-b border-slate-100">
            <span>Sesi</span><span>JP</span><span>Guru</span><span>Kehadiran</span><span>Status</span>
          </div>
          <div>
            <button
              v-for="row in filtered"
              :key="`${row.class_id}-${row.subject_id}-${row.date}-${row.lesson_hour_id ?? '0'}`"
              type="button"
              class="w-full text-left grid grid-cols-[1fr_74px_140px_150px_92px] gap-2.5 items-center px-4 py-2.5 border-b border-slate-100 text-[12.5px] hover:bg-slate-50 focus:outline-none focus:bg-slate-50"
              :class="{ 'bg-[repeating-linear-gradient(135deg,rgba(245,158,11,.06)_0_8px,transparent_8px_16px)] hover:bg-amber-50': row.percentage == null }"
              @click="openDetail(row)"
            >
              <div class="flex items-center gap-3 min-w-0">
                <span class="w-8.5 h-8.5 rounded-[10px] grid place-items-center font-bold text-[14px] shrink-0 bg-role-admin-soft text-role-admin" style="width:34px;height:34px">
                  {{ row.subject_name.charAt(0).toUpperCase() }}
                </span>
                <div class="min-w-0">
                  <div class="font-semibold text-slate-900 truncate">{{ row.subject_name }}</div>
                  <div class="text-[10.5px] text-slate-400 font-semibold">{{ row.class_name }}</div>
                </div>
              </div>
              <div class="text-[12px] font-semibold text-slate-600">
                <span v-if="row.jam_ke">JP {{ row.jam_ke }}</span>
                <span v-else-if="row.hour_number">JP {{ row.hour_number }}</span>
                <span v-else class="text-slate-400">—</span>
              </div>
              <div v-if="row.percentage == null" class="flex items-center gap-2 min-w-0">
                <span class="w-6 h-6 rounded-full grid place-items-center text-amber-700 bg-amber-100 font-bold text-[10px] shrink-0">!</span>
                <span class="text-[11px] font-semibold text-amber-700 truncate">Belum diinput</span>
              </div>
              <div v-else class="flex items-center gap-2 min-w-0">
                <span class="w-6 h-6 rounded-full grid place-items-center bg-brand-cobalt text-white font-bold text-[9px] shrink-0">
                  {{ teacherInitials(row.teacher_name) }}
                </span>
                <span class="text-[11px] font-semibold text-slate-500 truncate">
                  {{ row.teacher_name ?? '—' }}
                </span>
              </div>
              <div v-if="row.percentage == null">
                <div class="h-2 rounded-md bg-slate-100 overflow-hidden">
                  <div class="h-full w-full bg-[repeating-linear-gradient(90deg,#f1d9a8_0_5px,transparent_5px_10px)]" />
                </div>
              </div>
              <div v-else class="flex items-center gap-2">
                <span class="flex-1 h-2 rounded-md bg-slate-100 overflow-hidden">
                  <span class="block h-full" :style="{ width: (row.percentage ?? 0) + '%' }" :class="pctColor(row.percentage)" />
                </span>
                <span class="tabular-nums font-bold text-[12px] w-9 text-right" :class="pctInk(row.percentage)">
                  {{ Math.round(row.percentage) }}%
                </span>
              </div>
              <div>
                <span
                  v-if="row.percentage == null"
                  class="inline-flex items-center gap-1.5 text-[10.5px] font-bold px-2.5 py-1 rounded-full bg-amber-100 text-amber-700"
                >
                  <span class="w-1.5 h-1.5 rounded-full bg-amber-500" />Pending
                </span>
                <span
                  v-else
                  class="inline-flex items-center gap-1.5 text-[10.5px] font-bold px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700"
                >
                  <span class="w-1.5 h-1.5 rounded-full bg-emerald-500" />Terisi
                </span>
              </div>
            </button>
          </div>
        </template>
      </div>

      <!-- Right rail: pending reminder + lowest mapel insight -->
      <div class="flex flex-col gap-4">
        <div class="rounded-2xl border border-amber-200 bg-white shadow-card p-4">
          <div class="flex items-center gap-2.5 mb-2.5">
            <span class="w-9.5 h-9.5 rounded-[11px] bg-amber-100 text-amber-700 font-bold text-[14px] grid place-items-center" style="width:38px;height:38px">
              {{ kpiPending }}
            </span>
            <div>
              <h4 class="text-[13px] font-bold text-slate-900">Belum diinput guru</h4>
              <div class="text-[11px] text-slate-500 font-medium">
                {{ kpiPending === 0 ? 'Semua sesi tercatat 🎉' : `${kpiPending} sesi presensi kosong` }}
              </div>
            </div>
          </div>
          <div v-if="pendingRows.length > 0" class="flex flex-col gap-1 mb-3">
            <div
              v-for="row in pendingRows"
              :key="`p-${row.class_id}-${row.subject_id}-${row.date}-${row.lesson_hour_id ?? '0'}`"
              class="flex items-center gap-2.5 text-[11.5px] py-1"
            >
              <span class="w-6.5 h-6.5 rounded-lg bg-amber-100 text-amber-700 font-bold text-[11px] grid place-items-center" style="width:26px;height:26px">
                {{ row.subject_name.charAt(0).toUpperCase() }}
              </span>
              <span class="font-semibold text-slate-900 text-[11px] truncate flex-1">{{ row.subject_name }} · {{ row.class_name }}</span>
              <span class="text-[10px] text-slate-400 font-semibold">
                <span v-if="row.jam_ke">JP {{ row.jam_ke }}</span>
                <span v-else-if="row.hour_number">JP {{ row.hour_number }}</span>
              </span>
            </div>
          </div>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white shadow-card overflow-hidden">
          <div class="flex items-center gap-2 px-4 py-3.5 border-b border-slate-100">
            <h4 class="text-[13.5px] font-bold text-slate-900">Mapel kehadiran terendah</h4>
            <span class="text-[11px] text-slate-400 font-semibold ml-auto">hari ini</span>
          </div>
          <div class="p-4">
            <div v-if="lowestMapel.length === 0" class="text-center text-slate-400 text-[12px] py-3">
              Belum ada data.
            </div>
            <div
              v-for="x in lowestMapel"
              :key="x.name"
              class="flex items-center gap-2.5 text-[11.5px] mb-2"
            >
              <span class="w-24 shrink-0 font-semibold text-slate-600 truncate">{{ x.name }}</span>
              <span class="flex-1 h-1.5 rounded-md bg-slate-100 overflow-hidden">
                <span class="block h-full" :class="pctColor(x.pct)" :style="{ width: x.pct + '%' }" />
              </span>
              <span class="tabular-nums font-bold text-[11px] w-8 text-right" :class="pctInk(x.pct)">{{ x.pct }}%</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

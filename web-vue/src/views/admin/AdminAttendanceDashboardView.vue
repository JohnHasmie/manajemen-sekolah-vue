<!--
  AdminAttendanceDashboardView.vue — admin Kehadiran dashboard.

  Web port of Flutter's `AdminAttendanceDashboardScreen` (Mockup #11).
  Hits `/attendance/dashboard-summary?range=` for real data:
    1. BrandPageHeader (admin) + period segmented control (today/week/month)
    2. KpiStripCards — Rata Kehadiran / Hadir / Tidak Hadir / Δ vs kemarin
    3. Hero card — present_pct ring + range_label + total breakdown
    4. Per-tingkat panel — sparkline rows with delta + alert copy
    5. Action bar — link to Laporan + link to Heatmap

  Range chip change re-fetches with the new range. AY watcher reloads.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { AttendanceService } from '@/services/attendance.service';
import type { AttendanceDashboard, AttendanceRange, TingkatTrend } from '@/types/attendance';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AdminAttendanceNewSessionWizard from '@/components/feature/AdminAttendanceNewSessionWizard.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const router = useRouter();

const dashboard = ref<AttendanceDashboard | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);

const periodKey = ref<AttendanceRange>('today');

const PERIOD_OPTIONS: { key: AttendanceRange; label: string }[] = [
  { key: 'today', label: 'Hari ini' },
  { key: 'week', label: 'Pekan' },
  { key: 'month', label: 'Bulan' },
];

const state = computed<AsyncState<AttendanceDashboard>>(() => {
  if (isLoading.value && !dashboard.value) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (!dashboard.value) return { status: 'empty' };
  return { status: 'content', data: dashboard.value };
});

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    dashboard.value = await AttendanceService.getDashboardSummary({
      range: periodKey.value,
    });
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
useAcademicYearWatcher(load);

function onPeriodChange(v: string) {
  periodKey.value = v as AttendanceRange;
  void load();
}

// ── Derived ────────────────────────────────────────────────────────
const totals = computed(() => dashboard.value?.totals);
const kpi = computed(() => dashboard.value?.kpi);

const totalAbsent = computed(() => {
  const t = totals.value;
  if (!t) return 0;
  return t.excused + t.sick + t.alpha;
});

const totalRecorded = computed(() => {
  const t = totals.value;
  if (!t) return 0;
  return t.present + t.excused + t.sick + t.alpha;
});

const presentPct = computed(() => {
  return totals.value?.present_pct ?? 0;
});

const absentDeltaText = computed(() => {
  const d = kpi.value?.absent_delta ?? 0;
  if (d === 0) return 'Sama dengan kemarin';
  const arrow = d > 0 ? '↑' : '↓';
  return `${arrow} ${Math.abs(d)} dari kemarin`;
});

const absentDeltaTone = computed(() => {
  const d = kpi.value?.absent_delta ?? 0;
  if (d === 0) return 'slate';
  return d > 0 ? 'red' : 'green';
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'check-circle',
    label: 'Rata Kehadiran',
    value: `${(kpi.value?.avg_pct ?? 0).toFixed(1)}%`,
    suffix: '7 hari',
    tone: 'green',
    accented: true,
  },
  {
    icon: 'users',
    label: 'Hadir',
    value: totals.value?.present ?? 0,
    tone: 'brand',
  },
  {
    icon: 'user-x',
    label: 'Tidak Hadir',
    value: totalAbsent.value,
    tone: totalAbsent.value > 0 ? 'amber' : 'green',
    suffix: dashboard.value?.range_label ?? '',
  },
  {
    icon: 'trending-up',
    label: 'Δ vs Kemarin',
    value: absentDeltaText.value,
    tone: absentDeltaTone.value as KpiCard['tone'],
    accented: (kpi.value?.absent_delta ?? 0) !== 0,
  },
]);

// ── Sparkline helper ────────────────────────────────────────────────
function sparklinePath(series: number[], w = 80, h = 28): string {
  if (series.length === 0) return '';
  const max = Math.max(100, ...series);
  const min = Math.min(0, ...series);
  const span = max - min || 1;
  const step = w / Math.max(1, series.length - 1);
  return series
    .map((v, i) => {
      const x = i * step;
      const y = h - ((v - min) / span) * h;
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
}

function tingkatDeltaTone(t: TingkatTrend): 'green' | 'amber' | 'red' | 'slate' {
  if (t.delta_pct >= 2) return 'green';
  if (t.delta_pct <= -2) return 'red';
  if (t.current_pct < 80) return 'amber';
  return 'slate';
}

// ── Trend-window caption helpers ──────────────────────────────────
function formatShortDate(iso: string): string {
  if (!iso) return '—';
  // Parse as local date — backend sends YYYY-MM-DD.
  const [y, m, d] = iso.split('-').map((v) => Number(v));
  if (!y || !m || !d) return iso;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return `${d} ${months[m - 1]} ${y}`;
}

const trendWindowLabel = computed(() => {
  const w = dashboard.value?.trend_window;
  if (!w) return '7 hari terakhir';
  return `${formatShortDate(w.start)} – ${formatShortDate(w.end)}`;
});

const trendWindowIsHistorical = computed(
  () => dashboard.value?.trend_window?.is_historical === true,
);

function openTingkatHeatmap(t: TingkatTrend) {
  router.push({
    name: 'admin.attendance.tingkat',
    params: { tingkat: String(t.tingkat) },
  });
}

function openLaporan() {
  router.push({ name: 'admin.attendance.laporan' });
}

const showNewSessionWizard = ref(false);

function onWizardDone(payload: {
  teacher_id: string;
  teacher_name: string;
  class_id: string;
  subject_id: string;
  date: string;
  lesson_hour_id?: string;
}) {
  router.push({
    name: 'admin.attendance.detail',
    query: {
      class_id: payload.class_id,
      subject_id: payload.subject_id,
      date: payload.date,
      lesson_hour_id: payload.lesson_hour_id ?? '',
      teacher_id: payload.teacher_id,
      teacher_name: payload.teacher_name,
    },
  });
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Akademik · Kehadiran"
      title="Dashboard Kehadiran"
      meta="Ringkasan sekolah · drill ke tingkat untuk detail per-siswa"
      :live-dot="false"
    >
      <div class="flex items-center gap-2 flex-wrap">
        <SegmentedControl
          :model-value="periodKey"
          :options="PERIOD_OPTIONS"
          size="sm"
          @update:model-value="onPeriodChange"
        />
        <button
          type="button"
          class="text-[11px] font-bold text-white/90 hover:text-white px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
          @click="openLaporan"
        >
          <NavIcon name="file-text" :size="11" class="inline" />
          Laporan
        </button>
      </div>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <AsyncView
      :state="state"
      empty-title="Belum ada data kehadiran"
      empty-description="Tidak ada catatan presensi untuk rentang waktu ini. Coba periksa lagi setelah guru menginput kehadiran hari ini."
      empty-icon="check-square"
      error-title="Gagal memuat dashboard kehadiran"
      @retry="load"
    >
      <template #default>
        <!-- Ring hero -->
        <section
          class="rounded-3xl p-6 text-white shadow-xl shadow-role-admin/15 relative overflow-hidden"
          style="background: linear-gradient(135deg, #0A1F4D 0%, #143068 100%);"
        >
          <div class="absolute -top-12 -right-12 w-44 h-44 bg-white/10 rounded-full blur-3xl"></div>
          <div class="relative z-10 flex items-center gap-6 flex-wrap">
            <!-- Ring -->
            <div class="relative w-32 h-32 flex-shrink-0">
              <svg viewBox="0 0 120 120" class="w-full h-full -rotate-90">
                <circle
                  cx="60"
                  cy="60"
                  r="52"
                  fill="none"
                  stroke="rgba(255,255,255,0.15)"
                  stroke-width="10"
                />
                <circle
                  cx="60"
                  cy="60"
                  r="52"
                  fill="none"
                  stroke="#10B981"
                  stroke-width="10"
                  stroke-linecap="round"
                  :stroke-dasharray="`${(presentPct / 100) * 326.7} 326.7`"
                />
              </svg>
              <div class="absolute inset-0 grid place-items-center text-center">
                <div>
                  <p class="text-[10px] font-bold text-white/70 uppercase tracking-widest">
                    Hadir
                  </p>
                  <p class="text-2xl font-black">{{ presentPct.toFixed(1) }}%</p>
                </div>
              </div>
            </div>

            <!-- Right column — period + breakdown -->
            <div class="flex-1 min-w-[200px] space-y-2">
              <p class="text-[10px] font-bold tracking-widest uppercase text-white/70">
                {{ dashboard?.range_label ?? '—' }}
              </p>
              <p class="text-[12px] text-white/80">
                {{ totalRecorded }} siswa tercatat
                <span v-if="totals && totals.present > 0">· {{ totals.present }} hadir</span>
              </p>
              <div class="grid grid-cols-3 gap-2 mt-3">
                <div class="bg-white/10 rounded-xl px-3 py-2">
                  <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">
                    Izin
                  </p>
                  <p class="text-[15px] font-black mt-0.5">{{ totals?.excused ?? 0 }}</p>
                </div>
                <div class="bg-white/10 rounded-xl px-3 py-2">
                  <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">
                    Sakit
                  </p>
                  <p class="text-[15px] font-black mt-0.5">{{ totals?.sick ?? 0 }}</p>
                </div>
                <div class="bg-white/10 rounded-xl px-3 py-2">
                  <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">
                    Alpa
                  </p>
                  <p class="text-[15px] font-black mt-0.5">{{ totals?.alpha ?? 0 }}</p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- Per-tingkat sparkline panel -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4 mt-4">
          <header class="flex items-center justify-between mb-3 px-1">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-xl bg-violet-100 text-violet-700 grid place-items-center">
                <NavIcon name="activity" :size="16" />
              </div>
              <div>
                <h3 class="text-sm font-black text-slate-900 leading-none">
                  Tren per Tingkat
                </h3>
                <p class="text-[10px] text-slate-400 font-bold mt-0.5">
                  {{ trendWindowLabel }} · tap untuk lihat heatmap siswa
                </p>
              </div>
            </div>
            <span
              v-if="trendWindowIsHistorical && dashboard?.tingkats?.length"
              class="text-[9.5px] font-bold text-amber-700 bg-amber-50 border border-amber-200 px-2 py-1 rounded-lg"
              :title="`Tidak ada catatan presensi 7 hari terakhir; menampilkan data sampai ${formatShortDate(dashboard?.trend_window?.end ?? '')}`"
            >
              DATA HISTORIS
            </span>
          </header>

          <div
            v-if="!dashboard?.tingkats?.length"
            class="py-10 text-center text-[12px] text-slate-400 leading-relaxed"
          >
            Belum ada catatan presensi.<br />
            Mulai presensi pertama agar tren tingkat mulai terisi.
          </div>
          <ul v-else class="divide-y divide-slate-100">
            <li v-for="t in dashboard.tingkats" :key="t.tingkat">
              <button
                type="button"
                class="w-full text-left px-1 py-3 flex items-center gap-3 hover:bg-slate-50 rounded-xl transition-colors"
                @click="openTingkatHeatmap(t)"
              >
                <div class="w-10 h-10 rounded-xl bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0">
                  <span class="text-[13px] font-black">{{ t.tingkat }}</span>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-[13px] font-bold text-slate-900">Tingkat {{ t.tingkat }}</p>
                  <p
                    v-if="t.alert_copy"
                    class="text-[10px] font-bold mt-0.5 leading-tight"
                    :class="{
                      'text-red-700': t.current_pct < 80,
                      'text-amber-700': t.current_pct >= 80,
                    }"
                  >
                    {{ t.alert_copy }}
                  </p>
                  <p v-else class="text-[10px] text-slate-500 mt-0.5">
                    Stabil
                  </p>
                </div>
                <!-- Sparkline -->
                <svg
                  viewBox="0 0 80 28"
                  class="w-20 h-7 flex-shrink-0"
                  preserveAspectRatio="none"
                >
                  <path
                    :d="sparklinePath(t.series)"
                    fill="none"
                    :stroke="
                      tingkatDeltaTone(t) === 'green'
                        ? '#10B981'
                        : tingkatDeltaTone(t) === 'red'
                          ? '#EF4444'
                          : tingkatDeltaTone(t) === 'amber'
                            ? '#F59E0B'
                            : '#94A3B8'
                    "
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                </svg>
                <div class="text-right flex-shrink-0 w-16">
                  <p class="text-[13px] font-black text-slate-900 tabular-nums">
                    {{ t.current_pct.toFixed(1) }}%
                  </p>
                  <p
                    class="text-[10px] font-bold tabular-nums"
                    :class="{
                      'text-emerald-700': t.delta_pct > 0,
                      'text-red-700': t.delta_pct < 0,
                      'text-slate-400': t.delta_pct === 0,
                    }"
                  >
                    {{ t.delta_pct > 0 ? '+' : '' }}{{ t.delta_pct.toFixed(1) }}
                  </p>
                </div>
                <NavIcon name="chevron-right" :size="14" class="text-slate-300 ml-1" />
              </button>
            </li>
          </ul>
        </section>

        <!-- Action bar -->
        <section class="grid grid-cols-2 gap-2 mt-4">
          <Button variant="secondary" block @click="openLaporan">
            <NavIcon name="file-text" :size="13" />
            Lihat Laporan Sesi
          </Button>
          <Button
            variant="primary"
            block
            :disabled="!dashboard?.tingkats?.length"
            @click="dashboard?.tingkats?.[0] && openTingkatHeatmap(dashboard.tingkats[0])"
          >
            <NavIcon name="grid" :size="13" />
            Buka Heatmap Siswa
          </Button>
        </section>
      </template>
    </AsyncView>

    <!-- Mulai Presensi FAB -->
    <Button
      variant="primary"
      class="fixed bottom-6 right-6 z-30 shadow-lg shadow-role-admin/30"
      @click="showNewSessionWizard = true"
    >
      <NavIcon name="plus" :size="14" />
      Mulai Presensi
    </Button>

    <AdminAttendanceNewSessionWizard
      v-if="showNewSessionWizard"
      @close="showNewSessionWizard = false"
      @done="onWizardDone"
    />
  </div>
</template>

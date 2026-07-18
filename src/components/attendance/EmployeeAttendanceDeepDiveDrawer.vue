<!--
  EmployeeAttendanceDeepDiveDrawer.vue — per-person 30-day drill-down
  opened from a Rekap row on the pegawai attendance dashboard (MR-3
  Opsi A).

  Right-side slide-over that loads its own data on open — the parent
  only supplies `open`, `personId`, and the period bounds. This keeps
  the caller's state minimal (no need to prefetch or shape the deep-
  dive payload) and makes the drawer reusable from other surfaces
  later (mobile MR-4, engagement view, etc.).

  Sections (top to bottom):
    · Profile hero — name + personnel chip + subject/role + streak chip
    · KPI blocks — 4 stat tiles (ontime %, hadir, telat, absen)
    · 30-day heatmap — one square per calendar day, tone by status
    · Aktivitas terbaru — the last 10 raw rows the backend supplies
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import type {
  TeacherAttendanceEmployeeDeepDive,
  TeacherAttendanceHeatmapCell,
} from '@/types/teacher-attendance';
import {
  teacherAttendancePersonnelLabel,
  teacherAttendanceStatusLabel,
} from '@/types/teacher-attendance';

const props = defineProps<{
  open: boolean;
  personId: string | null;
  personName?: string | null;
  startDate?: string;
  endDate?: string;
}>();

defineEmits<{ close: [] }>();

const data = ref<TeacherAttendanceEmployeeDeepDive | null>(null);
const loading = ref(false);
const errorMsg = ref<string | null>(null);

async function load() {
  if (!props.personId) return;
  loading.value = true;
  errorMsg.value = null;
  try {
    data.value = await TeacherAttendanceService.adminEmployeeDeepDive({
      personId: props.personId,
      start_date: props.startDate,
      end_date: props.endDate,
    });
  } catch (e) {
    errorMsg.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

// Re-fetch each time the drawer opens with a fresh personId (or when
// the period bounds change while it's open — the parent can flip
// filters while a drawer is up).
watch(
  () => [props.open, props.personId, props.startDate, props.endDate] as const,
  ([isOpen, id]) => {
    if (isOpen && id) {
      data.value = null;
      load();
    }
  },
  { immediate: true },
);

// ── Derived helpers ───────────────────────────────────────────────
function fmtTime(iso: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

function fmtRange(): string {
  const p = data.value?.period;
  if (!p) return '';
  const fmt = (d: string) =>
    d
      ? new Date(d).toLocaleDateString('id-ID', {
          day: 'numeric',
          month: 'short',
        })
      : '';
  return `${fmt(p.start_date)} – ${fmt(p.end_date)}`;
}

const kpi = computed(() => data.value?.kpi ?? null);
const person = computed(() => data.value?.person ?? null);
const heatmap = computed<TeacherAttendanceHeatmapCell[]>(
  () => data.value?.heatmap ?? [],
);
const recent = computed(() => data.value?.recent_rows ?? []);

/** Column count for the heatmap grid — 7 for the classic weekday
 *  layout. The cells are dense (dense-ordered by date), so this is a
 *  simple grid-cols-7 pattern with a small gap. */
const HEAT_COLS = 7;
function heatCellClass(cell: TeacherAttendanceHeatmapCell): string {
  if (cell.status === 'present')
    return 'bg-emerald-500';
  if (cell.status === 'late') return 'bg-amber-500';
  if (cell.status === 'absent') return 'bg-red-500';
  return 'bg-slate-100'; // off / non-workday
}

function heatCellLabel(cell: TeacherAttendanceHeatmapCell): string {
  const dateLabel = cell.date.slice(8, 10);
  if (cell.status === 'off') return `${cell.date} · Libur`;
  const words: Record<string, string> = {
    present: 'Tepat waktu',
    late: 'Terlambat',
    absent: 'Absen',
  };
  return `${cell.date} · ${words[cell.status]} (${dateLabel})`;
}

const streakLabel = computed(() => {
  const d = kpi.value?.streak_days ?? 0;
  return d > 0 ? `${d} hari beruntun` : '-';
});
</script>

<template>
  <div>
    <!-- Backdrop -->
    <Transition
      enter-active-class="transition-opacity duration-200"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-200"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="open"
        class="fixed inset-0 bg-slate-900/50 z-40 backdrop-blur-sm"
        @click="$emit('close')"
      />
    </Transition>

    <!-- Panel -->
    <Transition
      enter-active-class="transition-transform duration-250 ease-out"
      enter-from-class="translate-x-full"
      enter-to-class="translate-x-0"
      leave-active-class="transition-transform duration-200 ease-in"
      leave-from-class="translate-x-0"
      leave-to-class="translate-x-full"
    >
      <aside
        v-if="open"
        class="fixed inset-y-0 right-0 w-full sm:w-[480px] bg-white border-l border-slate-200 z-50 flex flex-col shadow-2xl"
        role="dialog"
        aria-modal="true"
      >
        <!-- Header -->
        <header
          class="px-5 py-4 border-b border-slate-100 flex items-start justify-between gap-3"
        >
          <div class="min-w-0">
            <p
              class="text-3xs font-bold text-slate-400 uppercase tracking-widest"
            >
              Rekap Pegawai
            </p>
            <h2 class="text-[15px] font-black text-slate-900 truncate mt-0.5">
              {{ person?.name ?? personName ?? 'Detail Pegawai' }}
            </h2>
            <p class="text-2xs text-slate-500 mt-0.5">
              Periode {{ fmtRange() || '-' }}
            </p>
          </div>
          <button
            type="button"
            class="p-2 rounded-full hover:bg-slate-100 text-slate-500"
            aria-label="Tutup panel"
            @click="$emit('close')"
          >
            <NavIcon name="x" :size="18" />
          </button>
        </header>

        <!-- Body -->
        <div class="flex-1 overflow-y-auto">
          <!-- Loading -->
          <div
            v-if="loading"
            class="h-full grid place-items-center py-10 text-2xs text-slate-500"
          >
            <div class="flex items-center gap-2">
              <Spinner size="sm" />
              <span>Memuat detail…</span>
            </div>
          </div>

          <!-- Error -->
          <div
            v-else-if="errorMsg"
            class="p-5 space-y-2"
          >
            <p class="text-2xs font-bold text-red-600">Gagal memuat detail.</p>
            <p class="text-2xs text-slate-500">{{ errorMsg }}</p>
            <button
              type="button"
              class="px-3 py-1.5 rounded-lg border border-slate-200 text-2xs font-bold hover:bg-slate-50"
              @click="load"
            >
              Coba lagi
            </button>
          </div>

          <template v-else-if="data">
            <!-- Profile hero -->
            <section class="px-5 pt-5 pb-3">
              <div class="flex items-center gap-2 flex-wrap">
                <span
                  class="text-2xs font-bold px-2 py-1 rounded-full"
                  :class="
                    person?.personnel_type === 'staff'
                      ? 'bg-violet-100 text-violet-700'
                      : 'bg-sky-100 text-sky-700'
                  "
                >
                  {{
                    teacherAttendancePersonnelLabel(person?.personnel_type)
                  }}
                </span>
                <span
                  v-if="person?.employee_number"
                  class="text-2xs font-bold px-2 py-1 rounded-full bg-slate-100 text-slate-600"
                >
                  NIP {{ person.employee_number }}
                </span>
                <span
                  v-if="person?.role_label"
                  class="text-2xs font-bold px-2 py-1 rounded-full bg-slate-100 text-slate-600"
                >
                  {{ person.role_label }}
                </span>
                <span
                  class="text-2xs font-bold px-2 py-1 rounded-full bg-brand-cobalt/10 text-brand-cobalt inline-flex items-center gap-1"
                >
                  <NavIcon name="flame" :size="11" />{{ streakLabel }}
                </span>
              </div>
            </section>

            <!-- KPI stat blocks -->
            <section class="px-5 pb-4 grid grid-cols-2 gap-2">
              <div class="rounded-2xl border border-slate-200 bg-white p-3">
                <p
                  class="text-3xs font-bold text-slate-400 uppercase tracking-widest"
                >
                  Tepat waktu
                </p>
                <p class="text-xl font-black text-emerald-600 mt-1 tabular-nums">
                  {{ kpi?.ontime_pct ?? 0 }}<span class="text-2xs font-bold text-slate-400 ml-0.5">%</span>
                </p>
              </div>
              <div class="rounded-2xl border border-slate-200 bg-white p-3">
                <p
                  class="text-3xs font-bold text-slate-400 uppercase tracking-widest"
                >
                  Hari Hadir
                </p>
                <p class="text-xl font-black text-slate-900 mt-1 tabular-nums">
                  {{ kpi?.present_days ?? 0 }}
                </p>
              </div>
              <div class="rounded-2xl border border-slate-200 bg-white p-3">
                <p
                  class="text-3xs font-bold text-slate-400 uppercase tracking-widest"
                >
                  Terlambat
                </p>
                <p class="text-xl font-black text-amber-600 mt-1 tabular-nums">
                  {{ kpi?.late_days ?? 0 }}
                </p>
              </div>
              <div class="rounded-2xl border border-slate-200 bg-white p-3">
                <p
                  class="text-3xs font-bold text-slate-400 uppercase tracking-widest"
                >
                  Absen
                </p>
                <p class="text-xl font-black text-red-600 mt-1 tabular-nums">
                  {{ kpi?.absent_days ?? 0 }}
                </p>
              </div>
              <div
                v-if="(kpi?.overtime_minutes ?? 0) > 0"
                class="col-span-2 rounded-2xl border border-indigo-200 bg-indigo-50 p-3 flex items-center gap-2"
              >
                <NavIcon name="clock" :size="14" class="text-indigo-600" />
                <div class="flex-1">
                  <p
                    class="text-3xs font-bold text-indigo-500 uppercase tracking-widest"
                  >
                    Lembur
                  </p>
                  <p
                    class="text-[15px] font-black text-indigo-700 tabular-nums"
                  >
                    +{{ kpi?.overtime_minutes }} menit
                  </p>
                </div>
              </div>
            </section>

            <!-- 30-day heatmap -->
            <section class="px-5 pb-4">
              <div class="flex items-center justify-between mb-2">
                <p
                  class="text-3xs font-bold text-slate-500 uppercase tracking-widest"
                >
                  Pola 30 Hari Terakhir
                </p>
                <div class="flex items-center gap-2 text-3xs text-slate-400">
                  <span
                    class="inline-block w-2.5 h-2.5 rounded-sm bg-emerald-500"
                    aria-hidden="true"
                  />hadir
                  <span
                    class="inline-block w-2.5 h-2.5 rounded-sm bg-amber-500"
                    aria-hidden="true"
                  />telat
                  <span
                    class="inline-block w-2.5 h-2.5 rounded-sm bg-red-500"
                    aria-hidden="true"
                  />absen
                </div>
              </div>
              <div
                class="grid gap-1 rounded-2xl border border-slate-200 p-3 bg-white"
                :style="{
                  gridTemplateColumns: `repeat(${HEAT_COLS}, minmax(0, 1fr))`,
                }"
              >
                <div
                  v-for="cell in heatmap"
                  :key="cell.date"
                  class="aspect-square rounded-md"
                  :class="heatCellClass(cell)"
                  :title="heatCellLabel(cell)"
                />
                <div
                  v-if="heatmap.length === 0"
                  class="col-span-7 text-2xs text-slate-400 text-center py-4"
                >
                  Belum ada data untuk periode ini.
                </div>
              </div>
            </section>

            <!-- Aktivitas terbaru -->
            <section class="px-5 pb-6">
              <p
                class="text-3xs font-bold text-slate-500 uppercase tracking-widest mb-2"
              >
                Aktivitas Terbaru
              </p>
              <div
                v-if="recent.length === 0"
                class="text-2xs text-slate-400 text-center py-4 rounded-2xl border border-slate-100"
              >
                Belum ada catatan.
              </div>
              <ul
                v-else
                class="rounded-2xl border border-slate-200 bg-white overflow-hidden divide-y divide-slate-100"
              >
                <li
                  v-for="r in recent"
                  :key="r.id"
                  class="px-3 py-2.5 flex items-center gap-3 text-[12px]"
                >
                  <div class="flex-1 min-w-0">
                    <p class="font-bold text-slate-900">
                      {{
                        new Date(r.date).toLocaleDateString('id-ID', {
                          weekday: 'short',
                          day: 'numeric',
                          month: 'short',
                        })
                      }}
                    </p>
                    <p class="text-2xs text-slate-500">
                      Masuk {{ fmtTime(r.check_in_at) }}
                      · Pulang {{ fmtTime(r.check_out_at) }}
                    </p>
                  </div>
                  <span
                    class="text-3xs font-bold px-1.5 py-0.5 rounded-full"
                    :class="
                      r.status === 'late'
                        ? 'bg-amber-100 text-amber-700'
                        : 'bg-emerald-100 text-emerald-700'
                    "
                  >
                    {{ teacherAttendanceStatusLabel(r.status) }}
                  </span>
                </li>
              </ul>
            </section>
          </template>
        </div>
      </aside>
    </Transition>
  </div>
</template>

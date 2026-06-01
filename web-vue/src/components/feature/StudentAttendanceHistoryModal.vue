<!--
  StudentAttendanceHistoryModal.vue — drill-in view for one
  student's per-session attendance history.

  Mirrors Flutter's per-student detail flow: KPI strip (Hadir /
  Sakit / Izin / Alpa + streak), date-range segmented control
  (30 / 90 / Tahun Ajaran), status filter chips, then a
  reverse-chronological list of `AttendanceHistoryEntry` rows.

  Triggered from TeacherAttendanceDetailView when the user clicks
  a student's avatar / name on the roster. Lazy-loads history via
  `AttendanceService.getStudentHistory`.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { AttendanceService } from '@/services/attendance.service';
import {
  ATTENDANCE_LABELS,
  type AttendanceHistoryEntry,
  type AttendanceRow,
  type AttendanceStatus,
  type StudentAttendanceSummary,
} from '@/types/attendance';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';

const props = withDefaults(
  defineProps<{
    student: AttendanceRow;
    /** Restrict history to a single mapel id. Defaults to all. */
    subjectId?: string;
    /** Class label shown in the modal header. */
    className?: string;
    /** "30" days | "90" days | "ay" (academic year). */
    initialRange?: '30' | '90' | 'ay';
  }>(),
  { subjectId: undefined, className: '', initialRange: '30' },
);

defineEmits<{ close: [] }>();

const range = ref<'30' | '90' | 'ay'>(props.initialRange);
type StatusFilter = 'all' | NonNullable<AttendanceStatus>;
const statusFilter = ref<StatusFilter>('all');
const history = ref<AttendanceHistoryEntry[]>([]);
const isLoading = ref(true);

function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function isoNDaysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

async function load() {
  isLoading.value = true;
  history.value = [];
  try {
    const days = range.value === '90' ? 90 : range.value === 'ay' ? 365 : 30;
    history.value = await AttendanceService.getStudentHistory({
      student_id: props.student.student_id,
      date_start: isoNDaysAgo(days),
      date_end: todayIso(),
      subject_id: props.subjectId,
      per_page: 200,
    });
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
watch(range, load);

const summary = computed<StudentAttendanceSummary>(() => {
  let hadir = 0,
    sakit = 0,
    izin = 0,
    alpa = 0;
  for (const h of history.value) {
    if (h.status === 'hadir') hadir++;
    else if (h.status === 'sakit') sakit++;
    else if (h.status === 'izin') izin++;
    else if (h.status === 'alpa') alpa++;
  }
  const total = history.value.length;
  let streak = 0;
  for (const h of history.value) {
    if (h.status === 'hadir') streak++;
    else break;
  }
  return {
    hadir,
    sakit,
    izin,
    alpa,
    total,
    rate: total ? Math.round((hadir / total) * 100) : 0,
    streak,
  };
});

const filteredHistory = computed(() => {
  if (statusFilter.value === 'all') return history.value;
  return history.value.filter((h) => h.status === statusFilter.value);
});

function statusStyle(s: NonNullable<AttendanceStatus>): {
  bg: string;
  text: string;
  dot: string;
} {
  switch (s) {
    case 'hadir':
      return { bg: 'bg-emerald-50', text: 'text-emerald-700', dot: 'bg-emerald-600' };
    case 'sakit':
      return { bg: 'bg-amber-50', text: 'text-amber-700', dot: 'bg-amber-600' };
    case 'izin':
      return { bg: 'bg-sky-50', text: 'text-sky-700', dot: 'bg-sky-600' };
    case 'alpa':
      return { bg: 'bg-red-50', text: 'text-red-700', dot: 'bg-red-600' };
  }
}

function formatLongDate(d: string): string {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  } catch {
    return d;
  }
}
</script>

<template>
  <Modal title="" @close="$emit('close')">
    <!-- ── Header ──────────────────────────────────────────── -->
    <header class="flex items-start gap-3 -mt-2 mb-4">
      <InitialsAvatar
        :name="student.student_name"
        :size="48"
        :border-radius="14"
        :color="
          student.alert_tone === 'danger'
            ? '#B91C1C'
            : student.alert_tone === 'warning'
              ? '#B45309'
              : '#1B6FB8'
        "
      />
      <div class="flex-1 min-w-0">
        <p
          class="text-[10px] font-bold text-brand-cobalt uppercase tracking-widest"
        >
          Riwayat Kehadiran{{ className ? ` · ${className}` : '' }}
        </p>
        <h2 class="text-base font-black text-slate-900 leading-tight mt-0.5">
          {{ student.student_name || 'Tanpa nama' }}
        </h2>
        <p class="text-[11px] text-slate-500 mt-0.5">
          NIS {{ student.student_number || '—' }}
        </p>
      </div>
    </header>

    <!-- ── KPI strip ─────────────────────────────────────── -->
    <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-3">
      <div class="bg-emerald-50 rounded-xl p-3 text-center">
        <p class="text-[9px] font-bold text-emerald-700 uppercase tracking-widest">
          Hadir
        </p>
        <p class="text-lg font-black text-emerald-700 mt-1">
          {{ summary.hadir }}
        </p>
      </div>
      <div class="bg-amber-50 rounded-xl p-3 text-center">
        <p class="text-[9px] font-bold text-amber-700 uppercase tracking-widest">
          Sakit
        </p>
        <p class="text-lg font-black text-amber-700 mt-1">
          {{ summary.sakit }}
        </p>
      </div>
      <div class="bg-sky-50 rounded-xl p-3 text-center">
        <p class="text-[9px] font-bold text-sky-700 uppercase tracking-widest">
          Izin
        </p>
        <p class="text-lg font-black text-sky-700 mt-1">{{ summary.izin }}</p>
      </div>
      <div class="bg-red-50 rounded-xl p-3 text-center">
        <p class="text-[9px] font-bold text-red-700 uppercase tracking-widest">
          Alpa
        </p>
        <p class="text-lg font-black text-red-700 mt-1">{{ summary.alpa }}</p>
      </div>
    </div>

    <div
      class="flex items-center gap-4 flex-wrap px-3 py-2 bg-slate-50 border border-dashed border-slate-200 rounded-lg text-[11px] mb-4"
    >
      <span class="inline-flex items-center gap-1.5">
        <NavIcon name="bar-chart" :size="11" class="text-emerald-700" />
        Tingkat hadir:
        <b class="text-emerald-700 font-bold">{{ summary.rate }}%</b>
      </span>
      <span class="inline-flex items-center gap-1.5">
        <NavIcon name="check-circle" :size="11" class="text-brand-cobalt" />
        Streak hadir:
        <b class="text-brand-cobalt font-bold">{{ summary.streak }} sesi</b>
      </span>
      <span class="flex-1"></span>
      <span class="text-slate-500">{{ summary.total }} sesi tercatat</span>
    </div>

    <!-- ── Filter toolbar ────────────────────────────────── -->
    <div class="flex items-center gap-2 flex-wrap mb-3">
      <SegmentedControl
        :model-value="range"
        :options="[
          { key: '30', label: '30 hari' },
          { key: '90', label: '90 hari' },
          { key: 'ay', label: 'Tahun ajaran' },
        ]"
        size="sm"
        @update:model-value="(v) => (range = v as '30' | '90' | 'ay')"
      />
      <span class="flex-1"></span>
      <button
        v-for="opt in (['all', 'hadir', 'sakit', 'izin', 'alpa'] as const)"
        :key="opt"
        type="button"
        class="px-2.5 py-1 rounded-full text-[10px] font-bold border transition-colors"
        :class="
          statusFilter === opt
            ? opt === 'all'
              ? 'bg-brand-cobalt/10 text-brand-cobalt border-brand-cobalt'
              : opt === 'hadir'
                ? 'bg-emerald-100 text-emerald-700 border-emerald-300'
                : opt === 'sakit'
                  ? 'bg-amber-100 text-amber-700 border-amber-300'
                  : opt === 'izin'
                    ? 'bg-sky-100 text-sky-700 border-sky-300'
                    : 'bg-red-100 text-red-700 border-red-300'
            : 'bg-white text-slate-500 border-slate-200 hover:border-slate-300'
        "
        @click="statusFilter = opt"
      >
        {{ opt === 'all' ? 'Semua' : ATTENDANCE_LABELS[opt] }}
      </button>
    </div>

    <!-- ── History list ─────────────────────────────────── -->
    <div class="max-h-[50vh] overflow-y-auto pr-1">
      <div v-if="isLoading" class="py-12 text-center text-slate-400 text-sm">
        <NavIcon name="loader" :size="20" class="animate-spin inline-block mb-2" />
        <p>Memuat riwayat…</p>
      </div>

      <div
        v-else-if="filteredHistory.length === 0"
        class="py-10 text-center"
      >
        <p class="text-sm font-bold text-slate-700 mb-1">Tidak ada riwayat</p>
        <p class="text-[12px] text-slate-400">
          Belum ada catatan presensi untuk filter aktif.
        </p>
      </div>

      <div v-else class="space-y-1.5">
        <article
          v-for="h in filteredHistory"
          :key="h.id"
          class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl px-3 py-2.5"
        >
          <div class="w-12 text-center flex-shrink-0">
            <p class="text-[18px] font-black text-slate-900 leading-none">
              {{ new Date(h.date).getDate() }}
            </p>
            <p class="text-[9px] font-bold text-slate-400 uppercase tracking-wider mt-0.5">
              {{ new Date(h.date).toLocaleDateString('id-ID', { month: 'short' }) }}
            </p>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[12.5px] font-bold text-slate-900 truncate">
              {{ h.subject_name ?? h.session_label ?? 'Sesi' }}
            </p>
            <p class="text-[10.5px] text-slate-500 truncate">
              {{ formatLongDate(h.date) }}
              <span v-if="h.teacher_name"> · {{ h.teacher_name }}</span>
            </p>
            <p
              v-if="h.notes"
              class="text-[10.5px] text-slate-600 italic mt-0.5 truncate"
            >
              "{{ h.notes }}"
            </p>
          </div>
          <span
            class="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-1 rounded-full flex-shrink-0"
            :class="[
              statusStyle(h.status).bg,
              statusStyle(h.status).text,
            ]"
          >
            <span
              class="w-1.5 h-1.5 rounded-full"
              :class="statusStyle(h.status).dot"
            ></span>
            {{ ATTENDANCE_LABELS[h.status] }}
          </span>
        </article>
      </div>
    </div>

    <!-- ── Footer ───────────────────────────────────────── -->
    <footer
      class="mt-4 pt-3 border-t border-slate-100 flex items-center gap-2"
    >
      <Button variant="secondary" size="sm" @click="$emit('close')">Tutup</Button>
      <span class="flex-1"></span>
      <Button
        variant="ghost"
        size="sm"
        :disabled="isLoading"
        @click="load"
      >
        <NavIcon name="refresh-cw" :size="13" />
        Refresh
      </Button>
    </footer>
  </Modal>
</template>

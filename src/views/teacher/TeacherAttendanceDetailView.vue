<!--
  TeacherAttendanceDetailView.vue — Detail satu session Presensi.

  Reachable from the list page at /teacher/attendance/detail?class_id&
  subject_id&date&lesson_hour_id. Renders the per-student roster with
  inline edit on the status pill, an HSIA KPI strip, and a sticky
  action bar for save / export / mark-all.

  Mirrors Flutter's `teacher_attendance_detail.dart`.
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { useAcademicYearStore } from '@/stores/academic-year';
import { AttendanceService } from '@/services/attendance.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import {
  ATTENDANCE_LABELS,
  type AttendanceRow,
  type AttendanceStatus,
} from '@/types/attendance';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AttendanceStatusPickerModal from '@/components/feature/AttendanceStatusPickerModal.vue';
import StudentAttendanceHistoryModal from '@/components/feature/StudentAttendanceHistoryModal.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const auth = useAuthStore();
const academicYearStore = useAcademicYearStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

// ── Query params (driven by the list page) ──
const classId = computed(() => String(route.query.class_id ?? ''));
const subjectId = computed(() => String(route.query.subject_id ?? ''));
const date = computed(() => String(route.query.date ?? todayIso()));
const lessonHourId = computed(() =>
  route.query.lesson_hour_id
    ? String(route.query.lesson_hour_id)
    : undefined,
);

function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// ── Roster + edit state ──
const rows = ref<AttendanceRow[]>([]);
const original = ref<AttendanceRow[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const isSaving = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// Context (class + subject names) — fetched lazily so the header shows
// proper labels even when the user lands here from a deep link.
const className = ref<string>('');
const subjectName = ref<string>('');

// ── Modals: status picker + per-student history drill-in ──
const pickerStudent = ref<AttendanceRow | null>(null);
const historyStudent = ref<AttendanceRow | null>(null);

// Read-only mode: the selected academic year is not the active one.
const isReadOnly = computed(() => academicYearStore.isReadOnly);

// Parent-kelas variant: when the list page handed off a `teacher_name`
// query param, surface the recording teacher's name in the header
// strip so the homeroom teacher knows whose session this is.
const recordingTeacher = computed<string | null>(() => {
  const fromQuery = route.query.teacher_name;
  return typeof fromQuery === 'string' && fromQuery ? fromQuery : null;
});

// Filters on roster.
const searchQuery = ref<string>('');
type StatusFilter = 'all' | NonNullable<AttendanceStatus>;
const statusFilter = ref<StatusFilter>('all');

const filteredRows = computed<AttendanceRow[]>(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return rows.value.filter((r) => {
    if (statusFilter.value !== 'all' && r.status !== statusFilter.value)
      return false;
    if (q) {
      const blob = `${r.student_name} ${r.student_number}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

const state = computed<AsyncState<AttendanceRow[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

const summary = computed(() => {
  let h = 0,
    s = 0,
    i = 0,
    a = 0,
    u = 0;
  for (const r of rows.value) {
    switch (r.status) {
      case 'hadir':
        h += 1;
        break;
      case 'sakit':
        s += 1;
        break;
      case 'izin':
        i += 1;
        break;
      case 'alpa':
        a += 1;
        break;
      default:
        u += 1;
    }
  }
  const total = rows.value.length;
  return {
    hadir: h,
    sakit: s,
    izin: i,
    alpa: a,
    unmarked: u,
    total,
    rate: total ? Math.round((h / total) * 100) : 0,
  };
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'check-circle',
    label: t('tutor.sekolah.attendanceDetail.statusHadir'),
    value: summary.value.hadir,
    suffix: `· ${summary.value.total ? Math.round((summary.value.hadir / summary.value.total) * 100) : 0}%`,
    tone: 'green',
    accented: true,
  },
  {
    icon: 'bell',
    label: t('tutor.sekolah.attendanceDetail.statusSakit'),
    value: summary.value.sakit,
    tone: 'amber',
  },
  {
    icon: 'edit-3',
    label: t('tutor.sekolah.attendanceDetail.statusIzin'),
    value: summary.value.izin,
    tone: 'brand',
  },
  {
    icon: 'x',
    label: t('tutor.sekolah.attendanceDetail.statusAlpa'),
    value: summary.value.alpa,
    tone: 'red',
  },
]);

const dateLong = computed(() => {
  try {
    return new Date(date.value).toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  } catch {
    return date.value;
  }
});

const isDirty = computed(() => {
  if (rows.value.length !== original.value.length) return true;
  for (let i = 0; i < rows.value.length; i++) {
    if (rows.value[i].status !== original.value[i].status) return true;
    if ((rows.value[i].notes ?? '') !== (original.value[i].notes ?? ''))
      return true;
  }
  return false;
});

const STATUS_FILTERS = computed<{ key: StatusFilter; label: string }[]>(() => [
  { key: 'all', label: t('tutor.sekolah.attendanceDetail.filterAll') },
  { key: 'hadir', label: t('tutor.sekolah.attendanceDetail.statusHadir') },
  { key: 'sakit', label: t('tutor.sekolah.attendanceDetail.statusSakit') },
  { key: 'izin', label: t('tutor.sekolah.attendanceDetail.statusIzin') },
  { key: 'alpa', label: t('tutor.sekolah.attendanceDetail.statusAlpa') },
]);

// ── Data loaders ──
async function loadContext() {
  // Best-effort — header still renders fine without these.
  try {
    if (classId.value) {
      const list = (await ClassroomService.list({ per_page: 200 })).items;
      className.value = list.find((c) => c.id === classId.value)?.name ?? '';
    }
    if (subjectId.value) {
      const list = (await SubjectService.list({ per_page: 200 })).items;
      subjectName.value =
        list.find((s) => s.id === subjectId.value)?.name ?? '';
    }
  } catch {
    // silent
  }
}

async function loadRoster() {
  if (!classId.value || !subjectId.value) {
    rows.value = [];
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    const list = await AttendanceService.getRoster({
      class_id: classId.value,
      subject_id: subjectId.value,
      date: date.value,
      lesson_hour_id: lessonHourId.value,
    });
    rows.value = list.map((r) => ({ ...r }));
    original.value = list.map((r) => ({ ...r }));
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await Promise.all([loadContext(), loadRoster()]);
  window.addEventListener('keydown', onWindowKeydown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', onWindowKeydown);
});

watch(
  () => [classId.value, subjectId.value, date.value, lessonHourId.value],
  () => {
    loadContext();
    loadRoster();
  },
);

useAcademicYearWatcher(() => loadRoster());

function onWindowKeydown(e: KeyboardEvent) {
  // Ctrl+S / Cmd+S → save.
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    if (isDirty.value && !isSaving.value && !isReadOnly.value) save();
  }
  // Escape closes any open modal.
  if (e.key === 'Escape') {
    if (pickerStudent.value) pickerStudent.value = null;
    else if (historyStudent.value) historyStudent.value = null;
  }
}

// ── Edit actions ──
function openStatusPicker(r: AttendanceRow) {
  if (isReadOnly.value) {
    toast.value = {
      message: t('tutor.sekolah.attendanceDetail.readOnlyToast'),
      tone: 'error',
    };
    return;
  }
  pickerStudent.value = { ...r };
}

function openHistory(r: AttendanceRow) {
  historyStudent.value = { ...r };
}

function applyPicker(payload: {
  status: NonNullable<AttendanceStatus>;
  note: string | null;
}) {
  if (!pickerStudent.value) return;
  const studentId = pickerStudent.value.student_id;
  const idx = rows.value.findIndex((r) => r.student_id === studentId);
  if (idx >= 0) {
    rows.value[idx] = {
      ...rows.value[idx],
      status: payload.status,
      notes: payload.note ?? '',
    };
  }
  pickerStudent.value = null;
}

/** Status-pill colour + label for the roster row (read-only display). */
function statusPillClass(s: AttendanceStatus): string {
  switch (s) {
    case 'hadir':
      return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    case 'sakit':
      return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'izin':
      return 'bg-sky-50 text-sky-700 border-sky-200';
    case 'alpa':
      return 'bg-red-50 text-red-700 border-red-200';
    default:
      return 'bg-slate-50 text-slate-500 border-slate-200';
  }
}

function statusPillLabel(s: AttendanceStatus): string {
  if (!s) return t('tutor.sekolah.attendanceDetail.statusEmpty');
  return ATTENDANCE_LABELS[s];
}

function markAllHadir() {
  rows.value = rows.value.map((r) => ({ ...r, status: 'hadir' }));
}

function resetChanges() {
  rows.value = original.value.map((r) => ({ ...r }));
}

async function save() {
  const marked = rows.value.filter((r) => r.status !== null);
  if (marked.length === 0) {
    toast.value = {
      message: t('tutor.sekolah.attendanceDetail.markAtLeastOne'),
      tone: 'error',
    };
    return;
  }
  isSaving.value = true;
  try {
    await AttendanceService.saveBulk({
      teacher_id: auth.teacherId ?? auth.user?.id ?? '',
      class_id: classId.value,
      subject_id: subjectId.value,
      date: date.value,
      lesson_hour_id: lessonHourId.value,
      attendances: marked.map((r) => ({
        student_id: r.student_id,
        status: r.status as NonNullable<AttendanceStatus>,
        notes: r.notes ?? undefined,
      })),
    });
    original.value = rows.value.map((r) => ({ ...r }));
    toast.value = {
      message: t('tutor.sekolah.attendanceDetail.savedToast', { count: marked.length }),
      tone: 'success',
    };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

function backToList() {
  router.push('/teacher/attendance');
}
</script>

<template>
  <div class="space-y-md pb-28">
    <!-- ── 1. Brand header with context ──────────────────────── -->
    <BrandPageHeader
      role="guru"
      :kicker="t('tutor.sekolah.attendanceDetail.kicker')"
      :title="
        subjectName && className
          ? t('tutor.sekolah.attendanceDetail.titleWithCtx', { subject: subjectName, className })
          : t('tutor.sekolah.attendanceDetail.titleFallback')
      "
      :meta="
        recordingTeacher
          ? t('tutor.sekolah.attendanceDetail.metaWithTeacher', { date: dateLong, teacher: recordingTeacher })
          : dateLong
      "
      :live-dot="false"
    >
      <!-- Right side: back + export -->
      <div class="inline-flex items-center gap-2">
        <button
          type="button"
          class="px-3 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 border border-white/25 text-white text-[12px] font-bold inline-flex items-center gap-1.5"
          @click="backToList"
        >
          <NavIcon name="chevron-left" :size="13" />
          {{ t('tutor.sekolah.attendanceDetail.back') }}
        </button>
      </div>
    </BrandPageHeader>

    <!-- Read-only banner (past academic year) -->
    <section
      v-if="isReadOnly"
      class="rounded-2xl border border-sky-200 bg-sky-50 px-4 py-2.5 flex items-center gap-2.5 text-sky-700 text-[12px] font-bold"
    >
      <NavIcon name="lock" :size="14" />
      {{ t('tutor.sekolah.attendanceDetail.readOnlyBanner') }}
    </section>

    <!-- ── 2. KPI HSIA strip ─────────────────────────────────── -->
    <KpiStripCards :cards="kpiCards" />

    <!-- ── 3. Toolbar: search + status filter chips ──────────── -->
    <PageFilterToolbar
      :search="searchQuery"
      :search-placeholder="t('tutor.sekolah.attendanceDetail.searchPlaceholder')"
      @update:search="(v) => (searchQuery = v)"
    >
      <template #chips>
        <div class="inline-flex flex-wrap items-center gap-1.5">
          <button
            v-for="f in STATUS_FILTERS"
            :key="f.key"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              statusFilter === f.key
                ? f.key === 'all'
                  ? 'bg-brand-cobalt text-white border-brand-cobalt'
                  : f.key === 'hadir'
                    ? 'bg-emerald-50 text-emerald-700 border-emerald-300'
                    : f.key === 'sakit'
                      ? 'bg-amber-50 text-amber-700 border-amber-300'
                      : f.key === 'izin'
                        ? 'bg-sky-50 text-sky-700 border-sky-300'
                        : 'bg-red-50 text-red-700 border-red-300'
                : 'bg-white text-slate-600 border-slate-200 hover:border-slate-300'
            "
            @click="statusFilter = f.key"
          >
            {{ f.label }}
            <span
              v-if="f.key !== 'all'"
              class="ml-1 text-[10px] opacity-70"
            >
              {{
                f.key === 'hadir'
                  ? summary.hadir
                  : f.key === 'sakit'
                    ? summary.sakit
                    : f.key === 'izin'
                      ? summary.izin
                      : summary.alpa
              }}
            </span>
          </button>
        </div>
      </template>
    </PageFilterToolbar>

    <!-- ── 4. Section head ───────────────────────────────────── -->
    <div class="flex items-center gap-2 px-1">
      <span
        class="text-[11px] font-bold text-slate-500 uppercase tracking-widest"
        >{{ t('tutor.sekolah.attendanceDetail.studentListLabel') }}</span
      >
      <div class="flex-1 h-px bg-slate-200"></div>
      <span class="text-[11px] font-bold text-slate-500">
        {{ t('tutor.sekolah.attendanceDetail.studentCount', { shown: filteredRows.length, total: summary.total }) }}
      </span>
    </div>

    <!-- ── 5. Roster ─────────────────────────────────────────── -->
    <AsyncView
      :state="state"
      :empty-title="t('tutor.sekolah.attendanceDetail.emptyRosterTitle')"
      :empty-description="t('tutor.sekolah.attendanceDetail.emptyRosterDescription')"
      @retry="loadRoster"
    >
      <template #default>
        <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
          <div
            v-for="(r, idx) in filteredRows"
            :key="r.student_id"
            class="flex items-center gap-3 px-4 py-3 hover:bg-slate-50/60 transition-colors"
            :class="idx > 0 ? 'border-t border-slate-100' : ''"
          >
            <span
              class="w-6 text-center text-[11px] font-bold text-slate-400 flex-shrink-0"
            >
              {{ idx + 1 }}.
            </span>
            <!-- Avatar + name → click opens history modal -->
            <button
              type="button"
              class="flex items-center gap-3 min-w-0 flex-1 text-left group"
              :aria-label="t('tutor.sekolah.attendanceDetail.viewHistoryAria', { name: r.student_name })"
              @click="openHistory(r)"
            >
              <InitialsAvatar
                :name="r.student_name"
                :size="36"
                :border-radius="10"
                :color="
                  r.alert_tone === 'danger'
                    ? '#B91C1C'
                    : r.alert_tone === 'warning'
                      ? '#B45309'
                      : '#1B6FB8'
                "
              />
              <div class="min-w-0">
                <p
                  class="text-[13px] font-bold text-slate-900 truncate group-hover:text-brand-cobalt transition-colors"
                >
                  {{ r.student_name || t('tutor.sekolah.attendanceDetail.noName') }}
                </p>
                <p class="text-[11px] text-slate-400 truncate inline-flex items-center gap-1.5">
                  <span>{{ className ? className + ' · ' : '' }}{{ t('tutor.sekolah.attendanceDetail.nisLabel') }} {{ r.student_number || '—' }}</span>
                  <span
                    v-if="r.alert"
                    class="text-[9px] font-bold px-1.5 py-0.5 rounded-full"
                    :class="
                      r.alert_tone === 'danger'
                        ? 'bg-red-100 text-red-700'
                        : 'bg-amber-100 text-amber-700'
                    "
                  >
                    {{ r.alert }}
                  </span>
                  <span
                    v-if="r.notes"
                    class="text-[10px] text-slate-500 italic truncate"
                  >
                    · "{{ r.notes }}"
                  </span>
                </p>
              </div>
            </button>

            <!-- Status pill — click opens status picker modal -->
            <button
              type="button"
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-[12px] font-bold transition-colors flex-shrink-0"
              :class="[
                statusPillClass(r.status),
                isReadOnly ? 'cursor-not-allowed opacity-70' : 'hover:shadow-sm',
              ]"
              :disabled="isReadOnly"
              :aria-label="t('tutor.sekolah.attendanceDetail.changeStatusAria', { name: r.student_name })"
              @click="openStatusPicker(r)"
            >
              {{ statusPillLabel(r.status) }}
              <NavIcon
                v-if="!isReadOnly"
                name="chevron-down"
                :size="11"
                class="opacity-70"
              />
            </button>
          </div>
        </section>
      </template>
    </AsyncView>

    <!-- ── 6. Sticky action bar ──────────────────────────────── -->
    <section
      v-if="!isReadOnly"
      class="sticky bottom-4 flex items-center gap-3 px-4 py-3 bg-white border border-slate-200 rounded-2xl shadow-lg z-20"
    >
      <div class="text-[11px] text-slate-600">
        <p class="font-bold text-slate-900">
          {{ t('tutor.sekolah.attendanceDetail.markedSummary', { marked: summary.total - summary.unmarked, total: summary.total }) }}
        </p>
        <p class="text-slate-500">
          {{ t('tutor.sekolah.attendanceDetail.statusLegend', { hadir: summary.hadir, sakit: summary.sakit, izin: summary.izin, alpa: summary.alpa }) }}
        </p>
      </div>
      <span class="flex-1"></span>
      <span class="hidden md:inline-flex items-center gap-1 text-[10px] font-bold text-slate-400 mr-2">
        <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600">Ctrl</kbd>
        <span>+</span>
        <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600">S</kbd>
        {{ t('tutor.sekolah.attendanceDetail.toSave') }}
      </span>
      <Button
        variant="secondary"
        size="sm"
        :disabled="!isDirty"
        @click="resetChanges"
      >
        {{ t('tutor.sekolah.attendanceDetail.reset') }}
      </Button>
      <Button variant="secondary" size="sm" @click="markAllHadir">
        {{ t('tutor.sekolah.attendanceDetail.markAllHadir') }}
      </Button>
      <Button
        variant="primary"
        size="sm"
        :loading="isSaving"
        :disabled="!isDirty"
        @click="save"
      >
        {{ t('tutor.sekolah.attendanceDetail.saveChanges') }}
      </Button>
    </section>

    <!-- ── Status picker (notes!) — shared modal ────────────── -->
    <AttendanceStatusPickerModal
      v-if="pickerStudent"
      :student="pickerStudent"
      :initial-status="pickerStudent.status"
      :initial-note="pickerStudent.notes ?? ''"
      :is-saving="isSaving"
      @close="pickerStudent = null"
      @apply="applyPicker"
    />

    <!-- ── Per-student history drill-in — shared modal ──────── -->
    <StudentAttendanceHistoryModal
      v-if="historyStudent"
      :student="historyStudent"
      :class-name="className"
      :subject-id="subjectId"
      @close="historyStudent = null"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>

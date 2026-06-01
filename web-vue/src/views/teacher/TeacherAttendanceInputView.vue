<!--
  TeacherAttendanceInputView.vue — Input presensi (sesi baru).

  Reachable from /teacher/attendance/input?class_id&subject_id&date.
  Same UI flow as the Detail view (header + KPI strip + filter
  toolbar + roster + sticky action bar) but pre-seeded with default
  "Hadir" for every student and exposes the picker chips (date /
  jam ke- / class / subject) inline at the top so the teacher can
  pivot without leaving the page.

  Mirrors Flutter's `attendance_input_form.dart` + the take-attendance
  flow of `teacher_attendance_screen.dart`.
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { AttendanceService } from '@/services/attendance.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import type {
  AttendanceRow,
  AttendanceStatus,
} from '@/types/attendance';
import type { Classroom, Subject } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import AttendancePicker from '@/components/feature/AttendancePicker.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const auth = useAuthStore();
const route = useRoute();
const router = useRouter();

// ── State seeded from query, but editable inline ──
const classId = ref<string>(String(route.query.class_id ?? ''));
const subjectId = ref<string>(String(route.query.subject_id ?? ''));
const date = ref<string>(String(route.query.date ?? todayIso()));

const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const rows = ref<AttendanceRow[]>([]);
const isLoading = ref(false);
const error = ref<string | null>(null);
const isSaving = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);

const searchQuery = ref<string>('');
type FilterMode = 'all' | 'unmarked';
const filterMode = ref<FilterMode>('all');

function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const activeClass = computed(
  () => classes.value.find((c) => c.id === classId.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectId.value) ?? null,
);

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

const filteredRows = computed<AttendanceRow[]>(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return rows.value.filter((r) => {
    if (filterMode.value === 'unmarked' && r.status !== null) return false;
    if (q) {
      const blob = `${r.student_name} ${r.student_number}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

const state = computed<AsyncState<AttendanceRow[]>>(() => {
  if (!classId.value || !subjectId.value) return { status: 'empty' };
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
  return {
    hadir: h,
    sakit: s,
    izin: i,
    alpa: a,
    unmarked: u,
    total: rows.value.length,
  };
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'check-circle',
    label: 'Hadir',
    value: summary.value.hadir,
    tone: 'green',
    accented: true,
  },
  {
    icon: 'bell',
    label: 'Sakit',
    value: summary.value.sakit,
    tone: 'amber',
  },
  {
    icon: 'edit-3',
    label: 'Izin',
    value: summary.value.izin,
    tone: 'brand',
  },
  {
    icon: 'x',
    label: 'Alpa',
    value: summary.value.alpa,
    tone: 'red',
  },
]);

const isReadyToSave = computed(
  () => summary.value.unmarked === 0 && summary.value.total > 0,
);

// ── Loaders ──
async function loadReferences() {
  try {
    const [c, s] = await Promise.all([
      ClassroomService.list({ per_page: 100 }),
      SubjectService.list({ per_page: 100 }),
    ]);
    classes.value = c.items;
    subjects.value = s.items;
  } catch (e) {
    error.value = (e as Error).message;
  }
}

async function loadRoster() {
  if (!classId.value || !subjectId.value) {
    rows.value = [];
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    const list = await AttendanceService.getRoster({
      class_id: classId.value,
      subject_id: subjectId.value,
      date: date.value,
    });
    // Default every unmarked row to 'hadir' so the teacher only flips
    // exceptions — matches Flutter's "auto-fill Hadir" pattern.
    rows.value = list.map((r) => ({
      ...r,
      status: r.status ?? 'hadir',
    }));
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await loadRoster();
  window.addEventListener('keydown', onWindowKeydown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', onWindowKeydown);
});

watch([classId, subjectId, date], () => {
  loadRoster();
  focusedIndex.value = -1;
});

useAcademicYearWatcher(() => loadRoster());

// ── Keyboard navigation ──
/**
 * Index into `filteredRows` of the row that currently has keyboard
 * focus. -1 means no row is focused (clicks in inputs/buttons still
 * work as normal). H/S/I/A apply the status to the focused row;
 * ArrowUp/Down move; Ctrl+S saves.
 */
const focusedIndex = ref<number>(-1);

function focusRow(idx: number) {
  if (idx < 0 || idx >= filteredRows.value.length) return;
  focusedIndex.value = idx;
  // Scroll the focused row into view if needed.
  const el = document.querySelector<HTMLElement>(
    `[data-roster-row="${filteredRows.value[idx].student_id}"]`,
  );
  el?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
}

function onWindowKeydown(e: KeyboardEvent) {
  // Skip when the user is typing in an input/textarea/contenteditable.
  const t = e.target as HTMLElement | null;
  const tag = t?.tagName?.toUpperCase();
  if (
    tag === 'INPUT' ||
    tag === 'TEXTAREA' ||
    tag === 'SELECT' ||
    (t && t.isContentEditable)
  ) {
    return;
  }

  // Ctrl+S / Cmd+S → save.
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    if (isReadyToSave.value && !isSaving.value) save();
    return;
  }

  // Arrow keys move row focus.
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    if (focusedIndex.value < 0) focusRow(0);
    else focusRow(focusedIndex.value + 1);
    return;
  }
  if (e.key === 'ArrowUp') {
    e.preventDefault();
    if (focusedIndex.value <= 0) focusRow(0);
    else focusRow(focusedIndex.value - 1);
    return;
  }

  // H/S/I/A apply status to the focused row.
  const key = e.key.toLowerCase();
  const map: Record<string, NonNullable<AttendanceStatus>> = {
    h: 'hadir',
    s: 'sakit',
    i: 'izin',
    a: 'alpa',
  };
  const status = map[key];
  if (status && focusedIndex.value >= 0) {
    e.preventDefault();
    const r = filteredRows.value[focusedIndex.value];
    if (r) {
      setStatus(r.student_id, status);
      // Auto-advance so streak-marking feels fluid.
      if (focusedIndex.value < filteredRows.value.length - 1) {
        focusRow(focusedIndex.value + 1);
      }
    }
  }
}

// ── Edit + bulk actions ──
function setStatus(studentId: string, status: AttendanceStatus) {
  const idx = rows.value.findIndex((r) => r.student_id === studentId);
  if (idx >= 0) {
    rows.value[idx] = { ...rows.value[idx], status };
  }
}

function markAll(status: NonNullable<AttendanceStatus>) {
  rows.value = rows.value.map((r) => ({ ...r, status }));
}

function clearAll() {
  rows.value = rows.value.map((r) => ({ ...r, status: null }));
}

async function copyFromLast() {
  // Best-effort: pull yesterday's roster for the same class+subject
  // and copy the saved statuses over.
  try {
    const yesterday = new Date(date.value);
    yesterday.setDate(yesterday.getDate() - 1);
    const ystr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;
    const list = await AttendanceService.getRoster({
      class_id: classId.value,
      subject_id: subjectId.value,
      date: ystr,
    });
    const map = new Map(list.map((r) => [r.student_id, r.status]));
    rows.value = rows.value.map((r) => ({
      ...r,
      status: map.get(r.student_id) ?? r.status,
    }));
    toast.value = {
      message: 'Status disalin dari sesi sebelumnya.',
      tone: 'success',
    };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}

// ── Submit ──
async function save() {
  const marked = rows.value.filter((r) => r.status !== null);
  if (marked.length === 0) {
    toast.value = {
      message: 'Tandai minimal satu siswa terlebih dulu.',
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
      attendances: marked.map((r) => ({
        student_id: r.student_id,
        status: r.status as NonNullable<AttendanceStatus>,
        notes: r.notes ?? undefined,
      })),
    });
    toast.value = {
      message: `Presensi tersimpan: ${marked.length} siswa.`,
      tone: 'success',
    };
    // After save, route to detail view so the teacher sees the saved
    // result — same destination as opening it from the list.
    setTimeout(() => {
      router.replace({
        path: '/teacher/attendance/detail',
        query: {
          class_id: classId.value,
          subject_id: subjectId.value,
          date: date.value,
        },
      });
    }, 600);
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

function backToList() {
  router.push('/teacher/attendance');
}

function pickClass(id: string) {
  classId.value = id;
  showClassPicker.value = false;
}
function pickSubject(id: string) {
  subjectId.value = id;
  showSubjectPicker.value = false;
}
</script>

<template>
  <div class="space-y-md pb-28">
    <!-- ── 1. Brand header ───────────────────────────────────── -->
    <BrandPageHeader
      role="guru"
      kicker="Presensi · Input Sesi Baru"
      :title="
        activeSubject && activeClass
          ? `${activeSubject.name} · ${activeClass.name}`
          : 'Pilih sesi untuk input'
      "
      :meta="dateLong"
      :live-dot="false"
    >
      <button
        type="button"
        class="px-3 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 border border-white/25 text-white text-[12px] font-bold inline-flex items-center gap-1.5"
        @click="backToList"
      >
        <NavIcon name="chevron-left" :size="13" />
        Kembali
      </button>
    </BrandPageHeader>

    <!-- ── 2. Session picker chips (date / class / subject) ──── -->
    <section class="bg-white border border-slate-200 rounded-2xl p-3">
      <div class="flex items-center gap-2 flex-wrap">
        <span
          class="inline-flex flex-col rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 leading-none"
        >
          <span
            class="text-[9px] font-bold text-slate-400 uppercase tracking-widest"
            >Tanggal</span
          >
          <input
            v-model="date"
            type="date"
            class="bg-transparent border-0 outline-none text-[13px] font-bold text-slate-900 mt-1 w-[140px]"
          />
        </span>
        <AppFilterChip
          label="Kelas"
          :value="activeClass?.name ?? '— pilih kelas —'"
          icon-name="layers"
          tone="violet"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          label="Mata Pelajaran"
          :value="activeSubject?.name ?? '— pilih mapel —'"
          icon-name="book"
          tone="brand"
          @click="showSubjectPicker = true"
        />

        <span class="hidden sm:block w-px h-7 bg-slate-200"></span>

        <!-- Bulk actions -->
        <button
          type="button"
          class="text-[11px] font-bold px-3 py-2 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100"
          @click="markAll('hadir')"
        >
          ✓ Semua Hadir
        </button>
        <button
          type="button"
          class="text-[11px] font-bold px-3 py-2 rounded-xl bg-white text-slate-600 border border-slate-200 hover:border-slate-300"
          @click="clearAll"
        >
          ✕ Kosongkan
        </button>
        <button
          type="button"
          class="text-[11px] font-bold px-3 py-2 rounded-xl bg-white text-slate-600 border border-slate-200 hover:border-slate-300"
          @click="copyFromLast"
        >
          📋 Salin sesi sebelumnya
        </button>
      </div>
    </section>

    <!-- ── 3. KPI strip ──────────────────────────────────────── -->
    <KpiStripCards :cards="kpiCards" />

    <!-- ── 4. Roster toolbar ─────────────────────────────────── -->
    <PageFilterToolbar
      :search="searchQuery"
      search-placeholder="Cari siswa atau NIS..."
      @update:search="(v) => (searchQuery = v)"
    >
      <template #chips>
        <button
          type="button"
          class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
          :class="
            filterMode === 'all'
              ? 'bg-brand-cobalt text-white border-brand-cobalt'
              : 'bg-white text-slate-600 border-slate-200'
          "
          @click="filterMode = 'all'"
        >
          Semua siswa
        </button>
        <button
          type="button"
          class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
          :class="
            filterMode === 'unmarked'
              ? 'bg-amber-50 text-amber-700 border-amber-300'
              : 'bg-white text-slate-600 border-slate-200'
          "
          @click="filterMode = 'unmarked'"
        >
          Belum ditandai
          <span class="ml-1 text-[10px] opacity-70">{{ summary.unmarked }}</span>
        </button>
      </template>
    </PageFilterToolbar>

    <!-- ── 5. Section head ───────────────────────────────────── -->
    <div class="flex items-center gap-2 px-1 flex-wrap">
      <span
        class="text-[11px] font-bold text-slate-500 uppercase tracking-widest"
        >Daftar Siswa · Default Hadir</span
      >
      <div class="flex-1 h-px bg-slate-200"></div>
      <span class="text-[11px] font-bold text-slate-500">
        {{ filteredRows.length }} dari {{ summary.total }} siswa
      </span>
    </div>

    <!-- Keyboard shortcut hint (desktop only) -->
    <div
      class="hidden md:flex items-center gap-3 flex-wrap text-[10.5px] text-slate-500 px-1 -mt-2"
    >
      <span class="font-bold text-slate-400 uppercase tracking-widest">
        Pintasan:
      </span>
      <span class="inline-flex items-center gap-1">
        <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">↑</kbd>
        <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">↓</kbd>
        pindah baris
      </span>
      <span class="inline-flex items-center gap-1">
        <kbd class="px-1.5 py-0.5 rounded bg-emerald-50 border border-emerald-200 text-emerald-700 font-bold">H</kbd>
        Hadir ·
        <kbd class="px-1.5 py-0.5 rounded bg-amber-50 border border-amber-200 text-amber-700 font-bold">S</kbd>
        Sakit ·
        <kbd class="px-1.5 py-0.5 rounded bg-sky-50 border border-sky-200 text-sky-700 font-bold">I</kbd>
        Izin ·
        <kbd class="px-1.5 py-0.5 rounded bg-red-50 border border-red-200 text-red-700 font-bold">A</kbd>
        Alpa
      </span>
      <span class="inline-flex items-center gap-1">
        <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">Ctrl</kbd>
        +
        <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">S</kbd>
        simpan
      </span>
    </div>

    <!-- ── 6. Roster ─────────────────────────────────────────── -->
    <AsyncView
      :state="state"
      :empty-title="
        !classId || !subjectId
          ? 'Pilih kelas dan mata pelajaran'
          : 'Roster kosong'
      "
      empty-description="Setelah kelas dan mapel terpilih, daftar siswa akan muncul."
      @retry="loadRoster"
    >
      <template #default>
        <section
          class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
        >
          <div
            v-for="(r, idx) in filteredRows"
            :key="r.student_id"
            :data-roster-row="r.student_id"
            class="flex items-center gap-3 px-4 py-3 transition-colors cursor-pointer"
            :class="[
              idx > 0 ? 'border-t border-slate-100' : '',
              idx === focusedIndex
                ? 'bg-brand-cobalt/5 ring-1 ring-inset ring-brand-cobalt/40'
                : 'hover:bg-slate-50/60',
            ]"
            @click="focusRow(idx)"
          >
            <span
              class="w-6 text-center text-[11px] font-bold text-slate-400 flex-shrink-0"
            >
              {{ idx + 1 }}.
            </span>
            <InitialsAvatar
              :name="r.student_name"
              :size="36"
              :border-radius="10"
              color="#1B6FB8"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">
                {{ r.student_name || 'Tanpa nama' }}
              </p>
              <p class="text-[11px] text-slate-400 truncate">
                {{ activeClass?.name ? activeClass.name + ' · ' : '' }}NIS
                {{ r.student_number || '—' }}
              </p>
            </div>
            <AttendancePicker
              :model-value="r.status"
              @update:model-value="
                (v: AttendanceStatus) => setStatus(r.student_id, v)
              "
            />
          </div>
        </section>
      </template>
    </AsyncView>

    <!-- ── 7. Sticky submit bar ──────────────────────────────── -->
    <section
      class="sticky bottom-4 flex items-center gap-3 px-4 py-3 bg-white border border-slate-200 rounded-2xl shadow-lg z-20"
    >
      <div class="flex items-center gap-2 flex-1">
        <div class="w-32 h-1.5 bg-slate-100 rounded-full overflow-hidden">
          <div
            class="h-full bg-emerald-600 transition-all"
            :style="{
              width: `${summary.total ? ((summary.total - summary.unmarked) / summary.total) * 100 : 0}%`,
            }"
          ></div>
        </div>
        <div class="text-[11px]">
          <p class="font-bold text-slate-900">
            Siap disimpan:
            {{ summary.total - summary.unmarked }} dari {{ summary.total }} siswa
          </p>
          <p class="text-slate-500">
            {{ summary.hadir }} Hadir · {{ summary.sakit }} Sakit ·
            {{ summary.izin }} Izin · {{ summary.alpa }} Alpa
          </p>
        </div>
      </div>
      <Button variant="secondary" size="sm" @click="backToList">Batal</Button>
      <Button
        variant="primary"
        size="sm"
        :loading="isSaving"
        :disabled="!isReadyToSave"
        @click="save"
      >
        Simpan presensi
      </Button>
    </section>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />

    <!-- ── Class picker ──────────────────────────────────────── -->
    <Modal
      v-if="showClassPicker"
      title="Pilih Kelas"
      @close="showClassPicker = false"
    >
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                c.id === classId,
            }"
            @click="pickClass(c.id)"
          >
            <span>{{ c.name }}</span>
            <span v-if="c.student_count" class="text-[10px] text-slate-400">
              {{ c.student_count }} siswa
            </span>
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Subject picker ────────────────────────────────────── -->
    <Modal
      v-if="showSubjectPicker"
      title="Pilih Mata Pelajaran"
      @close="showSubjectPicker = false"
    >
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                s.id === subjectId,
            }"
            @click="pickSubject(s.id)"
          >
            <span>{{ s.name }}</span>
            <span v-if="s.code" class="text-[10px] text-slate-400">{{
              s.code
            }}</span>
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>

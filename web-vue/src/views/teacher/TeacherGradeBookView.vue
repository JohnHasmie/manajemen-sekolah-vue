<!--
  TeacherGradeBookView.vue — Nilai Siswa (Buku Nilai).

  Web port of Flutter's `teacher_grade_input_screen.dart`. Same flow
  shape as Presensi:

    Default landing (no specific filter):
      1. <BrandPageHeader> (guru) + <RoleToggleChipRow> (Mengajar/Wali)
      2. <KpiStripCards> — Total mapel / Asesmen / Rerata / Belum
      3. <PageFilterToolbar> — Kelas + Mapel chips + search
      4. Day-style summary cards: one per (class, subject) combo, with
         avg badge + meta cells + assessment type pills + progress bar
         + "Buka ›" CTA. Click → drills into the matrix mode.

    Matrix mode (after a card is opened):
      • Header gets a back chip; sub-meta shows class+subject names
      • Type tabs (Semua/Tugas/UH/UTS/UAS) + KKM summary strip
      • Editable matrix with Tab/Arrow/Enter nav + autosave-on-blur
        + Ctrl+S save + bulk-fill-column
      • Sticky save bar with dirty counter
-->
<script setup lang="ts">
import {
  computed,
  nextTick,
  onMounted,
  onUnmounted,
  ref,
  watch,
} from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { GradeService } from '@/services/grades.service';
import type { Classroom, Subject } from '@/types/entities';
import type {
  Assessment,
  AssessmentType,
  GradeMatrix,
  TeacherGradeSummaryClass,
  TeacherGradeSummarySubject,
} from '@/types/grades';
import { ASSESSMENT_LABELS } from '@/types/grades';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import RoleToggleChipRow, {
  type RoleOption,
} from '@/components/feature/RoleToggleChipRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useQuickAction } from '@/composables/useQuickAction';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const { fromQuickAction, queryString } = useQuickAction();
const auth = useAuthStore();
const route = useRoute();

// ── Admin-view support ──
// Admins can drill into a teacher's gradebook from
// AdminGradeOverviewView. The route is /admin/grades/teacher/:teacherId
// (with `?teacher_id=...` query alias). When that param is present,
// every API call here must use it instead of the logged-in user's id
// — otherwise the page loads the admin's own (empty) gradebook and
// renders "Belum ada mapel terdaftar".
const routeTeacherId = computed<string>(() => {
  const fromParam = route.params.teacherId;
  if (typeof fromParam === 'string' && fromParam.length > 0) return fromParam;
  const fromQuery = route.query.teacher_id;
  if (typeof fromQuery === 'string' && fromQuery.length > 0) return fromQuery;
  return '';
});
const isAdminView = computed(() => routeTeacherId.value.length > 0);
const effectiveTeacherId = computed<string>(
  () => routeTeacherId.value || auth.teacherId || auth.user?.id || '',
);

// ── Role toggle (Mengajar / Wali) ──
const selectedRoleId = ref<string>('mengajar');
const roleOptions = computed<RoleOption[]>(() => {
  const out: RoleOption[] = [
    {
      id: 'mengajar',
      shortName: 'Mengajar',
      subLabel: 'Mapel saya',
      avatarInitials: 'M',
    },
  ];
  for (const hc of auth.homeroomClasses) {
    const name = hc.name || hc.id;
    out.push({
      id: `wali:${hc.id}`,
      shortName: `Wali ${name}`,
      subLabel: 'Kelas perwalian',
      avatarInitials:
        name.length <= 2
          ? name.toUpperCase()
          : name.slice(0, 2).toUpperCase(),
    });
  }
  return out;
});
const isWaliMode = computed(() => selectedRoleId.value.startsWith('wali:'));
const activeHomeroomId = computed(() =>
  isWaliMode.value ? selectedRoleId.value.slice(5) : null,
);

// ── Filter state ──
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const classFilter = ref<string>('');
const subjectFilter = ref<string>('');
const semester = ref<string>('genap'); // kept internal; not surfaced
const searchQuery = ref<string>('');

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);

// ── Summary state (default landing) ──
const summary = ref<TeacherGradeSummaryClass[]>([]);
const isSummaryLoading = ref(true);
const summaryError = ref<string | null>(null);

// ── Matrix state (deep view after card tap) ──
type Mode = 'summary' | 'matrix';
const mode = ref<Mode>('summary');
const matrixClass = ref<{ id: string; name: string } | null>(null);
const matrixSubject = ref<{ id: string; name: string } | null>(null);
// Pre-seed assessments from the summary payload so the matrix still
// shows the assessment columns even when zero scores are entered.
const matrixAssessmentSeed = ref<Assessment[]>([]);
const matrix = ref<GradeMatrix>({ assessments: [], rows: [], kkm: 75 });
const isMatrixLoading = ref(false);
const matrixError = ref<string | null>(null);
const isSaving = ref(false);
const typeFilter = ref<AssessmentType | 'all'>('all');
const autosaveTimer = ref<ReturnType<typeof setTimeout> | null>(null);
// Column actions sheet — opens when teacher taps an assessment header
// in the matrix. Mirrors Flutter's `grade_column_options_sheet.dart`:
// Lihat Detail / Edit Asesmen / Hapus Asesmen.
const columnActionsFor = ref<Assessment | null>(null);
const columnDetail = ref<Assessment | null>(null);
const columnDeleteConfirm = ref<Assessment | null>(null);
const isDeletingColumn = ref(false);

// Add-assessment modal state — mirrors Flutter `grade_input_dialog.dart`
// trigger from the FAB.
const showAddAsesmen = ref(false);
const addForm = ref<{
  type: AssessmentType;
  title: string;
  date: string; // YYYY-MM-DD
}>({
  type: 'uh',
  title: '',
  date: new Date().toISOString().slice(0, 10),
});
const matrixSearchQuery = ref<string>('');

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const activeClass = computed(
  () => classes.value.find((c) => c.id === classFilter.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectFilter.value) ?? null,
);

// ── Summary derived ──
//
// Backend (`GradeController::teacherSummary` + school-aware
// `Teacher::resolveId`) now scopes (class, subject) combos to the
// active school, so this just flattens (no client-side cross-school
// filter needed).
const flatCards = computed<
  Array<{
    class_id: string;
    class_name: string;
    grade_level: string;
    student_count: number;
    subject: TeacherGradeSummarySubject;
  }>
>(() => {
  const out: Array<{
    class_id: string;
    class_name: string;
    grade_level: string;
    student_count: number;
    subject: TeacherGradeSummarySubject;
  }> = [];
  for (const c of summary.value) {
    for (const s of c.subjects) {
      out.push({
        class_id: c.class_id,
        class_name: c.class_name,
        grade_level: c.grade_level,
        student_count: c.student_count,
        subject: s,
      });
    }
  }
  return out;
});

const filteredCards = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return flatCards.value.filter((row) => {
    if (classFilter.value && row.class_id !== classFilter.value) return false;
    if (subjectFilter.value && row.subject.id !== subjectFilter.value)
      return false;
    if (q) {
      const blob =
        `${row.class_name} ${row.subject.name} ${row.subject.code}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

const summaryState = computed<AsyncState<typeof flatCards.value>>(() => {
  if (isSummaryLoading.value && summary.value.length === 0)
    return { status: 'loading' };
  if (summaryError.value)
    return { status: 'error', error: summaryError.value };
  if (filteredCards.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredCards.value };
});

const summaryKpi = computed<KpiCard[]>(() => {
  let totalCards = 0,
    totalAssessments = 0,
    sumAvg = 0,
    cardsWithAvg = 0,
    cardsBelumNilai = 0;
  for (const row of flatCards.value) {
    totalCards++;
    totalAssessments += row.subject.assessments.length;
    if (typeof row.subject.avg_score === 'number') {
      sumAvg += row.subject.avg_score;
      cardsWithAvg++;
    } else {
      cardsBelumNilai++;
    }
  }
  return [
    {
      icon: 'layers',
      label: 'Mapel · Kelas',
      value: totalCards,
      tone: 'brand',
    },
    {
      icon: 'edit-3',
      label: 'Asesmen',
      value: totalAssessments,
      tone: 'violet',
    },
    {
      icon: 'bar-chart',
      label: 'Rerata',
      value: cardsWithAvg
        ? Math.round((sumAvg / cardsWithAvg) * 10) / 10
        : '—',
      suffix: 'gabungan',
      tone: 'green',
      accented: true,
    },
    {
      icon: 'bell',
      label: 'Belum Dinilai',
      value: cardsBelumNilai,
      suffix: 'mapel',
      tone: cardsBelumNilai > 0 ? 'amber' : 'green',
    },
  ];
});

// ── Matrix derived ──
const visibleAssessments = computed<Assessment[]>(() =>
  typeFilter.value === 'all'
    ? matrix.value.assessments
    : matrix.value.assessments.filter((a) => a.type === typeFilter.value),
);

const filteredMatrixRows = computed(() => {
  const q = matrixSearchQuery.value.trim().toLowerCase();
  if (!q) return matrix.value.rows;
  return matrix.value.rows.filter(
    (r) =>
      r.student_name.toLowerCase().includes(q) ||
      r.student_number.toLowerCase().includes(q),
  );
});

function rowAverage(studentId: string): number | null {
  const row = matrix.value.rows.find((r) => r.student_id === studentId);
  if (!row) return null;
  const scores: number[] = [];
  for (const a of visibleAssessments.value) {
    const c = row.cells[a.id];
    if (c && typeof c.score === 'number') scores.push(c.score);
  }
  if (scores.length === 0) return null;
  return Math.round((scores.reduce((s, v) => s + v, 0) / scores.length) * 10) / 10;
}

const matrixSummary = computed(() => {
  let tuntas = 0,
    remed = 0,
    belum = 0,
    sum = 0,
    count = 0;
  for (const r of matrix.value.rows) {
    const avg = rowAverage(r.student_id);
    if (avg === null) {
      belum += 1;
      continue;
    }
    if (avg >= matrix.value.kkm) tuntas += 1;
    else remed += 1;
    sum += avg;
    count += 1;
  }
  return {
    tuntas,
    remed,
    belum,
    avg: count ? Math.round((sum / count) * 10) / 10 : 0,
  };
});

const dirtyCount = computed(() => {
  let n = 0;
  for (const r of matrix.value.rows) {
    for (const c of Object.values(r.cells)) if (c.dirty) n += 1;
  }
  return n;
});

const typeCounts = computed(() => {
  const m: Record<string, number> = {
    all: matrix.value.assessments.length,
  };
  for (const a of matrix.value.assessments) {
    m[a.type] = (m[a.type] ?? 0) + 1;
  }
  return m;
});

const typeOptions = computed(() => [
  { key: 'all', label: 'Semua', meta: String(typeCounts.value.all ?? 0) },
  { key: 'tugas', label: 'Tugas', meta: String(typeCounts.value.tugas ?? 0) },
  { key: 'uh', label: 'UH', meta: String(typeCounts.value.uh ?? 0) },
  { key: 'uts', label: 'UTS', meta: String(typeCounts.value.uts ?? 0) },
  { key: 'uas', label: 'UAS', meta: String(typeCounts.value.uas ?? 0) },
]);

const matrixState = computed<AsyncState<GradeMatrix>>(() => {
  if (isMatrixLoading.value && matrix.value.rows.length === 0)
    return { status: 'loading' };
  if (matrixError.value)
    return { status: 'error', error: matrixError.value };
  if (matrix.value.rows.length === 0) return { status: 'empty' };
  return { status: 'content', data: matrix.value };
});

// ── Loaders ──
async function loadReferences() {
  try {
    const [c, s] = await Promise.all([
      ClassroomService.list({ per_page: 100 }),
      SubjectService.list({ per_page: 100 }),
    ]);
    classes.value = c.items;
    subjects.value = s.items;
    if (fromQuickAction.value) {
      classFilter.value = queryString('class_id') ?? '';
      subjectFilter.value = queryString('subject_id') ?? '';
    }
  } catch (e) {
    summaryError.value = (e as Error).message;
  }
}

async function loadSummary() {
  const teacherId = effectiveTeacherId.value;
  if (!teacherId) {
    isSummaryLoading.value = false;
    return;
  }
  isSummaryLoading.value = true;
  summaryError.value = null;
  try {
    summary.value = await GradeService.getTeacherSummary({
      teacher_id: teacherId,
      view: isWaliMode.value ? 'wali_kelas' : 'mengajar',
      class_id: activeHomeroomId.value || undefined,
    });
  } catch (e) {
    summaryError.value = (e as Error).message;
  } finally {
    isSummaryLoading.value = false;
  }
}

async function loadMatrix() {
  if (!matrixClass.value?.id || !matrixSubject.value?.id) return;
  isMatrixLoading.value = true;
  matrixError.value = null;
  try {
    matrix.value = await GradeService.getMatrix({
      class_id: matrixClass.value.id,
      subject_id: matrixSubject.value.id,
      semester: semester.value,
      teacher_id: effectiveTeacherId.value,
      assessments_seed: matrixAssessmentSeed.value,
    });
  } catch (e) {
    matrixError.value = (e as Error).message;
  } finally {
    isMatrixLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await loadSummary();
  window.addEventListener('keydown', onWindowKeydown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', onWindowKeydown);
  if (autosaveTimer.value) clearTimeout(autosaveTimer.value);
});

useAcademicYearWatcher(() => {
  if (mode.value === 'matrix') loadMatrix();
  else loadSummary();
});

watch(selectedRoleId, () => {
  if (isWaliMode.value && activeHomeroomId.value) {
    classFilter.value = activeHomeroomId.value;
  } else if (!isWaliMode.value && fromQuickAction.value === false) {
    classFilter.value = '';
  }
  loadSummary();
});

// ── Navigation between summary and matrix mode ──
function openMatrix(card: (typeof flatCards.value)[number]) {
  // Track which (class, subject) the matrix is locked to — kept
  // separate from the summary-page filters so going "back" can
  // reset the chips to "Semua" without losing the matrix scope.
  matrixClass.value = { id: card.class_id, name: card.class_name };
  matrixSubject.value = { id: card.subject.id, name: card.subject.name };
  // Lift the summary's per-assessment list as a seed so the matrix
  // renders columns even when 0 grade cells exist yet — without the
  // seed the user would see "Belum ada asesmen" despite the card
  // claiming "3 asesmen".
  matrixAssessmentSeed.value = card.subject.assessments.map((a) => ({
    id: a.id,
    name: a.label,
    raw_title: a.raw_title,
    type: a.type,
  }));
  matrixSearchQuery.value = '';
  typeFilter.value = 'all';
  mode.value = 'matrix';
  loadMatrix();
}

function backToSummary() {
  mode.value = 'summary';
  matrixClass.value = null;
  matrixSubject.value = null;
  matrixAssessmentSeed.value = [];
  matrix.value = { assessments: [], rows: [], kkm: 75 };
  // Reset the summary-page filter chips back to "Semua kelas" /
  // "Semua mapel" so the user sees the full mapel×kelas grid again
  // instead of the narrowed combo they just drilled into.
  classFilter.value = '';
  subjectFilter.value = '';
  searchQuery.value = '';
  // Refresh summary to pick up any edits made in the matrix.
  loadSummary();
}

// ── Edit cell + keyboard navigation ──
function updateCell(studentId: string, assessmentId: string, raw: string) {
  const row = matrix.value.rows.find((r) => r.student_id === studentId);
  if (!row) return;
  const cell = row.cells[assessmentId];
  if (!cell) return;
  const num = raw.trim() === '' ? null : Number(raw);
  if (raw.trim() !== '' && Number.isNaN(num)) return;
  if (num !== null && (num < 0 || num > 100)) return;
  cell.score = num;
  cell.dirty = true;
  scheduleAutosave();
}

function scheduleAutosave() {
  if (autosaveTimer.value) clearTimeout(autosaveTimer.value);
  autosaveTimer.value = setTimeout(() => {
    if (dirtyCount.value > 0 && !isSaving.value) save({ silent: true });
  }, 1200);
}

function cellSelector(studentId: string, assessmentId: string): string {
  return `[data-grade-cell="${studentId}__${assessmentId}"]`;
}

function focusCell(studentId: string, assessmentId: string) {
  nextTick(() => {
    const el = document.querySelector<HTMLInputElement>(
      cellSelector(studentId, assessmentId),
    );
    if (el) {
      el.focus();
      el.select();
    }
  });
}

function moveCellFocus(
  studentId: string,
  assessmentId: string,
  dir: 'next' | 'prev' | 'up' | 'down',
) {
  const rows = filteredMatrixRows.value;
  const cols = visibleAssessments.value;
  const rIdx = rows.findIndex((r) => r.student_id === studentId);
  const cIdx = cols.findIndex((a) => a.id === assessmentId);
  if (rIdx < 0 || cIdx < 0) return;
  let nr = rIdx;
  let nc = cIdx;
  if (dir === 'next') {
    nc++;
    if (nc >= cols.length) {
      nc = 0;
      nr++;
    }
  } else if (dir === 'prev') {
    nc--;
    if (nc < 0) {
      nc = cols.length - 1;
      nr--;
    }
  } else if (dir === 'up') {
    nr--;
  } else if (dir === 'down') {
    nr++;
  }
  if (nr < 0 || nr >= rows.length) return;
  focusCell(rows[nr].student_id, cols[nc].id);
}

function onCellKeydown(
  e: KeyboardEvent,
  studentId: string,
  assessmentId: string,
) {
  if (e.key === 'Tab') {
    e.preventDefault();
    moveCellFocus(studentId, assessmentId, e.shiftKey ? 'prev' : 'next');
  } else if (e.key === 'Enter' || e.key === 'ArrowDown') {
    e.preventDefault();
    moveCellFocus(studentId, assessmentId, 'down');
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    moveCellFocus(studentId, assessmentId, 'up');
  } else if (
    e.key === 'ArrowRight' &&
    (e.target as HTMLInputElement).selectionStart ===
      (e.target as HTMLInputElement).value.length
  ) {
    e.preventDefault();
    moveCellFocus(studentId, assessmentId, 'next');
  } else if (
    e.key === 'ArrowLeft' &&
    (e.target as HTMLInputElement).selectionStart === 0
  ) {
    e.preventDefault();
    moveCellFocus(studentId, assessmentId, 'prev');
  }
}

function onWindowKeydown(e: KeyboardEvent) {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    if (dirtyCount.value > 0 && !isSaving.value) save();
  } else if (e.key === 'Escape' && mode.value === 'matrix') {
    // Only escape out when no input is focused.
    const t = document.activeElement;
    if (!t || (t.tagName !== 'INPUT' && t.tagName !== 'TEXTAREA')) {
      backToSummary();
    }
  }
}

// ── Column actions (Lihat Detail · Edit · Hapus) ──
// Mirrors Flutter's column header bottom-sheet menu.
function openColumnActions(assessment: Assessment) {
  columnActionsFor.value = assessment;
}

function viewColumnDetail() {
  if (!columnActionsFor.value) return;
  columnDetail.value = columnActionsFor.value;
  columnActionsFor.value = null;
}

function openDeleteConfirm() {
  if (!columnActionsFor.value) return;
  columnDeleteConfirm.value = columnActionsFor.value;
  columnActionsFor.value = null;
}

async function confirmDeleteColumn() {
  if (!columnDeleteConfirm.value || !matrixSubject.value?.id) return;
  const a = columnDeleteConfirm.value;
  if (!a.date) {
    toast.value = {
      message: 'Asesmen ini belum punya tanggal — tidak bisa dihapus dari web.',
      tone: 'error',
    };
    return;
  }
  isDeletingColumn.value = true;
  try {
    await GradeService.deleteAssessmentBatch({
      subject_id: matrixSubject.value.id,
      type: a.type,
      date: a.date,
      title: a.raw_title ?? null,
    });
    toast.value = {
      message: `Asesmen "${a.name}" dihapus beserta seluruh nilainya.`,
      tone: 'success',
    };
    columnDeleteConfirm.value = null;
    await loadSummary();
    const refreshedCard = flatCards.value.find(
      (c) =>
        c.class_id === matrixClass.value?.id &&
        c.subject.id === matrixSubject.value?.id,
    );
    if (refreshedCard) {
      matrixAssessmentSeed.value = refreshedCard.subject.assessments.map(
        (sa) => ({
          id: sa.id,
          name: sa.label,
          raw_title: sa.raw_title,
          type: sa.type,
        }),
      );
    }
    await loadMatrix();
  } catch (e) {
    const err = e as {
      response?: { data?: { message?: string; errors?: Record<string, string[]> } };
    };
    const data = err.response?.data;
    let message = (e as Error).message;
    if (data?.message) message = data.message;
    if (data?.errors) {
      const fields = Object.entries(data.errors)
        .map(([k, v]) => `${k}: ${Array.isArray(v) ? v[0] : String(v)}`)
        .slice(0, 3)
        .join(' · ');
      if (fields) message = `Validasi gagal — ${fields}`;
    }
    toast.value = { message, tone: 'error' };
  } finally {
    isDeletingColumn.value = false;
  }
}

// ── Add Assessment ──
function openAddAsesmen() {
  addForm.value = {
    type: 'uh',
    title: '',
    date: new Date().toISOString().slice(0, 10),
  };
  showAddAsesmen.value = true;
}

/**
 * Add a NEW virtual assessment column to the matrix in-memory. The
 * backend assessment row is created implicitly on the first POST
 * /grades — Flutter follows the same pattern via the unique index
 * `(teacher_id, subject_id, type, date, title)`.
 *
 * After clicking "Tambah", the column appears immediately with empty
 * cells ready for input. The teacher types scores, autosave fires,
 * and backend persists the assessment + grade in one shot.
 */
function applyAddAsesmen() {
  const f = addForm.value;
  if (!f.type || !f.date) {
    toast.value = { message: 'Tipe dan tanggal wajib diisi.', tone: 'error' };
    return;
  }
  const title = f.title.trim();
  // Synthetic id — replaced with the canonical backend id after the
  // first POST + refetch (handled by getMatrix dedup pass).
  const syntheticId = `__new__${f.type}__${title || 'tanpa-judul'}__${f.date}__${Date.now()}`;
  const newAssessment: Assessment = {
    id: syntheticId,
    name: title || ASSESSMENT_LABELS[f.type],
    raw_title: title || null,
    type: f.type,
    date: f.date,
  };
  // Append to matrix.assessments + backfill empty cell for every row.
  matrix.value.assessments = [...matrix.value.assessments, newAssessment];
  for (const r of matrix.value.rows) {
    if (!r.cells[syntheticId]) {
      r.cells[syntheticId] = {
        student_id: r.student_id,
        assessment_id: syntheticId,
        score: null,
      };
    }
  }
  showAddAsesmen.value = false;
  toast.value = {
    message: `Asesmen "${newAssessment.name}" ditambahkan — isi skor untuk menyimpan.`,
    tone: 'success',
  };
}

/** Aggregate stats for the column-detail modal. */
function columnStats(a: Assessment): {
  total: number;
  graded: number;
  avg: number | null;
  dateLabel: string;
} {
  let total = 0;
  let graded = 0;
  let sum = 0;
  for (const r of matrix.value.rows) {
    total++;
    const cell = r.cells[a.id];
    const score = cell?.score;
    if (typeof score === 'number') {
      graded++;
      sum += score;
    }
  }
  const avg = graded > 0 ? Math.round((sum / graded) * 10) / 10 : null;
  let dateLabel = '—';
  if (a.date) {
    try {
      dateLabel = new Date(a.date).toLocaleDateString('id-ID', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      });
    } catch {
      dateLabel = a.date;
    }
  }
  return { total, graded, avg, dateLabel };
}

// ── Save ──
async function save(opts: { silent?: boolean } = {}) {
  if (!matrixClass.value?.id || !matrixSubject.value?.id) return;
  const cells = matrix.value.rows.flatMap((r) => Object.values(r.cells));
  const dirty = cells.filter((c) => c.dirty);
  if (dirty.length === 0) {
    if (!opts.silent)
      toast.value = {
        message: 'Tidak ada perubahan untuk disimpan.',
        tone: 'error',
      };
    return;
  }
  if (isAdminView.value) {
    toast.value = {
      message: 'Mode admin — tampilan hanya-baca. Mintalah guru terkait untuk menyimpan perubahan.',
      tone: 'error',
    };
    return;
  }
  const teacherId = auth.teacherId ?? auth.user?.id ?? '';
  if (!teacherId) {
    toast.value = {
      message: 'Identitas guru belum siap — coba refresh halaman.',
      tone: 'error',
    };
    return;
  }
  isSaving.value = true;
  try {
    await GradeService.saveDirty({
      matrix: matrix.value,
      subject_id: matrixSubject.value.id,
      teacher_id: teacherId,
    });
    for (const r of matrix.value.rows) {
      for (const c of Object.values(r.cells)) c.dirty = false;
    }
    if (!opts.silent) {
      toast.value = {
        message: `${dirty.length} nilai tersimpan.`,
        tone: 'success',
      };
    }
    // Refetch summary FIRST so the assessment seed reflects any
    // backend-assigned ids from this save. Without this, the next
    // matrix refetch could merge stale seed assessments with new
    // entry-derived ones and surface as a phantom duplicate column.
    await loadSummary();
    const refreshedCard = flatCards.value.find(
      (c) =>
        c.class_id === matrixClass.value?.id &&
        c.subject.id === matrixSubject.value?.id,
    );
    if (refreshedCard) {
      matrixAssessmentSeed.value = refreshedCard.subject.assessments.map(
        (a) => ({ id: a.id, name: a.label, type: a.type }),
      );
    }
    // Refetch matrix so newly-created cells pick up their server `id`
    // (required for the next PUT to use the right endpoint).
    await loadMatrix();
  } catch (e) {
    const err = e as { response?: { data?: { message?: string; errors?: Record<string, string[]> } } };
    const data = err.response?.data;
    let message = (e as Error).message;
    if (data?.message) message = data.message;
    if (data?.errors) {
      // Backend Laravel-style validation bag — flatten first error per field.
      const fields = Object.entries(data.errors)
        .map(([k, v]) => `${k}: ${Array.isArray(v) ? v[0] : String(v)}`)
        .slice(0, 3)
        .join(' · ');
      if (fields) message = `Validasi gagal — ${fields}`;
    }
    toast.value = { message, tone: 'error' };
    // Surface to console for debugging the raw response.
    // eslint-disable-next-line no-console
    console.error('[grades.save]', data ?? e);
  } finally {
    isSaving.value = false;
  }
}

function pickClass(id: string) {
  classFilter.value = id;
  showClassPicker.value = false;
}
function pickSubject(id: string) {
  subjectFilter.value = id;
  showSubjectPicker.value = false;
}

// ── Card helpers ──
function avgTone(avg: number | null, kkm = 75): {
  bg: string;
  text: string;
  border: string;
} {
  if (avg === null)
    return {
      bg: 'bg-slate-50',
      text: 'text-slate-400',
      border: 'border-slate-200',
    };
  if (avg >= 85)
    return {
      bg: 'bg-emerald-50',
      text: 'text-emerald-700',
      border: 'border-emerald-200',
    };
  if (avg >= kkm)
    return {
      bg: 'bg-emerald-50',
      text: 'text-emerald-700',
      border: 'border-emerald-200',
    };
  if (avg >= kkm - 10)
    return {
      bg: 'bg-amber-50',
      text: 'text-amber-700',
      border: 'border-amber-200',
    };
  return { bg: 'bg-red-50', text: 'text-red-700', border: 'border-red-200' };
}

function typePillClass(type: AssessmentType): string {
  switch (type) {
    case 'uh':
      return 'bg-violet-50 text-violet-700 border-violet-200';
    case 'uts':
      return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'uas':
      return 'bg-red-50 text-red-700 border-red-200';
    case 'tugas':
      return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    default:
      return 'bg-slate-50 text-slate-600 border-slate-200';
  }
}

function typeCountsFor(s: TeacherGradeSummarySubject) {
  const m: Partial<Record<AssessmentType, number>> = {};
  for (const a of s.assessments) {
    m[a.type] = (m[a.type] ?? 0) + 1;
  }
  return Object.entries(m).map(([k, v]) => ({
    type: k as AssessmentType,
    count: v ?? 0,
  }));
}
</script>

<template>
  <div class="space-y-md pb-24">
    <!-- ── 1. Header ────────────────────────────────────────── -->
    <BrandPageHeader
      role="guru"
      :kicker="
        mode === 'matrix'
          ? 'Buku Nilai · Matrix'
          : isWaliMode
            ? 'Buku Nilai · Wali Kelas'
            : 'Akademik · Buku Nilai'
      "
      :title="
        mode === 'matrix' && matrixSubject && matrixClass
          ? `${matrixSubject.name} · ${matrixClass.name}`
          : 'Nilai Siswa'
      "
      :meta="
        mode === 'matrix'
          ? `KKM ${matrix.kkm} · ${matrix.rows.length} siswa · ${visibleAssessments.length} asesmen`
          : `${flatCards.length} mapel·kelas · semester aktif`
      "
      :live-dot="false"
    >
      <!-- Back chip in matrix mode -->
      <button
        v-if="mode === 'matrix'"
        type="button"
        class="px-3 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 border border-white/25 text-white text-[12px] font-bold inline-flex items-center gap-1.5"
        @click="backToSummary"
      >
        <NavIcon name="chevron-left" :size="13" />
        Kembali ke daftar
      </button>

      <template v-if="mode === 'summary'" #role-toggle>
        <RoleToggleChipRow
          :roles="roleOptions"
          :selected-role-id="selectedRoleId"
          accent-color="#1B6FB8"
          @update:selected-role-id="(v) => (selectedRoleId = v)"
        />
      </template>
    </BrandPageHeader>

    <!-- ════════════════════════════════════════════════════════
         DEFAULT VIEW — summary cards
         ════════════════════════════════════════════════════════ -->
    <template v-if="mode === 'summary'">
      <KpiStripCards :cards="summaryKpi" />

      <PageFilterToolbar
        :search="searchQuery"
        search-placeholder="Cari mapel atau kelas…"
        @update:search="(v) => (searchQuery = v)"
      >
        <template #chips>
          <AppFilterChip
            v-if="!isWaliMode"
            label="Kelas"
            :value="activeClass?.name ?? 'Semua kelas'"
            icon-name="layers"
            tone="brand"
            @click="showClassPicker = true"
          />
          <AppFilterChip
            label="Mata pelajaran"
            :value="activeSubject?.name ?? 'Semua mapel'"
            icon-name="book"
            tone="amber"
            @click="showSubjectPicker = true"
          />
        </template>
      </PageFilterToolbar>

      <AsyncView
        :state="summaryState"
        empty-title="Belum ada mapel terdaftar"
        empty-description="Hubungi admin untuk mengatur kelas + mata pelajaran yang Anda ajar."
        @retry="loadSummary"
      >
        <template #default>
          <section
            class="grid grid-cols-1 lg:grid-cols-2 gap-3"
          >
            <button
              v-for="row in filteredCards"
              :key="`${row.class_id}__${row.subject.id}`"
              type="button"
              class="w-full text-left bg-white border border-slate-200 rounded-2xl p-4 hover:border-brand-cobalt/40 hover:shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30 transition-all"
              @click="openMatrix(row)"
            >
              <!-- Header row -->
              <div class="flex items-start gap-3">
                <span
                  class="w-12 h-12 rounded-2xl border grid place-items-center text-[13px] font-black flex-shrink-0"
                  :class="[
                    avgTone(row.subject.avg_score, matrix.kkm).bg,
                    avgTone(row.subject.avg_score, matrix.kkm).text,
                    avgTone(row.subject.avg_score, matrix.kkm).border,
                  ]"
                >
                  <span v-if="row.subject.avg_score !== null">
                    {{ row.subject.avg_score }}
                  </span>
                  <span v-else>—</span>
                </span>
                <div class="flex-1 min-w-0">
                  <p
                    class="text-[10px] font-bold text-brand-cobalt uppercase tracking-widest"
                  >
                    Kelas {{ row.class_name }}
                  </p>
                  <p
                    class="text-[14px] font-black text-slate-900 leading-tight mt-0.5 truncate"
                  >
                    {{ row.subject.name }}
                  </p>
                  <p
                    v-if="row.subject.code"
                    class="text-[10.5px] text-slate-400 mt-0.5"
                  >
                    {{ row.subject.code }}
                  </p>
                </div>
                <span
                  class="text-[10px] font-bold text-brand-cobalt inline-flex items-center gap-0.5 flex-shrink-0"
                >
                  Buka
                  <NavIcon name="chevron-right" :size="12" />
                </span>
              </div>

              <!-- 3 meta cells -->
              <div class="grid grid-cols-3 gap-1.5 mt-3">
                <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
                  <p
                    class="text-[8.5px] font-bold text-slate-400 uppercase tracking-widest"
                  >
                    Siswa
                  </p>
                  <p class="text-[12px] font-black text-slate-900 mt-0.5">
                    {{ row.student_count }}
                  </p>
                </div>
                <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
                  <p
                    class="text-[8.5px] font-bold text-slate-400 uppercase tracking-widest"
                  >
                    Asesmen
                  </p>
                  <p class="text-[12px] font-black text-slate-900 mt-0.5">
                    {{ row.subject.assessments.length }}
                  </p>
                </div>
                <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
                  <p
                    class="text-[8.5px] font-bold text-slate-400 uppercase tracking-widest"
                  >
                    Nilai
                  </p>
                  <p class="text-[12px] font-black text-slate-900 mt-0.5">
                    {{ row.subject.total_nilai }}
                  </p>
                </div>
              </div>

              <!-- Type pills -->
              <div
                v-if="row.subject.assessments.length > 0"
                class="flex flex-wrap items-center gap-1.5 mt-3"
              >
                <span
                  v-for="tc in typeCountsFor(row.subject)"
                  :key="tc.type"
                  class="text-[10px] font-bold uppercase tracking-widest px-2 py-0.5 rounded-full border"
                  :class="typePillClass(tc.type)"
                >
                  {{ ASSESSMENT_LABELS[tc.type] }} × {{ tc.count }}
                </span>
              </div>

              <!-- Progress strip (1 bar per assessment) -->
              <div
                v-if="row.subject.assessments.length > 0"
                class="flex items-center gap-1 mt-3 h-1 rounded-full overflow-hidden bg-slate-100"
              >
                <span
                  v-for="a in row.subject.assessments"
                  :key="a.id"
                  class="h-full flex-1 transition-colors"
                  :class="
                    a.avg !== null
                      ? a.avg >= 75
                        ? 'bg-emerald-500'
                        : 'bg-amber-500'
                      : 'bg-slate-200'
                  "
                  :title="`${a.label}: ${a.avg ?? 'belum dinilai'}`"
                ></span>
              </div>

              <!-- Empty assessment hint -->
              <p
                v-else
                class="text-[11px] text-slate-400 mt-3 inline-flex items-center gap-1.5"
              >
                <NavIcon name="bell" :size="11" />
                Belum ada asesmen — tambah di matrix.
              </p>
            </button>
          </section>
        </template>
      </AsyncView>
    </template>

    <!-- ════════════════════════════════════════════════════════
         MATRIX MODE — editable students × assessments grid
         ════════════════════════════════════════════════════════ -->
    <template v-else>
      <PageFilterToolbar
        :search="matrixSearchQuery"
        search-placeholder="Cari nama atau NIS siswa…"
        @update:search="(v) => (matrixSearchQuery = v)"
      >
        <template #chips>
          <span
            class="inline-flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5"
          >
            <span
              class="text-[9px] font-bold uppercase tracking-widest text-slate-400"
              >Kelas</span
            >
            <span class="text-[12px] font-bold text-slate-900">{{
              matrixClass?.name
            }}</span>
          </span>
          <span
            class="inline-flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5"
          >
            <span
              class="text-[9px] font-bold uppercase tracking-widest text-slate-400"
              >Mapel</span
            >
            <span class="text-[12px] font-bold text-slate-900">{{
              matrixSubject?.name
            }}</span>
          </span>
        </template>
      </PageFilterToolbar>

      <section class="bg-white border border-slate-200 rounded-2xl p-3 space-y-2.5">
        <div class="flex items-center gap-3 flex-wrap">
          <span
            class="text-[11px] font-bold text-slate-500 uppercase tracking-widest"
          >
            Jenis asesmen
          </span>
          <SegmentedControl
            :model-value="typeFilter"
            :options="typeOptions"
            size="sm"
            @update:model-value="(v) => (typeFilter = v as AssessmentType | 'all')"
          />
        </div>
        <div
          class="flex items-center gap-4 flex-wrap px-3 py-2 bg-slate-50 border border-dashed border-slate-200 rounded-lg text-[11px] text-slate-600"
        >
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-emerald-700"></span>
            <b class="text-slate-900 font-bold">{{ matrixSummary.tuntas }}</b>
            Tuntas
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-red-700"></span>
            <b class="text-slate-900 font-bold">{{ matrixSummary.remed }}</b>
            Remedial
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-slate-300"></span>
            <b class="text-slate-900 font-bold">{{ matrixSummary.belum }}</b>
            Belum dinilai
          </span>
          <span class="flex-1"></span>
          <span class="text-slate-500">
            Rata-rata kelas:
            <b class="text-slate-900 font-bold">{{ matrixSummary.avg || '—' }}</b>
            · KKM {{ matrix.kkm }}
          </span>
        </div>
        <p
          class="hidden md:flex items-center gap-3 flex-wrap text-[10.5px] text-slate-500 px-1"
        >
          <span class="font-bold text-slate-400 uppercase tracking-widest">
            Pintasan:
          </span>
          <span class="inline-flex items-center gap-1">
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">Tab</kbd>
            /
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">↵</kbd>
            pindah sel
          </span>
          <span class="inline-flex items-center gap-1">
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">↑</kbd>
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">↓</kbd>
            pindah baris
          </span>
          <span class="inline-flex items-center gap-1">
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">Ctrl</kbd>
            +
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">S</kbd>
            simpan ·
            <em class="text-slate-400">
              otomatis tersimpan 1.2 dtk setelah berhenti mengetik
            </em>
          </span>
        </p>
      </section>

      <AsyncView
        :state="matrixState"
        empty-title="Belum ada asesmen"
        empty-description="Tambahkan asesmen lewat tombol + Tambah Asesmen di pojok kanan bawah."
        @retry="loadMatrix"
      >
        <template #default>
          <section
            class="bg-white border border-slate-200 rounded-2xl overflow-x-auto"
          >
            <table class="w-full text-[12px] border-collapse">
              <thead>
                <tr
                  class="bg-slate-50 text-slate-500 text-[10px] uppercase tracking-widest"
                >
                  <th
                    class="text-left font-bold px-4 py-2.5 sticky left-0 bg-slate-50 z-10"
                  >
                    Siswa
                  </th>
                  <th
                    v-for="a in visibleAssessments"
                    :key="a.id"
                    class="font-bold px-3 py-2.5 text-center min-w-[80px]"
                  >
                    <button
                      type="button"
                      class="w-full inline-flex flex-col items-center gap-0.5 px-2 py-1 rounded-md hover:bg-brand-cobalt/10 transition-colors text-slate-500 hover:text-brand-cobalt"
                      :title="`Aksi untuk ${a.name}`"
                      @click="openColumnActions(a)"
                    >
                      <span>{{ a.name }}</span>
                      <span class="text-[9px] font-medium text-slate-400">
                        {{ ASSESSMENT_LABELS[a.type] }}
                      </span>
                    </button>
                  </th>
                  <th class="font-bold px-3 py-2.5 text-center min-w-[64px]">
                    Rata-rata
                  </th>
                  <th class="font-bold px-3 py-2.5 text-center min-w-[100px]">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(row, idx) in filteredMatrixRows"
                  :key="row.student_id"
                  :class="{ 'border-t border-slate-100': idx > 0 }"
                >
                  <td class="px-4 py-2.5 sticky left-0 bg-white z-10">
                    <div class="flex items-center gap-2.5">
                      <InitialsAvatar
                        :name="row.student_name"
                        :size="28"
                        :border-radius="7"
                        :color="
                          row.alert_tone === 'danger' ? '#B91C1C' : '#1B6FB8'
                        "
                      />
                      <div>
                        <p class="font-bold text-slate-900 text-[12px]">
                          {{ row.student_name }}
                        </p>
                        <p class="text-[10px] text-slate-400">
                          NIS {{ row.student_number }}
                        </p>
                      </div>
                    </div>
                  </td>
                  <td
                    v-for="a in visibleAssessments"
                    :key="a.id"
                    class="px-3 py-2.5 text-center"
                    :class="{
                      'bg-red-50':
                        row.cells[a.id]?.score !== null &&
                        (row.cells[a.id]?.score as number) < matrix.kkm,
                    }"
                  >
                    <input
                      type="number"
                      min="0"
                      max="100"
                      :value="row.cells[a.id]?.score ?? ''"
                      :data-grade-cell="`${row.student_id}__${a.id}`"
                      class="w-14 px-1.5 py-1 text-[12px] font-bold text-center rounded-md border border-slate-200 focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
                      :class="{
                        'border-red-200 text-red-700 bg-red-50/60':
                          row.cells[a.id]?.score !== null &&
                          (row.cells[a.id]?.score as number) < matrix.kkm,
                        'ring-2 ring-amber-300/40': row.cells[a.id]?.dirty,
                      }"
                      @input="
                        (e) =>
                          updateCell(
                            row.student_id,
                            a.id,
                            (e.target as HTMLInputElement).value,
                          )
                      "
                      @keydown="
                        (e) => onCellKeydown(e, row.student_id, a.id)
                      "
                    />
                  </td>
                  <td
                    class="px-3 py-2.5 text-center font-bold text-slate-900"
                    :class="{
                      'bg-red-50 text-red-700':
                        rowAverage(row.student_id) !== null &&
                        (rowAverage(row.student_id) as number) < matrix.kkm,
                    }"
                  >
                    {{ rowAverage(row.student_id) ?? '—' }}
                  </td>
                  <td class="px-3 py-2.5 text-center">
                    <span
                      v-if="rowAverage(row.student_id) === null"
                      class="inline-flex items-center gap-1.5 text-[10px] font-bold text-slate-500"
                    >
                      <span class="w-1.5 h-1.5 rounded-full bg-slate-300"></span>
                      Belum
                    </span>
                    <span
                      v-else-if="(rowAverage(row.student_id) as number) >= matrix.kkm"
                      class="inline-flex items-center gap-1.5 text-[10px] font-bold text-emerald-700"
                    >
                      <span class="w-1.5 h-1.5 rounded-full bg-emerald-700"></span>
                      Tuntas
                    </span>
                    <span
                      v-else
                      class="inline-flex items-center gap-1.5 text-[10px] font-bold text-red-700"
                    >
                      <span class="w-1.5 h-1.5 rounded-full bg-red-700"></span>
                      Remedial
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </section>
        </template>
      </AsyncView>

      <!-- Sticky save bar -->
      <section
        v-if="matrix.rows.length > 0"
        class="sticky bottom-4 flex items-center gap-3 px-4 py-3 bg-white border border-slate-200 rounded-2xl shadow-lg z-20"
      >
        <div class="text-[11px] text-slate-600">
          <span
            v-if="dirtyCount === 0 && !isSaving"
            class="text-emerald-700 font-bold inline-flex items-center gap-1"
          >
            <NavIcon name="check-circle" :size="12" />
            Tersimpan
          </span>
          <span v-else-if="isSaving" class="text-brand-cobalt font-bold">
            Menyimpan otomatis…
          </span>
          <span v-else class="text-amber-700 font-bold">
            {{ dirtyCount }} perubahan belum tersimpan
          </span>
          <span v-if="matrixSummary.remed > 0" class="ml-2 text-slate-400">
            ·
            <span class="text-red-700 font-bold">{{ matrixSummary.remed }}</span>
            remedial perlu ditindaklanjuti
          </span>
        </div>
        <span class="flex-1"></span>
        <Button variant="secondary" size="sm" @click="loadMatrix">
          Muat ulang
        </Button>
        <Button
          variant="primary"
          size="sm"
          :loading="isSaving"
          :disabled="dirtyCount === 0"
          @click="save()"
        >
          Simpan nilai
        </Button>
      </section>

      <!-- ── FAB: Tambah Asesmen (Flutter parity) ─────────────── -->
      <!-- Hidden when matrix has no students — adding a column
           when there's no roster has no save target. -->
      <button
        v-if="matrix.rows.length > 0"
        type="button"
        class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
        @click="openAddAsesmen"
      >
        <NavIcon name="plus" :size="16" />
        Tambah Asesmen
      </button>
    </template>

    <!-- ── Column actions sheet (Flutter parity) ────────────── -->
    <Modal
      v-if="columnActionsFor"
      :title="columnActionsFor.name"
      :subtitle="ASSESSMENT_LABELS[columnActionsFor.type]"
      @close="columnActionsFor = null"
    >
      <ul class="space-y-1">
        <li>
          <button
            type="button"
            class="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-slate-50 text-left"
            @click="viewColumnDetail"
          >
            <span class="w-9 h-9 rounded-lg bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0">
              <NavIcon name="eye" :size="16" />
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">Lihat detail</p>
              <p class="text-[11px] text-slate-500">Tipe, tanggal, statistik kelas</p>
            </div>
            <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
          </button>
        </li>
        <li>
          <button
            type="button"
            class="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-red-50 text-left"
            @click="openDeleteConfirm"
          >
            <span class="w-9 h-9 rounded-lg bg-red-100 text-red-700 grid place-items-center flex-shrink-0">
              <NavIcon name="trash" :size="16" />
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-red-700">Hapus asesmen</p>
              <p class="text-[11px] text-slate-500">Hapus seluruh nilai pada kolom ini</p>
            </div>
            <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
          </button>
        </li>
      </ul>
      <p class="mt-4 pt-3 border-t border-slate-100 text-[11px] text-slate-400">
        Mengikuti pola aplikasi mobile — tap header asesmen untuk membuka menu ini.
      </p>
    </Modal>

    <!-- ── Column detail modal ──────────────────────────────── -->
    <Modal
      v-if="columnDetail"
      :title="columnDetail.name"
      :subtitle="`${ASSESSMENT_LABELS[columnDetail.type]} · Detail asesmen`"
      @close="columnDetail = null"
    >
      <div class="space-y-3">
        <div class="grid grid-cols-2 gap-2">
          <div class="bg-slate-50 rounded-xl p-3">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Tipe</p>
            <p class="text-[14px] font-bold text-slate-900 mt-1">{{ ASSESSMENT_LABELS[columnDetail.type] }}</p>
          </div>
          <div class="bg-slate-50 rounded-xl p-3">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Tanggal</p>
            <p class="text-[13px] font-bold text-slate-900 mt-1">{{ columnStats(columnDetail).dateLabel }}</p>
          </div>
        </div>
        <div class="grid grid-cols-3 gap-2">
          <div class="bg-brand-cobalt/5 rounded-xl p-3 text-center">
            <p class="text-[10px] font-bold text-brand-cobalt uppercase tracking-widest">Siswa</p>
            <p class="text-[18px] font-black text-brand-cobalt mt-0.5">{{ columnStats(columnDetail).total }}</p>
          </div>
          <div class="bg-emerald-50 rounded-xl p-3 text-center">
            <p class="text-[10px] font-bold text-emerald-700 uppercase tracking-widest">Dinilai</p>
            <p class="text-[18px] font-black text-emerald-700 mt-0.5">{{ columnStats(columnDetail).graded }}</p>
          </div>
          <div class="bg-violet-50 rounded-xl p-3 text-center">
            <p class="text-[10px] font-bold text-violet-700 uppercase tracking-widest">Rerata</p>
            <p class="text-[18px] font-black text-violet-700 mt-0.5">{{ columnStats(columnDetail).avg ?? '—' }}</p>
          </div>
        </div>
        <div class="flex items-center justify-end pt-2">
          <Button variant="secondary" size="sm" @click="columnDetail = null">Tutup</Button>
        </div>
      </div>
    </Modal>

    <!-- ── Delete assessment confirm ────────────────────────── -->
    <Modal
      v-if="columnDeleteConfirm"
      title="Hapus asesmen?"
      :subtitle="`Seluruh nilai siswa pada kolom '${columnDeleteConfirm.name}' akan ikut terhapus dan tidak dapat dipulihkan.`"
      @close="!isDeletingColumn && (columnDeleteConfirm = null)"
    >
      <div class="space-y-3">
        <div class="bg-red-50 border border-red-100 rounded-xl px-3 py-2.5">
          <p class="text-[12px] text-red-700 leading-relaxed">
            <strong>{{ columnDeleteConfirm.name }}</strong>
            ·
            {{ ASSESSMENT_LABELS[columnDeleteConfirm.type] }}
            ·
            {{ columnStats(columnDeleteConfirm).graded }} dari
            {{ columnStats(columnDeleteConfirm).total }} siswa sudah dinilai
          </p>
        </div>
        <div class="flex items-center justify-end gap-2 pt-1">
          <Button
            variant="secondary"
            size="sm"
            :disabled="isDeletingColumn"
            @click="columnDeleteConfirm = null"
          >
            Batal
          </Button>
          <Button
            variant="primary"
            size="sm"
            :loading="isDeletingColumn"
            class="!bg-red-600 hover:!bg-red-700"
            @click="confirmDeleteColumn"
          >
            Hapus permanen
          </Button>
        </div>
      </div>
    </Modal>

    <!-- ── Tambah Asesmen modal (Flutter parity FAB flow) ───── -->
    <Modal
      v-if="showAddAsesmen"
      title="Tambah Asesmen Baru"
      subtitle="Setelah dibuat, kolom kosong akan muncul. Isi skor siswa untuk menyimpan."
      @close="showAddAsesmen = false"
    >
      <form class="space-y-md" @submit.prevent="applyAddAsesmen">
        <div>
          <label
            class="block text-[11px] font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            Tipe Asesmen
          </label>
          <SegmentedControl
            :model-value="addForm.type"
            :options="[
              { key: 'tugas', label: 'Tugas' },
              { key: 'uh', label: 'UH' },
              { key: 'uts', label: 'UTS' },
              { key: 'uas', label: 'UAS' },
              { key: 'lainnya', label: 'Lainnya' },
            ]"
            size="sm"
            @update:model-value="(v) => (addForm.type = v as AssessmentType)"
          />
        </div>
        <div>
          <label
            class="block text-[11px] font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            Judul (opsional)
          </label>
          <input
            v-model="addForm.title"
            type="text"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            placeholder="Contoh: Ulangan Harian 4, UTS Genap"
          />
          <p class="text-[10.5px] text-slate-400 mt-1">
            Kosongkan untuk pakai label default ({{ ASSESSMENT_LABELS[addForm.type] }}).
          </p>
        </div>
        <div>
          <label
            class="block text-[11px] font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            Tanggal
          </label>
          <input
            v-model="addForm.date"
            type="date"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
          />
        </div>
        <div class="bg-slate-50 border border-dashed border-slate-200 rounded-lg px-3 py-2 text-[11px] text-slate-500">
          <NavIcon name="check-circle" :size="11" class="inline-block mr-1 -mt-0.5 text-brand-cobalt" />
          Kolom baru muncul langsung di matrix; backend menyimpan asesmen otomatis saat skor siswa pertama disimpan.
        </div>
        <div class="flex items-center justify-end gap-2 pt-1">
          <Button
            variant="secondary"
            size="sm"
            @click="showAddAsesmen = false"
          >
            Batal
          </Button>
          <Button variant="primary" size="sm" @click="applyAddAsesmen">
            Tambah
          </Button>
        </div>
      </form>
    </Modal>

    <!-- ── Picker modals ────────────────────────────────────── -->
    <Modal
      v-if="showClassPicker"
      title="Pilih Kelas"
      @close="showClassPicker = false"
    >
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold': !classFilter,
            }"
            @click="pickClass('')"
          >
            Semua kelas
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                c.id === classFilter,
            }"
            @click="pickClass(c.id)"
          >
            <span>{{ c.name }}</span>
            <span class="text-[10px] text-slate-400">
              {{ c.student_count }} siswa
            </span>
          </button>
        </li>
      </ul>
    </Modal>

    <Modal
      v-if="showSubjectPicker"
      title="Pilih Mata Pelajaran"
      @close="showSubjectPicker = false"
    >
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold': !subjectFilter,
            }"
            @click="pickSubject('')"
          >
            Semua mapel
          </button>
        </li>
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                s.id === subjectFilter,
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

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>

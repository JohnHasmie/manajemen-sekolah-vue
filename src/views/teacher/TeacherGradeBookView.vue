<!--
  TeacherGradeBookView.vue — Grade Student (Gradebook).

  Web port of Flutter's `teacher_grade_input_screen.dart`. Same flow
  shape as Presensi:

    Default landing (no specific filter):
      1. <BrandPageHeader> (teacher) + <RoleToggleChipRow> (Mengajar/Parent)
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
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { GradeService } from '@/services/grades.service';
import { localISODate } from '@/lib/format';
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
const { t } = useI18n();

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

// ── Role toggle (Mengajar / Parent) ──
const selectedRoleId = ref<string>('mengajar');
const roleOptions = computed<RoleOption[]>(() => {
  const out: RoleOption[] = [
    {
      id: 'mengajar',
      shortName: t('tutor.sekolah.gradebook.roleTeachingShort'),
      subLabel: t('tutor.sekolah.gradebook.roleTeachingSub'),
      avatarInitials: 'M',
    },
  ];
  for (const hc of auth.homeroomClasses) {
    const name = hc.name || hc.id;
    out.push({
      id: `wali:${hc.id}`,
      shortName: t('tutor.sekolah.gradebook.roleHomeroomShort', { name }),
      subLabel: t('tutor.sekolah.gradebook.roleHomeroomSub'),
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
// Edit-assessment modal — opens when the teacher taps the assessment
// header then "Edit Asesmen". Lets them rename (judul) + change the
// type/date of an existing column. Mirrors Flutter's `onEditAssessment`
// tile in `grade_column_options_sheet.dart`.
const columnEditFor = ref<Assessment | null>(null);
const editForm = ref<{ type: AssessmentType; title: string; date: string }>({
  type: 'daily_test',
  title: '',
  date: localISODate(),
});
const isSavingColumnEdit = ref(false);

// Add-assessment modal state — mirrors Flutter `grade_input_dialog.dart`
// trigger from the FAB.
const showAddAsesmen = ref(false);
const addForm = ref<{
  type: AssessmentType;
  title: string;
  date: string; // YYYY-MM-DD
}>({
  type: 'daily_test',
  title: '',
  date: localISODate(),
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
      label: t('tutor.sekolah.gradebook.kpiMapelKelas'),
      value: totalCards,
      tone: 'brand',
    },
    {
      icon: 'edit-3',
      label: t('tutor.sekolah.gradebook.kpiAsesmen'),
      value: totalAssessments,
      tone: 'violet',
    },
    {
      icon: 'bar-chart',
      label: t('tutor.sekolah.gradebook.kpiRerata'),
      value: cardsWithAvg
        ? Math.round((sumAvg / cardsWithAvg) * 10) / 10
        : '—',
      suffix: t('tutor.sekolah.gradebook.kpiRerataSuffix'),
      tone: 'green',
      accented: true,
    },
    {
      icon: 'bell',
      label: t('tutor.sekolah.gradebook.kpiBelumDinilai'),
      value: cardsBelumNilai,
      suffix: t('tutor.sekolah.gradebook.kpiBelumSuffix'),
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

/**
 * When two assessments share the SAME title but differ in `type`
 * (e.g. "UH Bab 1" exists as both `daily_test` AND `uh`, which the
 * DB allows — assessment_unique_with_title is on
 * (teacher_id, subject_id, type, date, title)), the header used to
 * render only the title — the user saw "UH Bab 1" twice with no way
 * to tell them apart, and reasonably called it a duplicate
 * (Luay 2026-06-19, SMP Kamil Edu B / TIK).
 *
 * Prefix the type ("UH · UH Bab 1") only when there is an in-view
 * collision so the common case (unique titles) stays terse. The
 * existing 9px type subtitle below the header stays as well, but a
 * loud prefix is what actually makes the columns visually distinct
 * at a glance.
 */
const assessmentDisplayNames = computed<Record<string, string>>(() => {
  const titleCount = new Map<string, number>();
  for (const a of visibleAssessments.value) {
    titleCount.set(a.name, (titleCount.get(a.name) ?? 0) + 1);
  }
  const out: Record<string, string> = {};
  for (const a of visibleAssessments.value) {
    out[a.id] =
      (titleCount.get(a.name) ?? 0) > 1
        ? `${typeLabel(a.type)} · ${a.name}`
        : a.name;
  }
  return out;
});

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

// Option keys use the canonical English AssessmentType values so the
// selected key matches `assessment.type` (also canonical) when the
// matrix filters `visibleAssessments`. The labels stay Indonesian.
const typeOptions = computed(() => [
  { key: 'all', label: t('tutor.sekolah.gradebook.typeAll'), meta: String(typeCounts.value.all ?? 0) },
  {
    key: 'assignment',
    label: t('tutor.sekolah.gradebook.typeAssignment'),
    meta: String(typeCounts.value.assignment ?? 0),
  },
  {
    key: 'daily_test',
    label: t('tutor.sekolah.gradebook.typeDailyTest'),
    meta: String(typeCounts.value.daily_test ?? 0),
  },
  {
    key: 'midterm',
    label: t('tutor.sekolah.gradebook.typeMidterm'),
    meta: String(typeCounts.value.midterm ?? 0),
  },
  {
    key: 'final_exam',
    label: t('tutor.sekolah.gradebook.typeFinalExam'),
    meta: String(typeCounts.value.final_exam ?? 0),
  },
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
      view: isWaliMode.value ? 'homeroom_teacher' : 'teaching',
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

// ── Edit assessment (rename + details) ──
// Opens the edit modal pre-filled with the column's current title /
// type / date. Title falls back to '' when the backend column is NULL
// (raw_title null) so the input shows the placeholder, not "(tanpa
// judul)".
function openEditColumn() {
  const a = columnActionsFor.value;
  if (!a) return;
  columnEditFor.value = a;
  editForm.value = {
    type: a.type,
    title: a.raw_title ?? '',
    date: a.date ?? localISODate(),
  };
  columnActionsFor.value = null;
}

async function applyEditColumn() {
  const a = columnEditFor.value;
  if (!a || !matrixSubject.value?.id) return;
  const f = editForm.value;
  if (!f.type || !f.date) {
    toast.value = { message: t('tutor.sekolah.gradebook.toastTypeDateRequired'), tone: 'error' };
    return;
  }
  // Editing requires the original column to have a date so the
  // backend batch-delete can target it (same limit as delete).
  if (!a.date) {
    toast.value = {
      message: t('tutor.sekolah.gradebook.toastEditNoDate'),
      tone: 'error',
    };
    return;
  }
  const nextTitle = f.title.trim() || null;
  const oldTitle = a.raw_title ?? null;
  // No-op guard — nothing actually changed.
  if (f.type === a.type && f.date === a.date && nextTitle === oldTitle) {
    columnEditFor.value = null;
    return;
  }
  if (isAdminView.value) {
    toast.value = {
      message: t('tutor.sekolah.gradebook.toastReadOnly'),
      tone: 'error',
    };
    return;
  }
  // Synthetic (not-yet-saved) column added via the FAB this session —
  // it has no backend assessment row to migrate. Just edit it in place;
  // it persists with the new details on first score save.
  if (a.id.startsWith('__new__')) {
    const target = matrix.value.assessments.find((x) => x.id === a.id);
    if (target) {
      target.type = f.type;
      target.date = f.date;
      target.raw_title = nextTitle;
      target.name = nextTitle || typeLabel(f.type);
    }
    columnEditFor.value = null;
    toast.value = {
      message: t('tutor.sekolah.gradebook.toastAssessmentUpdated', {
        name: nextTitle || typeLabel(f.type),
      }),
      tone: 'success',
    };
    return;
  }
  // The backend PATCH endpoint school-scopes internally and derives
  // teacher_id from the row it locks, so no teacher_id gate is needed
  // here. Grades stay attached to the same assessment_id (in-place
  // update), so there's nothing to migrate row-by-row either.
  isSavingColumnEdit.value = true;
  try {
    await GradeService.renameAssessment({
      old: { type: a.type, date: a.date, title: oldTitle },
      next: { type: f.type, date: f.date, title: nextTitle },
      assessmentId: a.id,
    });
    toast.value = {
      message: t('tutor.sekolah.gradebook.toastAssessmentUpdated', {
        name: nextTitle || typeLabel(f.type),
      }),
      tone: 'success',
    };
    columnEditFor.value = null;
    // Refresh summary first so the seed reflects the new assessment id,
    // then refetch the matrix (same reconcile order as save/delete).
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
      if (fields) message = t('tutor.sekolah.gradebook.toastValidationFailed', { fields });
    }
    toast.value = { message, tone: 'error' };
  } finally {
    isSavingColumnEdit.value = false;
  }
}

async function confirmDeleteColumn() {
  if (!columnDeleteConfirm.value || !matrixSubject.value?.id) return;
  const a = columnDeleteConfirm.value;
  if (!a.date) {
    toast.value = {
      message: t('tutor.sekolah.gradebook.toastDeleteNoDate'),
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
      message: t('tutor.sekolah.gradebook.toastAssessmentDeleted', { name: a.name }),
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
      if (fields) message = t('tutor.sekolah.gradebook.toastValidationFailed', { fields });
    }
    toast.value = { message, tone: 'error' };
  } finally {
    isDeletingColumn.value = false;
  }
}

// ── Add Assessment ──
function openAddAsesmen() {
  addForm.value = {
    type: 'daily_test',
    title: '',
    date: localISODate(),
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
    toast.value = { message: t('tutor.sekolah.gradebook.toastTypeDateRequired'), tone: 'error' };
    return;
  }
  const title = f.title.trim();
  // Synthetic id — replaced with the canonical backend id after the
  // first POST + refetch (handled by getMatrix dedup pass).
  const syntheticId = `__new__${f.type}__${title || 'tanpa-judul'}__${f.date}__${Date.now()}`;
  const newAssessment: Assessment = {
    id: syntheticId,
    name: title || typeLabel(f.type),
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
    message: t('tutor.sekolah.gradebook.toastAssessmentAdded', { name: newAssessment.name }),
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
        message: t('tutor.sekolah.gradebook.toastNoChanges'),
        tone: 'error',
      };
    return;
  }
  if (isAdminView.value) {
    toast.value = {
      message: t('tutor.sekolah.gradebook.toastReadOnly'),
      tone: 'error',
    };
    return;
  }
  const teacherId = auth.teacherId ?? auth.user?.id ?? '';
  if (!teacherId) {
    toast.value = {
      message: t('tutor.sekolah.gradebook.toastTeacherIdMissing'),
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
        message: t('tutor.sekolah.gradebook.toastSaved', { count: dirty.length }),
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
      if (fields) message = t('tutor.sekolah.gradebook.toastValidationFailed', { fields });
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
    case 'daily_test':
      return 'bg-violet-50 text-violet-700 border-violet-200';
    case 'midterm':
      return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'final_exam':
      return 'bg-red-50 text-red-700 border-red-200';
    case 'assignment':
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

// Localized label for an assessment type. Mirrors `ASSESSMENT_LABELS`
// from `@/types/grades` but routes through i18n so the headers,
// modals, and toasts in this view follow the active locale instead of
// surfacing the canonical Indonesian fallbacks.
function typeLabel(type: AssessmentType): string {
  switch (type) {
    case 'assignment':
      return t('tutor.sekolah.gradebook.typeAssignment');
    case 'daily_test':
      return t('tutor.sekolah.gradebook.typeDailyTest');
    case 'midterm':
      return t('tutor.sekolah.gradebook.typeMidterm');
    case 'final_exam':
      return t('tutor.sekolah.gradebook.typeFinalExam');
    case 'quiz':
      return t('tutor.sekolah.gradebook.typeQuiz');
    case 'other':
      return t('tutor.sekolah.gradebook.typeOther');
    default:
      return ASSESSMENT_LABELS[type];
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <!-- ── 1. Header ────────────────────────────────────────── -->
    <BrandPageHeader
      role="guru"
      :kicker="
        mode === 'matrix'
          ? t('tutor.sekolah.gradebook.kickerMatrix')
          : isWaliMode
            ? t('tutor.sekolah.gradebook.kickerHomeroom')
            : t('tutor.sekolah.gradebook.kickerDefault')
      "
      :title="
        mode === 'matrix' && matrixSubject && matrixClass
          ? `${matrixSubject.name} · ${matrixClass.name}`
          : t('tutor.sekolah.gradebook.titleSummary')
      "
      :meta="
        mode === 'matrix'
          ? t('tutor.sekolah.gradebook.metaMatrix', { kkm: matrix.kkm, students: matrix.rows.length, assessments: visibleAssessments.length })
          : t('tutor.sekolah.gradebook.metaSummary', { count: flatCards.length })
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
        {{ t('tutor.sekolah.gradebook.backToList') }}
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
        :search-placeholder="t('tutor.sekolah.gradebook.searchSummaryPlaceholder')"
        @update:search="(v) => (searchQuery = v)"
      >
        <template #chips>
          <AppFilterChip
            v-if="!isWaliMode"
            :label="t('tutor.sekolah.gradebook.chipClass')"
            :value="activeClass?.name ?? t('tutor.sekolah.gradebook.allClasses')"
            icon-name="layers"
            tone="brand"
            @click="showClassPicker = true"
          />
          <AppFilterChip
            :label="t('tutor.sekolah.gradebook.chipSubject')"
            :value="activeSubject?.name ?? t('tutor.sekolah.gradebook.allSubjects')"
            icon-name="book"
            tone="amber"
            @click="showSubjectPicker = true"
          />
        </template>
      </PageFilterToolbar>

      <AsyncView
        :state="summaryState"
        :empty-title="t('tutor.sekolah.gradebook.emptyTitle')"
        :empty-description="t('tutor.sekolah.gradebook.emptyDescription')"
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
                    class="text-3xs font-bold text-brand-cobalt uppercase tracking-widest"
                  >
                    {{ t('tutor.sekolah.gradebook.cardClassPrefix', { name: row.class_name }) }}
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
                  class="text-3xs font-bold text-brand-cobalt inline-flex items-center gap-0.5 flex-shrink-0"
                >
                  {{ t('tutor.sekolah.gradebook.cardOpen') }}
                  <NavIcon name="chevron-right" :size="12" />
                </span>
              </div>

              <!-- 3 meta cells -->
              <div class="grid grid-cols-3 gap-1.5 mt-3">
                <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
                  <p
                    class="text-[8.5px] font-bold text-slate-400 uppercase tracking-widest"
                  >
                    {{ t('tutor.sekolah.gradebook.cardSiswa') }}
                  </p>
                  <p class="text-[12px] font-black text-slate-900 mt-0.5">
                    {{ row.student_count }}
                  </p>
                </div>
                <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
                  <p
                    class="text-[8.5px] font-bold text-slate-400 uppercase tracking-widest"
                  >
                    {{ t('tutor.sekolah.gradebook.cardAsesmen') }}
                  </p>
                  <p class="text-[12px] font-black text-slate-900 mt-0.5">
                    {{ row.subject.assessments.length }}
                  </p>
                </div>
                <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
                  <p
                    class="text-[8.5px] font-bold text-slate-400 uppercase tracking-widest"
                  >
                    {{ t('tutor.sekolah.gradebook.cardNilai') }}
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
                  class="text-3xs font-bold uppercase tracking-widest px-2 py-0.5 rounded-full border"
                  :class="typePillClass(tc.type)"
                >
                  {{ typeLabel(tc.type) }} × {{ tc.count }}
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
                  :title="`${a.label}: ${a.avg ?? t('tutor.sekolah.gradebook.cardProgressNoScore')}`"
                ></span>
              </div>

              <!-- Empty assessment hint -->
              <p
                v-else
                class="text-2xs text-slate-400 mt-3 inline-flex items-center gap-1.5"
              >
                <NavIcon name="bell" :size="11" />
                {{ t('tutor.sekolah.gradebook.cardEmptyAssessment') }}
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
        :search-placeholder="t('tutor.sekolah.gradebook.matrixSearchPlaceholder')"
        @update:search="(v) => (matrixSearchQuery = v)"
      >
        <template #chips>
          <span
            class="inline-flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5"
          >
            <span
              class="text-4xs font-bold uppercase tracking-widest text-slate-400"
              >{{ t('tutor.sekolah.gradebook.matrixChipClass') }}</span
            >
            <span class="text-[12px] font-bold text-slate-900">{{
              matrixClass?.name
            }}</span>
          </span>
          <span
            class="inline-flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5"
          >
            <span
              class="text-4xs font-bold uppercase tracking-widest text-slate-400"
              >{{ t('tutor.sekolah.gradebook.matrixChipSubject') }}</span
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
            class="text-2xs font-bold text-slate-500 uppercase tracking-widest"
          >
            {{ t('tutor.sekolah.gradebook.matrixTypeLabel') }}
          </span>
          <SegmentedControl
            :model-value="typeFilter"
            :options="typeOptions"
            size="sm"
            @update:model-value="(v) => (typeFilter = v as AssessmentType | 'all')"
          />
        </div>
        <div
          class="flex items-center gap-4 flex-wrap px-3 py-2 bg-slate-50 border border-dashed border-slate-200 rounded-lg text-2xs text-slate-600"
        >
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-emerald-700"></span>
            <b class="text-slate-900 font-bold">{{ matrixSummary.tuntas }}</b>
            {{ t('tutor.sekolah.gradebook.kkmTuntas') }}
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-red-700"></span>
            <b class="text-slate-900 font-bold">{{ matrixSummary.remed }}</b>
            {{ t('tutor.sekolah.gradebook.kkmRemed') }}
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-slate-300"></span>
            <b class="text-slate-900 font-bold">{{ matrixSummary.belum }}</b>
            {{ t('tutor.sekolah.gradebook.kkmBelum') }}
          </span>
          <span class="flex-1"></span>
          <span class="text-slate-500">
            {{ t('tutor.sekolah.gradebook.kkmClassAvg') }}
            <b class="text-slate-900 font-bold">{{ matrixSummary.avg || '—' }}</b>
            · {{ t('tutor.sekolah.gradebook.kkmLabel', { kkm: matrix.kkm }) }}
          </span>
        </div>
        <p
          class="hidden md:flex items-center gap-3 flex-wrap text-[10.5px] text-slate-500 px-1"
        >
          <span class="font-bold text-slate-400 uppercase tracking-widest">
            {{ t('tutor.sekolah.gradebook.shortcutsLabel') }}
          </span>
          <span class="inline-flex items-center gap-1">
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">Tab</kbd>
            /
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">↵</kbd>
            {{ t('tutor.sekolah.gradebook.shortcutsMoveCell') }}
          </span>
          <span class="inline-flex items-center gap-1">
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">↑</kbd>
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">↓</kbd>
            {{ t('tutor.sekolah.gradebook.shortcutsMoveRow') }}
          </span>
          <span class="inline-flex items-center gap-1">
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">{{ t('tutor.sekolah.gradebook.shortcutsCtrl') }}</kbd>
            +
            <kbd class="px-1.5 py-0.5 rounded bg-slate-100 border border-slate-200 text-slate-600 font-bold">S</kbd>
            {{ t('tutor.sekolah.gradebook.shortcutsSave') }}
            <em class="text-slate-400">
              {{ t('tutor.sekolah.gradebook.shortcutsAutosave') }}
            </em>
          </span>
        </p>
      </section>

      <AsyncView
        :state="matrixState"
        :empty-title="t('tutor.sekolah.gradebook.matrixEmptyTitle')"
        :empty-description="t('tutor.sekolah.gradebook.matrixEmptyDesc')"
        @retry="loadMatrix"
      >
        <template #default>
          <section
            class="bg-white border border-slate-200 rounded-2xl overflow-x-auto"
          >
            <table class="w-full text-[12px] border-collapse">
              <thead>
                <tr
                  class="bg-slate-50 text-slate-500 text-3xs uppercase tracking-widest"
                >
                  <th
                    class="text-left font-bold px-4 py-2.5 sticky left-0 bg-slate-50 z-10"
                  >
                    {{ t('tutor.sekolah.gradebook.matrixColStudent') }}
                  </th>
                  <th
                    v-for="a in visibleAssessments"
                    :key="a.id"
                    class="font-bold px-3 py-2.5 text-center min-w-[80px]"
                  >
                    <button
                      type="button"
                      class="w-full inline-flex flex-col items-center gap-0.5 px-2 py-1 rounded-md hover:bg-brand-cobalt/10 transition-colors text-slate-500 hover:text-brand-cobalt"
                      :title="t('tutor.sekolah.gradebook.matrixColActionTitle', { name: assessmentDisplayNames[a.id] || a.name })"
                      @click="openColumnActions(a)"
                    >
                      <span>{{ assessmentDisplayNames[a.id] || a.name }}</span>
                      <span class="text-4xs font-medium text-slate-400">
                        {{ typeLabel(a.type) }}
                      </span>
                    </button>
                  </th>
                  <th class="font-bold px-3 py-2.5 text-center min-w-[64px]">
                    {{ t('tutor.sekolah.gradebook.matrixColAverage') }}
                  </th>
                  <th class="font-bold px-3 py-2.5 text-center min-w-[100px]">
                    {{ t('tutor.sekolah.gradebook.matrixColStatus') }}
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
                        <p class="text-3xs text-slate-400">
                          {{ t('tutor.sekolah.gradebook.matrixStudentNumber', { number: row.student_number }) }}
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
                      class="inline-flex items-center gap-1.5 text-3xs font-bold text-slate-500"
                    >
                      <span class="w-1.5 h-1.5 rounded-full bg-slate-300"></span>
                      {{ t('tutor.sekolah.gradebook.matrixStatusBelum') }}
                    </span>
                    <span
                      v-else-if="(rowAverage(row.student_id) as number) >= matrix.kkm"
                      class="inline-flex items-center gap-1.5 text-3xs font-bold text-emerald-700"
                    >
                      <span class="w-1.5 h-1.5 rounded-full bg-emerald-700"></span>
                      {{ t('tutor.sekolah.gradebook.matrixStatusTuntas') }}
                    </span>
                    <span
                      v-else
                      class="inline-flex items-center gap-1.5 text-3xs font-bold text-red-700"
                    >
                      <span class="w-1.5 h-1.5 rounded-full bg-red-700"></span>
                      {{ t('tutor.sekolah.gradebook.matrixStatusRemedial') }}
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
        <div class="text-2xs text-slate-600">
          <span
            v-if="dirtyCount === 0 && !isSaving"
            class="text-emerald-700 font-bold inline-flex items-center gap-1"
          >
            <NavIcon name="check-circle" :size="12" />
            {{ t('tutor.sekolah.gradebook.saveSaved') }}
          </span>
          <span v-else-if="isSaving" class="text-brand-cobalt font-bold">
            {{ t('tutor.sekolah.gradebook.saveSaving') }}
          </span>
          <span v-else class="text-amber-700 font-bold">
            {{ t('tutor.sekolah.gradebook.saveDirty', { count: dirtyCount }) }}
          </span>
          <span v-if="matrixSummary.remed > 0" class="ml-2 text-slate-400">
            ·
            <span class="text-red-700 font-bold">{{ matrixSummary.remed }}</span>
            {{ t('tutor.sekolah.gradebook.saveRemedNote') }}
          </span>
        </div>
        <span class="flex-1"></span>
        <Button variant="secondary" size="sm" @click="loadMatrix">
          {{ t('tutor.sekolah.gradebook.saveReload') }}
        </Button>
        <Button
          variant="primary"
          size="sm"
          :loading="isSaving"
          :disabled="dirtyCount === 0"
          @click="save()"
        >
          {{ t('tutor.sekolah.gradebook.saveButton') }}
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
        {{ t('tutor.sekolah.gradebook.fabAdd') }}
      </button>
    </template>

    <!-- ── Column actions sheet (Flutter parity) ────────────── -->
    <Modal
      v-if="columnActionsFor"
      :title="columnActionsFor.name"
      :subtitle="typeLabel(columnActionsFor.type)"
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
              <p class="text-[13px] font-bold text-slate-900">{{ t('tutor.sekolah.gradebook.actionViewDetail') }}</p>
              <p class="text-2xs text-slate-500">{{ t('tutor.sekolah.gradebook.actionViewDetailDesc') }}</p>
            </div>
            <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
          </button>
        </li>
        <li>
          <button
            type="button"
            class="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-amber-50 text-left"
            @click="openEditColumn"
          >
            <span class="w-9 h-9 rounded-lg bg-amber-100 text-amber-700 grid place-items-center flex-shrink-0">
              <NavIcon name="edit-3" :size="16" />
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">{{ t('tutor.sekolah.gradebook.actionEdit') }}</p>
              <p class="text-2xs text-slate-500">{{ t('tutor.sekolah.gradebook.actionEditDesc') }}</p>
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
              <p class="text-[13px] font-bold text-red-700">{{ t('tutor.sekolah.gradebook.actionDelete') }}</p>
              <p class="text-2xs text-slate-500">{{ t('tutor.sekolah.gradebook.actionDeleteDesc') }}</p>
            </div>
            <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
          </button>
        </li>
      </ul>
      <p class="mt-4 pt-3 border-t border-slate-100 text-2xs text-slate-400">
        {{ t('tutor.sekolah.gradebook.actionFooter') }}
      </p>
    </Modal>

    <!-- ── Column detail modal ──────────────────────────────── -->
    <Modal
      v-if="columnDetail"
      :title="columnDetail.name"
      :subtitle="t('tutor.sekolah.gradebook.detailSubtitle', { type: typeLabel(columnDetail.type) })"
      @close="columnDetail = null"
    >
      <div class="space-y-3">
        <div class="grid grid-cols-2 gap-2">
          <div class="bg-slate-50 rounded-xl p-3">
            <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">{{ t('tutor.sekolah.gradebook.detailType') }}</p>
            <p class="text-[14px] font-bold text-slate-900 mt-1">{{ typeLabel(columnDetail.type) }}</p>
          </div>
          <div class="bg-slate-50 rounded-xl p-3">
            <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">{{ t('tutor.sekolah.gradebook.detailDate') }}</p>
            <p class="text-[13px] font-bold text-slate-900 mt-1">{{ columnStats(columnDetail).dateLabel }}</p>
          </div>
        </div>
        <div class="grid grid-cols-3 gap-2">
          <div class="bg-brand-cobalt/5 rounded-xl p-3 text-center">
            <p class="text-3xs font-bold text-brand-cobalt uppercase tracking-widest">{{ t('tutor.sekolah.gradebook.detailStudents') }}</p>
            <p class="text-[18px] font-black text-brand-cobalt mt-0.5">{{ columnStats(columnDetail).total }}</p>
          </div>
          <div class="bg-emerald-50 rounded-xl p-3 text-center">
            <p class="text-3xs font-bold text-emerald-700 uppercase tracking-widest">{{ t('tutor.sekolah.gradebook.detailGraded') }}</p>
            <p class="text-[18px] font-black text-emerald-700 mt-0.5">{{ columnStats(columnDetail).graded }}</p>
          </div>
          <div class="bg-violet-50 rounded-xl p-3 text-center">
            <p class="text-3xs font-bold text-violet-700 uppercase tracking-widest">{{ t('tutor.sekolah.gradebook.detailAvg') }}</p>
            <p class="text-[18px] font-black text-violet-700 mt-0.5">{{ columnStats(columnDetail).avg ?? '—' }}</p>
          </div>
        </div>
        <div class="flex items-center justify-end pt-2">
          <Button variant="secondary" size="sm" @click="columnDetail = null">{{ t('tutor.sekolah.gradebook.detailClose') }}</Button>
        </div>
      </div>
    </Modal>

    <!-- ── Delete assessment confirm ────────────────────────── -->
    <Modal
      v-if="columnDeleteConfirm"
      :title="t('tutor.sekolah.gradebook.deleteTitle')"
      :subtitle="t('tutor.sekolah.gradebook.deleteSubtitle', { name: columnDeleteConfirm.name })"
      @close="!isDeletingColumn && (columnDeleteConfirm = null)"
    >
      <div class="space-y-3">
        <div class="bg-red-50 border border-red-100 rounded-xl px-3 py-2.5">
          <p class="text-[12px] text-red-700 leading-relaxed">
            <strong>{{ columnDeleteConfirm.name }}</strong>
            ·
            {{ typeLabel(columnDeleteConfirm.type) }}
            ·
            {{ t('tutor.sekolah.gradebook.deleteSummary', { graded: columnStats(columnDeleteConfirm).graded, total: columnStats(columnDeleteConfirm).total }) }}
          </p>
        </div>
        <div class="flex items-center justify-end gap-2 pt-1">
          <Button
            variant="secondary"
            size="sm"
            :disabled="isDeletingColumn"
            @click="columnDeleteConfirm = null"
          >
            {{ t('tutor.sekolah.gradebook.deleteCancel') }}
          </Button>
          <Button
            variant="primary"
            size="sm"
            :loading="isDeletingColumn"
            class="!bg-red-600 hover:!bg-red-700"
            @click="confirmDeleteColumn"
          >
            {{ t('tutor.sekolah.gradebook.deleteConfirm') }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- ── Tambah Asesmen modal (Flutter parity FAB flow) ───── -->
    <Modal
      v-if="showAddAsesmen"
      :title="t('tutor.sekolah.gradebook.addModalTitle')"
      :subtitle="t('tutor.sekolah.gradebook.addModalSubtitle')"
      @close="showAddAsesmen = false"
    >
      <form class="space-y-md" @submit.prevent="applyAddAsesmen">
        <div>
          <label
            class="block text-2xs font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.gradebook.addFieldType') }}
          </label>
          <SegmentedControl
            :model-value="addForm.type"
            :options="[
              { key: 'assignment', label: t('tutor.sekolah.gradebook.typeAssignment') },
              { key: 'daily_test', label: t('tutor.sekolah.gradebook.typeDailyTest') },
              { key: 'midterm', label: t('tutor.sekolah.gradebook.typeMidterm') },
              { key: 'final_exam', label: t('tutor.sekolah.gradebook.typeFinalExam') },
              { key: 'other', label: t('tutor.sekolah.gradebook.typeOther') },
            ]"
            size="sm"
            @update:model-value="(v) => (addForm.type = v as AssessmentType)"
          />
        </div>
        <div>
          <label
            class="block text-2xs font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.gradebook.addFieldTitle') }}
          </label>
          <input
            v-model="addForm.title"
            type="text"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :placeholder="t('tutor.sekolah.gradebook.addTitlePlaceholder')"
          />
          <p class="text-[10.5px] text-slate-400 mt-1">
            {{ t('tutor.sekolah.gradebook.addTitleHint', { label: typeLabel(addForm.type) }) }}
          </p>
        </div>
        <div>
          <label
            class="block text-2xs font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.gradebook.addFieldDate') }}
          </label>
          <input
            v-model="addForm.date"
            type="date"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
          />
        </div>
        <div class="bg-slate-50 border border-dashed border-slate-200 rounded-lg px-3 py-2 text-2xs text-slate-500">
          <NavIcon name="check-circle" :size="11" class="inline-block mr-1 -mt-0.5 text-brand-cobalt" />
          {{ t('tutor.sekolah.gradebook.addInfo') }}
        </div>
        <div class="flex items-center justify-end gap-2 pt-1">
          <Button
            variant="secondary"
            size="sm"
            @click="showAddAsesmen = false"
          >
            {{ t('tutor.sekolah.gradebook.addCancel') }}
          </Button>
          <Button variant="primary" size="sm" @click="applyAddAsesmen">
            {{ t('tutor.sekolah.gradebook.addSubmit') }}
          </Button>
        </div>
      </form>
    </Modal>

    <!-- ── Edit Asesmen modal (rename + details) ────────────── -->
    <Modal
      v-if="columnEditFor"
      :title="t('tutor.sekolah.gradebook.editModalTitle')"
      :subtitle="t('tutor.sekolah.gradebook.editModalSubtitle', { name: columnEditFor.name })"
      @close="!isSavingColumnEdit && (columnEditFor = null)"
    >
      <form class="space-y-md" @submit.prevent="applyEditColumn">
        <div>
          <label
            class="block text-2xs font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.gradebook.addFieldType') }}
          </label>
          <SegmentedControl
            :model-value="editForm.type"
            :options="[
              { key: 'assignment', label: t('tutor.sekolah.gradebook.typeAssignment') },
              { key: 'daily_test', label: t('tutor.sekolah.gradebook.typeDailyTest') },
              { key: 'midterm', label: t('tutor.sekolah.gradebook.typeMidterm') },
              { key: 'final_exam', label: t('tutor.sekolah.gradebook.typeFinalExam') },
              { key: 'other', label: t('tutor.sekolah.gradebook.typeOther') },
            ]"
            size="sm"
            @update:model-value="(v) => (editForm.type = v as AssessmentType)"
          />
        </div>
        <div>
          <label
            class="block text-2xs font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.gradebook.addFieldTitle') }}
          </label>
          <input
            v-model="editForm.title"
            type="text"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :placeholder="t('tutor.sekolah.gradebook.addTitlePlaceholder')"
          />
          <p class="text-[10.5px] text-slate-400 mt-1">
            {{ t('tutor.sekolah.gradebook.addTitleHint', { label: typeLabel(editForm.type) }) }}
          </p>
        </div>
        <div>
          <label
            class="block text-2xs font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.gradebook.addFieldDate') }}
          </label>
          <input
            v-model="editForm.date"
            type="date"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
          />
        </div>
        <div class="bg-amber-50 border border-dashed border-amber-200 rounded-lg px-3 py-2 text-2xs text-amber-700">
          <NavIcon name="edit-3" :size="11" class="inline-block mr-1 -mt-0.5" />
          {{ t('tutor.sekolah.gradebook.editInfo') }}
        </div>
        <div class="flex items-center justify-end gap-2 pt-1">
          <Button
            variant="secondary"
            size="sm"
            :disabled="isSavingColumnEdit"
            @click="columnEditFor = null"
          >
            {{ t('tutor.sekolah.gradebook.editCancel') }}
          </Button>
          <Button
            variant="primary"
            size="sm"
            :loading="isSavingColumnEdit"
            @click="applyEditColumn"
          >
            {{ t('tutor.sekolah.gradebook.editSubmit') }}
          </Button>
        </div>
      </form>
    </Modal>

    <!-- ── Picker modals ────────────────────────────────────── -->
    <Modal
      v-if="showClassPicker"
      :title="t('tutor.sekolah.gradebook.pickClassTitle')"
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
            {{ t('tutor.sekolah.gradebook.allClasses') }}
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
            <span class="text-3xs text-slate-400">
              {{ t('tutor.sekolah.gradebook.pickClassStudents', { count: c.student_count }) }}
            </span>
          </button>
        </li>
      </ul>
    </Modal>

    <Modal
      v-if="showSubjectPicker"
      :title="t('tutor.sekolah.gradebook.pickSubjectTitle')"
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
            {{ t('tutor.sekolah.gradebook.allSubjects') }}
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
            <span v-if="s.code" class="text-3xs text-slate-400">{{
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

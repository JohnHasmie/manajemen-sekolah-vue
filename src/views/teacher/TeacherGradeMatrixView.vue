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
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { GradeService } from '@/services/grades.service';
import { localISODate } from '@/lib/format';
import type {
  Assessment,
  AssessmentType,
  GradeMatrix,
} from '@/types/grades';
import { ASSESSMENT_LABELS } from '@/types/grades';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const auth = useAuthStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

// URL-driven mode. The gradebook has two visual modes — a summary
// grid of subject-class cards and a matrix of scores drilled into
// one card — and they now share the same view. Parity with the
// grade-recap pair (list + `:classId/:subjectId` detail): if the
// route carries classId + subjectId, the matrix renders; otherwise
// the summary grid renders. Browser back, deep-link, and refresh
// all behave the way teachers expect because the state is in the
// URL, not just in memory.
const matrixClassIdFromRoute = computed(
  () => (route.params.classId as string | undefined) ?? '',
);
const matrixSubjectIdFromRoute = computed(
  () => (route.params.subjectId as string | undefined) ?? '',
);

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

// ── Role hint ──
// Matrix hydration needs to know whether the caller is a homeroom
// teacher (wali) or a subject teacher — the summary endpoint's
// `view` parameter is what tells the backend which lens to return.
// This view has no role toggle (the list view is where the user
// picks); if a hint is on the URL later we can lift it from
// route.query. Default 'mengajar' matches the list view's default.
const selectedRoleId = ref<string>('mengajar');
const isWaliMode = computed(() => selectedRoleId.value.startsWith('wali:'));

// Semester filter — internal; not surfaced on this view. The list
// view exposes a picker; the matrix inherits the same default.
const semester = ref<string>('genap');

// ── Matrix state (this view IS the matrix) ──
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

// The list-only summary computeds (flatCards/filteredCards/
// summaryState/summaryKpi/activeClass/activeSubject) live in
// TeacherGradeBookView.vue since they only ever drive the list grid.
// This view's `matrixSummary` computed further down derives the
// header stats for the matrix alone.

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
  await hydrateFromRoute();
  window.addEventListener('keydown', onWindowKeydown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', onWindowKeydown);
  if (autosaveTimer.value) clearTimeout(autosaveTimer.value);
});

useAcademicYearWatcher(() => loadMatrix());

// Route params changing while the view is mounted (in-app nav from
// one matrix to another) — re-hydrate.
watch(
  [matrixClassIdFromRoute, matrixSubjectIdFromRoute],
  hydrateFromRoute,
);

// ── Route-driven hydration ──
// The matrix view has classId + subjectId (+ optional teacherId for
// admin) in the URL. To render, we still need the class + subject
// NAMES and the per-assessment seed (so columns render before any
// grade rows exist). Fetch summary once to find the matching card,
// then fetch matrix. Two calls, but the summary is cheap and
// skipping it means the header shows a raw UUID instead of
// "B. Arab · 7A".
async function hydrateFromRoute() {
  const classId = matrixClassIdFromRoute.value;
  const subjectId = matrixSubjectIdFromRoute.value;
  if (!classId || !subjectId) {
    exitToList();
    return;
  }
  const teacherId = effectiveTeacherId.value;
  if (!teacherId) {
    matrixError.value = 'Missing teacher id — cannot hydrate matrix.';
    return;
  }
  isMatrixLoading.value = true;
  matrixError.value = null;
  try {
    const summaryRes = await GradeService.getTeacherSummary({
      teacher_id: teacherId,
      view: isWaliMode.value ? 'homeroom_teacher' : 'teaching',
    });
    // Flatten (class × subject) the same way TeacherGradeBookView's
    // flatCards computed does. Mirror is deliberate — keeping the
    // matrix hydration close to the list's shape means the seed
    // fields (id, raw_title, type, label) map 1:1.
    let matchedCard: {
      class_id: string;
      class_name: string;
      subject: {
        id: string;
        name: string;
        assessments: Array<{
          id: string;
          label: string;
          raw_title: string | null | undefined;
          type: AssessmentType;
        }>;
      };
    } | null = null;
    for (const c of summaryRes) {
      for (const s of c.subjects) {
        if (c.class_id === classId && s.id === subjectId) {
          matchedCard = {
            class_id: c.class_id,
            class_name: c.class_name,
            subject: {
              id: s.id,
              name: s.name,
              assessments: s.assessments.map((a) => ({
                id: a.id,
                label: a.label,
                raw_title: a.raw_title,
                type: a.type,
              })),
            },
          };
          break;
        }
      }
      if (matchedCard) break;
    }
    if (!matchedCard) {
      // Bad deep-link / stale bookmark / teacher no longer teaches
      // this subject. Bail to list — safer than a dedicated 404
      // for an internal tool.
      exitToList();
      return;
    }
    matrixClass.value = {
      id: matchedCard.class_id,
      name: matchedCard.class_name,
    };
    matrixSubject.value = {
      id: matchedCard.subject.id,
      name: matchedCard.subject.name,
    };
    matrixAssessmentSeed.value = matchedCard.subject.assessments.map((a) => ({
      id: a.id,
      name: a.label,
      raw_title: a.raw_title,
      type: a.type,
    }));
    await loadMatrix();
  } catch (e) {
    matrixError.value = (e as Error).message;
    isMatrixLoading.value = false;
  }
}

// Exit to whichever list-route we came from. Admin exits to
// admin.grades.teacher (the same view in list mode), teacher exits
// to teacher.grades. Query preserved so ?ay= / admin flags follow.
function exitToList() {
  if (isAdminView.value) {
    router.push({
      name: 'admin.grades.teacher',
      params: { teacherId: routeTeacherId.value },
      query: route.query,
    });
    return;
  }
  router.push({
    name: 'teacher.grades',
    query: route.query,
  });
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
  } else if (e.key === 'Escape') {
    // Only escape out when no input is focused.
    const t = document.activeElement;
    if (!t || (t.tagName !== 'INPUT' && t.tagName !== 'TEXTAREA')) {
      exitToList();
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
    // Re-hydrate the seed + matrix — mirrors the assessment CRUD
    // reconcile order from before the split (summary first so the
    // seed picks up any new/renamed columns, then matrix). Single
    // call now that hydrateFromRoute() encapsulates both.
    await hydrateFromRoute();
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
    // Re-hydrate the seed + matrix — mirrors the assessment CRUD
    // reconcile order from before the split (summary first so the
    // seed picks up any new/renamed columns, then matrix). Single
    // call now that hydrateFromRoute() encapsulates both.
    await hydrateFromRoute();
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
    // Re-hydrate the seed + matrix. Summary FIRST so the seed picks
    // up backend-assigned ids from this save; without that, the
    // matrix could merge stale seed columns with new entry-derived
    // ones and surface a phantom duplicate.
    await hydrateFromRoute();
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

// Localized label for an assessment type. Mirrors `ASSESSMENT_LABELS`
// from `@/types/grades` but routes through i18n so the modals + toasts
// in this view follow the active locale instead of surfacing the
// canonical Indonesian fallbacks.
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
    <!-- ── 1. Header ─────────────────────────────────────────
         This view IS the matrix — the header always shows the
         drilled-in class/subject + a Kembali button. The sibling
         TeacherGradeBookView owns the list-mode header. -->
    <BrandPageHeader
      role="guru"
      :kicker="t('tutor.sekolah.gradebook.kickerMatrix')"
      :title="matrixSubject && matrixClass
        ? `${matrixSubject.name} · ${matrixClass.name}`
        : t('tutor.sekolah.gradebook.titleSummary')"
      :meta="t('tutor.sekolah.gradebook.metaMatrix', {
        kkm: matrix.kkm,
        students: matrix.rows.length,
        assessments: visibleAssessments.length,
      })"
      :live-dot="false"
    >
      <button
        type="button"
        class="px-3 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 border border-white/25 text-white text-[12px] font-bold inline-flex items-center gap-1.5"
        @click="exitToList"
      >
        <NavIcon name="chevron-left" :size="13" />
        {{ t('tutor.sekolah.gradebook.backToList') }}
      </button>
    </BrandPageHeader>

    <!-- ════════════════════════════════════════════════════════
         MATRIX MODE — editable students × assessments grid.
         List-mode template lives in the sibling TeacherGradeBookView.
         ════════════════════════════════════════════════════════ -->
    <template>
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

    <!-- List-mode picker modals live in TeacherGradeBookView. -->

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>

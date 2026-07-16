<!--
  TeacherGradeRecapDetailView.vue — editable recap matrix (Bab × Student).

  Web port of Flutter's `teacher_grade_recap_screen.dart` step 2
  (table mode) + `grade_recap_table_view.dart`.

  Layout:
    BrandPageHeader (back chip · class+subject meta)
    → KPI strip (Student · Bab · Rerata · Kelengkapan)
    → Toolbar (Search + Tambah Bab + Export)
    → Frozen-left matrix:
        [#  Nama]  | Bab 1  Bab 2 ... | UTS | UAS | Final | Skill | Grade | Desk.
    → Floating save bar when any cell is dirty

  Editable cells:
    - bab_scores[i], uts, uas, skill_score, predikat — inline inputs
    - deskripsi — click cell to open textarea modal (matches Flutter)

  final_score is read-only: backend computes the per-row "effective
  final" as `COALESCE(final_score, avg(bab_scores))` for display, so
  we only persist final_score when the teacher explicitly overrides.
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useAuthStore } from '@/stores/auth';
import { GradeRecapService } from '@/services/grade-recap.service';
import type {
  GradeRecapRow,
  GradeRecapSavePayload,
} from '@/types/grade-recap';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import GradeRecapSourcePickerModal, {
  type RecapColumnKind,
} from '@/components/feature/GradeRecapSourcePickerModal.vue';
import LinkMasterBanner from '@/components/feature/LinkMasterBanner.vue';

const route = useRoute();
const router = useRouter();
const ay = useAcademicYearStore();
const auth = useAuthStore();
const { t } = useI18n();

const classId = computed(() => String(route.params.classId ?? ''));
const subjectId = computed(() => String(route.params.subjectId ?? ''));
const className = computed(() => String(route.query.className ?? '-'));
const subjectName = computed(() => String(route.query.subjectName ?? '-'));

// ── State ──
const rows = ref<GradeRecapRow[]>([]);
const chapters = ref<string[]>([]); // chapter display names indexed 0..N-1
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const isSaving = ref(false);

const searchQuery = ref('');
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// Per-row dirty flag — flipped whenever any cell in that row changes.
// We push all dirty rows in one `/grade-recaps/batch` call on save.
const dirtyByRow = ref<Map<string, boolean>>(new Map());

// Deskripsi modal — Flutter opens a sheet because the cell is too
// short to type a paragraph into.
const editDesc = ref<{
  row: GradeRecapRow;
  draft: string;
} | null>(null);

// Add / rename / delete chapter modals
const showAddChapter = ref(false);
const addChapterDraft = ref('');
// Slack 1783643111 — Luay Prio Medium 2026-07-10: "add nilai belum
// ada pilihan untuk mengambil dari nilai [existing]". Toggle inside
// the Add Chapter modal — when true, `confirmAddChapter` opens the
// existing `GradeRecapSourcePickerModal` for the freshly-added bab
// column so the teacher can prefill scores from a gradebook
// assessment in one flow instead of add → then remember to open
// picker manually.
const addChapterFromExisting = ref(false);
const renameChapter = ref<{ index: number; draft: string } | null>(null);
const deleteChapter = ref<{ index: number } | null>(null);

// Source-picker modal (web port of Flutter's column_source_picker_sheet).
// `column` is the logical recap column the chosen assessment fills;
// `babIndex` is set only for Bab columns so we know which chapter slot
// to write into. `label` drives the modal header text.
const sourcePicker = ref<{
  column: RecapColumnKind;
  babIndex: number | null;
  label: string;
} | null>(null);

function openSourcePicker(
  column: RecapColumnKind,
  label: string,
  babIndex: number | null = null,
) {
  sourcePicker.value = { column, babIndex, label };
}

// ── Loaders ──
async function load() {
  if (!classId.value || !subjectId.value) {
    loadError.value = t('tutor.sekolah.gradeRecapDetail.incompleteParams');
    isLoading.value = false;
    return;
  }
  const yearId = ay.selectedYearId;
  if (!yearId) {
    loadError.value = t('tutor.sekolah.gradeRecapDetail.noAcademicYear');
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await GradeRecapService.listMatrix({
      class_id: classId.value,
      subject_id: subjectId.value,
      academic_year_id: Number(yearId),
    });
    rows.value = res;
    chapters.value = deriveChapters(res);
    // Pad each row's bab_scores up to chapters.length so v-model
    // can bind by index without per-cell undefined checks.
    for (const r of rows.value) {
      const padded: (number | null)[] = [];
      for (let i = 0; i < chapters.value.length; i++) {
        const existing = r.chapter_scores?.[i];
        padded.push(typeof existing === 'number' ? existing : null);
      }
      r.chapter_scores = padded;
      if (!r.chapter_names) r.chapter_names = chapters.value.slice();
    }
    dirtyByRow.value = new Map();
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

function deriveChapters(matrix: GradeRecapRow[]): string[] {
  // Union: walk every row and collect the widest bab_names + bab_scores
  // length. Falls back to `Bab N` when names are missing.
  let maxLen = 0;
  let referenceNames: string[] | null = null;
  for (const r of matrix) {
    const len = Math.max(r.chapter_scores?.length ?? 0, r.chapter_names?.length ?? 0);
    if (len > maxLen) maxLen = len;
    if (
      r.chapter_names &&
      r.chapter_names.length >= maxLen &&
      r.chapter_names.some((n) => n.trim().length > 0)
    ) {
      referenceNames = r.chapter_names;
    }
  }
  if (maxLen === 0) maxLen = 1; // always render at least one Bab column
  const out: string[] = [];
  for (let i = 0; i < maxLen; i++) {
    const name = referenceNames?.[i]?.trim();
    out.push(name && name.length > 0 ? name : t('tutor.sekolah.gradeRecapDetail.chapterFallback', { n: i + 1 }));
  }
  return out;
}

onMounted(load);

// ── Derived ──
const filteredRows = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return rows.value;
  return rows.value.filter(
    (r) =>
      r.student_name.toLowerCase().includes(q) ||
      (r.nis ?? '').toLowerCase().includes(q),
  );
});

const matrixState = computed<AsyncState<GradeRecapRow[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (filteredRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredRows.value };
});

const dirtyCount = computed(() => dirtyByRow.value.size);
const hasUnsavedChanges = computed(() => dirtyCount.value > 0);

// Effective final per row: prefers stored `final_score`, falls back
// to avg of numeric bab_scores. Mirrors backend's
// `COALESCE(final_score, avg(bab_scores))` so the display matches
// the overview KPI without a second roundtrip.
function effectiveFinal(r: GradeRecapRow): number | null {
  if (typeof r.final_score === 'number') return r.final_score;
  const arr = (r.chapter_scores ?? []).filter(
    (v): v is number => typeof v === 'number',
  );
  if (arr.length === 0) return null;
  return Math.round((arr.reduce((s, v) => s + v, 0) / arr.length) * 10) / 10;
}

const kpiCards = computed<KpiCard[]>(() => {
  const totalStudents = rows.value.length;
  let filled = 0;
  let scoreSum = 0;
  let scoreCount = 0;
  for (const r of rows.value) {
    const final = effectiveFinal(r);
    if (
      final !== null ||
      typeof r.midterm_score === 'number' ||
      typeof r.final_exam_score === 'number' ||
      (r.chapter_scores ?? []).some((v) => typeof v === 'number')
    ) {
      filled += 1;
    }
    if (final !== null) {
      scoreSum += final;
      scoreCount += 1;
    }
  }
  const completion =
    totalStudents > 0 ? Math.round((filled / totalStudents) * 100) : 0;
  return [
    {
      icon: 'users',
      label: t('tutor.sekolah.gradeRecapDetail.kpiStudents'),
      value: totalStudents,
      tone: 'brand',
    },
    {
      icon: 'book-open',
      label: t('tutor.sekolah.gradeRecapDetail.kpiChapters'),
      value: chapters.value.length,
      tone: 'violet',
    },
    {
      icon: 'bar-chart',
      label: t('tutor.sekolah.gradeRecapDetail.kpiAverage'),
      value: scoreCount
        ? Math.round((scoreSum / scoreCount) * 10) / 10
        : '—',
      tone: 'green',
      accented: true,
    },
    {
      icon: 'check-circle',
      label: t('tutor.sekolah.gradeRecapDetail.kpiCompleteness'),
      value: completion,
      suffix: '%',
      tone: completion >= 80 ? 'green' : completion >= 40 ? 'amber' : 'red',
    },
  ];
});

// ── Editing helpers ──
//
// Score inputs return string from <input type=number>. We coerce
// here so the row's typed fields stay clean and dirty tracking
// only fires when the value actually differs.

function markDirty(rowId: string) {
  dirtyByRow.value.set(rowId, true);
  // trigger Map reactivity
  dirtyByRow.value = new Map(dirtyByRow.value);
}

function parseScore(input: string): number | null {
  if (input === '' || input == null) return null;
  const n = Number(input);
  if (!Number.isFinite(n)) return null;
  return Math.max(0, Math.min(100, n));
}

function onBabInput(r: GradeRecapRow, i: number, raw: string) {
  const next = parseScore(raw);
  const prev = r.chapter_scores?.[i] ?? null;
  if (next === prev) return;
  if (!r.chapter_scores) r.chapter_scores = [];
  r.chapter_scores[i] = next;
  markDirty(r.student_class_id);
}

function onScoreInput(
  r: GradeRecapRow,
  field: 'midterm_score' | 'final_exam_score' | 'skill_score' | 'final_score',
  raw: string,
) {
  const next = parseScore(raw);
  if (r[field] === next) return;
  r[field] = next;
  markDirty(r.student_class_id);
}

function onPredikatInput(r: GradeRecapRow, raw: string) {
  const next = raw.trim().slice(0, 3) || null;
  if (r.predicate === next) return;
  r.predicate = next;
  markDirty(r.student_class_id);
}

function openDescEditor(r: GradeRecapRow) {
  editDesc.value = { row: r, draft: r.description ?? '' };
}

function saveDescEdit() {
  if (!editDesc.value) return;
  const { row, draft } = editDesc.value;
  const next = draft.trim() || null;
  if (row.description !== next) {
    row.description = next;
    markDirty(row.student_class_id);
  }
  editDesc.value = null;
}

// ── Chapter ops ──
function openAddChapter() {
  addChapterDraft.value = `Bab ${chapters.value.length + 1}`;
  addChapterFromExisting.value = false;
  showAddChapter.value = true;
}

function confirmAddChapter() {
  const name = addChapterDraft.value.trim();
  if (!name) return;
  chapters.value.push(name);
  // Extend every row's bab_scores + bab_names so v-model index lookups
  // stay safe. We DON'T mark the rows dirty — they'll only be saved
  // when the teacher actually inputs a score.
  for (const r of rows.value) {
    if (!r.chapter_scores) r.chapter_scores = [];
    if (!r.chapter_names) r.chapter_names = [];
    r.chapter_scores.push(null);
    r.chapter_names.push(name);
  }
  const newIndex = chapters.value.length - 1;
  const shouldPrefill = addChapterFromExisting.value;
  showAddChapter.value = false;
  toast.value = { message: t('tutor.sekolah.gradeRecapDetail.chapterAddedToast'), tone: 'success' };
  // Chain into the source picker when the teacher opted in — same
  // modal every existing column uses, just seeded with the new bab
  // name + index (Slack 1783643111).
  if (shouldPrefill) {
    openSourcePicker('bab', name, newIndex);
  }
}

function openRenameChapter(index: number) {
  renameChapter.value = { index, draft: chapters.value[index] ?? '' };
}

function confirmRenameChapter() {
  if (!renameChapter.value) return;
  const { index, draft } = renameChapter.value;
  const name = draft.trim();
  if (!name || name === chapters.value[index]) {
    renameChapter.value = null;
    return;
  }
  chapters.value[index] = name;
  // Mark every row dirty so the new chapter name propagates on save.
  for (const r of rows.value) {
    if (!r.chapter_names) r.chapter_names = chapters.value.slice();
    r.chapter_names[index] = name;
    markDirty(r.student_class_id);
  }
  renameChapter.value = null;
  toast.value = { message: t('tutor.sekolah.gradeRecapDetail.chapterRenamedToast'), tone: 'success' };
}

function openDeleteChapter(index: number) {
  if (chapters.value.length <= 1) {
    toast.value = {
      message: t('tutor.sekolah.gradeRecapDetail.minOneChapterToast'),
      tone: 'error',
    };
    return;
  }
  deleteChapter.value = { index };
}

function confirmDeleteChapter() {
  if (!deleteChapter.value) return;
  const { index } = deleteChapter.value;
  chapters.value.splice(index, 1);
  for (const r of rows.value) {
    r.chapter_scores?.splice(index, 1);
    r.chapter_names?.splice(index, 1);
    markDirty(r.student_class_id);
  }
  deleteChapter.value = null;
  toast.value = { message: t('tutor.sekolah.gradeRecapDetail.chapterDeletedToast'), tone: 'success' };
}

// ── Source picker (pull column values from Gradebook) ──
//
// Web port of Flutter's `_showFixedColumnSourcePicker`: the modal
// resolves a `student_id → score` map (or null for "Input Manual") and
// hands it back here. We write each row's matching score into the
// target column, blanking rows the map doesn't cover, then mark every
// row dirty so the floating Save bar persists the pull on the next
// `/grade-recaps/batch`.
function applySource(payload: {
  scoresByStudentId: Map<string, number> | null;
}) {
  const picker = sourcePicker.value;
  if (!picker) return;
  const { column, babIndex } = picker;
  const map = payload.scoresByStudentId;

  for (const r of rows.value) {
    const pulled = map?.get(r.student_id) ?? null;
    switch (column) {
      case 'midterm':
        r.midterm_score = pulled;
        break;
      case 'final_exam':
        r.final_exam_score = pulled;
        break;
      case 'skill':
        r.skill_score = pulled;
        break;
      case 'bab':
        if (babIndex !== null) {
          if (!r.chapter_scores) r.chapter_scores = [];
          r.chapter_scores[babIndex] = pulled;
        }
        break;
    }
    markDirty(r.student_class_id);
  }

  const filledCount = map ? map.size : 0;
  sourcePicker.value = null;
  toast.value = {
    message: map
      ? t('tutor.sekolah.gradeRecapDetail.sourceAppliedToast', { label: picker.label, count: filledCount })
      : t('tutor.sekolah.gradeRecapDetail.sourceClearedToast', { label: picker.label }),
    tone: 'success',
  };
}

// ── Save ──
async function save() {
  if (isSaving.value) return;
  const yearId = ay.selectedYearId;
  if (!yearId) {
    toast.value = { message: t('tutor.sekolah.gradeRecapDetail.noAcademicYear'), tone: 'error' };
    return;
  }
  const dirtyIds = Array.from(dirtyByRow.value.keys());
  if (dirtyIds.length === 0) return;

  isSaving.value = true;
  try {
    const payloads: GradeRecapSavePayload[] = rows.value
      .filter((r) => dirtyByRow.value.get(r.student_class_id))
      .map((r) => ({
        student_class_id: r.student_class_id,
        subject_id: subjectId.value,
        academic_year_id: Number(yearId),
        predicate: r.predicate,
        description: r.description,
        final_score: r.final_score,
        skill_score: r.skill_score,
        chapter_scores: r.chapter_scores,
        chapter_names: r.chapter_names ?? chapters.value.slice(),
        midterm_score: r.midterm_score,
        final_exam_score: r.final_exam_score,
      }));
    const resp = await GradeRecapService.saveBatch(payloads);
    if (resp.success === false) {
      toast.value = {
        message: resp.error ?? t('tutor.sekolah.gradeRecapDetail.saveFailedToast'),
        tone: 'error',
      };
      return;
    }
    dirtyByRow.value = new Map();
    toast.value = {
      message: t('tutor.sekolah.gradeRecapDetail.savedRowsToast', { count: resp.saved ?? payloads.length }),
      tone: 'success',
    };
    // Refresh from server so server-computed final_score (and any
    // backend defaults like predikat normalization) appear.
    await load();
  } catch (e) {
    toast.value = {
      message: (e as Error).message,
      tone: 'error',
    };
  } finally {
    isSaving.value = false;
  }
}

// ── Export Excel ──
//
// Backend (`RekapNilaiExport`) reads fields with Indonesian-Flutter
// names (`nis`, `nama`, `uts`, `uas`, `final_score`, `skill_score`,
// `predikat`, `deskripsi`, `bab_scores`) and treats each chapter
// entry as an object with `judul_bab`/`judul`/`title`. Vue rows
// use English-ish names (`student_name`, `uts_score`, `uas_score`),
// so we remap before POSTing so headings + rows render correctly.
async function exportExcel() {
  try {
    const remappedRows = rows.value.map((r) => ({
      nis: r.nis ?? '-',
      nama: r.student_name,
      bab_scores: r.chapter_scores ?? [],
      uts: r.midterm_score,
      uas: r.final_exam_score,
      final_score: r.final_score ?? effectiveFinal(r),
      skill_score: r.skill_score,
      predikat: r.predicate ?? '',
      deskripsi: r.description ?? '',
    })) as unknown as typeof rows.value;
    const remappedChapters = chapters.value.map((name) => ({
      judul_bab: name,
    })) as unknown as string[];
    const blob = await GradeRecapService.exportExcel({
      tableData: remappedRows,
      chapters: remappedChapters,
      className: className.value,
      subjectName: subjectName.value,
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    const safe = `${className.value}_${subjectName.value}`.replace(
      /[^A-Za-z0-9_-]/g,
      '_',
    );
    a.download = `rekap_${safe}_${new Date().toISOString().slice(0, 10)}.xlsx`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  } catch (e) {
    toast.value = {
      message: t('tutor.sekolah.gradeRecapDetail.exportFailedToast', { error: (e as Error).message }),
      tone: 'error',
    };
  }
}

// ── Unsaved-changes guards ──
function beforeUnloadGuard(e: BeforeUnloadEvent) {
  if (hasUnsavedChanges.value) {
    e.preventDefault();
    e.returnValue = '';
  }
}

onMounted(() => window.addEventListener('beforeunload', beforeUnloadGuard));
onBeforeUnmount(() =>
  window.removeEventListener('beforeunload', beforeUnloadGuard),
);

// Unsaved-changes guard for in-app navigation. Vue Router's navigation
// guard is synchronous, but we want the friendly ConfirmationDialog
// rather than the browser's native confirm(). Pattern: cancel the
// navigation immediately, stash `next` in a ref, and let the modal's
// Confirm/Close handlers call next(true)/next(false) once the teacher
// answers.
const pendingNav = ref<{
  open: boolean;
  next: ((to?: boolean) => void) | null;
}>({ open: false, next: null });

onBeforeRouteLeave((_to, _from, next) => {
  if (!hasUnsavedChanges.value) return next();
  pendingNav.value = { open: true, next };
});

function confirmNavLeave() {
  const cb = pendingNav.value.next;
  pendingNav.value = { open: false, next: null };
  if (cb) cb(true);
}

function cancelNavLeave() {
  const cb = pendingNav.value.next;
  pendingNav.value = { open: false, next: null };
  if (cb) cb(false);
}

function backToOverview() {
  // useAuth state, no real reason to dirty-block on the back chip
  // since onBeforeRouteLeave will catch it.
  router.push({ name: 'teacher.grade-recap' });
}

// Track which row's predikat input is focused so we can show a
// small popover with quick A/B/C/D presets — keeps the cell tiny
// but still scannable.
const focusedPredikatRow = ref<string | null>(null);
const PREDIKAT_OPTIONS = ['A', 'B', 'C', 'D', 'E'];

function setPredikatPreset(r: GradeRecapRow, val: string) {
  if (r.predicate !== val) {
    r.predicate = val;
    markDirty(r.student_class_id);
  }
  focusedPredikatRow.value = null;
}

// Delay so a click on the popover preset button registers before
// the input's blur tears it down.
function onPredikatBlur(rowId: string) {
  window.setTimeout(() => {
    if (focusedPredikatRow.value === rowId) focusedPredikatRow.value = null;
  }, 150);
}
</script>

<template>
  <div class="space-y-4 pb-32 relative">
    <!-- HEADER -->
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutor.sekolah.gradeRecapDetail.kicker')"
      :title="`${subjectName} · ${className}`"
      :meta="t('tutor.sekolah.gradeRecapDetail.meta', { students: rows.length, chapters: chapters.length })"
      :live-dot="false"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1 rounded-full bg-white/15 hover:bg-white/25 text-white px-3 py-1.5 text-[12px] font-bold"
        @click="backToOverview"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('tutor.sekolah.gradeRecapDetail.back') }}
      </button>
    </BrandPageHeader>

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" :loading="isLoading" />

    <!--
      Warning banner: if this subject_schools row isn't linked to a
      master curriculum subject, admins/guru see an inline nudge with
      a one-click "Tautkan Sekarang" flow. The matrix still renders
      (score entry works either way) — the banner just surfaces that
      chapter labels will land on ad-hoc names until the link exists.
      When the link is saved we re-fetch the matrix so the recap
      picks up any master-derived chapter defaults.
    -->
    <LinkMasterBanner
      v-if="subjectId"
      :subject-id="subjectId"
      context="grade-recap"
      @linked="load"
    />

    <!-- TOOLBAR -->
    <div class="bg-white border border-slate-200 rounded-2xl p-3 flex items-center gap-2 flex-wrap">
      <div class="relative flex-1 min-w-[200px]">
        <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400">
          <NavIcon name="search" :size="14" />
        </span>
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="t('tutor.sekolah.gradeRecapDetail.searchPlaceholder')"
          class="w-full pl-9 pr-3 py-2 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-brand-cobalt"
        />
      </div>
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl border border-brand-cobalt text-brand-cobalt text-[12px] font-bold hover:bg-brand-cobalt/5"
        @click="openAddChapter"
      >
        <NavIcon name="plus" :size="14" />
        {{ t('tutor.sekolah.gradeRecapDetail.addChapter') }}
      </button>
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 text-slate-700 text-[12px] font-bold hover:bg-slate-50"
        @click="exportExcel"
      >
        <NavIcon name="download" :size="14" />
        {{ t('tutor.sekolah.gradeRecapDetail.export') }}
      </button>
    </div>

    <!-- MATRIX -->
    <AsyncView
      :state="matrixState"
      :empty-title="t('tutor.sekolah.gradeRecapDetail.emptyTitle')"
      :empty-description="t('tutor.sekolah.gradeRecapDetail.emptyDescription')"
      empty-icon="users"
    >
      <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <div class="overflow-x-auto">
          <table class="text-[12px] min-w-full border-separate border-spacing-0">
            <thead>
              <tr class="bg-brand-cobalt text-white">
                <th
                  class="sticky left-0 z-20 bg-brand-cobalt text-left font-bold px-3 py-2.5 border-r border-white/10 min-w-[180px]"
                >
                  {{ t('tutor.sekolah.gradeRecapDetail.colStudent') }}
                </th>
                <th
                  v-for="(name, i) in chapters"
                  :key="`bab-${i}`"
                  class="px-2 py-2.5 text-center font-bold border-r border-white/10 min-w-[90px] cursor-pointer hover:bg-brand-cobalt/80 group"
                  @click="openRenameChapter(i)"
                  @contextmenu.prevent="openDeleteChapter(i)"
                  :title="`Klik untuk rename · Klik kanan untuk hapus`"
                >
                  <div class="flex items-center justify-center gap-1">
                    <span class="truncate max-w-[80px]">{{ name }}</span>
                    <button
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-white/80 hover:text-white transition"
                      @click.stop="openSourcePicker('bab', name, i)"
                      :title="`Ambil nilai ${name} dari Buku Nilai`"
                    >
                      <NavIcon name="database" :size="11" />
                    </button>
                    <button
                      v-if="chapters.length > 1"
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-white/80 hover:text-white transition"
                      @click.stop="openDeleteChapter(i)"
                      :title="`Hapus ${name}`"
                    >
                      <NavIcon name="x" :size="11" />
                    </button>
                  </div>
                </th>
                <th class="px-2 py-2.5 text-center font-bold border-r border-white/10 min-w-[80px] group">
                  <div class="flex items-center justify-center gap-1">
                    <span>UTS</span>
                    <button
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-white/80 hover:text-white transition"
                      @click.stop="openSourcePicker('midterm', 'UTS')"
                      title="Ambil nilai UTS dari Buku Nilai"
                    >
                      <NavIcon name="database" :size="11" />
                    </button>
                  </div>
                </th>
                <th class="px-2 py-2.5 text-center font-bold border-r border-white/10 min-w-[80px] group">
                  <div class="flex items-center justify-center gap-1">
                    <span>UAS</span>
                    <button
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-white/80 hover:text-white transition"
                      @click.stop="openSourcePicker('final_exam', 'UAS')"
                      title="Ambil nilai UAS dari Buku Nilai"
                    >
                      <NavIcon name="database" :size="11" />
                    </button>
                  </div>
                </th>
                <th class="px-2 py-2.5 text-center font-bold border-r border-white/10 min-w-[70px] bg-brand-cobalt/90">
                  {{ t('tutor.sekolah.gradeRecapDetail.colFinal') }}
                </th>
                <th class="px-2 py-2.5 text-center font-bold border-r border-white/10 min-w-[80px] group">
                  <div class="flex items-center justify-center gap-1">
                    <span>Skill</span>
                    <button
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-white/80 hover:text-white transition"
                      @click.stop="openSourcePicker('skill', 'Skill')"
                      title="Ambil nilai Skill dari Buku Nilai"
                    >
                      <NavIcon name="database" :size="11" />
                    </button>
                  </div>
                </th>
                <th class="px-2 py-2.5 text-center font-bold border-r border-white/10 min-w-[60px]">
                  {{ t('tutor.sekolah.gradeRecapDetail.colPredicate') }}
                </th>
                <th class="px-2 py-2.5 text-center font-bold min-w-[150px]">
                  {{ t('tutor.sekolah.gradeRecapDetail.colDescription') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(r, idx) in filteredRows"
                :key="r.student_class_id"
                class="border-b border-slate-100"
                :class="
                  dirtyByRow.get(r.student_class_id)
                    ? 'bg-amber-50/40'
                    : idx % 2
                      ? 'bg-slate-50/40'
                      : 'bg-white'
                "
              >
                <td
                  class="sticky left-0 z-10 px-3 py-2 border-r border-slate-200 min-w-[180px]"
                  :class="
                    dirtyByRow.get(r.student_class_id)
                      ? 'bg-amber-50'
                      : idx % 2
                        ? 'bg-slate-50'
                        : 'bg-white'
                  "
                >
                  <div class="flex items-center gap-2">
                    <span class="text-3xs font-semibold text-slate-400 w-5 text-right tabular-nums">
                      {{ idx + 1 }}
                    </span>
                    <div class="flex-1 min-w-0">
                      <p class="text-[12px] font-semibold text-slate-900 leading-tight truncate">
                        {{ r.student_name }}
                      </p>
                      <p v-if="r.nis" class="text-3xs text-slate-500 leading-tight">
                        {{ r.nis }}
                      </p>
                    </div>
                  </div>
                </td>

                <!-- Bab columns -->
                <td
                  v-for="(_, i) in chapters"
                  :key="`bab-cell-${r.student_class_id}-${i}`"
                  class="px-1 py-1 border-r border-slate-100 text-center"
                >
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="1"
                    :value="r.chapter_scores?.[i] ?? ''"
                    placeholder="—"
                    class="w-full max-w-[64px] text-center text-[12px] font-semibold rounded-md border border-transparent focus:border-brand-cobalt focus:bg-white px-1 py-1 outline-none tabular-nums"
                    @input="onBabInput(r, i, ($event.target as HTMLInputElement).value)"
                  />
                </td>

                <!-- UTS / UAS -->
                <td class="px-1 py-1 border-r border-slate-100 text-center">
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="1"
                    :value="r.midterm_score ?? ''"
                    placeholder="—"
                    class="w-full max-w-[64px] text-center text-[12px] font-semibold rounded-md border border-transparent focus:border-brand-cobalt focus:bg-white px-1 py-1 outline-none tabular-nums"
                    @input="onScoreInput(r, 'midterm_score', ($event.target as HTMLInputElement).value)"
                  />
                </td>
                <td class="px-1 py-1 border-r border-slate-100 text-center">
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="1"
                    :value="r.final_exam_score ?? ''"
                    placeholder="—"
                    class="w-full max-w-[64px] text-center text-[12px] font-semibold rounded-md border border-transparent focus:border-brand-cobalt focus:bg-white px-1 py-1 outline-none tabular-nums"
                    @input="onScoreInput(r, 'final_exam_score', ($event.target as HTMLInputElement).value)"
                  />
                </td>

                <!-- Final (read-only display, but editable on focus) -->
                <td class="px-1 py-1 border-r border-slate-100 text-center bg-slate-50/30">
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="1"
                    :value="r.final_score ?? effectiveFinal(r) ?? ''"
                    placeholder="auto"
                    class="w-full max-w-[60px] text-center text-[12px] font-bold rounded-md border border-transparent focus:border-brand-cobalt focus:bg-white px-1 py-1 outline-none tabular-nums"
                    :class="{
                      'text-emerald-700':
                        typeof effectiveFinal(r) === 'number' && effectiveFinal(r)! >= 80,
                      'text-amber-700':
                        typeof effectiveFinal(r) === 'number' && effectiveFinal(r)! >= 60 && effectiveFinal(r)! < 80,
                      'text-red-700':
                        typeof effectiveFinal(r) === 'number' && effectiveFinal(r)! < 60,
                    }"
                    @input="onScoreInput(r, 'final_score', ($event.target as HTMLInputElement).value)"
                  />
                </td>

                <!-- Skill -->
                <td class="px-1 py-1 border-r border-slate-100 text-center">
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="1"
                    :value="r.skill_score ?? ''"
                    placeholder="—"
                    class="w-full max-w-[64px] text-center text-[12px] font-semibold rounded-md border border-transparent focus:border-brand-cobalt focus:bg-white px-1 py-1 outline-none tabular-nums"
                    @input="onScoreInput(r, 'skill_score', ($event.target as HTMLInputElement).value)"
                  />
                </td>

                <!-- Predikat -->
                <td class="px-1 py-1 border-r border-slate-100 text-center relative">
                  <input
                    type="text"
                    maxlength="3"
                    :value="r.predicate ?? ''"
                    placeholder="—"
                    class="w-full max-w-[44px] text-center text-[12px] font-bold uppercase rounded-md border border-transparent focus:border-brand-cobalt focus:bg-white px-1 py-1 outline-none"
                    @focus="focusedPredikatRow = r.student_class_id"
                    @blur="onPredikatBlur(r.student_class_id)"
                    @input="onPredikatInput(r, ($event.target as HTMLInputElement).value)"
                  />
                  <div
                    v-if="focusedPredikatRow === r.student_class_id"
                    class="absolute z-30 mt-1 right-0 bg-white border border-slate-200 rounded-lg shadow-lg p-1 flex gap-0.5"
                  >
                    <button
                      v-for="p in PREDIKAT_OPTIONS"
                      :key="p"
                      type="button"
                      class="w-7 h-7 text-[12px] font-bold rounded-md hover:bg-brand-cobalt/10 text-slate-700"
                      @mousedown.prevent="setPredikatPreset(r, p)"
                    >
                      {{ p }}
                    </button>
                  </div>
                </td>

                <!-- Deskripsi (tap to open editor) -->
                <td class="px-2 py-1">
                  <button
                    type="button"
                    class="w-full text-left text-2xs text-slate-700 hover:text-brand-cobalt rounded-md px-1 py-1 hover:bg-slate-50 transition truncate"
                    :class="{ italic: !r.description, 'text-slate-400': !r.description }"
                    @click="openDescEditor(r)"
                  >
                    {{ r.description || t('tutor.sekolah.gradeRecapDetail.addDescription') }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </AsyncView>

    <!-- SAVE BAR (floating) -->
    <div
      v-if="hasUnsavedChanges"
      class="fixed bottom-4 left-1/2 -translate-x-1/2 z-40 flex items-center gap-3 bg-slate-900 text-white rounded-2xl shadow-2xl px-4 py-2.5 border border-slate-800"
    >
      <span class="text-[12px] font-bold">
        {{ t('tutor.sekolah.gradeRecapDetail.unsavedRows', { count: dirtyCount }) }}
      </span>
      <Button
        variant="ghost"
        size="sm"
        @click="load"
      >
        <span class="text-white">{{ t('tutor.sekolah.gradeRecapDetail.cancel') }}</span>
      </Button>
      <Button
        variant="primary"
        size="sm"
        :disabled="isSaving"
        @click="save"
      >
        {{ isSaving ? t('tutor.sekolah.gradeRecapDetail.saving') : t('tutor.sekolah.gradeRecapDetail.save') }}
      </Button>
    </div>

    <!-- DESCRIPTION EDITOR MODAL -->
    <Modal
      v-if="editDesc !== null"
      :title="t('tutor.sekolah.gradeRecapDetail.editDescriptionTitle')"
      @close="editDesc = null"
    >
      <div v-if="editDesc" class="space-y-3">
        <p class="text-[12px] text-slate-500">
          {{ editDesc.row.student_name }}
        </p>
        <textarea
          v-model="editDesc.draft"
          rows="5"
          :placeholder="t('tutor.sekolah.gradeRecapDetail.descriptionPlaceholder')"
          class="w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
        />
        <div class="flex justify-end gap-2">
          <Button variant="ghost" @click="editDesc = null">{{ t('tutor.sekolah.gradeRecapDetail.cancel') }}</Button>
          <Button variant="primary" @click="saveDescEdit">{{ t('tutor.sekolah.gradeRecapDetail.save') }}</Button>
        </div>
      </div>
    </Modal>

    <!-- ADD CHAPTER MODAL -->
    <Modal
      v-if="showAddChapter"
      :title="t('tutor.sekolah.gradeRecapDetail.addChapterTitle')"
      @close="showAddChapter = false"
    >
      <div class="space-y-3">
        <label class="text-[12px] font-semibold text-slate-700">
          {{ t('tutor.sekolah.gradeRecapDetail.chapterName') }}
        </label>
        <input
          v-model="addChapterDraft"
          type="text"
          class="w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          :placeholder="t('tutor.sekolah.gradeRecapDetail.chapterNameExample')"
          @keyup.enter="confirmAddChapter"
        />
        <!-- Slack 1783643111 — Luay: "add nilai belum ada pilihan
             untuk mengambil dari nilai [existing]". Checkbox opens
             the same GradeRecapSourcePickerModal that already backs
             every existing column, so the teacher gets one modal
             flow instead of add → then remember to open the picker. -->
        <label class="flex items-center gap-2 text-[12.5px] text-slate-700 cursor-pointer">
          <input
            v-model="addChapterFromExisting"
            type="checkbox"
            class="w-4 h-4 accent-brand-cobalt"
          />
          <span>
            <b>Ambil nilai dari asesmen di gradebook.</b>
            Setelah bab dibuat, aku akan buka picker asesmen supaya
            skor per murid otomatis ke-fill dari nilai yang sudah
            diinput di buku nilai.
          </span>
        </label>
        <div class="flex justify-end gap-2">
          <Button variant="ghost" @click="showAddChapter = false">{{ t('tutor.sekolah.gradeRecapDetail.cancel') }}</Button>
          <Button
            variant="primary"
            :disabled="!addChapterDraft.trim()"
            @click="confirmAddChapter"
          >
            {{ t('tutor.sekolah.gradeRecapDetail.add') }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- RENAME CHAPTER MODAL -->
    <Modal
      v-if="renameChapter !== null"
      :title="t('tutor.sekolah.gradeRecapDetail.renameChapterTitle')"
      @close="renameChapter = null"
    >
      <div v-if="renameChapter" class="space-y-3">
        <input
          v-model="renameChapter.draft"
          type="text"
          class="w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          :placeholder="t('tutor.sekolah.gradeRecapDetail.chapterName')"
          @keyup.enter="confirmRenameChapter"
        />
        <div class="flex justify-end gap-2">
          <Button variant="ghost" @click="renameChapter = null">{{ t('tutor.sekolah.gradeRecapDetail.cancel') }}</Button>
          <Button
            variant="primary"
            :disabled="!renameChapter.draft.trim()"
            @click="confirmRenameChapter"
          >
            {{ t('tutor.sekolah.gradeRecapDetail.save') }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- DELETE CHAPTER CONFIRM -->
    <Modal
      v-if="deleteChapter !== null"
      :title="t('tutor.sekolah.gradeRecapDetail.deleteChapterTitle')"
      @close="deleteChapter = null"
    >
      <div v-if="deleteChapter" class="space-y-3">
        <p class="text-sm text-slate-700">
          {{ t('tutor.sekolah.gradeRecapDetail.deleteChapterMessage', { name: chapters[deleteChapter.index] }) }}
        </p>
        <div class="flex justify-end gap-2">
          <Button variant="ghost" @click="deleteChapter = null">{{ t('tutor.sekolah.gradeRecapDetail.cancel') }}</Button>
          <Button
            variant="primary"
            class="!bg-red-600 hover:!bg-red-700"
            @click="confirmDeleteChapter"
          >
            {{ t('tutor.sekolah.gradeRecapDetail.delete') }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- SOURCE PICKER (pull column values from Gradebook) -->
    <GradeRecapSourcePickerModal
      v-if="sourcePicker"
      :column="sourcePicker.column"
      :column-label="sourcePicker.label"
      :class-id="classId"
      :subject-id="subjectId"
      :academic-year-id="Number(ay.selectedYearId ?? 0)"
      :teacher-id="auth.teacherId"
      @close="sourcePicker = null"
      @apply="applySource"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />

    <ConfirmationDialog
      v-if="pendingNav.open"
      :title="t('tutor.sekolah.gradeRecapDetail.unsavedTitle')"
      :message="t('tutor.sekolah.gradeRecapDetail.unsavedMessage', { count: dirtyCount })"
      :confirm-label="t('tutor.sekolah.gradeRecapDetail.leave')"
      danger
      @close="cancelNavLeave"
      @confirm="confirmNavLeave"
    />
  </div>
</template>

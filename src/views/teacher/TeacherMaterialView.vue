<!--
  TeacherMaterialView.vue - Materi (chapter / sub-chapter tree).

  Mirrors Flutter's `teacher_material_screen.dart` + `sub_chapter_detail_screen.dart`
  (Frame C of the Materi redesign mockup):

    1. Page header + KPI strip
    2. Filter toolbar (tingkat / mapel / periode) + tabs (Semua/Selesai/Belum)
    3. Chapter accordion with sub-chapter rows (tap row → open detail)
    4. Sub-chapter detail modal with tabs (Materi / Kuis / Referensi)
       - Materi tab: AI sections + manual lampiran + AI upsell card
       - Kuis tab: MC + Essay quizzes from generated_materials
       - Referensi tab: list of references
       - Footer: Tandai selesai / Regenerate materi / Generate dengan AI
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { MaterialService } from '@/services/materials.service';
import { SubjectService } from '@/services/subjects.service';
import type {
  Chapter,
  ContentMaterial,
  GeneratedMaterial,
  MaterialTree,
  QuizItem,
  SubChapter,
} from '@/types/materials';
import type { Subject } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import MaterialAiPollingOverlay from '@/components/feature/MaterialAiPollingOverlay.vue';
import MaterialSectionEditorModal from '@/components/feature/MaterialSectionEditorModal.vue';
import { formatDateShort, localISODate } from '@/lib/format';
import { useQuickAction } from '@/composables/useQuickAction';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useI18n } from 'vue-i18n';
import { subjectLabel } from '@/lib/labels';

const auth = useAuthStore();
const { fromQuickAction, queryString } = useQuickAction();
const { t } = useI18n();

// Filters
const subjects = ref<Subject[]>([]);
const subjectId = ref<string>('');
const gradeLevel = ref<string>('');
const semester = ref<string>('genap');
const tabKey = ref<'all' | 'done' | 'todo'>('all');

const showSubjectPicker = ref(false);
const showGradePicker = ref(false);

// Data
const tree = ref<MaterialTree>({ chapters: [], done_total: 0, total_total: 0 });
const isLoading = ref(true);
const error = ref<string | null>(null);
const expanded = ref<Set<string>>(new Set());
const isSaving = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Bulk-select state (mirrors Flutter's MaterialChapterMixin
//    `_checkedSubChapter` map). Only sub-bab that DON'T yet have
//    AI content can be selected — the action bar's "Generate AI"
//    triggers the batch sheet.
const selectedSubIds = ref<Set<string>>(new Set());
const isBulkBusy = ref(false);
const showBatchSheet = ref(false);
const batchProgress = ref<{ done: number; total: number; current: string } | null>(null);

interface SelectableSub {
  chapter: Chapter;
  sub: SubChapter;
}

const selectedRows = computed<SelectableSub[]>(() => {
  const out: SelectableSub[] = [];
  for (const c of tree.value.chapters) {
    for (const s of c.sub_chapters) {
      if (selectedSubIds.value.has(s.id)) out.push({ chapter: c, sub: s });
    }
  }
  return out;
});

const selectedCount = computed(() => selectedSubIds.value.size);
const selectedEstMinutes = computed(() => {
  // Flutter ETA: ~40s per item rounded up to whole minutes.
  const seconds = selectedCount.value * 40;
  return Math.max(1, Math.ceil(seconds / 60));
});

function toggleSelect(s: SubChapter) {
  const next = new Set(selectedSubIds.value);
  if (next.has(s.id)) next.delete(s.id);
  else next.add(s.id);
  selectedSubIds.value = next;
}

function clearSelection() {
  selectedSubIds.value = new Set();
}

function selectAllInChapter(c: Chapter) {
  const next = new Set(selectedSubIds.value);
  const allSelected = c.sub_chapters.every((s) => next.has(s.id));
  if (allSelected) {
    for (const s of c.sub_chapters) next.delete(s.id);
  } else {
    for (const s of c.sub_chapters)
      if (!s.ai_generated) next.add(s.id);
  }
  selectedSubIds.value = next;
}

function isChapterAllSelected(c: Chapter): boolean {
  if (c.sub_chapters.length === 0) return false;
  return c.sub_chapters.every((s) => selectedSubIds.value.has(s.id));
}

function isChapterPartialSelected(c: Chapter): boolean {
  const some = c.sub_chapters.some((s) => selectedSubIds.value.has(s.id));
  return some && !isChapterAllSelected(c);
}

// AI generate sheet
const showAiSheet = ref(false);
const aiForm = ref({ chapter_label: '', topic: '' });
const isGenerating = ref(false);
// Inline form error shown inside the AI sheet (rather than dismissable
// toast) so the teacher reads it next to the field they need to fix.
// Cleared on every open + on every keystroke that changes form state.
const aiFormError = ref<string | null>(null);

// Detail modal
const detail = ref<{ sub: SubChapter; chapter: Chapter } | null>(null);
const detailTab = ref<'materi' | 'kuis' | 'referensi'>('materi');
const detailContent = ref<ContentMaterial[]>([]);
const detailAi = ref<GeneratedMaterial | null>(null);
const detailLoading = ref(false);
const detailBusy = ref<'' | 'regen-materi' | 'regen-quiz' | 'regen-ref' | 'generate'>('');

const activeSubject = computed(() =>
  subjects.value.find((s) => s.id === subjectId.value) ?? null,
);

const state = computed<AsyncState<MaterialTree>>(() => {
  if (isLoading.value && tree.value.chapters.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (tree.value.chapters.length === 0) return { status: 'empty' };
  return { status: 'content', data: tree.value };
});

// Filtered view of chapters according to the active tab.
const visibleChapters = computed<Chapter[]>(() => {
  if (tabKey.value === 'all') return tree.value.chapters;
  return tree.value.chapters.map((c) => ({
    ...c,
    sub_chapters: c.sub_chapters.filter((s) =>
      tabKey.value === 'done' ? s.done : !s.done,
    ),
  }));
});

const progressPct = computed(() =>
  tree.value.total_total > 0
    ? Math.round((tree.value.done_total / tree.value.total_total) * 100)
    : 0,
);

const aiCount = computed(() =>
  tree.value.chapters.reduce(
    (sum, c) => sum + c.sub_chapters.filter((s) => s.ai_generated).length,
    0,
  ),
);

// Shared KpiStripCards source — mirrors the chrome used by Buku
// Grade / Presensi / Rekap Grade so the four teacher screens read
// identically. `accented` lights up the "AI" card when most
// sub-bab have AI content (≥50%).
const kpiCards = computed<KpiCard[]>(() => {
  const total = tree.value.total_total;
  const done = tree.value.done_total;
  const remaining = Math.max(0, total - done);
  const aiPct = total > 0 ? Math.round((aiCount.value / total) * 100) : 0;
  return [
    {
      icon: 'book',
      label: t('tutor.sekolah.material.kpiTotalBab'),
      value: tree.value.chapters.length,
      suffix: t('tutor.sekolah.material.kpiTotalBabSuffix', { count: total }),
      tone: 'brand',
    },
    {
      icon: 'check-circle',
      label: t('tutor.sekolah.material.kpiSudahDiajar'),
      value: done,
      suffix: `${progressPct.value}%`,
      tone: 'green',
      accented: progressPct.value >= 80,
    },
    {
      icon: 'clock',
      label: t('tutor.sekolah.material.kpiBelumDiajar'),
      value: remaining,
      suffix: t('tutor.sekolah.material.kpiBelumDiajarSuffix'),
      tone: remaining > 0 ? 'amber' : 'green',
    },
    {
      icon: 'sparkles',
      label: t('tutor.sekolah.material.kpiKontenAi'),
      value: aiCount.value,
      suffix: t('tutor.sekolah.material.kpiKontenAiSuffix', { pct: aiPct }),
      tone: 'violet',
      accented: aiPct >= 50,
    },
  ];
});

const tabOptions = computed(() => [
  { key: 'all', label: t('tutor.sekolah.material.tabAll'), meta: String(tree.value.total_total) },
  { key: 'done', label: t('tutor.sekolah.material.tabDone'), meta: String(tree.value.done_total) },
  {
    key: 'todo',
    label: t('tutor.sekolah.material.tabTodo'),
    meta: String(tree.value.total_total - tree.value.done_total),
  },
]);

const detailTabOptions = computed(() => [
  { key: 'materi', label: t('tutor.sekolah.material.tabMateri') },
  {
    key: 'kuis',
    label: t('tutor.sekolah.material.tabKuis'),
    meta: detailAi.value ? String(detailAi.value.quizzes.length) : '0',
  },
  {
    key: 'referensi',
    label: t('tutor.sekolah.material.tabReferensi'),
    meta: detailAi.value ? String(detailAi.value.references.length) : '0',
  },
]);

const tujuanList = computed<string[]>(() => {
  const tp = detailAi.value?.parsed_content?.tujuan_pembelajaran;
  if (!tp) return [];
  if (Array.isArray(tp)) return tp.map((x) => String(x));
  return [String(tp)];
});

const poinList = computed<string[]>(() => {
  const p = detailAi.value?.parsed_content?.poin_utama;
  if (!Array.isArray(p)) return [];
  return p.map((x) => String(x));
});

const mcQuizzes = computed<QuizItem[]>(() =>
  (detailAi.value?.quizzes ?? []).filter((q) => q.question_type === 'multiple_choice'),
);
const essayQuizzes = computed<QuizItem[]>(() =>
  (detailAi.value?.quizzes ?? []).filter((q) => q.question_type === 'essay'),
);

async function loadReferences() {
  try {
    // Scope the mapel filter to the subjects THIS teacher teaches (bug:
    // Teacher/Materi previously listed every school subject, so chapters/
    // sub-chapters from non-taught mapel leaked in). Fall back to the full
    // list only when there's no teacher context or the teacher has none
    // mapped yet, so the page never renders empty.
    const tid = auth.teacherId ?? auth.user?.id ?? '';
    let items: Subject[] = [];
    if (tid) {
      items = await SubjectService.listForTeacher(tid);
    }
    if (items.length === 0) {
      items = (await SubjectService.list({ per_page: 100 })).items;
    }
    subjects.value = items;

    if (fromQuickAction.value) {
      subjectId.value = queryString('subject_id') ?? '';
      gradeLevel.value = queryString('grade_level') ?? '';
    } else {
      // Auto-pick first subject so the chapter tree renders.
      subjectId.value = subjects.value[0]?.id ?? '';
      gradeLevel.value = '';
      tabKey.value = 'all';
    }
  } catch {
    // ignore
  }
}

async function reload() {
  if (!subjectId.value) {
    tree.value = { chapters: [], done_total: 0, total_total: 0 };
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    tree.value = await MaterialService.getTree({
      subject_id: subjectId.value,
      grade_level: gradeLevel.value || undefined,
      semester: semester.value,
      // Pass teacher_id so the service second-phase fetches
      // /material-progress and restores per-sub-bab done flags
      // on reload — without it the chapter list endpoint always
      // ships `is_checked: false`.
      teacher_id: auth.teacherId ?? auth.user?.id ?? undefined,
    });
    // Auto-expand chapters with in-progress work.
    expanded.value = new Set(
      tree.value.chapters
        .filter((c) => c.done_count > 0 && c.done_count < c.total_count)
        .map((c) => c.id),
    );
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await reload();
});

watch([subjectId, gradeLevel, semester], () => reload());

// Materi is academic-year scoped on the backend — refetch when the
// AY chip changes so a teacher switching years doesn't see stale
// chapters/sub-chapters from the previous year.
useAcademicYearWatcher(() => {
  loadReferences();
  reload();
});

function toggle(chapterId: string) {
  const next = new Set(expanded.value);
  if (next.has(chapterId)) next.delete(chapterId);
  else next.add(chapterId);
  expanded.value = next;
}

function chapterAccent(c: Chapter): {
  bg: string;
  text: string;
} {
  if (c.done_count === c.total_count && c.total_count > 0) {
    return { bg: 'bg-emerald-100', text: 'text-emerald-700' };
  }
  if (c.done_count > 0) {
    return { bg: 'bg-amber-100', text: 'text-amber-700' };
  }
  return { bg: 'bg-slate-100', text: 'text-slate-500' };
}

/**
 * Toggle the "sudah diajar" check for a sub-bab. Backend
 * (`/material-progress`) requires the full (teacher, subject,
 * chapter, sub_chapter) tuple — passing only the sub-bab id
 * trips a 422.
 *
 * Accepts both call shapes for back-compat:
 *   toggleSubChapter(sub)                — looks up parent chapter
 *   toggleSubChapter(sub, chapter)       — explicit parent (cheaper)
 */
async function toggleSubChapter(s: SubChapter, parent?: Chapter) {
  const chapter =
    parent ??
    tree.value.chapters.find((c) =>
      c.sub_chapters.some((x) => x.id === s.id),
    );
  if (!chapter) {
    toast.value = {
      message: t('tutor.sekolah.material.toastParentNotFound'),
      tone: 'error',
    };
    return;
  }
  const teacherId = auth.teacherId ?? auth.user?.id;
  if (!teacherId || !subjectId.value) {
    toast.value = {
      message: t('tutor.sekolah.material.toastNeedSubjectAndTeacher'),
      tone: 'error',
    };
    return;
  }
  const next = !s.done;
  // Optimistic
  s.done = next;
  s.taught_at = next ? localISODate() : null;
  for (const c of tree.value.chapters) {
    c.done_count = c.sub_chapters.filter((x) => x.done).length;
  }
  tree.value.done_total = tree.value.chapters.reduce((sum, c) => sum + c.done_count, 0);
  try {
    isSaving.value = true;
    await MaterialService.toggleSubChapter({
      teacher_id: teacherId,
      subject_id: subjectId.value,
      chapter_id: chapter.id,
      sub_chapter_id: s.id,
      is_checked: next,
    });
  } catch (e) {
    // Revert
    s.done = !next;
    s.taught_at = !next ? localISODate() : null;
    for (const c of tree.value.chapters) {
      c.done_count = c.sub_chapters.filter((x) => x.done).length;
    }
    tree.value.done_total = tree.value.chapters.reduce((sum, c) => sum + c.done_count, 0);
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// ── Detail modal ────────────────────────────────────────────────
async function openDetail(c: Chapter, s: SubChapter) {
  detail.value = { sub: s, chapter: c };
  detailTab.value = 'materi';
  detailContent.value = [];
  detailAi.value = null;
  detailBusy.value = '';
  detailLoading.value = true;
  try {
    const [content, ai] = await Promise.all([
      MaterialService.getContentMaterials(s.id),
      MaterialService.resolveAiMaterial({
        teacher_id: auth.teacherId ?? auth.user?.id,
        chapter_id: c.id,
        sub_chapter_id: s.id,
      }),
    ]);
    detailContent.value = content;
    detailAi.value = ai;
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    detailLoading.value = false;
  }
}

function closeDetail() {
  detail.value = null;
  detailContent.value = [];
  detailAi.value = null;
  detailBusy.value = '';
}

// ── Batch generate (bulk selection) ────────────────────────────
//
// Mirror Flutter's MaterialGenerateSheet flow: confirm-list
// modal → POST per sub-chapter in sequence (backend doesn't have
// a true bulk endpoint), with progress bar so the teacher can
// see which item is being processed. Failures are collected and
// reported at the end — successful items stay marked done so a
// retry only re-runs the failed ones.
async function runBatchGenerate() {
  if (selectedRows.value.length === 0 || !subjectId.value) return;
  isBulkBusy.value = true;
  batchProgress.value = {
    done: 0,
    total: selectedRows.value.length,
    current: '',
  };
  const failed: SelectableSub[] = [];
  for (const row of selectedRows.value) {
    if (!batchProgress.value) break;
    batchProgress.value.current = `${row.chapter.label} · ${row.sub.name}`;
    try {
      await MaterialService.generateWithAi({
        teacher_id: auth.teacherId ?? auth.user?.id,
        subject_id: subjectId.value,
        chapter_id: row.chapter.id,
        sub_chapter_id: row.sub.id,
        chapter_label: `${row.chapter.label} · ${row.sub.name}`,
      });
      // Optimistic flag flip so the violet AI pill appears
      // immediately; reload below will reconcile with server truth.
      row.sub.ai_generated = true;
    } catch {
      failed.push(row);
    }
    if (batchProgress.value) batchProgress.value.done += 1;
  }
  isBulkBusy.value = false;
  showBatchSheet.value = false;
  batchProgress.value = null;
  // Remove successful items from selection so a retry only covers
  // the failures; clear if all succeeded.
  const failedIds = new Set(failed.map((r) => r.sub.id));
  selectedSubIds.value = failedIds;
  if (failed.length === 0) {
    toast.value = {
      message: t('tutor.sekolah.material.toastBatchSuccess', { count: selectedRows.value.length }),
      tone: 'success',
    };
  } else {
    toast.value = {
      message: t('tutor.sekolah.material.toastBatchPartialFail', {
        failed: failed.length,
        total: selectedRows.value.length + failed.length,
      }),
      tone: 'error',
    };
  }
  // Re-fetch tree so AI status flips reflect server truth.
  await reload();
}

// ── AI polling overlay state ──
//
// `aiPolling` drives <MaterialAiPollingOverlay>. The overlay shows
// during single-item generate AND regenerate flows (materi/quiz/
// referensi) so the teacher gets consistent feedback for any
// AI call instead of a bare "menunggu hasil" toast.
//
// `_aiPollAbort` is a flag the polling loop checks each tick — set
// to true by the cancel button or when the detail modal is closed.
const aiPolling = ref<{
  title: string;
  subtitle: string;
  estimatedSeconds: number;
  /** Flipped true when the poll loop exceeds its deadline so the
   *  overlay shows the in-place Retry / Tutup choice. */
  timedOut: boolean;
  /** Caller wires this — what to re-run when the user taps Retry. */
  retry?: () => void;
} | null>(null);
let aiPollAbort = false;

function closeAiOverlay() {
  aiPollAbort = true;
  aiPolling.value = null;
}

function retryAiPoll() {
  const cb = aiPolling.value?.retry;
  if (!cb) return;
  // Reset timeout state, then invoke the caller-provided retry fn
  // (which kicks the polling loop back into life).
  if (aiPolling.value) aiPolling.value.timedOut = false;
  cb();
}

// ── Section editor state ──
//
// Mirror Flutter's `MaterialSectionEditorSheet` flow: pencil icon
// in each section card opens this modal seeded with the current
// value. Save writes back to `detailAi.parsed_content` in place —
// backend PATCH endpoint doesn't exist yet on either platform, so
// edits live in-session and are reset on next regenerate (matches
// Flutter's documented behavior).
type EditorField =
  | 'ringkasan'
  | 'tujuan_pembelajaran'
  | 'poin_utama'
  | 'cara_mengajar';

const editorTarget = ref<{
  key: EditorField;
  label: string;
  mode: 'text' | 'list';
  value: string;
} | null>(null);

function editorLabel(key: EditorField): string {
  switch (key) {
    case 'ringkasan':
      return t('tutor.sekolah.material.sectionRingkasan');
    case 'tujuan_pembelajaran':
      return t('tutor.sekolah.material.sectionTujuan');
    case 'poin_utama':
      return t('tutor.sekolah.material.sectionPoin');
    case 'cara_mengajar':
      return t('tutor.sekolah.material.sectionCara');
  }
}

function openSectionEditor(key: EditorField) {
  const parsed = detailAi.value?.parsed_content;
  if (!parsed) return;
  // Coerce backend's mixed shape (string vs string[]) into the
  // editor's flat string contract. List fields get joined by
  // newline so the textarea shows one item per line.
  let value: string;
  let mode: 'text' | 'list' = 'text';
  if (key === 'tujuan_pembelajaran' || key === 'poin_utama') {
    mode = 'list';
    const raw = parsed[key];
    if (Array.isArray(raw)) {
      value = raw.map((x) => String(x)).join('\n');
    } else if (typeof raw === 'string') {
      value = raw;
    } else {
      value = '';
    }
  } else {
    const raw = parsed[key];
    value = typeof raw === 'string' ? raw : '';
  }
  editorTarget.value = { key, label: editorLabel(key), mode, value };
}

function saveSectionEdit(next: string) {
  if (!editorTarget.value || !detailAi.value || !detailAi.value.parsed_content) {
    return;
  }
  const { key, mode } = editorTarget.value;
  // List mode: split by newlines, trim, drop empty lines so the
  // teacher can delete an item by clearing its line.
  if (mode === 'list') {
    const items = next
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
    (detailAi.value.parsed_content as Record<string, unknown>)[key] = items;
  } else {
    (detailAi.value.parsed_content as Record<string, unknown>)[key] = next;
  }
  toast.value = {
    message: t('tutor.sekolah.material.editLocalUpdated', { label: editorTarget.value.label }),
    tone: 'success',
  };
  editorTarget.value = null;
}

/**
 * Poll `resolveAiMaterial` every 2s until a fresh material lands
 * or the elapsed time exceeds `timeoutSec`. Returns the resolved
 * material or null on timeout / cancel.
 */
async function pollForAiMaterial(args: {
  chapter_id: string;
  sub_chapter_id: string;
  /** Previous material_id — wait until the resolver returns a
   *  different id (regenerate) OR the first non-null (fresh). */
  previousMaterialId?: string;
  timeoutSec?: number;
}): Promise<GeneratedMaterial | null> {
  const deadline = Date.now() + (args.timeoutSec ?? 90) * 1000;
  aiPollAbort = false;
  // First tick after a short delay — AI rarely returns in under 5s.
  await new Promise((r) => setTimeout(r, 3500));
  while (Date.now() < deadline) {
    if (aiPollAbort) return null;
    const m = await MaterialService.resolveAiMaterial({
      teacher_id: auth.teacherId ?? auth.user?.id,
      chapter_id: args.chapter_id,
      sub_chapter_id: args.sub_chapter_id,
    });
    if (m && m.id && m.id !== args.previousMaterialId) return m;
    await new Promise((r) => setTimeout(r, 2500));
  }
  return null;
}

async function generateForDetail() {
  if (!detail.value || !subjectId.value) return;
  detailBusy.value = 'generate';
  const chapter = detail.value.chapter;
  const sub = detail.value.sub;
  try {
    await MaterialService.generateWithAi({
      teacher_id: auth.teacherId ?? auth.user?.id,
      subject_id: subjectId.value,
      chapter_id: chapter.id,
      sub_chapter_id: sub.id,
      chapter_label: `${chapter.label} · ${sub.name}`,
    });
    // Open the polling overlay — pollForAiMaterial will close it
    // automatically once the material lands. On timeout we flip
    // `timedOut` instead of nulling it so the user gets a Retry.
    aiPolling.value = {
      title: t('tutor.sekolah.material.overlayGenerating'),
      subtitle: `${chapter.label} · ${sub.name}`,
      estimatedSeconds: 60,
      timedOut: false,
      retry: generateForDetail,
    };
    const fresh = await pollForAiMaterial({
      chapter_id: chapter.id,
      sub_chapter_id: sub.id,
    });
    if (!detail.value) {
      aiPolling.value = null;
      return; // teacher closed the modal mid-poll
    }
    if (fresh) {
      aiPolling.value = null;
      detailAi.value = fresh;
      // Flip the sub-bab AI pill in the tree without a full reload.
      sub.ai_generated = true;
      toast.value = { message: t('tutor.sekolah.material.toastMateriReady'), tone: 'success' };
    } else if (!aiPollAbort) {
      // Keep the overlay mounted but flip into timeout mode so the
      // teacher can retry without re-navigating.
      if (aiPolling.value) aiPolling.value.timedOut = true;
    } else {
      aiPolling.value = null;
    }
  } catch (e) {
    aiPolling.value = null;
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    detailBusy.value = '';
  }
}

/**
 * Shared regenerate-then-poll helper. Each regenerate flow fires a
 * specific endpoint, then polls the same `getGeneratedMaterial`
 * until `updated_at` (or array length) changes — confirming the AI
 * job finished. Falls back to a short bounded wait if the change-
 * detection signal isn't present in the response.
 */
async function regenAndPoll(args: {
  busyTag: '' | 'regen-materi' | 'regen-quiz' | 'regen-ref';
  overlayTitle: string;
  estimatedSeconds: number;
  fire: () => Promise<unknown>;
  changeDetector: (
    before: GeneratedMaterial,
    after: GeneratedMaterial,
  ) => boolean;
}) {
  if (!detailAi.value || !detail.value) return;
  const materialId = detailAi.value.id;
  const before = detailAi.value;
  detailBusy.value = args.busyTag;
  try {
    await args.fire();
    aiPolling.value = {
      title: args.overlayTitle,
      subtitle: `${detail.value.chapter.label} · ${detail.value.sub.name}`,
      estimatedSeconds: args.estimatedSeconds,
      timedOut: false,
      retry: () => regenAndPoll(args),
    };
    aiPollAbort = false;
    const deadline = Date.now() + 90_000;
    await new Promise((r) => setTimeout(r, 3000));
    while (Date.now() < deadline) {
      if (aiPollAbort) break;
      const updated = await MaterialService.getGeneratedMaterial(materialId);
      if (updated && args.changeDetector(before, updated)) {
        if (detail.value) detailAi.value = updated;
        aiPolling.value = null;
        toast.value = { message: t('tutor.sekolah.material.toastAiUpdated'), tone: 'success' };
        return;
      }
      await new Promise((r) => setTimeout(r, 2500));
    }
    if (!aiPollAbort) {
      // Keep overlay mounted, flip to timeout mode so the user gets
      // an in-place Retry option instead of a disposable toast.
      if (aiPolling.value) aiPolling.value.timedOut = true;
    } else {
      aiPolling.value = null;
    }
  } catch (e) {
    aiPolling.value = null;
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    detailBusy.value = '';
  }
}

async function regenMateri() {
  if (!detailAi.value) return;
  const materialId = detailAi.value.id;
  await regenAndPoll({
    busyTag: 'regen-materi',
    overlayTitle: t('tutor.sekolah.material.overlayRegenMateri'),
    estimatedSeconds: 45,
    fire: () => MaterialService.regenerateMaterialContent(materialId),
    changeDetector: (before, after) =>
      before.updated_at !== after.updated_at ||
      JSON.stringify(before.parsed_content ?? null) !==
        JSON.stringify(after.parsed_content ?? null),
  });
}

async function regenQuiz() {
  if (!detailAi.value) return;
  const materialId = detailAi.value.id;
  await regenAndPoll({
    busyTag: 'regen-quiz',
    overlayTitle: t('tutor.sekolah.material.overlayRegenQuiz'),
    estimatedSeconds: 40,
    fire: () => MaterialService.regenerateQuiz(materialId),
    changeDetector: (before, after) =>
      before.quizzes.length !== after.quizzes.length ||
      before.updated_at !== after.updated_at,
  });
}

async function regenRef() {
  if (!detailAi.value) return;
  const materialId = detailAi.value.id;
  await regenAndPoll({
    busyTag: 'regen-ref',
    overlayTitle: t('tutor.sekolah.material.overlayRegenRef'),
    estimatedSeconds: 30,
    fire: () => MaterialService.regenerateReferences(materialId),
    changeDetector: (before, after) =>
      before.references.length !== after.references.length ||
      before.updated_at !== after.updated_at,
  });
}

async function generateAi() {
  if (!subjectId.value) return;

  // Local pre-validation. The backend's GenerateMaterialRequest
  // withValidator emits the same rule ("at least one of chapter_label
  // / topic"), but enforcing it here means the teacher gets the
  // message INLINE next to the field they are looking at, not as a
  // toast that arrives 200ms after a round trip. It also avoids
  // burning an AI-quota probe on an empty submission.
  const chapterLabel = aiForm.value.chapter_label.trim();
  const topic = aiForm.value.topic.trim();
  if (!chapterLabel && !topic) {
    aiFormError.value =
      'Isi minimal salah satu: nama bab/sub-bab atau topik utama.';
    return;
  }
  aiFormError.value = null;

  isGenerating.value = true;
  try {
    await MaterialService.generateWithAi({
      teacher_id: auth.teacherId ?? auth.user?.id,
      subject_id: subjectId.value,
      grade_level: gradeLevel.value,
      chapter_label: chapterLabel || undefined,
      topic: topic || undefined,
    });
    showAiSheet.value = false;
    aiForm.value = { chapter_label: '', topic: '' };
    aiFormError.value = null;
    toast.value = {
      message: t('tutor.sekolah.material.toastGenerateQueued'),
      tone: 'success',
    };
    await reload();
  } catch (e) {
    // Show the friendly message inline (next to the form) AND as a
    // toast — the toast is what users see if they accidentally close
    // the sheet before reading; the inline copy is what they see if
    // the sheet stays open (typical, since on failure we don't close).
    // The service translated axios → Bahasa Indonesia, so this string
    // is already user-ready.
    const message = (e as Error).message;
    aiFormError.value = message;
    toast.value = { message, tone: 'error' };
  } finally {
    isGenerating.value = false;
  }
}

/**
 * Clear stale form error every time the sheet opens. Without this,
 * a previous failed attempt's red banner would be visible the moment
 * the teacher reopens the sheet, which feels broken.
 */
watch(showAiSheet, (open) => {
  if (open) aiFormError.value = null;
});

const gradeOptions = computed(() => [
  { key: '7', label: t('tutor.sekolah.material.classPrefix', { grade: '7' }) },
  { key: '8', label: t('tutor.sekolah.material.classPrefix', { grade: '8' }) },
  { key: '9', label: t('tutor.sekolah.material.classPrefix', { grade: '9' }) },
  { key: '10', label: t('tutor.sekolah.material.classPrefix', { grade: '10' }) },
  { key: '11', label: t('tutor.sekolah.material.classPrefix', { grade: '11' }) },
  { key: '12', label: t('tutor.sekolah.material.classPrefix', { grade: '12' }) },
]);

function pickSubject(id: string) {
  subjectId.value = id;
  showSubjectPicker.value = false;
}
function pickGrade(g: string) {
  gradeLevel.value = g;
  showGradePicker.value = false;
}

/**
 * Match a quiz option against the row's `correct_answer`.
 *
 * Backend may store the answer in any of these shapes:
 *   - Letter:   "A" / "B" / "C" / "D"
 *   - Index:    "0" / "1" / "2" / "3"  (or integer)
 *   - Full text identical to the option text
 *
 * We handle all three by checking letter mapping (oi → A/B/C/D),
 * index string, and exact text match.
 */
function isCorrectOption(q: QuizItem, oi: number, opt: string): boolean {
  const ans = String(q.correct_answer ?? '').trim();
  if (!ans) return false;
  const letter = ['A', 'B', 'C', 'D', 'E', 'F'][oi];
  if (letter && ans.toUpperCase() === letter) return true;
  if (ans === String(oi)) return true;
  if (ans === opt) return true;
  return false;
}

function difficultyConfig(d?: string): { bg: string; text: string; label: string } {
  switch ((d ?? '').toLowerCase()) {
    case 'easy':
      return { bg: 'bg-emerald-100', text: 'text-emerald-700', label: 'Mudah' };
    case 'medium':
      return { bg: 'bg-amber-100', text: 'text-amber-700', label: 'Sedang' };
    case 'hard':
      return { bg: 'bg-red-100', text: 'text-red-700', label: 'Sulit' };
    default:
      return { bg: 'bg-slate-100', text: 'text-slate-600', label: (d ?? '—').toUpperCase() };
  }
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER (shared chrome) -->
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutor.sekolah.material.kicker')"
      :title="activeSubject?.name ? t('tutor.sekolah.material.titleWithSubject', { subject: activeSubject.name }) : t('tutor.sekolah.material.titleFallback')"
      :meta="
        t('tutor.sekolah.material.meta', {
          gradePrefix: gradeLevel ? t('tutor.sekolah.material.classPrefix', { grade: gradeLevel }) + ' · ' : '',
          semester: semester === 'ganjil' ? t('tutor.sekolah.material.semester1') : t('tutor.sekolah.material.semester2'),
          subCount: tree.total_total,
        })
      "
      :live-dot="false"
    >
      <Button variant="primary" size="sm" @click="showAiSheet = true">
        <NavIcon name="sparkles" :size="14" />
        {{ t('tutor.sekolah.material.generateAi') }}
      </Button>
    </BrandPageHeader>

    <!-- KPI strip -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar>
      <template #chips>
        <AppFilterChip
          :label="t('tutor.sekolah.material.chipGrade')"
          :value="gradeLevel ? t('tutor.sekolah.material.classPrefix', { grade: gradeLevel }) : t('tutor.sekolah.material.allGrades')"
          :is-active="!!gradeLevel"
          @click="showGradePicker = true"
        />
        <AppFilterChip
          :label="t('tutor.sekolah.material.chipSubject')"
          :value="activeSubject?.name ?? t('tutor.sekolah.material.pickSubject')"
          :is-active="!!subjectId"
          @click="showSubjectPicker = true"
        />
        <AppFilterChip
          :label="t('tutor.sekolah.material.chipSemester')"
          :value="semester === 'ganjil' ? t('tutor.sekolah.material.semester1') : t('tutor.sekolah.material.semester2')"
          :is-active="true"
          @click="semester = semester === 'ganjil' ? 'genap' : 'ganjil'"
        />
      </template>
      <template #segmented>
        <SegmentedControl
          :model-value="tabKey"
          :options="tabOptions"
          size="sm"
          @update:model-value="(v) => (tabKey = v as 'all' | 'done' | 'todo')"
        />
      </template>
    </PageFilterToolbar>

    <!-- Progress legend (kept — quick at-a-glance under filters) -->
    <div
      class="flex items-center gap-4 flex-wrap px-3 py-2 bg-slate-50 border border-dashed border-slate-200 rounded-lg text-2xs text-slate-600"
    >
      <span class="inline-flex items-center gap-1.5">
        <span class="w-2 h-2 rounded-full bg-emerald-700"></span>
        <b class="text-slate-900 font-bold">{{ tree.done_total }}</b> {{ t('tutor.sekolah.material.legendDone') }}
      </span>
      <span class="inline-flex items-center gap-1.5">
        <span class="w-2 h-2 rounded-full bg-slate-300"></span>
        <b class="text-slate-900 font-bold">{{
          tree.total_total - tree.done_total
        }}</b> {{ t('tutor.sekolah.material.legendNotTaught') }}
      </span>
      <span class="inline-flex items-center gap-1.5">
        <span class="w-2 h-2 rounded-full bg-violet-500"></span>
        <b class="text-slate-900 font-bold">{{ aiCount }}</b> {{ t('tutor.sekolah.material.legendWithAi') }}
      </span>
      <span class="flex-1"></span>
      <span>
        {{ t('tutor.sekolah.material.semesterProgress') }}
        <b class="text-emerald-700 font-bold">{{ progressPct }}%</b>
      </span>
    </div>

    <!-- Tree -->
    <AsyncView
      :state="state"
      :empty-title="t('tutor.sekolah.material.emptyTitle')"
      :empty-description="t('tutor.sekolah.material.emptyDescription')"
      @retry="reload()"
    >
      <template #default>
        <section class="space-y-2.5">
          <article
            v-for="c in visibleChapters"
            :key="c.id"
            class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
          >
            <header
              class="px-4 py-3 flex items-center gap-3 cursor-pointer hover:bg-slate-50"
              :class="{ 'bg-slate-50': expanded.has(c.id) }"
              @click="toggle(c.id)"
            >
              <!-- Chapter-level select (selects all sub-bab in this Bab) -->
              <button
                type="button"
                class="w-4 h-4 rounded border grid place-items-center flex-shrink-0 transition-colors"
                :class="
                  isChapterAllSelected(c)
                    ? 'bg-brand-cobalt border-brand-cobalt text-white'
                    : isChapterPartialSelected(c)
                      ? 'bg-brand-cobalt/30 border-brand-cobalt text-brand-cobalt'
                      : 'border-slate-300 hover:border-brand-cobalt/60'
                "
                :title="
                  isChapterAllSelected(c)
                    ? t('tutor.sekolah.material.chapterCheckRemoveSel')
                    : t('tutor.sekolah.material.chapterCheckSelectAll')
                "
                @click.stop="selectAllInChapter(c)"
              >
                <svg
                  v-if="isChapterAllSelected(c)"
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="w-2.5 h-2.5"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                <span
                  v-else-if="isChapterPartialSelected(c)"
                  class="w-1.5 h-0.5 bg-current rounded-sm"
                />
              </button>
              <span class="text-slate-400 text-xs">
                {{ expanded.has(c.id) ? '▼' : '▶' }}
              </span>
              <span
                class="w-8 h-8 rounded-xl grid place-items-center flex-shrink-0"
                :class="[chapterAccent(c).bg, chapterAccent(c).text]"
              >
                <NavIcon name="book" :size="14" />
              </span>
              <div class="flex-1 min-w-0">
                <p class="text-[13px] font-bold text-slate-900 truncate">
                  {{ c.label }}{{ c.name ? ` · ${c.name}` : '' }}
                </p>
                <p class="text-2xs text-slate-400 truncate">
                  {{ t('tutor.sekolah.material.chapterMetaSubCount', { count: c.total_count }) }}{{ c.meta ? ` · ${c.meta}` : '' }}
                </p>
              </div>
              <div class="flex items-center gap-2 flex-shrink-0">
                <span class="text-2xs font-bold text-slate-600">
                  {{ c.done_count }}/{{ c.total_count }}
                </span>
                <div class="w-16 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                  <div
                    class="h-full bg-brand-cobalt transition-all"
                    :style="{ width: c.total_count ? `${(c.done_count / c.total_count) * 100}%` : '0%' }"
                  ></div>
                </div>
              </div>
            </header>

            <div v-if="expanded.has(c.id) && c.sub_chapters.length > 0" class="pl-12 pr-4 py-1">
              <div
                v-for="(s, idx) in c.sub_chapters"
                :key="s.id"
                class="flex items-center gap-3 py-2 cursor-pointer hover:bg-slate-50 -mx-1 px-1 rounded-lg transition-colors"
                :class="[
                  idx > 0 ? 'border-t border-slate-100' : '',
                  selectedSubIds.has(s.id) ? 'bg-brand-cobalt/5' : '',
                ]"
                @click="openDetail(c, s)"
              >
                <!-- Per-sub-bab select (for batch AI generate) -->
                <button
                  type="button"
                  class="w-4 h-4 rounded border grid place-items-center flex-shrink-0 transition-colors"
                  :class="
                    selectedSubIds.has(s.id)
                      ? 'bg-brand-cobalt border-brand-cobalt text-white'
                      : 'border-slate-300 hover:border-brand-cobalt/60'
                  "
                  :title="
                    selectedSubIds.has(s.id) ? t('tutor.sekolah.material.subRowSelectRemove') : t('tutor.sekolah.material.subRowSelectAdd')
                  "
                  @click.stop="toggleSelect(s)"
                >
                  <svg
                    v-if="selectedSubIds.has(s.id)"
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="w-2.5 h-2.5"
                  >
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                </button>
                <button
                  type="button"
                  class="w-4 h-4 rounded border grid place-items-center flex-shrink-0 transition-colors"
                  :class="
                    s.done
                      ? 'bg-emerald-600 border-emerald-600 text-white'
                      : 'border-slate-300 hover:border-emerald-400'
                  "
                  :aria-label="s.done ? t('tutor.sekolah.material.subRowToggleOff') : t('tutor.sekolah.material.subRowToggleOn')"
                  :disabled="isSaving"
                  @click.stop="toggleSubChapter(s, c)"
                >
                  <svg
                    v-if="s.done"
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="w-2.5 h-2.5"
                  >
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                </button>
                <span
                  class="flex-1 text-[12px]"
                  :class="
                    s.done
                      ? 'text-slate-400 line-through'
                      : 'text-slate-700 font-medium'
                  "
                >
                  {{ s.number ? `${s.number} ` : '' }}{{ s.name }}
                </span>
                <span
                  v-if="s.ai_generated"
                  class="text-4xs font-bold px-1.5 py-0.5 rounded-full bg-violet-100 text-violet-700 uppercase tracking-wider"
                >
                  AI
                </span>
                <span class="text-3xs text-slate-400 min-w-[80px] text-right">
                  {{
                    s.done && s.taught_at
                      ? t('tutor.sekolah.material.subRowTaughtAt', { date: formatDateShort(s.taught_at) })
                      : t('tutor.sekolah.material.subRowNotTaught')
                  }}
                </span>
                <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
              </div>
            </div>
            <div
              v-else-if="expanded.has(c.id) && c.sub_chapters.length === 0"
              class="pl-12 pr-4 py-3 text-2xs text-slate-400 italic"
            >
              {{ t('tutor.sekolah.material.subRowEmptyFilter') }}
            </div>
          </article>
        </section>
      </template>
    </AsyncView>

    <!-- Subject picker -->
    <Modal v-if="showSubjectPicker" :title="t('tutor.sekolah.material.pickSubjectTitle')" @close="showSubjectPicker = false">
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': s.id === subjectId }"
            @click="pickSubject(s.id)"
          >
            {{ subjectLabel(s) }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- Grade picker -->
    <Modal v-if="showGradePicker" :title="t('tutor.sekolah.material.pickGradeTitle')" @close="showGradePicker = false">
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': gradeLevel === '' }"
            @click="pickGrade('')"
          >
            {{ t('tutor.sekolah.material.allGrades') }}
          </button>
        </li>
        <li v-for="g in gradeOptions" :key="g.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': g.key === gradeLevel }"
            @click="pickGrade(g.key)"
          >
            {{ g.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- AI generate sheet -->
    <Modal
      v-if="showAiSheet"
      :title="t('tutor.sekolah.material.aiSheetTitle')"
      :subtitle="t('tutor.sekolah.material.aiSheetSubtitle')"
      @close="showAiSheet = false"
    >
      <form class="space-y-md" @submit.prevent="generateAi">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">
            {{ t('tutor.sekolah.material.aiSheetChapterLabel') }} <span class="text-slate-400 font-normal">{{ t('tutor.sekolah.material.aiSheetChapterOptional') }}</span>
          </label>
          <input
            v-model="aiForm.chapter_label"
            type="text"
            :placeholder="t('tutor.sekolah.material.aiSheetChapterPlaceholder')"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isGenerating"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">{{ t('tutor.sekolah.material.aiSheetTopicLabel') }}</label>
          <textarea
            v-model="aiForm.topic"
            rows="3"
            :placeholder="t('tutor.sekolah.material.aiSheetTopicPlaceholder')"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none resize-none"
            :disabled="isGenerating"
          ></textarea>
        </div>
        <p class="text-2xs text-slate-500 bg-slate-50 rounded-lg p-3 leading-relaxed">
          {{ t('tutor.sekolah.material.aiSheetHint') }} <b class="text-slate-900">{{ t('tutor.sekolah.material.aiSheetHintEta') }}</b>{{ t('tutor.sekolah.material.aiSheetHintTail') }}
        </p>
        <!--
          Inline error banner — shown for both local validation failures
          ("topic / bab harus diisi") and translated backend errors
          (the materials service already converts axios → Bahasa
          Indonesia). Lives inside the form so the teacher reads it
          next to the field rather than chasing a toast.
        -->
        <div
          v-if="aiFormError"
          role="alert"
          class="flex items-start gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2.5 text-[12px] text-red-700 leading-relaxed"
        >
          <NavIcon name="alert-triangle" :size="14" class="mt-[2px] flex-shrink-0 text-red-500" />
          <span class="flex-1">{{ aiFormError }}</span>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <Button variant="secondary" block :disabled="isGenerating" @click="showAiSheet = false">
            {{ t('tutor.sekolah.material.aiSheetCancel') }}
          </Button>
          <Button variant="primary" block :loading="isGenerating" @click="generateAi">
            {{ t('tutor.sekolah.material.aiSheetSubmit') }}
          </Button>
        </div>
      </form>
    </Modal>

    <!-- ── Sub-chapter detail modal (mirrors Flutter Frame C) ── -->
    <Teleport v-if="detail" to="body">
      <div
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/40 px-md py-md sm:p-lg"
        @click.self="closeDetail()"
      >
        <div
          class="w-full max-w-3xl bg-white rounded-2xl shadow-2xl max-h-[92vh] flex flex-col"
          role="dialog"
          aria-modal="true"
        >
          <!-- Header -->
          <header class="px-5 py-4 border-b border-slate-100 flex items-start gap-4">
            <div class="w-11 h-11 rounded-2xl bg-violet-100 text-violet-700 grid place-items-center flex-shrink-0">
              <NavIcon name="book" :size="20" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-1">
                <span class="text-3xs font-bold text-violet-700 uppercase tracking-widest">
                  {{ detail.chapter.label }} · {{ detail.sub.number }}
                </span>
                <span
                  v-if="detail.sub.ai_generated || detailAi"
                  class="text-4xs font-bold px-1.5 py-0.5 rounded-full bg-violet-100 text-violet-700 uppercase tracking-wider"
                >
                  {{ t('tutor.sekolah.material.detailAiReady') }}
                </span>
              </div>
              <h2 class="text-base font-black text-slate-900 truncate">
                {{ detail.sub.name }}
              </h2>
              <p class="text-2xs text-slate-400 truncate">
                {{ activeSubject?.name ?? '—' }} · {{ semester === 'ganjil' ? t('tutor.sekolah.material.semester1') : t('tutor.sekolah.material.semester2') }}
                {{ detail.sub.done && detail.sub.taught_at ? t('tutor.sekolah.material.detailTaughtSuffix', { date: formatDateShort(detail.sub.taught_at) }) : '' }}
              </p>
            </div>
            <button
              type="button"
              class="text-slate-400 hover:text-slate-700 p-1 -m-1"
              :aria-label="t('tutor.sekolah.material.detailAriaClose')"
              @click="closeDetail()"
            >
              <NavIcon name="x" :size="18" />
            </button>
          </header>

          <!-- KPI strip -->
          <div class="px-5 pt-4">
            <div class="grid grid-cols-3 gap-2 bg-slate-50 rounded-xl p-3">
              <div class="text-center">
                <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">{{ t('tutor.sekolah.material.detailKpiMateri') }}</p>
                <p class="text-lg font-black" :class="detailAi ? 'text-violet-700' : 'text-slate-400'">
                  {{ detailAi ? t('tutor.sekolah.material.detailKpiMateriReady') : '—' }}
                </p>
              </div>
              <div class="text-center">
                <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">{{ t('tutor.sekolah.material.detailKpiKuis') }}</p>
                <p class="text-lg font-black text-slate-900">
                  {{ detailAi?.quizzes.length ?? 0 }}
                </p>
              </div>
              <div class="text-center">
                <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">{{ t('tutor.sekolah.material.detailKpiReferensi') }}</p>
                <p class="text-lg font-black text-slate-900">
                  {{ detailAi?.references.length ?? 0 }}
                </p>
              </div>
            </div>
          </div>

          <!-- Tabs -->
          <div class="px-5 pt-3">
            <SegmentedControl
              :model-value="detailTab"
              :options="detailTabOptions"
              size="sm"
              @update:model-value="(v) => (detailTab = v as 'materi' | 'kuis' | 'referensi')"
            />
          </div>

          <!-- Body -->
          <div class="flex-1 overflow-y-auto px-5 py-4">
            <div v-if="detailLoading" class="py-12 text-center text-slate-400 text-sm">
              <NavIcon name="loader" :size="20" class="animate-spin inline-block mb-2" />
              <p>{{ t('tutor.sekolah.material.detailLoading') }}</p>
            </div>

            <!-- ── Materi tab ───────────────────────────────────────── -->
            <div v-else-if="detailTab === 'materi'" class="space-y-md">
              <!-- AI sections -->
              <template v-if="detailAi?.parsed_content">
                <!-- Ringkasan -->
                <section
                  v-if="detailAi.parsed_content.ringkasan"
                  class="bg-white border border-slate-200 rounded-2xl p-4 group"
                >
                  <div class="flex items-center gap-2 mb-2">
                    <span class="w-7 h-7 rounded-lg bg-sky-100 text-sky-700 grid place-items-center">
                      <NavIcon name="file-text" :size="14" />
                    </span>
                    <h3 class="text-sm font-bold text-slate-900 flex-1">
                      {{ t('tutor.sekolah.material.sectionRingkasan') }}
                    </h3>
                    <button
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-slate-400 hover:text-brand-cobalt transition"
                      :title="t('tutor.sekolah.material.editRingkasanTitle')"
                      @click="openSectionEditor('ringkasan')"
                    >
                      <NavIcon name="edit" :size="14" />
                    </button>
                  </div>
                  <p class="text-[13px] text-slate-700 leading-relaxed whitespace-pre-wrap">
                    {{ detailAi.parsed_content.ringkasan }}
                  </p>
                </section>

                <!-- Tujuan Pembelajaran -->
                <section
                  v-if="tujuanList.length > 0"
                  class="bg-white border border-slate-200 rounded-2xl p-4 group"
                >
                  <div class="flex items-center gap-2 mb-2">
                    <span class="w-7 h-7 rounded-lg bg-emerald-100 text-emerald-700 grid place-items-center">
                      <NavIcon name="flag" :size="14" />
                    </span>
                    <h3 class="text-sm font-bold text-slate-900 flex-1">
                      {{ t('tutor.sekolah.material.sectionTujuan') }}
                    </h3>
                    <button
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-slate-400 hover:text-brand-cobalt transition"
                      :title="t('tutor.sekolah.material.editTujuanTitle')"
                      @click="openSectionEditor('tujuan_pembelajaran')"
                    >
                      <NavIcon name="edit" :size="14" />
                    </button>
                  </div>
                  <ol class="space-y-2">
                    <li
                      v-for="(item, idx) in tujuanList"
                      :key="idx"
                      class="flex gap-2.5 text-[13px] text-slate-700 leading-relaxed"
                    >
                      <span class="w-6 h-6 rounded-md bg-emerald-100 text-emerald-700 grid place-items-center text-2xs font-bold flex-shrink-0">
                        {{ idx + 1 }}
                      </span>
                      <span>{{ item }}</span>
                    </li>
                  </ol>
                </section>

                <!-- Poin Utama -->
                <section
                  v-if="poinList.length > 0"
                  class="bg-white border border-slate-200 rounded-2xl p-4 group"
                >
                  <div class="flex items-center gap-2 mb-2">
                    <span class="w-7 h-7 rounded-lg bg-amber-100 text-amber-700 grid place-items-center">
                      <NavIcon name="zap" :size="14" />
                    </span>
                    <h3 class="text-sm font-bold text-slate-900 flex-1">
                      {{ t('tutor.sekolah.material.sectionPoin') }}
                    </h3>
                    <button
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-slate-400 hover:text-brand-cobalt transition"
                      :title="t('tutor.sekolah.material.editPoinTitle')"
                      @click="openSectionEditor('poin_utama')"
                    >
                      <NavIcon name="edit" :size="14" />
                    </button>
                  </div>
                  <ol class="space-y-2">
                    <li
                      v-for="(item, idx) in poinList"
                      :key="idx"
                      class="flex gap-2.5 text-[13px] text-slate-700 leading-relaxed"
                    >
                      <span class="w-6 h-6 rounded-md bg-amber-100 text-amber-700 grid place-items-center text-2xs font-bold flex-shrink-0">
                        {{ idx + 1 }}
                      </span>
                      <span>{{ item }}</span>
                    </li>
                  </ol>
                </section>

                <!-- Cara Mengajar -->
                <section
                  v-if="detailAi.parsed_content.cara_mengajar"
                  class="bg-white border border-slate-200 rounded-2xl p-4 group"
                >
                  <div class="flex items-center gap-2 mb-2">
                    <span class="w-7 h-7 rounded-lg bg-violet-100 text-violet-700 grid place-items-center">
                      <NavIcon name="book" :size="14" />
                    </span>
                    <h3 class="text-sm font-bold text-slate-900 flex-1">
                      {{ t('tutor.sekolah.material.sectionCara') }}
                    </h3>
                    <button
                      type="button"
                      class="opacity-0 group-hover:opacity-100 text-slate-400 hover:text-brand-cobalt transition"
                      :title="t('tutor.sekolah.material.editCaraTitle')"
                      @click="openSectionEditor('cara_mengajar')"
                    >
                      <NavIcon name="edit" :size="14" />
                    </button>
                  </div>
                  <p class="text-[13px] text-slate-700 leading-relaxed whitespace-pre-wrap">
                    {{ detailAi.parsed_content.cara_mengajar }}
                  </p>
                </section>
              </template>

              <!-- AI upsell card (when AI already present) -->
              <button
                v-if="detailAi"
                type="button"
                class="w-full text-left rounded-2xl border-2 border-dashed border-violet-300 bg-gradient-to-br from-violet-50 to-sky-50 p-5 hover:border-violet-400 transition-colors"
                :disabled="detailBusy === 'regen-materi'"
                @click="regenMateri"
              >
                <div class="flex flex-col items-center text-center gap-2">
                  <span class="w-11 h-11 rounded-2xl bg-white shadow-md text-violet-700 grid place-items-center">
                    <NavIcon name="sparkles" :size="18" />
                  </span>
                  <p class="text-sm font-black text-slate-900">Materi Lebih Lengkap dari AI</p>
                  <p class="text-[11.5px] text-slate-500 leading-relaxed">
                    Regenerate ringkasan, tujuan, dan cara mengajar untuk sub-bab ini.
                  </p>
                  <span class="mt-1 inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-violet-600 text-white text-[12px] font-bold shadow-lg shadow-violet-200">
                    <NavIcon name="sparkles" :size="13" />
                    {{ detailBusy === 'regen-materi' ? 'Memperbarui…' : 'Regenerate Materi' }}
                  </span>
                </div>
              </button>

              <!-- Empty state: no AI yet -->
              <button
                v-if="!detailAi"
                type="button"
                class="w-full text-left rounded-2xl border-2 border-dashed border-violet-300 bg-gradient-to-br from-violet-50 to-sky-50 p-6 hover:border-violet-400 transition-colors"
                :disabled="detailBusy === 'generate'"
                @click="generateForDetail"
              >
                <div class="flex flex-col items-center text-center gap-2">
                  <span class="w-12 h-12 rounded-2xl bg-white shadow-md text-violet-700 grid place-items-center">
                    <NavIcon name="sparkles" :size="20" />
                  </span>
                  <p class="text-sm font-black text-slate-900">Belum Ada Konten AI</p>
                  <p class="text-[11.5px] text-slate-500 leading-relaxed">
                    Generate ringkasan, kuis, dan referensi untuk sub-bab ini dalam beberapa detik.
                  </p>
                  <span class="mt-1 inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-violet-600 text-white text-[12px] font-bold shadow-lg shadow-violet-200">
                    <NavIcon name="sparkles" :size="13" />
                    {{ detailBusy === 'generate' ? 'Mengirim…' : 'Generate dengan AI' }}
                  </span>
                </div>
              </button>

              <!-- Manual lampiran -->
              <template v-if="detailContent.length > 0">
                <div class="flex items-center gap-2 pt-2">
                  <span class="w-7 h-7 rounded-lg bg-slate-200 text-slate-700 grid place-items-center">
                    <NavIcon name="paperclip" :size="14" />
                  </span>
                  <h3 class="text-sm font-bold text-slate-900">Lampiran Manual</h3>
                  <span class="text-2xs text-slate-400">{{ detailContent.length }} item</span>
                </div>
                <a
                  v-for="(item, idx) in detailContent"
                  :key="item.id"
                  :href="item.file_url ?? '#'"
                  target="_blank"
                  rel="noopener"
                  class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl p-3 hover:border-violet-300 transition-colors"
                  :class="[idx > 0 ? '' : '']"
                >
                  <span class="w-10 h-10 rounded-lg bg-violet-100 text-violet-700 grid place-items-center flex-shrink-0">
                    <NavIcon name="file-text" :size="16" />
                  </span>
                  <div class="flex-1 min-w-0">
                    <p class="text-[13px] font-bold text-slate-900 truncate">{{ item.title }}</p>
                    <p v-if="item.description" class="text-[11.5px] text-slate-500 truncate">
                      {{ item.description }}
                    </p>
                  </div>
                  <span v-if="item.kind" class="text-4xs font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 uppercase tracking-wider">
                    {{ item.kind }}
                  </span>
                  <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
                </a>
              </template>
            </div>

            <!-- ── Kuis tab ────────────────────────────────────────── -->
            <div v-else-if="detailTab === 'kuis'" class="space-y-md">
              <div v-if="!detailAi || detailAi.quizzes.length === 0" class="py-10 text-center">
                <p class="text-sm font-bold text-slate-700 mb-1">Belum Ada Kuis</p>
                <p class="text-[12px] text-slate-400 mb-4">
                  Generate materi AI untuk mendapatkan kuis otomatis.
                </p>
                <Button variant="primary" size="sm" @click="generateForDetail">
                  <NavIcon name="sparkles" :size="13" />
                  Generate dengan AI
                </Button>
              </div>

              <template v-else>
                <!-- Stats bar -->
                <div class="grid grid-cols-3 gap-2 bg-slate-50 rounded-xl p-3 text-center">
                  <div>
                    <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">Total</p>
                    <p class="text-lg font-black text-slate-900">{{ detailAi.quizzes.length }}</p>
                  </div>
                  <div>
                    <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">PG</p>
                    <p class="text-lg font-black text-violet-700">{{ mcQuizzes.length }}</p>
                  </div>
                  <div>
                    <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">Essay</p>
                    <p class="text-lg font-black text-amber-700">{{ essayQuizzes.length }}</p>
                  </div>
                </div>

                <!-- MC section -->
                <template v-if="mcQuizzes.length > 0">
                  <div class="flex items-center gap-2 pt-2">
                    <span class="w-7 h-7 rounded-lg bg-violet-100 text-violet-700 grid place-items-center">
                      <NavIcon name="check-circle" :size="14" />
                    </span>
                    <h3 class="text-sm font-bold text-slate-900">Pilihan Ganda</h3>
                    <span class="text-3xs font-bold text-violet-700 bg-violet-100 px-1.5 py-0.5 rounded">{{ mcQuizzes.length }}</span>
                  </div>
                  <article
                    v-for="(q, idx) in mcQuizzes"
                    :key="`mc-${idx}`"
                    class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
                  >
                    <header class="px-4 py-3 bg-violet-50 flex items-center gap-3">
                      <span class="w-7 h-7 rounded-lg bg-violet-100 text-violet-700 grid place-items-center text-[13px] font-bold">
                        {{ idx + 1 }}
                      </span>
                      <p class="text-[12px] font-bold text-slate-600 flex-1">Pertanyaan {{ idx + 1 }}</p>
                      <span
                        class="text-3xs font-bold px-2 py-0.5 rounded-full"
                        :class="[difficultyConfig(q.difficulty).bg, difficultyConfig(q.difficulty).text]"
                      >
                        {{ difficultyConfig(q.difficulty).label }}
                      </span>
                    </header>
                    <div class="px-4 py-3 space-y-2">
                      <p class="text-[13px] font-medium text-slate-800 leading-relaxed whitespace-pre-wrap">
                        {{ q.question }}
                      </p>
                      <ul class="space-y-1.5">
                        <li
                          v-for="(opt, oi) in q.options ?? []"
                          :key="oi"
                          class="flex items-center gap-2 px-3 py-2 rounded-lg border text-[12.5px]"
                          :class="
                            isCorrectOption(q, oi, opt)
                              ? 'bg-emerald-50 border-emerald-200 text-emerald-800 font-bold'
                              : 'bg-slate-50 border-slate-200 text-slate-700'
                          "
                        >
                          <span class="w-5 h-5 rounded-full grid place-items-center text-2xs font-bold flex-shrink-0"
                            :class="
                              isCorrectOption(q, oi, opt)
                                ? 'bg-emerald-600 text-white'
                                : 'bg-slate-200 text-slate-600'
                            "
                          >
                            {{ ['A', 'B', 'C', 'D', 'E'][oi] ?? oi + 1 }}
                          </span>
                          <span class="flex-1">{{ opt }}</span>
                        </li>
                      </ul>
                      <div v-if="q.explanation" class="bg-amber-50 border-l-4 border-amber-400 rounded-r-lg p-3 text-[12px] text-amber-900 leading-relaxed">
                        <p class="text-3xs font-bold uppercase tracking-widest text-amber-700 mb-1">Penjelasan</p>
                        {{ q.explanation }}
                      </div>
                    </div>
                  </article>
                </template>

                <!-- Essay section -->
                <template v-if="essayQuizzes.length > 0">
                  <div class="flex items-center gap-2 pt-2">
                    <span class="w-7 h-7 rounded-lg bg-amber-100 text-amber-700 grid place-items-center">
                      <NavIcon name="edit-3" :size="14" />
                    </span>
                    <h3 class="text-sm font-bold text-slate-900">Essay</h3>
                    <span class="text-3xs font-bold text-amber-700 bg-amber-100 px-1.5 py-0.5 rounded">{{ essayQuizzes.length }}</span>
                  </div>
                  <article
                    v-for="(q, idx) in essayQuizzes"
                    :key="`essay-${idx}`"
                    class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
                  >
                    <header class="px-4 py-3 bg-amber-50 flex items-center gap-3">
                      <span class="w-7 h-7 rounded-lg bg-amber-100 text-amber-700 grid place-items-center text-[13px] font-bold">
                        {{ idx + 1 }}
                      </span>
                      <p class="text-[12px] font-bold text-slate-600 flex-1">Essay {{ idx + 1 }}</p>
                      <span
                        class="text-3xs font-bold px-2 py-0.5 rounded-full"
                        :class="[difficultyConfig(q.difficulty).bg, difficultyConfig(q.difficulty).text]"
                      >
                        {{ difficultyConfig(q.difficulty).label }}
                      </span>
                    </header>
                    <div class="px-4 py-3 space-y-2">
                      <p class="text-[13px] font-medium text-slate-800 leading-relaxed whitespace-pre-wrap">
                        {{ q.question }}
                      </p>
                      <div v-if="q.answer_key" class="bg-emerald-50 border-l-4 border-emerald-400 rounded-r-lg p-3 text-[12px] text-emerald-900 leading-relaxed">
                        <p class="text-3xs font-bold uppercase tracking-widest text-emerald-700 mb-1">Kunci Jawaban</p>
                        <span class="whitespace-pre-wrap">{{ q.answer_key }}</span>
                      </div>
                    </div>
                  </article>
                </template>
              </template>
            </div>

            <!-- ── Referensi tab ───────────────────────────────────── -->
            <div v-else class="space-y-md">
              <div v-if="!detailAi || detailAi.references.length === 0" class="py-10 text-center">
                <p class="text-sm font-bold text-slate-700 mb-1">Belum Ada Referensi</p>
                <p class="text-[12px] text-slate-400 mb-4">
                  Generate materi AI untuk mendapatkan daftar referensi otomatis.
                </p>
                <Button variant="primary" size="sm" @click="generateForDetail">
                  <NavIcon name="sparkles" :size="13" />
                  Generate dengan AI
                </Button>
              </div>

              <template v-else>
                <a
                  v-for="(r, idx) in detailAi.references"
                  :key="`ref-${idx}`"
                  :href="r.url ?? '#'"
                  target="_blank"
                  rel="noopener"
                  class="flex items-start gap-3 bg-white border border-slate-200 rounded-2xl p-4 hover:border-violet-300 transition-colors"
                >
                  <span class="w-10 h-10 rounded-lg bg-sky-100 text-sky-700 grid place-items-center flex-shrink-0">
                    <NavIcon name="link" :size="16" />
                  </span>
                  <div class="flex-1 min-w-0">
                    <p class="text-[13px] font-bold text-slate-900 leading-snug">
                      {{ r.title }}
                    </p>
                    <p v-if="r.description" class="text-[11.5px] text-slate-500 leading-relaxed mt-1">
                      {{ r.description }}
                    </p>
                    <div class="flex items-center gap-2 mt-1.5">
                      <span v-if="r.kind" class="text-4xs font-bold px-1.5 py-0.5 rounded-full bg-violet-100 text-violet-700 uppercase tracking-wider">
                        {{ r.kind }}
                      </span>
                      <span v-if="r.url" class="text-2xs text-violet-700 truncate font-medium">
                        {{ r.url }}
                      </span>
                    </div>
                  </div>
                  <NavIcon name="external-link" :size="14" class="text-slate-300 flex-shrink-0 mt-1" />
                </a>
              </template>
            </div>
          </div>

          <!-- Sticky footer -->
          <footer class="px-5 py-3 border-t border-slate-100 bg-slate-50 rounded-b-2xl flex items-center gap-2 flex-wrap">
            <Button variant="secondary" size="sm" @click="closeDetail()">
              Tutup
            </Button>
            <span class="flex-1"></span>

            <Button
              v-if="!detail.sub.done"
              variant="success"
              size="sm"
              :loading="isSaving"
              @click="toggleSubChapter(detail.sub, detail.chapter)"
            >
              <NavIcon name="check-circle" :size="13" />
              Tandai Selesai
            </Button>
            <Button
              v-else
              variant="secondary"
              size="sm"
              :loading="isSaving"
              @click="toggleSubChapter(detail.sub, detail.chapter)"
            >
              Batalkan tanda selesai
            </Button>

            <Button
              v-if="detailAi && detailTab === 'kuis'"
              variant="primary"
              size="sm"
              :loading="detailBusy === 'regen-quiz'"
              @click="regenQuiz"
            >
              <NavIcon name="refresh-cw" :size="13" />
              Tambah kuis
            </Button>

            <Button
              v-if="detailAi && detailTab === 'referensi'"
              variant="primary"
              size="sm"
              :loading="detailBusy === 'regen-ref'"
              @click="regenRef"
            >
              <NavIcon name="refresh-cw" :size="13" />
              Regenerate referensi
            </Button>
          </footer>
        </div>
      </div>
    </Teleport>

    <!-- FLOATING SELECTION BAR -->
    <div
      v-if="selectedCount > 0 && !showBatchSheet"
      class="fixed bottom-4 left-1/2 -translate-x-1/2 z-40 flex items-center gap-3 bg-slate-900 text-white rounded-2xl shadow-2xl px-4 py-2.5 border border-slate-800"
    >
      <span class="text-[12px] font-bold">
        {{ selectedCount }} sub-bab dipilih
      </span>
      <span class="text-2xs text-slate-400">
        · ~{{ selectedEstMinutes }} menit
      </span>
      <Button variant="ghost" size="sm" @click="clearSelection">
        <span class="text-white">Batal</span>
      </Button>
      <Button variant="primary" size="sm" @click="showBatchSheet = true">
        <NavIcon name="sparkles" :size="14" />
        Generate AI
      </Button>
    </div>

    <!-- BATCH GENERATE CONFIRMATION SHEET -->
    <Modal
      v-if="showBatchSheet"
      title="Generate Materi dengan AI"
      :subtitle="`${selectedCount} sub-bab · estimasi ~${selectedEstMinutes} menit`"
      @close="showBatchSheet = false"
    >
      <div class="space-y-3">
        <!-- Summary card -->
        <div
          class="rounded-xl border border-violet-200 bg-violet-50 p-3 flex items-start gap-3"
        >
          <span
            class="w-9 h-9 rounded-xl bg-violet-100 text-violet-700 grid place-items-center flex-shrink-0"
          >
            <NavIcon name="sparkles" :size="16" />
          </span>
          <div class="flex-1 text-[12px] text-slate-700 leading-relaxed">
            AI akan merangkum materi, menyusun kuis, dan mencari referensi
            untuk
            <strong class="text-violet-700">{{ selectedCount }} sub-bab</strong>
            yang dipilih.
            <br />
            <span class="text-slate-500">
              Estimasi: 40 detik per sub-bab. Kamu bisa tinggalkan halaman,
              hasilnya tetap tersimpan.
            </span>
          </div>
        </div>

        <!-- Preview list -->
        <div class="border border-slate-200 rounded-xl overflow-hidden max-h-72 overflow-y-auto">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="row in selectedRows"
              :key="row.sub.id"
              class="px-3 py-2 flex items-center gap-3 text-[12px]"
            >
              <span
                class="w-6 h-6 rounded-lg bg-violet-100 text-violet-700 grid place-items-center flex-shrink-0 text-3xs font-bold"
              >
                {{ row.sub.number || '–' }}
              </span>
              <span class="flex-1 truncate font-medium text-slate-900">
                {{ row.sub.name }}
              </span>
              <span class="text-3xs text-slate-400 truncate max-w-[120px]">
                {{ row.chapter.label }}
              </span>
              <button
                type="button"
                class="text-slate-400 hover:text-red-600"
                title="Hapus dari pilihan"
                @click="toggleSelect(row.sub)"
              >
                <NavIcon name="x" :size="12" />
              </button>
            </li>
          </ul>
        </div>

        <!-- Progress strip (active during generation) -->
        <div
          v-if="batchProgress"
          class="rounded-xl border border-brand-cobalt/30 bg-brand-cobalt/5 p-3"
        >
          <div class="flex items-center justify-between mb-1.5">
            <span class="text-2xs font-bold text-slate-700">
              {{ batchProgress.done }} / {{ batchProgress.total }} selesai
            </span>
            <span class="text-3xs text-slate-500 truncate max-w-[200px]">
              {{ batchProgress.current }}
            </span>
          </div>
          <div class="h-1.5 rounded-full overflow-hidden bg-slate-200">
            <div
              class="h-full bg-brand-cobalt transition-all"
              :style="{
                width: batchProgress.total
                  ? `${(batchProgress.done / batchProgress.total) * 100}%`
                  : '0%',
              }"
            />
          </div>
        </div>

        <!-- Footer -->
        <div class="flex justify-end gap-2 pt-2 border-t border-slate-100">
          <Button
            variant="ghost"
            :disabled="isBulkBusy"
            @click="showBatchSheet = false"
          >
            Batal
          </Button>
          <Button
            variant="primary"
            :disabled="isBulkBusy || selectedCount === 0"
            @click="runBatchGenerate"
          >
            <NavIcon name="sparkles" :size="14" />
            {{ isBulkBusy ? `Menggenerate ${batchProgress?.done ?? 0}/${batchProgress?.total ?? selectedCount}…` : 'Generate Sekarang' }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- AI POLLING OVERLAY -->
    <MaterialAiPollingOverlay
      :visible="aiPolling !== null"
      :title="aiPolling?.title"
      :subtitle="aiPolling?.subtitle"
      :estimated-seconds="aiPolling?.estimatedSeconds ?? 60"
      :timed-out="aiPolling?.timedOut === true"
      @cancel="closeAiOverlay"
      @retry="retryAiPoll"
    />

    <!-- SECTION EDITOR -->
    <MaterialSectionEditorModal
      :open="editorTarget !== null"
      :field-label="editorTarget?.label ?? ''"
      :field-key="editorTarget?.key ?? ''"
      :current-value="editorTarget?.value ?? ''"
      :mode="editorTarget?.mode ?? 'text'"
      :helper-text="
        editorTarget?.mode === 'list'
          ? 'Setiap baris akan jadi satu item nomor.'
          : 'Edit lokal — akan reset bila kamu regenerate konten AI.'
      "
      @close="editorTarget = null"
      @save="saveSectionEdit"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>

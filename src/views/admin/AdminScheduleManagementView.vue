<!--
  AdminScheduleManagementView.vue — Admin Schedule hub.

  Web port of Flutter's `TeachingScheduleManagementScreen` (admin role).

  Layout:
    1. BrandPageHeader (admin) — kicker + title + actions
    2. KpiStripCards — Total / Hari Ini / Bentrok / Teacher
    3. PageFilterToolbar — chips for Teacher / Mapel / Hari / Kelas / Jam + search
    4. View toggle (List / Timetable) — persisted in localStorage
    5. Body — sticky-day list OR per-class Pola C timetable grid
    6. Floating "Tambah" + bulk-mode CTAs (Phase 3+ wires them)

  Endpoints:
    GET /teaching-schedule         — paginated list (with filters)
    GET /teaching-schedule/all     — non-paginated (list-view backing data)
    GET /teaching-schedules/matrix — per-class week grid (Pola C, Sprint 3)
    GET /teaching-schedule/filter-options — dropdown options
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { ScheduleService } from '@/services/schedule.service';
import { LessonHourService } from '@/services/lesson-hour.service';
import { SubjectService } from '@/services/subjects.service';
import { subjectLabel } from '@/lib/labels';
import type {
  AdminScheduleFilters,
} from '@/services/schedule.service';
import {
  DAY_ORDER,
  type DayKey,
  type LessonHour,
  type ScheduleFilterOptions,
  type ScheduleRow,
  type ScheduleStats,
} from '@/types/schedule';
import { useAcademicYearStore } from '@/stores/academic-year';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import ScheduleFormModal from '@/components/feature/ScheduleFormModal.vue';
import ScheduleTimetableGrid, {
  type TimetableCreatePayload,
} from '@/components/feature/ScheduleTimetableGrid.vue';
import ScheduleDetailModal from '@/components/feature/ScheduleDetailModal.vue';
import SingleRescheduleModal from '@/components/feature/SingleRescheduleModal.vue';
import ChangeTeacherModal from '@/components/feature/ChangeTeacherModal.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import BulkDayPickerModal from '@/components/feature/BulkDayPickerModal.vue';
import BulkTeacherPickerModal from '@/components/feature/BulkTeacherPickerModal.vue';
import SchedulePrintScopeModal from '@/components/feature/SchedulePrintScopeModal.vue';
import ScheduleImportModal, {
  type ScheduleImportResults,
} from '@/components/feature/ScheduleImportModal.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useRouter } from 'vue-router';
import { storage } from '@/lib/storage';

const { t: $t } = useI18n();
const ayStore = useAcademicYearStore();
const router = useRouter();

// ── Data ────────────────────────────────────────────────────────────
const rows = ref<ScheduleRow[]>([]);
// stats is now a pure client-side derivation off `filteredRows` — see
// the `stats` computed further down. The old ref + /stats fetch was
// removed as part of the single-fetch-per-AY refactor.
const filterOptions = ref<ScheduleFilterOptions | null>(null);
const lessonHours = ref<LessonHour[]>([]);
/** True only when the lesson-hours request errored. Lets us tell a
 * school that genuinely hasn't configured its Jam Pelajaran (actionable)
 * apart from a request that simply failed (not the school's fault, and
 * not something the settings page would fix). */
const hoursLoadFailed = ref(false);
// Full school subject list — used to populate the Mapel filter so the
// list view offers every subject (not just the ones present in the
// currently-loaded/paginated rows). Matches the matrix view's coverage.
const allSubjects = ref<Array<{ id: string; name: string; code?: string | null }>>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Filters ─────────────────────────────────────────────────────────
const filterTeacherId = ref<string>('');
const filterClassId = ref<string>('');
const filterDayId = ref<string>('');
const filterSubjectId = ref<string>('');
const filterHourNumber = ref<number | ''>('');
const search = ref<string>('');

const showTeacherSheet = ref(false);
const showClassSheet = ref(false);
const showDaySheet = ref(false);
const showSubjectSheet = ref(false);
const showHourSheet = ref(false);

// View mode: list (sticky-day grouped) | timetable (Pola C per-class
// week grid, Sprint 3 MR C). The old drag-drop `matrix` mode is gone —
// it showed all classes' cells overlaid in the same week grid, which
// broke down for any school with more than a handful of teachers. The
// new timetable view is a strict per-class read that also serves as an
// entry surface (empty cell → CREATE with pre-fill, filled cell → EDIT).
type ViewMode = 'list' | 'timetable';
const VIEW_MODE_STORAGE_KEY = 'schedule_view_mode';
// Rehydrate the last-picked mode so a page reload lands where the
// admin left off. Ignored (falls back to 'list') if storage was
// tampered with or holds an unknown legacy value.
const initialViewMode: ViewMode = (() => {
  const raw = storage.get<string>(VIEW_MODE_STORAGE_KEY);
  return raw === 'timetable' || raw === 'list' ? raw : 'list';
})();
const viewMode = ref<ViewMode>(initialViewMode);
// Persist on every change — the storage layer no-ops in SSR so this is
// safe to call unconditionally.
watch(viewMode, (v) => storage.set(VIEW_MODE_STORAGE_KEY, v));

// Timetable grid ref — the parent calls .refresh() after ScheduleFormModal
// saves so the matrix picks up the just-created/edited cell in place.
const timetableGridRef = ref<InstanceType<typeof ScheduleTimetableGrid> | null>(
  null,
);
// Pola C pre-fill payload — set when the admin clicks an empty cell in
// the timetable grid. Consumed by ScheduleFormModal via props (see
// preFilledClassId / preFilledDayId / preFilledLessonHourId).
const prefill = ref<TimetableCreatePayload | null>(null);
const skipSetupForForm = ref(false);

// ── Loaders ─────────────────────────────────────────────────────────
function activeFilters(): AdminScheduleFilters {
  return {
    teacher_id: filterTeacherId.value || undefined,
    class_id: filterClassId.value || undefined,
    day_id: filterDayId.value || undefined,
    subject_id: filterSubjectId.value || undefined,
    hour_number: filterHourNumber.value === '' ? undefined : filterHourNumber.value,
    search: search.value.trim() || undefined,
  };
}

async function loadFilterOptions() {
  filterOptions.value = await ScheduleService.getFilterOptions({
    academic_year_id: ayStore.selectedYearId ?? undefined,
  });
}

async function loadLessonHours() {
  // One-shot — lesson hours drive the "has no Jam Pelajaran" banner
  // above the toolbar. The timetable grid does its own hour lookup
  // via /matrix; this fetch is only kept so the top-of-page banner
  // can distinguish "school hasn't seeded hours" from "school just
  // hasn't loaded them yet".
  hoursLoadFailed.value = false;
  try {
    lessonHours.value = await LessonHourService.list();
  } catch {
    hoursLoadFailed.value = true;
    lessonHours.value = [];
  }
}

/**
 * The school has no Jam Pelajaran configured. Everything downstream of
 * it is quietly dead: "Tambah Sesi" opens a form whose Jam Pelajaran
 * picker can never be filled, so its save button can never enable. The
 * page's own empty state ("Tap tombol + …") points straight into that
 * dead-end, so we surface the real blocker up front instead.
 *
 * Note the Excel import is NOT blocked by this — it detects unregistered
 * hours and offers to register them from the file (MISSING_LESSON_HOURS
 * → "Daftarkan & Impor"), which is why the banner names it as the other
 * way out rather than warning the admin off it.
 */
const hasNoLessonHours = computed(
  () => !isLoading.value && !hoursLoadFailed.value && lessonHours.value.length === 0,
);

async function loadAllSubjects() {
  // One-shot — the full school subject catalogue. The Mapel filter
  // reads from this so the list view offers every subject, not just
  // the few that appear in the currently-loaded rows.
  try {
    const res = await SubjectService.list({ per_page: 200 });
    // Keep `code` — several subjects share a name (Al Qur'an Hadis 7/8/9)
    // and the Mapel filter can only tell them apart by their code.
    allSubjects.value = res.items.map((s) => ({
      id: s.id,
      name: s.name,
      code: s.code ?? null,
    }));
  } catch {
    allSubjects.value = [];
  }
}

// Single-fetch model: the /teaching-schedule/all endpoint returns
// EVERY session for the current AY + semester in one shot. We keep
// that entire dataset in `rows` and let the filter chips, search box,
// view-mode toggle, and KPI counters all read from CLIENT-SIDE
// computeds derived from it. That is what the user asked for —
// "kenapa ganti view selalu fetch" — and the network tab now shows
// a single /all + /stats call per AY change instead of a fetch per
// interaction.
async function loadRows() {
  isLoading.value = true;
  error.value = null;
  try {
    // Deliberately NOT passing activeFilters() — the /all endpoint
    // only honours AY + semester server-side; sending chip filters
    // (teacher/class/day/subject/hour/search) here would be a wasted
    // round-trip since we re-apply them client-side anyway.
    rows.value = await ScheduleService.listAll({});
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await Promise.all([loadFilterOptions(), loadLessonHours(), loadAllSubjects()]);
  await loadRows();
});

useAcademicYearWatcher(async () => {
  await Promise.all([loadFilterOptions(), loadLessonHours(), loadAllSubjects()]);
  await loadRows();
});

// No watchers on filter chips / search / viewMode — the computed
// pipeline (filteredRows → rowsByDay + matrixRows + statsLive) reacts
// synchronously and never issues a network call. The KPI header keeps
// its old "total: 42" vs "conflicts: 12" split by reading from the
// same client-side stats derivation.

// ── Filter chip values ──────────────────────────────────────────────
const teacherChipValue = computed(() => {
  if (!filterTeacherId.value) return $t('admin.schedule.allTeachers');
  return filterOptions.value?.teachers.find((t) => t.id === filterTeacherId.value)?.name ?? '—';
});
const classChipValue = computed(() => {
  if (!filterClassId.value) return $t('admin.schedule.allClasses');
  return filterOptions.value?.classes.find((c) => c.id === filterClassId.value)?.name ?? '—';
});
const dayChipValue = computed(() => {
  if (!filterDayId.value) return $t('admin.schedule.allDays');
  return filterOptions.value?.days.find((d) => d.id === filterDayId.value)?.name ?? '—';
});
const subjectChipValue = computed(() => {
  if (!filterSubjectId.value) return $t('admin.schedule.allSubjects');
  // Prefer the full subject catalogue (covers subjects not in current rows);
  // fall back to deriving the name from the loaded rows.
  const fromCatalogue = allSubjects.value.find((s) => s.id === filterSubjectId.value);
  if (fromCatalogue) return subjectLabel(fromCatalogue);
  const found = rows.value.find((r) => r.subject_id === filterSubjectId.value);
  return found?.subject_name ?? '—';
});
const hourChipValue = computed(() => {
  if (filterHourNumber.value === '') return $t('admin.schedule.allHours');
  return $t('admin.schedule.hourNumber', { n: filterHourNumber.value });
});

// Subject options for the Mapel filter. Prefer the full school subject
// catalogue so the list view offers every subject (bug: it used to show
// only the handful present in the currently-loaded rows). Fall back to
// deriving from rows if the catalogue couldn't be loaded.
//
// Carries `code` through so same-named subjects stay distinguishable in
// the picker. The rows fallback can't: ScheduleRow has no subject code
// field, and this branch only runs when the catalogue fetch FAILED, so
// there is nothing to look the code up against. Those options degrade to
// name-only rather than showing a made-up code.
const subjectOptions = computed(() => {
  const seen = new Map<string, { id: string; name: string; code?: string | null }>();
  if (allSubjects.value.length > 0) {
    for (const s of allSubjects.value) {
      if (!seen.has(s.id)) {
        seen.set(s.id, { id: s.id, name: s.name, code: s.code ?? null });
      }
    }
  } else {
    for (const r of rows.value) {
      if (!seen.has(r.subject_id)) {
        seen.set(r.subject_id, { id: r.subject_id, name: r.subject_name, code: null });
      }
    }
  }
  return Array.from(seen.values()).sort((a, b) => a.name.localeCompare(b.name, 'id'));
});

// Localised day labels — the static DAY_LABELS export stays Indonesian
// for any non-UI consumer (sort keys, exports, etc.). The view-layer
// version below tracks the active i18n locale so headers + chips read
// "MONDAY" in English mode.
const LOCALIZED_DAY_LABELS = computed<Record<string, string>>(() => ({
  mon: $t('admin.schedule.dayMon'),
  tue: $t('admin.schedule.dayTue'),
  wed: $t('admin.schedule.dayWed'),
  thu: $t('admin.schedule.dayThu'),
  fri: $t('admin.schedule.dayFri'),
  sat: $t('admin.schedule.daySat'),
  sun: $t('admin.schedule.daySun'),
}));

// Hour options derived from rows (or from /filter-options once we expose them).
const hourOptions = computed(() => {
  const seen = new Set<number>();
  for (const r of rows.value) {
    if (r.hour_number > 0) seen.add(r.hour_number);
  }
  return Array.from(seen).sort((a, b) => a - b);
});

// ── KPI cards ───────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const s = stats.value;
  return [
    {
      icon: 'calendar',
      label: $t('admin.schedule.kpiTotalSessions'),
      value: s?.total ?? rows.value.length,
      tone: 'brand',
    },
    {
      icon: 'sun',
      label: $t('admin.schedule.kpiToday'),
      value: s?.today ?? 0,
      tone: 'amber',
      accented: (s?.today ?? 0) > 0,
    },
    {
      icon: 'alert-triangle',
      label: $t('admin.schedule.kpiConflicts'),
      value: s?.conflicts ?? 0,
      tone: (s?.conflicts ?? 0) > 0 ? 'red' : 'slate',
      accented: (s?.conflicts ?? 0) > 0,
    },
    {
      icon: 'users',
      label: $t('admin.schedule.kpiActiveTeachers'),
      value: s?.total_teachers ?? 0,
      tone: 'violet',
    },
  ];
});

// ── Shared client-side filter for BOTH views ───────────────────────
//
// The full /teaching-schedule/all payload lives in `rows`. Both the
// sticky-day list AND the week-grid matrix render off this single
// filtered slice, so switching view mode is a pure re-render — no
// network call. Filter chips + search are also client-side; the only
// reason to hit the network is an AY change.
const filteredRows = computed<ScheduleRow[]>(() => {
  return rows.value.filter((r) => {
    if (filterTeacherId.value && r.teacher_id !== filterTeacherId.value) return false;
    if (filterClassId.value && r.class_id !== filterClassId.value) return false;
    if (filterDayId.value && r.day_id !== filterDayId.value) return false;
    if (filterSubjectId.value && r.subject_id !== filterSubjectId.value) return false;
    if (filterHourNumber.value !== '' && r.hour_number !== filterHourNumber.value) return false;
    if (search.value.trim()) {
      const q = search.value.trim().toLowerCase();
      const haystack = [r.subject_name, r.class_name, r.teacher_name ?? '']
        .join(' ')
        .toLowerCase();
      if (!haystack.includes(q)) return false;
    }
    return true;
  });
});

// ── List grouping (sticky day) ──────────────────────────────────────
const rowsByDay = computed<Record<DayKey, ScheduleRow[]>>(() => {
  const out: Record<DayKey, ScheduleRow[]> = {
    mon: [], tue: [], wed: [], thu: [], fri: [], sat: [],
  };
  for (const r of filteredRows.value) out[r.day].push(r);
  for (const k of DAY_ORDER) {
    out[k].sort((a, b) => {
      if (a.hour_number !== b.hour_number) return a.hour_number - b.hour_number;
      return a.start_time.localeCompare(b.start_time);
    });
  }
  return out;
});

// ── Client-side stats derivation ────────────────────────────────────
//
// Replaces the /teaching-schedule/stats network call. Every field the
// KPI cards + header meta line read comes from the already-fetched
// rows. `today` mirrors the server's Carbon::now()->format('l') logic
// by matching today's day-of-week key against ScheduleRow.day (which
// the backend seeds lowercase mon/tue/…). Sunday returns undefined
// and yields a zero count — schools don't schedule Sundays here.
const DAY_KEY_BY_JS_INDEX: Record<number, DayKey | undefined> = {
  0: undefined,
  1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu', 5: 'fri', 6: 'sat',
};
const stats = computed<ScheduleStats>(() => {
  const scope = filteredRows.value;
  const teachers = new Set<string>();
  const classes = new Set<string>();
  const subjects = new Set<string>();
  let conflicts = 0;
  let today = 0;
  const todayKey = DAY_KEY_BY_JS_INDEX[new Date().getDay()];
  for (const r of scope) {
    if (r.teacher_id) teachers.add(r.teacher_id);
    if (r.class_id) classes.add(r.class_id);
    if (r.subject_id) subjects.add(r.subject_id);
    if (r.conflict_with && r.conflict_with.length > 0) conflicts += 1;
    if (todayKey && r.day === todayKey) today += 1;
  }
  return {
    total: scope.length,
    total_teachers: teachers.size,
    total_classes: classes.size,
    total_subjects: subjects.size,
    today,
    conflicts,
  };
});

const listState = computed<AsyncState<ScheduleRow[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

// ── Active filter count for the clear-all chip ──────────────────────
const activeFilterCount = computed(() => {
  let n = 0;
  if (filterTeacherId.value) n++;
  if (filterClassId.value) n++;
  if (filterDayId.value) n++;
  if (filterSubjectId.value) n++;
  if (filterHourNumber.value !== '') n++;
  if (search.value.trim()) n++;
  return n;
});

function clearFilters() {
  filterTeacherId.value = '';
  filterClassId.value = '';
  filterDayId.value = '';
  filterSubjectId.value = '';
  filterHourNumber.value = '';
  search.value = '';
}

// Header meta shows dashes while the first fetch is in flight — a bare
// "0 sesi · 0 bentrok · TP —" reads like real data ("this school has no
// sessions"), which is misleading before we've heard back from the API.
// Once loaded, the real values render.
const headerMeta = computed(() => {
  if (isLoading.value && rows.value.length === 0) {
    return $t('admin.schedule.meta', {
      sessions: '—',
      conflicts: '—',
      year: ayStore.yearLabel || '—',
    });
  }
  return $t('admin.schedule.meta', {
    sessions: stats.value?.total ?? rows.value.length,
    conflicts: stats.value?.conflicts ?? 0,
    year: ayStore.yearLabel,
  });
});

// CRUD modal state
const showForm = ref(false);
const editingRow = ref<ScheduleRow | null>(null);

// Detail sheet + per-row action modals
const detailRow = ref<ScheduleRow | null>(null);
const rescheduleRow = ref<ScheduleRow | null>(null);
const changeTeacherRow = ref<ScheduleRow | null>(null);
const deleteRow = ref<ScheduleRow | null>(null);
const isDeleting = ref(false);

function onAddClick() {
  editingRow.value = null;
  prefill.value = null;
  skipSetupForForm.value = false;
  showForm.value = true;
}
function onRowClick(row: ScheduleRow) {
  detailRow.value = row;
}
function onSaved(rows: ScheduleRow[]) {
  toast.value = {
    message: editingRow.value
      ? 'Jadwal diperbarui.'
      : `${rows.length} jadwal dibuat.`,
    tone: 'success',
  };
  // The list view reads from the shared `rows` cache; the timetable
  // grid reads from its own /matrix cache. Refresh both so either view
  // is fresh whichever one the admin is looking at right now.
  void loadRows();
  timetableGridRef.value?.refresh();
}

// ── Pola C timetable grid handlers ─────────────────────────────────
//
// The grid emits either an `edit` (schedule_id) or a `create`
// (pre-fill payload). Both paths reuse ScheduleFormModal; the create
// path also flips skipSetupForForm so the modal doesn't briefly show
// the setup checklist for a school whose class + hours were just
// visibly rendered as an empty cell.
function onTimetableEdit(scheduleId: string) {
  const row = rows.value.find((r) => r.id === scheduleId);
  if (!row) {
    // rows[] is the full /all cache — a miss means the grid saw a
    // schedule the list load missed (rare: race between /all and
    // /matrix after a fresh create). Fall through to a light message
    // rather than opening the modal on a stale/empty row.
    toast.value = {
      message: 'Jadwal tidak ditemukan di cache — coba muat ulang halaman.',
      tone: 'error',
    };
    return;
  }
  editingRow.value = row;
  prefill.value = null;
  skipSetupForForm.value = false;
  showForm.value = true;
}

function onTimetableCreate(payload: TimetableCreatePayload) {
  editingRow.value = null;
  prefill.value = payload;
  skipSetupForForm.value = true;
  showForm.value = true;
}

function onFormClose() {
  showForm.value = false;
  prefill.value = null;
  skipSetupForForm.value = false;
}

// Detail action handlers
function detailEdit() {
  if (!detailRow.value) return;
  editingRow.value = detailRow.value;
  detailRow.value = null;
  showForm.value = true;
}
function detailReschedule() {
  rescheduleRow.value = detailRow.value;
  detailRow.value = null;
}
function detailChangeTeacher() {
  changeTeacherRow.value = detailRow.value;
  detailRow.value = null;
}
async function detailDuplicate() {
  if (!detailRow.value) return;
  // "Duplikat" = clone with same teacher/subject/class/day/hour but
  // server-side dedupe will reject identical row. Easiest is to open
  // the form pre-filled and let the admin tweak day/hour before save.
  editingRow.value = { ...detailRow.value, id: '' };
  detailRow.value = null;
  showForm.value = true;
}
function detailDelete() {
  deleteRow.value = detailRow.value;
  detailRow.value = null;
}

async function confirmDelete() {
  if (!deleteRow.value) return;
  isDeleting.value = true;
  try {
    await ScheduleService.destroy(deleteRow.value.id);
    toast.value = { message: 'Jadwal dihapus.', tone: 'success' };
    await loadRows();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDeleting.value = false;
    deleteRow.value = null;
  }
}

function onRescheduled(_: ScheduleRow) {
  toast.value = { message: 'Slot dipindahkan.', tone: 'success' };
  void loadRows();
}
function onTeacherChanged(_: ScheduleRow) {
  toast.value = { message: 'Guru diganti.', tone: 'success' };
  void loadRows();
}

// ── Bulk select state ──────────────────────────────────────────────
const bulkMode = ref(false);
const selectedIds = ref<Set<string>>(new Set());
const showBulkDay = ref(false);
const showBulkTeacher = ref(false);
const showBulkDelete = ref(false);
const isBulkDeleting = ref(false);

function enterBulkMode() {
  bulkMode.value = true;
  selectedIds.value = new Set();
}
function exitBulkMode() {
  bulkMode.value = false;
  selectedIds.value = new Set();
}
function toggleSelect(id: string) {
  const set = new Set(selectedIds.value);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  selectedIds.value = set;
}
function selectAllVisible() {
  if (selectedIds.value.size === rows.value.length) {
    selectedIds.value = new Set();
  } else {
    selectedIds.value = new Set(rows.value.map((r) => r.id));
  }
}
const selectedRows = computed(() =>
  rows.value.filter((r) => selectedIds.value.has(r.id)),
);

function onBulkMoved(result: { moved: number; skipped: number }) {
  const skipNote = result.skipped > 0 ? ` · ${result.skipped} dilewati` : '';
  toast.value = {
    message: `${result.moved} jadwal dipindahkan${skipNote}.`,
    tone: 'success',
  };
  exitBulkMode();
  void loadRows();
}
function onBulkTeacherChanged(result: { changed: number; skipped: number }) {
  const skipNote = result.skipped > 0 ? ` · ${result.skipped} dilewati` : '';
  toast.value = {
    message: `${result.changed} jadwal diganti guru${skipNote}.`,
    tone: 'success',
  };
  exitBulkMode();
  void loadRows();
}
// Print + Import modal state
const showPrint = ref(false);
const showImport = ref(false);

function onImportDone(res: ScheduleImportResults) {
  // Compose a toast that surfaces every non-zero bucket the backend
  // reported. Previously we only read `created` + `skipped`, so
  // `restored` (soft-deleted schedules re-hydrated on re-import) and
  // `failed` (per-row rejections that didn't abort the whole file)
  // were silently discarded.
  const parts: string[] = [`${res.created} jadwal diimpor`];
  if (res.restored > 0) parts.push(`${res.restored} dipulihkan`);
  if (res.skipped > 0) parts.push(`${res.skipped} dilewati`);
  if (res.failed > 0) parts.push(`${res.failed} gagal`);
  toast.value = {
    message: `${parts.join(' · ')}.`,
    tone: res.failed > 0 ? 'error' : 'success',
  };
  void loadRows();
}

async function bulkDelete() {
  if (selectedIds.value.size === 0) return;
  isBulkDeleting.value = true;
  try {
    const res = await ScheduleService.bulkDestroy(Array.from(selectedIds.value));
    toast.value = {
      message: `${res.deleted_count} jadwal dihapus.`,
      tone: 'success',
    };
    exitBulkMode();
    await loadRows();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isBulkDeleting.value = false;
    showBulkDelete.value = false;
  }
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="$t('admin.shared.kicker')"
      :title="$t('admin.schedule.title')"
      :meta="headerMeta"
    >
      <div class="flex items-center gap-2 flex-wrap">
        <SegmentedControl
          v-model="viewMode"
          :options="[
            { key: 'list', label: $t('admin.schedule.viewList') },
            { key: 'timetable', label: $t('admin.schedule.viewTimetable') },
          ]"
        />
        <button
          type="button"
          class="text-2xs font-bold text-white/90 hover:text-white px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
          @click="showPrint = true"
        >
          <NavIcon name="download" :size="11" class="inline" />
          {{ $t('admin.schedule.print') }}
        </button>
        <button
          type="button"
          class="text-2xs font-bold text-white/90 hover:text-white px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
          @click="showImport = true"
        >
          <NavIcon name="upload" :size="11" class="inline" />
          {{ $t('admin.schedule.import') }}
        </button>
        <button
          type="button"
          class="text-2xs font-bold text-white/90 hover:text-white px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
          @click="router.push({ name: 'admin.schedule.lesson-hours' })"
        >
          <NavIcon name="clock" :size="11" class="inline" />
          {{ $t('admin.schedule.lessonHours') }}
        </button>
      </div>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" :loading="isLoading && rows.length === 0" />

    <!-- Jam Pelajaran not set up — manual "Tambah Sesi" cannot work until
         it is, so say so here rather than letting the admin discover it
         as a permanently-disabled save button. -->
    <button
      v-if="hasNoLessonHours"
      type="button"
      class="w-full text-left rounded-2xl border border-dashed border-amber-300 bg-amber-50 p-4 hover:bg-amber-100 transition-colors"
      @click="router.push({ name: 'admin.schedule.lesson-hours' })"
    >
      <p class="text-3xs font-bold uppercase tracking-widest text-amber-700 flex items-center gap-1.5">
        <NavIcon name="alert-triangle" :size="12" />
        {{ $t('admin.schedule.emptyLessonHours.badge') }}
      </p>
      <p class="text-[13px] font-bold text-amber-900 mt-1">
        {{ $t('admin.schedule.emptyLessonHours.pageDesc') }}
      </p>
      <p class="text-2xs text-amber-700 mt-1.5 leading-relaxed">
        <span class="font-bold">{{ $t('admin.schedule.emptyLessonHours.cta') }}</span> ·
        {{ $t('admin.schedule.emptyLessonHours.menuHint') }}
      </p>
      <p class="text-2xs text-amber-700 mt-1 leading-relaxed">
        {{ $t('admin.schedule.emptyLessonHours.importAlternative') }}
      </p>
    </button>

    <PageFilterToolbar
      v-model:search="search"
      :search-placeholder="$t('admin.schedule.searchPlaceholder')"
      :search-min-width="240"
    >
      <template #chips>
        <AppFilterChip
          icon-name="user"
          :label="$t('admin.schedule.filterTeacher')"
          :value="teacherChipValue"
          tone="violet"
          @click="showTeacherSheet = true"
        />
        <AppFilterChip
          icon-name="book-open"
          :label="$t('admin.schedule.filterSubject')"
          :value="subjectChipValue"
          tone="brand"
          @click="showSubjectSheet = true"
        />
        <AppFilterChip
          icon-name="calendar"
          :label="$t('admin.schedule.filterDay')"
          :value="dayChipValue"
          tone="amber"
          @click="showDaySheet = true"
        />
        <AppFilterChip
          icon-name="layers"
          :label="$t('admin.schedule.filterClass')"
          :value="classChipValue"
          tone="green"
          @click="showClassSheet = true"
        />
        <AppFilterChip
          icon-name="clock"
          :label="$t('admin.schedule.filterHour')"
          :value="hourChipValue"
          tone="red"
          @click="showHourSheet = true"
        />
        <button
          v-if="activeFilterCount > 0"
          type="button"
          class="text-2xs font-bold text-slate-500 hover:text-role-admin px-2"
          @click="clearFilters"
        >
          {{ $t('common.reset') }} ({{ activeFilterCount }})
        </button>
        <button
          type="button"
          class="text-2xs font-bold px-3 py-1.5 rounded-lg border transition-colors"
          :class="
            bulkMode
              ? 'bg-role-admin text-white border-role-admin'
              : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
          "
          @click="bulkMode ? exitBulkMode() : enterBulkMode()"
        >
          <NavIcon name="check-square" :size="11" class="inline" />
          {{ bulkMode ? $t('common.done') : $t('admin.schedule.select') }}
        </button>
      </template>
    </PageFilterToolbar>

    <!-- TIMETABLE VIEW — Pola C per-class week grid (Sprint 3 MR C).
         Rendered OUTSIDE AsyncView because it uses its own /matrix
         data source and manages its own loading / error / empty
         states; wrapping it in AsyncView would swap it out for the
         list-view spinner whenever the /all fetch was in flight. -->
    <ScheduleTimetableGrid
      v-if="viewMode === 'timetable'"
      ref="timetableGridRef"
      :filter-options="filterOptions"
      :default-semester-id="filterOptions?.semesters?.[0]?.id"
      :options-loading="filterOptions === null"
      @edit="onTimetableEdit"
      @create="onTimetableCreate"
    />

    <AsyncView
      v-else
      :state="listState"
      :empty-title="$t('admin.schedule.emptyTitle')"
      :empty-description="$t('admin.schedule.emptyDesc')"
      empty-icon="calendar"
      @retry="loadRows"
    >
      <template #default>
        <!-- LIST VIEW — sticky day groups -->
        <div class="space-y-4">
          <section
            v-for="d in DAY_ORDER"
            :key="d"
            v-show="rowsByDay[d].length > 0"
            class="space-y-2"
          >
            <header class="flex items-center justify-between sticky top-0 z-10 bg-slate-50 py-2 px-1 rounded-lg">
              <h3 class="text-2xs font-black text-slate-700 uppercase tracking-widest">
                {{ LOCALIZED_DAY_LABELS[d] }}
              </h3>
              <span class="text-3xs font-bold text-slate-400">
                {{ $t('admin.schedule.sessionsCount', { count: rowsByDay[d].length }) }}
              </span>
            </header>
            <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
              <div
                v-for="(r, idx) in rowsByDay[d]"
                :key="r.id"
                class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-slate-50 transition-colors cursor-pointer"
                :class="[
                  idx > 0 ? 'border-t border-slate-100' : '',
                  r.conflict_with && r.conflict_with.length > 0 ? 'bg-red-50/40' : '',
                  bulkMode && selectedIds.has(r.id) ? 'bg-role-admin/5' : '',
                ]"
                @click="bulkMode ? toggleSelect(r.id) : onRowClick(r)"
              >
                <input
                  v-if="bulkMode"
                  type="checkbox"
                  class="w-4 h-4 accent-role-admin flex-shrink-0"
                  :checked="selectedIds.has(r.id)"
                  @click.stop="toggleSelect(r.id)"
                />
                <div class="w-12 text-center flex-shrink-0">
                  <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">JP</p>
                  <p class="text-[15px] font-black text-role-admin">{{ r.hour_number }}</p>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-[13px] font-bold text-slate-900 truncate">
                    {{ r.subject_name }}
                    <span v-if="r.conflict_with && r.conflict_with.length > 0" class="text-red-600 ml-1">⚠ {{ $t('admin.schedule.conflictBadge') }}</span>
                  </p>
                  <p class="text-2xs text-slate-500 truncate">
                    {{ r.class_name }} · {{ r.teacher_name ?? 'Tanpa guru' }}
                    <span v-if="r.room"> · {{ r.room }}</span>
                  </p>
                </div>
                <div class="text-right flex-shrink-0">
                  <p class="text-[12px] font-bold text-slate-900 tabular-nums">
                    {{ r.start_time }}–{{ r.end_time }}
                  </p>
                </div>
                <NavIcon name="chevron-right" :size="14" class="text-slate-300 ml-1" />
              </div>
            </div>
          </section>
        </div>

      </template>
    </AsyncView>

    <!-- Floating Tambah CTA — hidden when in bulk mode -->
    <Button
      v-if="!bulkMode"
      variant="primary"
      class="fixed bottom-6 right-6 z-30 shadow-lg shadow-role-admin/30"
      @click="onAddClick"
    >
      <NavIcon name="plus" :size="14" />
      {{ $t('admin.schedule.addFab') }}
    </Button>

    <!-- Bulk action bar — sticky bottom when rows selected -->
    <section
      v-if="bulkMode"
      class="fixed bottom-4 left-1/2 -translate-x-1/2 z-30 bg-white border border-slate-200 rounded-2xl shadow-lg p-3 flex items-center gap-2 max-w-2xl w-[calc(100%-2rem)]"
    >
      <button
        type="button"
        class="text-2xs font-bold text-slate-600 hover:text-role-admin px-2"
        @click="selectAllVisible"
      >
        {{ selectedIds.size === rows.length ? $t('admin.sekolah.schedule_management.unselect_all') : $t('admin.sekolah.schedule_management.select_all') }}
      </button>
      <span class="text-2xs text-slate-400">·</span>
      <p class="text-2xs font-bold text-slate-700 flex-1">
        {{ $t('admin.sekolah.schedule_management.selected_count', { count: selectedIds.size }) }}
      </p>
      <Button variant="secondary" size="sm" :disabled="selectedIds.size === 0" @click="showBulkDay = true">
        <NavIcon name="move" :size="12" />
        {{ $t('admin.sekolah.schedule_management.move_day') }}
      </Button>
      <Button variant="secondary" size="sm" :disabled="selectedIds.size === 0" @click="showBulkTeacher = true">
        <NavIcon name="user" :size="12" />
        {{ $t('admin.sekolah.schedule_management.change_teacher') }}
      </Button>
      <Button variant="danger" size="sm" :disabled="selectedIds.size === 0" @click="showBulkDelete = true">
        <NavIcon name="trash-2" :size="12" />
        {{ $t('admin.sekolah.schedule_management.bulk_delete', { count: selectedIds.size }) }}
      </Button>
    </section>

    <!-- Filter sheets -->
    <Modal
      v-if="showTeacherSheet"
      :title="$t('admin.sekolah.schedule_management.filter_teacher_title')"
      size="sm"
      @close="showTeacherSheet = false"
    >
      <div class="space-y-1 max-h-[60vh] overflow-y-auto">
        <button
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="!filterTeacherId ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterTeacherId = ''; showTeacherSheet = false"
        >
          {{ $t('admin.sekolah.schedule_management.all_teachers') }}
        </button>
        <button
          v-for="teacher in filterOptions?.teachers ?? []"
          :key="teacher.id"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="filterTeacherId === teacher.id ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterTeacherId = teacher.id; showTeacherSheet = false"
        >
          {{ teacher.name }}
        </button>
      </div>
    </Modal>

    <Modal
      v-if="showClassSheet"
      :title="$t('admin.sekolah.schedule_management.filter_class_title')"
      size="sm"
      @close="showClassSheet = false"
    >
      <div class="space-y-1 max-h-[60vh] overflow-y-auto">
        <button
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="!filterClassId ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterClassId = ''; showClassSheet = false"
        >
          {{ $t('admin.sekolah.schedule_management.all_classes') }}
        </button>
        <button
          v-for="c in filterOptions?.classes ?? []"
          :key="c.id"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="filterClassId === c.id ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterClassId = c.id; showClassSheet = false"
        >
          {{ c.name }}
          <span v-if="c.grade_level" class="text-3xs text-slate-500 font-medium ml-2">{{ $t('admin.sekolah.schedule_management.tingkat', { grade: c.grade_level }) }}</span>
        </button>
      </div>
    </Modal>

    <Modal
      v-if="showDaySheet"
      :title="$t('admin.sekolah.schedule_management.filter_day_title')"
      size="sm"
      @close="showDaySheet = false"
    >
      <div class="space-y-1">
        <button
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="!filterDayId ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterDayId = ''; showDaySheet = false"
        >
          {{ $t('admin.sekolah.schedule_management.all_days') }}
        </button>
        <button
          v-for="d in filterOptions?.days ?? []"
          :key="d.id"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="filterDayId === d.id ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterDayId = d.id; showDaySheet = false"
        >
          {{ d.name }}
        </button>
      </div>
    </Modal>

    <Modal
      v-if="showSubjectSheet"
      title="Filter Mata Pelajaran"
      size="sm"
      @close="showSubjectSheet = false"
    >
      <div class="space-y-1 max-h-[60vh] overflow-y-auto">
        <button
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="!filterSubjectId ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterSubjectId = ''; showSubjectSheet = false"
        >
          Semua mapel
        </button>
        <button
          v-for="s in subjectOptions"
          :key="s.id"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="filterSubjectId === s.id ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterSubjectId = s.id; showSubjectSheet = false"
        >
          {{ subjectLabel(s) }}
        </button>
      </div>
    </Modal>

    <Modal
      v-if="showHourSheet"
      title="Filter Jam ke-"
      size="sm"
      @close="showHourSheet = false"
    >
      <div class="space-y-1 max-h-[60vh] overflow-y-auto">
        <button
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="filterHourNumber === '' ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterHourNumber = ''; showHourSheet = false"
        >
          Semua jam
        </button>
        <button
          v-for="h in hourOptions"
          :key="h"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="filterHourNumber === h ? 'bg-role-admin/10 text-role-admin' : 'text-slate-700 hover:bg-slate-50'"
          @click="filterHourNumber = h; showHourSheet = false"
        >
          Jam ke-{{ h }}
        </button>
      </div>
    </Modal>

    <ScheduleFormModal
      v-if="showForm"
      :row="editingRow"
      :filter-options="filterOptions"
      :default-semester-id="filterOptions?.semesters?.[0]?.id"
      :pre-filled-class-id="prefill?.class_id"
      :pre-filled-day-id="prefill?.day_id"
      :pre-filled-lesson-hour-id="prefill?.lesson_hour_id"
      :skip-setup-check="skipSetupForForm"
      @close="onFormClose"
      @saved="onSaved"
    />

    <ScheduleDetailModal
      v-if="detailRow"
      :row="detailRow"
      @close="detailRow = null"
      @edit="detailEdit"
      @reschedule="detailReschedule"
      @change-teacher="detailChangeTeacher"
      @duplicate="detailDuplicate"
      @delete="detailDelete"
    />

    <SingleRescheduleModal
      v-if="rescheduleRow"
      :row="rescheduleRow"
      :filter-options="filterOptions"
      @close="rescheduleRow = null"
      @done="onRescheduled"
    />

    <ChangeTeacherModal
      v-if="changeTeacherRow"
      :row="changeTeacherRow"
      :filter-options="filterOptions"
      @close="changeTeacherRow = null"
      @done="onTeacherChanged"
    />

    <ConfirmationDialog
      v-if="deleteRow"
      title="Hapus Jadwal"
      :message="`Hapus ${deleteRow.subject_name} (${deleteRow.class_name}) di ${deleteRow.start_time}? Tindakan ini permanen dan tidak bisa dibatalkan.`"
      confirm-label="Hapus"
      danger
      :loading="isDeleting"
      @close="deleteRow = null"
      @confirm="confirmDelete"
    />

    <BulkDayPickerModal
      v-if="showBulkDay"
      :rows="selectedRows"
      :filter-options="filterOptions"
      @close="showBulkDay = false"
      @done="onBulkMoved"
    />

    <BulkTeacherPickerModal
      v-if="showBulkTeacher"
      :rows="selectedRows"
      :filter-options="filterOptions"
      @close="showBulkTeacher = false"
      @done="onBulkTeacherChanged"
    />

    <ConfirmationDialog
      v-if="showBulkDelete"
      title="Hapus Jadwal Massal"
      :message="`Hapus ${selectedIds.size} jadwal terpilih? Tindakan ini akan men-soft-delete semua rownya.`"
      confirm-label="Hapus semua"
      danger
      :loading="isBulkDeleting"
      @close="showBulkDelete = false"
      @confirm="bulkDelete"
    />

    <SchedulePrintScopeModal
      v-if="showPrint"
      :filter-options="filterOptions"
      @close="showPrint = false"
      @done="toast = { message: 'PDF terdownload.', tone: 'success' }"
    />

    <ScheduleImportModal
      v-if="showImport"
      @close="showImport = false"
      @done="onImportDone"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>

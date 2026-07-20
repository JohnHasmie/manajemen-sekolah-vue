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
import CreateCombinedScheduleWizard from '@/views/admin/schedule/CreateCombinedScheduleWizard.vue';
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

// A2 entry — how many active slots lost their mapel (orphaned by a
// delete-then-reimport). Drives the "Sinkronkan Jadwal" header button,
// which only appears when there's something to fix. Fail-safe to 0 so a
// preview error never breaks the page chrome.
const resyncOrphanCount = ref(0);
async function loadResyncCount() {
  try {
    resyncOrphanCount.value = (await ScheduleService.resyncPreview()).total;
  } catch {
    resyncOrphanCount.value = 0;
  }
}

onMounted(async () => {
  await Promise.all([loadFilterOptions(), loadLessonHours(), loadAllSubjects()]);
  await loadRows();
  void loadResyncCount();
});

useAcademicYearWatcher(async () => {
  await Promise.all([loadFilterOptions(), loadLessonHours(), loadAllSubjects()]);
  await loadRows();
  void loadResyncCount();
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
    // Semua / Tunggal / Gabung — client-side filter for jadwal-gabung
    // discoverability. `single` = plain slot, `group` = row belongs to
    // a schedule_group. The pinned "Jadwal Gabung" section reads from
    // this same predicate so switching to "Tunggal" collapses it too.
    if (listFilter.value === 'single' && r.is_grouped) return false;
    if (listFilter.value === 'group' && !r.is_grouped) return false;
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

// ── Jadwal gabung — group aggregation for the pinned section ───
// The list view surfaces a pinned "⚭ Jadwal Gabung" section above
// the per-day groups, listing each group once (not once per member
// class row). Aggregate here so both the pinned section and the KPI
// counter chip read from the same source. Empty when the school has
// no group entries.
interface GroupedEntry {
  group_id: string;
  day: DayKey;
  day_id: string | null;
  day_name: string | null;
  hour_number: number;
  start_time: string;
  end_time: string;
  subject_name: string;
  teacher_name: string | null;
  room: string | null;
  members: Array<{ id: string; name: string }>;
  /** Primary row id — used by the click handler as an entry point
   *  to open the detail sheet (which the modal then treats as a
   *  group-scoped edit if the row is grouped). */
  primary_row_id: string;
}

const groupedEntries = computed<GroupedEntry[]>(() => {
  const byId = new Map<string, GroupedEntry>();
  // Note: we walk `rows` (not `filteredRows`) so the pinned section
  // always shows all group entries even if the list filter is set to
  // "Tunggal". Chip filters (teacher/class/day/subject/hour) DO apply
  // though — they scope the whole page.
  for (const r of rows.value) {
    if (!r.schedule_group_id) continue;
    if (filterTeacherId.value && r.teacher_id !== filterTeacherId.value) continue;
    if (filterDayId.value && r.day_id !== filterDayId.value) continue;
    if (filterSubjectId.value && r.subject_id !== filterSubjectId.value) continue;
    if (
      filterHourNumber.value !== '' &&
      r.hour_number !== filterHourNumber.value
    )
      continue;
    // Class filter is intentionally NOT honoured — a group whose
    // member set includes the filtered class should still appear
    // even when another sibling row satisfies the same filter.
    const existing = byId.get(r.schedule_group_id);
    if (existing) {
      if (!existing.members.some((m) => m.id === r.class_id)) {
        existing.members.push({ id: r.class_id, name: r.class_name });
      }
    } else {
      byId.set(r.schedule_group_id, {
        group_id: r.schedule_group_id,
        day: r.day,
        day_id: r.day_id ?? null,
        day_name: r.day_name ?? null,
        hour_number: r.hour_number,
        start_time: r.start_time,
        end_time: r.end_time,
        subject_name: r.subject_name,
        teacher_name: r.teacher_name ?? null,
        room: r.room ?? null,
        members: [{ id: r.class_id, name: r.class_name }],
        primary_row_id: r.id,
      });
    }
  }
  // Sort: day order → hour asc.
  const out = Array.from(byId.values());
  out.sort((a, b) => {
    const da = DAY_ORDER.indexOf(a.day);
    const db = DAY_ORDER.indexOf(b.day);
    if (da !== db) return da - db;
    return a.hour_number - b.hour_number;
  });
  return out;
});

/** Total number of unique group entries — used by the filter chip. */
const groupedEntryCount = computed(() => groupedEntries.value.length);

/**
 * Per-day dedup: a group appears once at the group's primary_row_id
 * in the day list, and sibling rows for the same group are hidden.
 * This stops "PJOK 7A" + "PJOK 7B" from appearing as two adjacent
 * rows in the day group — the pinned section already lists them once.
 */
const dedupedGroupIds = computed(() => {
  const primary = new Set<string>();
  for (const g of groupedEntries.value) primary.add(g.primary_row_id);
  return primary;
});

// ── List grouping (sticky day) ──────────────────────────────────────
//
// Grouped rows are collapsed: only the "primary" sibling of each
// jadwal-gabung group appears in the day list, tagged with an "⚭
// (bareng 7B)" inline indicator. Other siblings are hidden — they
// already read once in the pinned "⚭ Jadwal Gabung" section above.
// This stops "PJOK 7A" + "PJOK 7B" from appearing as two adjacent
// same-time rows, which would look like a duplication bug.
const rowsByDay = computed<Record<DayKey, ScheduleRow[]>>(() => {
  const out: Record<DayKey, ScheduleRow[]> = {
    mon: [], tue: [], wed: [], thu: [], fri: [], sat: [],
  };
  const primaryOfGroup = dedupedGroupIds.value;
  for (const r of filteredRows.value) {
    if (r.schedule_group_id && !primaryOfGroup.has(r.id)) {
      // Non-primary sibling of a group — hide from day list.
      continue;
    }
    out[r.day].push(r);
  }
  for (const k of DAY_ORDER) {
    out[k].sort((a, b) => {
      if (a.hour_number !== b.hour_number) return a.hour_number - b.hour_number;
      return a.start_time.localeCompare(b.start_time);
    });
  }
  return out;
});

/**
 * Look up the sibling class names for a grouped primary row (used by
 * the "⚭ (bareng 7B)" inline indicator). Returns [] for a non-grouped
 * row. Reads from the groupedEntries aggregate so members are already
 * deduped and consistent with the pinned section.
 */
function siblingsForGroupedRow(row: ScheduleRow): Array<{ id: string; name: string }> {
  if (!row.schedule_group_id) return [];
  const g = groupedEntries.value.find(
    (gg) => gg.group_id === row.schedule_group_id,
  );
  if (!g) return [];
  return g.members.filter((m) => m.id !== row.class_id);
}

/**
 * Human slot length between two "HH:MM" clock strings — "40m" / "1j 20m".
 * Powers the small duration hint under each list-row time anchor. Returns
 * '' when either bound is missing / unparseable / non-positive so the
 * template can hide it rather than print a nonsense "0m" / "-5m".
 */
function slotDuration(start: string, end: string): string {
  const toMinutes = (clock: string): number | null => {
    const m = /^(\d{1,2}):(\d{2})/.exec(clock ?? '');
    if (!m) return null;
    return Number(m[1]) * 60 + Number(m[2]);
  };
  const a = toMinutes(start);
  const b = toMinutes(end);
  if (a === null || b === null || b <= a) return '';
  const total = b - a;
  const hours = Math.floor(total / 60);
  const minutes = total % 60;
  if (hours > 0) return minutes > 0 ? `${hours}j ${minutes}m` : `${hours}j`;
  return `${minutes}m`;
}

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
/**
 * Jadwal gabung — dedicated 3-step wizard for creating a combined-
 * class schedule. Second entry point alongside the in-place toggle
 * on ScheduleFormModal; kept separate so a first-timer who's never
 * done a jadwal gabung sees the guided flow rather than a form
 * where the "combined" checkbox is easy to miss.
 */
const showCombinedWizard = ref(false);
/** FAB dropdown open state. */
const fabOpen = ref(false);
/** List-view filter chip: Semua / Tunggal / Gabung (jadwal gabung
 *  discoverability — pinned + inline options are complementary). */
type ListFilter = 'all' | 'single' | 'group';
const listFilter = ref<ListFilter>('all');

// Detail sheet + per-row action modals
const detailRow = ref<ScheduleRow | null>(null);
const rescheduleRow = ref<ScheduleRow | null>(null);
const changeTeacherRow = ref<ScheduleRow | null>(null);
const deleteRow = ref<ScheduleRow | null>(null);
const isDeleting = ref(false);

/** FAB dropdown option: single-class schedule (existing flow). */
function onFabAddSingle() {
  fabOpen.value = false;
  editingRow.value = null;
  prefill.value = null;
  skipSetupForForm.value = false;
  showForm.value = true;
}

/** FAB dropdown option: jadwal gabung wizard. */
function onFabAddCombined() {
  fabOpen.value = false;
  showCombinedWizard.value = true;
}

/** Backdrop click on the FAB dropdown — close the menu without opening
 *  anything. Rendered as a full-viewport transparent capture div while
 *  fabOpen is true. */
function closeFabMenu() {
  fabOpen.value = false;
}

/**
 * Click on a row in the pinned "Jadwal Gabung" section — open the
 * detail sheet for the group's primary row. The detail modal itself
 * exposes edit/delete controls; when the underlying row carries a
 * `schedule_group_id`, the form modal opens in group-aware mode and
 * the delete confirmation offers the "hapus semua kelas dalam
 * gabungan" cascade option.
 */
function onGroupEntryClick(g: { primary_row_id: string }) {
  const row = rows.value.find((r) => r.id === g.primary_row_id);
  if (row) detailRow.value = row;
}

/** Wizard save handler — mirrors onSaved's cache-refresh contract. */
function onCombinedSaved(created: ScheduleRow[]) {
  toast.value = {
    message: $t('admin.schedule.combined.savedToast', {
      count: created.length,
    }),
    tone: 'success',
  };
  showCombinedWizard.value = false;
  void loadRows();
  timetableGridRef.value?.refresh();
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
// The grid emits either an `edit` (a filled cell was tapped, schedule_id)
// or a `create` (an empty cell was tapped, pre-fill payload).
//
// PARITY: a filled-cell tap opens the SAME ScheduleDetailModal the list
// view uses — surfacing the full action set (Edit · Pindah Slot · Ganti
// Guru · Duplikat · Hapus, plus the group-scope delete for jadwal
// gabung). It previously jumped straight into the edit form, which left
// the Timetable view with no way to delete / reschedule / duplicate /
// change-teacher a slot. Routing through the detail modal closes that
// gap with zero new endpoints — every action already exists.
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
  detailRow.value = row;
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

/**
 * Delete scope for a group row — the confirmation dialog offers two
 * outcomes:
 *   'row'   → just this class (leaves siblings intact; back-compat
 *             delete for a plain single-class schedule)
 *   'group' → all classes in the gabungan (cascade siblings)
 * A plain row (no schedule_group_id) always deletes as 'row'.
 */
const deleteScope = ref<'row' | 'group'>('row');

async function confirmDelete() {
  if (!deleteRow.value) return;
  isDeleting.value = true;
  try {
    await ScheduleService.destroy(deleteRow.value.id, {
      scope: deleteScope.value,
    });
    toast.value = {
      message:
        deleteScope.value === 'group'
          ? $t('admin.schedule.combined.deletedGroupToast')
          : 'Jadwal dihapus.',
      tone: 'success',
    };
    await loadRows();
    // Keep the timetable grid in sync — delete is now reachable from the
    // Timetable view (filled cell → detail modal → Hapus), so its
    // /matrix cache would otherwise still show the deleted cell.
    timetableGridRef.value?.refresh();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDeleting.value = false;
    deleteRow.value = null;
    deleteScope.value = 'row';
  }
}

/** Delete confirmation message — expands to a "N kelas dalam
 *  gabungan" prompt when the row is grouped. */
const deleteConfirmMessage = computed(() => {
  const row = deleteRow.value;
  if (!row) return '';
  if (row.is_grouped && deleteScope.value === 'group') {
    const memberCount = row.grouped_class_names?.length ?? 2;
    return (
      $t('admin.schedule.combined.deleteGroupPrompt', {
        count: memberCount,
        subject: row.subject_name,
      }) +
      ' ' +
      $t('admin.schedule.deleteRecoverableNote')
    );
  }
  // B4 — schedules are soft-deleted (Part A1 recycle bin), so the old
  // "permanen dan tidak bisa dibatalkan" copy was both scary and wrong.
  return $t('admin.schedule.deleteSingleMessage', {
    subject: row.subject_name,
    class: row.class_name,
    time: row.start_time,
  });
});

function onRescheduled(_: ScheduleRow) {
  toast.value = { message: 'Slot dipindahkan.', tone: 'success' };
  // Refresh BOTH backing stores — the list reads `rows`, the timetable
  // grid reads its own /matrix cache. Since this action can now be
  // launched from the Timetable view (via the detail modal), the grid
  // must re-fetch too or the moved slot lingers in its old cell.
  void loadRows();
  timetableGridRef.value?.refresh();
}
function onTeacherChanged(_: ScheduleRow) {
  toast.value = { message: 'Guru diganti.', tone: 'success' };
  void loadRows();
  timetableGridRef.value?.refresh();
}

// ── Bulk select state ──────────────────────────────────────────────
const bulkMode = ref(false);
const selectedIds = ref<Set<string>>(new Set());
const showBulkDay = ref(false);
const showBulkTeacher = ref(false);
const showBulkDelete = ref(false);
const isBulkDeleting = ref(false);

// B2 — bulk-delete type-to-confirm guard. Deleting a large batch (the 45
// -schedule incident that spawned this work) is easy to fat-finger, so at
// ≥10 selected rows we require the admin to TYPE the exact count before
// the delete button enables.
const BULK_DELETE_TYPE_THRESHOLD = 10;
const bulkDeleteConfirmText = ref('');
const requiresTypedConfirm = computed(
  () => selectedIds.value.size >= BULK_DELETE_TYPE_THRESHOLD,
);
const bulkDeleteTypedOk = computed(
  () => bulkDeleteConfirmText.value.trim() === String(selectedIds.value.size),
);
function openBulkDelete() {
  bulkDeleteConfirmText.value = '';
  showBulkDelete.value = true;
}

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
  // B2 — belt-and-suspenders: never fire when the typed count is required
  // but doesn't match (the button is already disabled, this guards
  // programmatic calls / Enter-key edge cases).
  if (requiresTypedConfirm.value && !bulkDeleteTypedOk.value) return;
  isBulkDeleting.value = true;
  try {
    const res = await ScheduleService.bulkDestroy(Array.from(selectedIds.value));
    toast.value = {
      message: `${res.deleted_count} jadwal dihapus.`,
      tone: 'success',
    };
    exitBulkMode();
    await loadRows();
    // A large bulk-delete can orphan nothing, but re-checking keeps the
    // resync button honest if the deleted rows were the last references.
    void loadResyncCount();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isBulkDeleting.value = false;
    showBulkDelete.value = false;
    bulkDeleteConfirmText.value = '';
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
        <!-- Cetak / Import compressed to icon-only affordances so the
             hero action cluster stays tidy; the label rides along as a
             native tooltip + aria-label for accessibility. "Jam
             Pelajaran" keeps its text label because it's the primary
             setup entry point (a bare clock icon reads as ambiguous). -->
        <button
          type="button"
          class="grid place-items-center w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition-colors"
          :title="$t('admin.schedule.print')"
          :aria-label="$t('admin.schedule.print')"
          @click="showPrint = true"
        >
          <NavIcon name="download" :size="13" />
        </button>
        <button
          type="button"
          class="grid place-items-center w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition-colors"
          :title="$t('admin.schedule.import')"
          :aria-label="$t('admin.schedule.import')"
          @click="showImport = true"
        >
          <NavIcon name="upload" :size="13" />
        </button>
        <button
          type="button"
          class="text-2xs font-bold text-white/90 hover:text-white px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
          @click="router.push({ name: 'admin.schedule.lesson-hours' })"
        >
          <NavIcon name="clock" :size="11" class="inline" />
          {{ $t('admin.schedule.lessonHours') }}
        </button>
        <!-- A2 — appears only when active slots have an orphaned mapel
             (delete-then-reimport). Amber-tinted so it reads as an
             attention item, not a routine action. -->
        <button
          v-if="resyncOrphanCount > 0"
          type="button"
          class="text-2xs font-bold text-white px-3 py-1.5 rounded-lg bg-amber-500/90 hover:bg-amber-500 transition-colors flex items-center gap-1.5"
          @click="router.push({ name: 'admin.schedule.resync' })"
        >
          <NavIcon name="link" :size="11" />
          {{ $t('admin.schedule.resync.headerButton', { count: resyncOrphanCount }) }}
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
          :active="!!filterTeacherId"
          @click="showTeacherSheet = true"
        />
        <AppFilterChip
          icon-name="book-open"
          :label="$t('admin.schedule.filterSubject')"
          :value="subjectChipValue"
          tone="brand"
          :active="!!filterSubjectId"
          @click="showSubjectSheet = true"
        />
        <AppFilterChip
          icon-name="calendar"
          :label="$t('admin.schedule.filterDay')"
          :value="dayChipValue"
          tone="amber"
          :active="!!filterDayId"
          @click="showDaySheet = true"
        />
        <AppFilterChip
          icon-name="layers"
          :label="$t('admin.schedule.filterClass')"
          :value="classChipValue"
          tone="green"
          :active="!!filterClassId"
          @click="showClassSheet = true"
        />
        <AppFilterChip
          icon-name="clock"
          :label="$t('admin.schedule.filterHour')"
          :value="hourChipValue"
          tone="red"
          :active="filterHourNumber !== ''"
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
        <!-- LIST VIEW — sticky day groups + pinned jadwal-gabung strip. -->
        <div class="space-y-4">
          <!-- List-filter chip row — Semua / Tunggal / ⚭ Gabung.
               Sits above the pinned section so the count is visible
               even when the current filter hides the section (chip
               reads "⚭ Gabung · 3" even when filter = "Tunggal"). -->
          <div class="flex items-center gap-1.5 flex-wrap">
            <button
              type="button"
              class="text-2xs font-bold px-3 py-1.5 rounded-lg border transition-colors"
              :class="listFilter === 'all'
                ? 'bg-role-admin/10 text-role-admin border-role-admin/30'
                : 'bg-white text-slate-700 border-slate-200 hover:border-slate-300'"
              @click="listFilter = 'all'"
            >
              {{ $t('admin.schedule.combined.filterAll') }}
            </button>
            <button
              type="button"
              class="text-2xs font-bold px-3 py-1.5 rounded-lg border transition-colors"
              :class="listFilter === 'single'
                ? 'bg-role-admin/10 text-role-admin border-role-admin/30'
                : 'bg-white text-slate-700 border-slate-200 hover:border-slate-300'"
              @click="listFilter = 'single'"
            >
              {{ $t('admin.schedule.combined.filterSingle') }}
            </button>
            <button
              type="button"
              class="text-2xs font-bold px-3 py-1.5 rounded-lg border transition-colors inline-flex items-center gap-1"
              :class="listFilter === 'group'
                ? 'bg-violet-100 text-violet-800 border-violet-300'
                : 'bg-white text-violet-700 border-violet-200 hover:border-violet-300'"
              @click="listFilter = 'group'"
            >
              <span class="text-sm leading-none">⚭</span>
              {{ $t('admin.schedule.combined.filterGroup') }}
              <span
                v-if="groupedEntryCount > 0"
                class="ml-0.5 inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full bg-violet-500 text-white text-3xs font-bold"
              >
                {{ groupedEntryCount }}
              </span>
            </button>
          </div>

          <!-- Pinned "⚭ Jadwal Gabung" section — always at the top,
               reads from `groupedEntries` (deduped, one row per
               group). Only shown when filter is 'all' or 'group' and
               the school actually has group entries. -->
          <section
            v-if="listFilter !== 'single' && groupedEntries.length > 0"
            class="space-y-2"
          >
            <header class="flex items-center justify-between sticky top-0 z-10 bg-violet-50 py-2 px-3 rounded-lg border border-violet-200">
              <h3 class="text-2xs font-black text-violet-800 uppercase tracking-widest flex items-center gap-1.5">
                <span class="text-sm leading-none">⚭</span>
                {{
                  $t('admin.schedule.combined.pinnedSectionTitle', {
                    count: groupedEntries.length,
                  })
                }}
              </h3>
              <span class="text-3xs font-bold text-violet-600">
                {{ $t('admin.schedule.combined.pinnedSectionMeta') }}
              </span>
            </header>
            <div class="bg-white border-2 border-violet-200 rounded-2xl overflow-hidden">
              <div
                v-for="(g, idx) in groupedEntries"
                :key="g.group_id"
                class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-violet-50/40 transition-colors cursor-pointer"
                :class="idx > 0 ? 'border-t border-violet-100' : ''"
                @click="onGroupEntryClick(g)"
              >
                <div class="w-12 text-center flex-shrink-0">
                  <p class="text-3xs font-bold text-violet-500 uppercase tracking-widest">
                    JP
                  </p>
                  <p class="text-[15px] font-black text-violet-700">
                    {{ g.hour_number }}
                  </p>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-[13px] font-bold text-slate-900 truncate">
                    <span class="text-violet-700 mr-1">⚭</span>
                    {{ g.subject_name }} ·
                    <span class="text-slate-600 font-normal">
                      {{ g.teacher_name ?? 'Tanpa guru' }}
                    </span>
                  </p>
                  <div class="mt-0.5 flex flex-wrap items-center gap-1">
                    <span
                      v-for="m in g.members"
                      :key="m.id"
                      class="inline-flex items-center px-1.5 py-0 rounded bg-violet-100 text-violet-800 border border-violet-200 text-[11px] font-bold"
                    >
                      {{ m.name }}
                    </span>
                    <span v-if="g.room" class="text-2xs text-slate-500 ml-1">
                      · {{ g.room }}
                    </span>
                  </div>
                </div>
                <div class="text-right flex-shrink-0">
                  <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
                    {{ g.day_name ?? LOCALIZED_DAY_LABELS[g.day] }}
                  </p>
                  <p class="text-[12px] font-bold text-slate-900 tabular-nums">
                    {{ g.start_time }}–{{ g.end_time }}
                  </p>
                </div>
                <NavIcon name="chevron-right" :size="14" class="text-violet-300 ml-1" />
              </div>
            </div>
          </section>

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
                  r.is_grouped ? 'bg-violet-50/30' : '',
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
                <!-- Time anchor — the slot's clock time is the row's
                     spine. Start reads large + bold; end, duration and
                     the JP ordinal ride underneath it as quiet meta. -->
                <div class="w-16 flex-shrink-0 leading-tight">
                  <p class="text-[12px] font-bold text-slate-900 tabular-nums">{{ r.start_time }}</p>
                  <p class="text-3xs text-slate-400 tabular-nums">– {{ r.end_time }}</p>
                  <p class="text-4xs font-bold text-slate-400 uppercase tracking-wide mt-0.5">
                    <template v-if="slotDuration(r.start_time, r.end_time)">
                      {{ slotDuration(r.start_time, r.end_time) }} ·
                    </template>
                    {{ $t('admin.schedule.jpAbbrev') }}{{ r.hour_number }}
                  </p>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-[13px] font-bold text-slate-900 truncate">
                    <!-- ⚭ marker for grouped rows so the per-day list
                         echoes what the pinned section already said. -->
                    <span v-if="r.is_grouped" class="text-violet-700 mr-1">⚭</span>
                    {{ r.subject_name }}
                    <span v-if="r.conflict_with && r.conflict_with.length > 0" class="text-red-600 ml-1">⚠ {{ $t('admin.schedule.conflictBadge') }}</span>
                  </p>
                  <div class="mt-1 flex flex-wrap items-center gap-x-1.5 gap-y-1 min-w-0">
                    <!-- Kelas as a cobalt chip — the class is the row's
                         key secondary fact, so it earns a pill instead of
                         hiding inside a run-on meta line. -->
                    <span class="inline-flex items-center px-1.5 py-0.5 rounded-md bg-brand-cobalt/10 text-brand-cobalt border border-brand-cobalt/20 text-[11px] font-bold leading-none">
                      {{ r.class_name }}
                    </span>
                    <!-- Inline "bareng 7B, 7C" indicator — collapses the
                         group's other members onto the same line so the
                         admin sees why this slot is special without
                         scanning the pinned section. -->
                    <span
                      v-if="r.is_grouped"
                      class="text-2xs text-violet-700 font-bold"
                    >
                      {{
                        $t('admin.schedule.combined.inlineSiblingsLabel', {
                          names: siblingsForGroupedRow(r).map((m) => m.name).join(', '),
                        })
                      }}
                    </span>
                    <span class="text-2xs text-slate-500 truncate">{{ r.teacher_name ?? 'Tanpa guru' }}</span>
                    <span v-if="r.room" class="text-2xs text-slate-400">· {{ r.room }}</span>
                  </div>
                </div>
                <NavIcon name="chevron-right" :size="14" class="text-slate-300 ml-1" />
              </div>
            </div>
          </section>
        </div>

      </template>
    </AsyncView>

    <!-- Floating Tambah CTA — hidden when in bulk mode. Now a
         dropdown with two entry points: single-class schedule (the
         pre-jadwal-gabung flow) OR the combined-class wizard. Kept
         a plain <button> stack because the shared <Button> primitive
         has no built-in dropdown affordance and stacking two chips
         above the FAB reads as a menu without any new component. -->
    <div v-if="!bulkMode" class="fixed bottom-6 right-6 z-30">
      <!-- Backdrop click-to-close capture — only rendered while the
           menu is open so we don't intercept clicks otherwise. -->
      <div
        v-if="fabOpen"
        class="fixed inset-0"
        @click="closeFabMenu"
      />
      <div class="relative flex flex-col items-end gap-2">
        <!-- Dropdown items appear above the FAB when open. -->
        <transition
          enter-active-class="transition duration-150"
          enter-from-class="opacity-0 translate-y-1"
          enter-to-class="opacity-100 translate-y-0"
          leave-active-class="transition duration-100"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0"
        >
          <div v-if="fabOpen" class="flex flex-col items-end gap-2">
            <button
              type="button"
              class="inline-flex items-center gap-2 rounded-xl bg-violet-600 text-white text-2xs font-bold px-4 py-2.5 shadow-lg shadow-violet-500/30 hover:bg-violet-700 transition-colors"
              @click="onFabAddCombined"
            >
              <span class="text-sm leading-none">⚭</span>
              {{ $t('admin.schedule.combined.fabAddCombined') }}
            </button>
            <button
              type="button"
              class="inline-flex items-center gap-2 rounded-xl bg-white border border-slate-200 text-slate-800 text-2xs font-bold px-4 py-2.5 shadow-lg hover:bg-slate-50 transition-colors"
              @click="onFabAddSingle"
            >
              <NavIcon name="plus" :size="12" />
              {{ $t('admin.schedule.combined.fabAddSingle') }}
            </button>
          </div>
        </transition>

        <!-- Primary FAB — toggles the dropdown. Kept the same visual
             role-admin fill as before so muscle memory holds. -->
        <Button
          variant="primary"
          class="shadow-lg shadow-role-admin/30"
          :aria-expanded="fabOpen"
          @click="fabOpen = !fabOpen"
        >
          <NavIcon :name="fabOpen ? 'x' : 'plus'" :size="14" />
          {{ $t('admin.schedule.addFab') }}
        </Button>
      </div>
    </div>

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
      <Button variant="danger" size="sm" :disabled="selectedIds.size === 0" @click="openBulkDelete">
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

    <!-- Jadwal gabung — dedicated wizard invoked from the FAB dropdown.
         Kept as its own mount (not a mode of ScheduleFormModal) because
         the 3-step progression + summary review don't fit inside the
         single-form layout the modal was built around. -->
    <CreateCombinedScheduleWizard
      v-if="showCombinedWizard"
      :filter-options="filterOptions"
      :default-semester-id="filterOptions?.semesters?.[0]?.id"
      @close="showCombinedWizard = false"
      @saved="onCombinedSaved"
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

    <!-- Delete confirmation. For a grouped row the dialog is preceded
         by an inline scope picker (Hapus baris ini / Hapus semua kelas
         dalam gabungan) — the dialog itself just carries the confirm
         button, so we tuck the picker into a wrapper Modal that
         forwards the confirmation to the same handler. -->
    <template v-if="deleteRow">
      <Modal
        v-if="deleteRow.is_grouped"
        :title="$t('admin.schedule.combined.deleteScopeTitle')"
        size="sm"
        @close="deleteRow = null; deleteScope = 'row'"
      >
        <div class="space-y-3">
          <p class="text-2xs text-slate-600 leading-relaxed">
            {{
              $t('admin.schedule.combined.deleteScopeHint', {
                subject: deleteRow.subject_name,
                count: deleteRow.grouped_class_names?.length ?? 2,
              })
            }}
          </p>
          <p class="text-2xs text-emerald-700 leading-relaxed flex items-start gap-1.5">
            <NavIcon name="archive" :size="12" class="mt-0.5 flex-shrink-0" />
            <span>{{ $t('admin.schedule.deleteRecoverableNote') }}</span>
          </p>
          <div class="space-y-2">
            <label
              class="flex items-start gap-2.5 rounded-xl border p-3 cursor-pointer transition-colors"
              :class="deleteScope === 'row'
                ? 'border-role-admin bg-role-admin/5'
                : 'border-slate-200 hover:border-slate-300'"
            >
              <input
                v-model="deleteScope"
                type="radio"
                value="row"
                name="deleteScope"
                class="mt-1 accent-role-admin"
              />
              <div class="min-w-0 flex-1">
                <p class="text-[13px] font-bold text-slate-900">
                  {{ $t('admin.schedule.combined.deleteScopeRowTitle') }}
                </p>
                <p class="text-2xs text-slate-500 mt-0.5 leading-snug">
                  {{
                    $t('admin.schedule.combined.deleteScopeRowHint', {
                      class: deleteRow.class_name,
                    })
                  }}
                </p>
              </div>
            </label>
            <label
              class="flex items-start gap-2.5 rounded-xl border p-3 cursor-pointer transition-colors"
              :class="deleteScope === 'group'
                ? 'border-red-400 bg-red-50'
                : 'border-slate-200 hover:border-slate-300'"
            >
              <input
                v-model="deleteScope"
                type="radio"
                value="group"
                name="deleteScope"
                class="mt-1 accent-red-500"
              />
              <div class="min-w-0 flex-1">
                <p class="text-[13px] font-bold text-slate-900">
                  {{
                    $t('admin.schedule.combined.deleteScopeGroupTitle', {
                      count: deleteRow.grouped_class_names?.length ?? 2,
                    })
                  }}
                </p>
                <p class="text-2xs text-slate-500 mt-0.5 leading-snug">
                  {{ $t('admin.schedule.combined.deleteScopeGroupHint') }}
                </p>
              </div>
            </label>
          </div>
          <div class="grid grid-cols-2 gap-2 pt-2">
            <Button
              variant="secondary"
              block
              @click="deleteRow = null; deleteScope = 'row'"
            >
              {{ $t('common.cancel') }}
            </Button>
            <Button
              variant="danger"
              block
              :loading="isDeleting"
              @click="confirmDelete"
            >
              {{
                deleteScope === 'group'
                  ? $t('admin.schedule.combined.deleteScopeGroupConfirm')
                  : $t('admin.schedule.combined.deleteScopeRowConfirm')
              }}
            </Button>
          </div>
        </div>
      </Modal>
      <ConfirmationDialog
        v-else
        title="Hapus Jadwal"
        :message="deleteConfirmMessage"
        confirm-label="Hapus"
        danger
        :loading="isDeleting"
        @close="deleteRow = null; deleteScope = 'row'"
        @confirm="confirmDelete"
      />
    </template>

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

    <!-- B2 — bulk delete. At ≥10 rows the admin must TYPE the exact count
         (a fat-finger guard for large batches, the 45-schedule incident);
         under that it's a plain confirm. Both note that deleted schedules
         are recoverable from Data Terhapus. -->
    <Modal
      v-if="showBulkDelete && requiresTypedConfirm"
      :title="$t('admin.sekolah.schedule_management.bulk_delete_type_title', { count: selectedIds.size })"
      size="sm"
      @close="showBulkDelete = false; bulkDeleteConfirmText = ''"
    >
      <div class="space-y-3">
        <p class="text-sm text-slate-600 leading-relaxed">
          {{ $t('admin.sekolah.schedule_management.bulk_delete_type_prompt', { count: selectedIds.size }) }}
        </p>
        <div class="rounded-xl border border-emerald-200 bg-emerald-50 p-3">
          <p class="text-2xs text-emerald-800 leading-relaxed flex items-start gap-2">
            <NavIcon name="archive" :size="13" class="mt-0.5 flex-shrink-0" />
            <span>{{ $t('admin.schedule.deleteRecoverableNote') }}</span>
          </p>
        </div>
        <input
          v-model="bulkDeleteConfirmText"
          type="text"
          inputmode="numeric"
          autocomplete="off"
          :placeholder="String(selectedIds.size)"
          class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[15px] font-black text-slate-900 outline-none focus:border-red-400 focus:ring-2 focus:ring-red-100 tabular-nums text-center"
          @keyup.enter="bulkDeleteTypedOk && bulkDelete()"
        />
        <div class="grid grid-cols-2 gap-2 pt-1">
          <Button variant="secondary" block @click="showBulkDelete = false; bulkDeleteConfirmText = ''">
            {{ $t('common.cancel') }}
          </Button>
          <Button
            variant="danger"
            block
            :loading="isBulkDeleting"
            :disabled="!bulkDeleteTypedOk"
            @click="bulkDelete"
          >
            {{ $t('admin.sekolah.schedule_management.bulk_delete', { count: selectedIds.size }) }}
          </Button>
        </div>
      </div>
    </Modal>
    <ConfirmationDialog
      v-else-if="showBulkDelete"
      :title="$t('admin.sekolah.schedule_management.bulk_delete_title')"
      :message="$t('admin.sekolah.schedule_management.bulk_delete_message', {
        count: selectedIds.size,
        note: $t('admin.schedule.deleteRecoverableNote'),
      })"
      :confirm-label="$t('admin.sekolah.schedule_management.bulk_delete_confirm')"
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

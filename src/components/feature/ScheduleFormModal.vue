<!--
  ScheduleFormModal.vue — admin add/edit schedule (Sprint 2 Pola B).

  Two modes rendered inside a single <Modal>:
    1. `setup`   — <ScheduleSetupChecklist> when GET /schedule/prereq-check
                   reports the school hasn't seeded lesson-hours/classes/
                   teachers. Only shown on CREATE — editing an existing
                   row already implies the prereqs pass.
    2. `form`    — the reordered Pola B field grid:
                     Kelas → Semester → Slot (Hari × Jam Ke-) →
                     Guru (slot-filtered) → Mapel (guru-filtered) →
                     Ruangan (free-text, remembered per-class).

  Guru is the key change vs the old Pola A form: instead of picking a
  teacher first and letting them collide with an existing slot, we ask
  the backend for ONLY the teachers that are free at (class × day ×
  lesson_hour) and sort the picked class's wali kelas to the top with
  a "WALI KELAS" badge. Backend contract: MR A of Sprint 2.

  "Buat + Tambah Lagi" button — after save it keeps the modal open,
  resets Guru + Mapel (Kelas + Semester + Slot stay), and auto-advances
  the Jam Ke- dropdown to the next hour on the same day. This turns the
  common "fill 6 slots in one class in a row" flow into a one-form
  session instead of one drawer per row.

  The inline Quick-Add mapel panel from MR!866 is preserved beneath the
  Mapel dropdown so a picked teacher with no assigned mapel can still
  be used without leaving the drawer.

  Ruangan is remembered per class in localStorage
  (`schedule_last_room_${classId}`) so switching kelas rehydrates the
  right last-used room instead of dragging a stale value across.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import {
  ScheduleService,
  type AvailableTeacher,
  type LessonHourSeedPreset,
  type LessonHourSeedResponse,
  type SchedulePrereqCheck,
} from '@/services/schedule.service';
import { LessonHourService } from '@/services/lesson-hour.service';
import { SubjectService, type CheckExistingResult } from '@/services/subjects.service';
import { api } from '@/lib/http';
import type {
  LessonHour,
  ScheduleConflict,
  ScheduleFilterOptions,
  ScheduleRow,
} from '@/types/schedule';
import { useAcademicYearStore } from '@/stores/academic-year';
import { storage } from '@/lib/storage';
import { semesterLabel, subjectLabel } from '@/lib/labels';
import { formatDayName } from '@/lib/day-name';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import ScheduleSetupChecklist from '@/components/feature/ScheduleSetupChecklist.vue';

const props = defineProps<{
  /** Pass a row to edit; omit/null to create. */
  row?: ScheduleRow | null;
  /** Pre-loaded filter options (admin hub already fetched them). */
  filterOptions?: ScheduleFilterOptions | null;
  /** Pre-filled semester id (defaults to first option). */
  defaultSemesterId?: string;
  /**
   * Sprint 3 Pola C — pre-filled slot coming from the timetable grid.
   * When any of these three are set, the form opens with those fields
   * already selected (the admin clicked an empty cell in the week grid
   * and shouldn't have to re-pick the slot they just picked). The
   * fields stay visible + editable — the pre-fill is a starting point,
   * not a lock.
   */
  preFilledClassId?: string;
  preFilledDayId?: string;
  preFilledLessonHourId?: string;
  /**
   * Sprint 3 Pola C — the timetable grid only surfaces classes that
   * exist, and only fires the pre-fill flow after prereqs are visibly
   * satisfied by the grid itself. Set this to skip the prereq-check
   * gate on create so the modal opens straight into the form instead
   * of flashing the setup checklist for a school that's clearly ready.
   */
  skipSetupCheck?: boolean;
}>();

const emit = defineEmits<{
  close: [];
  saved: [ScheduleRow[]];
}>();

const ayStore = useAcademicYearStore();
const { t } = useI18n();
const router = useRouter();

const isEdit = computed(() => Boolean(props.row?.id));

// ── Mode gate ───────────────────────────────────────────────────────
// `checking` — initial prereq-check in flight (create only)
// `setup`    — one or more prereqs missing → show checklist
// `form`     — either edit mode or a green-lit create
type Mode = 'checking' | 'setup' | 'form';
// Edit mode and Pola-C-with-skipSetupCheck both bypass the prereq gate:
// the row/grid caller has already established the school is ready.
const mode = ref<Mode>(
  isEdit.value || props.skipSetupCheck ? 'form' : 'checking',
);
const prereq = ref<SchedulePrereqCheck | null>(null);
const isSeeding = ref(false);
const setupError = ref<string | null>(null);

// ── Form state ──────────────────────────────────────────────────────
// Precedence for initial values: existing row (edit) > Pola C pre-fill
// (grid empty-cell click) > empty. Pre-fills only take effect on
// CREATE — editing an existing row must always trust the row's own
// values or the admin could silently rewrite a different slot.
const teacherId = ref<string>(props.row?.teacher_id ?? '');
const subjectId = ref<string>(props.row?.subject_id ?? '');
const classId = ref<string>(
  props.row?.class_id ?? props.preFilledClassId ?? '',
);

// ── Jadwal gabung (combined-class) state ────────────────────────────
//
// The single-class picker above stays load-bearing for the plain flow.
// When the admin toggles "Jadwalkan bareng kelas lain" ON, we widen
// into `classIds` (multi-select chip picker) — the array is what the
// submit path sends to the backend as `class_ids: [...]`. On edit of
// an existing grouped row, we hydrate `classIds` from the row's
// `grouped_class_names` so the same members show up as chips instead
// of a single "primary" class + hidden siblings.
const combinedMode = ref<boolean>(
  Boolean(props.row?.is_grouped) ||
    Boolean(
      props.row?.grouped_class_names &&
        props.row.grouped_class_names.length > 1,
    ),
);
const classIds = ref<string[]>(
  props.row?.grouped_class_names && props.row.grouped_class_names.length > 0
    ? props.row.grouped_class_names.map((c) => c.id)
    : props.row?.class_id
      ? [props.row.class_id]
      : props.preFilledClassId
        ? [props.preFilledClassId]
        : [],
);
const semesterId = ref<string>(
  props.row?.semester_id ?? props.defaultSemesterId ?? '',
);
const academicYearId = ref<string | number>(
  props.row?.academic_year_id ?? ayStore.selectedYearId ?? '',
);
/** Pola B is single-day. UI drives one dayId at a time (paired with
 *  lessonHourId for the "slot"). Multi-day fan-out has been dropped —
 *  it clashed with the slot-filtered teacher dropdown, which is
 *  scoped to one day × one hour. */
const dayId = ref<string>(
  props.row?.day_id ?? props.preFilledDayId ?? '',
);
/** UUID of the picked lesson_hour row (defines the JP slot). */
const lessonHourId = ref<string>(
  props.row?.lesson_hour_days_id ?? props.preFilledLessonHourId ?? '',
);
const room = ref<string>(props.row?.room ?? '');

// ── Loaded data ─────────────────────────────────────────────────────
const teacherSubjects = ref<Array<{ id: string; name: string; code?: string | null }>>([]);
const allSubjects = ref<Array<{ id: string; name: string; code?: string | null }>>([]);
const lessonHours = ref<LessonHour[]>([]);
const conflicts = ref<ScheduleConflict[]>([]);
/** Occupied slots — existing schedules for the picked class/day/term.
 * Used to mark each lesson-hour option as "Terisi" + disable it. */
const occupiedSlots = ref<ScheduleRow[]>([]);
/** Slot-filtered teacher list (from /available-teachers). Populated
 *  reactively whenever class + day + hour are all set. */
const availableTeachers = ref<AvailableTeacher[]>([]);
const isLoadingAvailableTeachers = ref(false);
const availableTeachersError = ref<string | null>(null);
/**
 * True only once /available-teachers has actually ANSWERED for the current
 * slot. An empty `availableTeachers` is ambiguous on its own — it means either
 * "the server says nobody is free" or "we never asked" — and the UI must never
 * present the second as the first. Without this the picker claimed "Semua guru
 * sudah punya jadwal di jam ini" on a slot it had never sent a request for.
 */
const hasFetchedAvailableTeachers = ref(false);
/** True only when the teacher-subjects request errored (not when it
 * succeeded but returned an empty list). Mirrors Flutter: on error we
 * fall back to showing all subjects; on a genuine empty result we show
 * none so the picker is scoped strictly to the teacher's mapel. */
const subjectsLoadFailed = ref(false);
/** True only when the lesson-hours request errored. Same rationale as
 * `subjectsLoadFailed`. */
const hoursLoadFailed = ref(false);

const isLoadingSubjects = ref(false);
// See legacy note: seeded true so the "belum diatur" empty state
// doesn't flash on schools that have hours while the fetch resolves.
const isLoadingHours = ref(true);
const isProbingConflicts = ref(false);
const isSaving = ref(false);
const err = ref<string | null>(null);
const forceSave = ref(false);

// ── Inline Quick-Add mapel state ────────────────────────────────────
// Preserved from MR!866 — when the picked teacher has no mapel we
// expose an inline expandable panel so the admin can create + assign a
// mapel without leaving the drawer.
const quickAddOpen = ref(false);
const quickAddName = ref('');
const quickAddCode = ref('');
const isQuickAdding = ref(false);
const quickAddErr = ref<string | null>(null);

// ── Quick-Add tabs — "Pilih Existing" (default) + "Buat Baru" ─────
// The Quick-Add panel used to expose ONLY the "create new" form, which
// pushed admins to mint duplicates of mapel the school already owned
// (e.g. "Al Qur'an Hadis" next to the existing "Al Qur'an Hadis
// (QH-7/8/9)"). Attach-existing shown first + create-new as escape
// hatch makes the duplicate the harder path instead of the default.
type QuickAddTab = 'pick' | 'create';
const quickAddTab = ref<QuickAddTab>('pick');
const quickAddSelectedExistingId = ref<string>('');
const quickAddExistingSearch = ref<string>('');
const isQuickAddAttaching = ref(false);

// Smart-hint on quick-add: reuse /subjects/check-existing so the admin
// gets the same "sudah ada N mapel bernama X" warning inline. Quick-Add
// always creates a grade-agnostic row (no grade field in this panel),
// so the message is purely informational — no confirm dialog, just a
// heads-up that they may be about to shadow their existing grade-scoped
// rows with a universal one.
const quickAddSimilar = ref<CheckExistingResult>({
  matches: [],
  has_similar: false,
  existing_grades: [],
});
let quickAddSimilarTimer: ReturnType<typeof setTimeout> | null = null;

watch(quickAddName, (v) => {
  if (quickAddSimilarTimer) clearTimeout(quickAddSimilarTimer);
  quickAddSimilarTimer = setTimeout(async () => {
    const trimmed = v.trim();
    if (trimmed.length < 2) {
      quickAddSimilar.value = { matches: [], has_similar: false, existing_grades: [] };
      return;
    }
    quickAddSimilar.value = await SubjectService.checkExisting({ name: trimmed });
  }, 300);
});

// ── Loaders ─────────────────────────────────────────────────────────
// The school's mapel catalogue, scoped to the picked class's grade. Grade
// scoping is what lets the admin pick the RIGHT "Al Qur'an Hadis" — the one
// for kelas 9 (QH-9) — instead of QH-7/8, and keeps the list short. When no
// grade is known yet (class not picked) we load the whole catalogue.
async function loadAllSubjects() {
  try {
    const params: Record<string, unknown> = { per_page: 500 };
    if (selectedClassGrade.value) params.grade_level = selectedClassGrade.value;
    const res = await api.get('/subject', { params });
    const body = res.data;
    const list = Array.isArray(body?.data) ? body.data : Array.isArray(body) ? body : [];
    allSubjects.value = list.map((s: any) => ({
      id: String(s.id),
      name: String(s.name ?? s.nama ?? ''),
      code: s.code ?? s.kode ?? null,
    }));
  } catch {
    allSubjects.value = [];
  }
}

async function loadSubjectsForTeacher(tId: string) {
  if (!tId) {
    teacherSubjects.value = [];
    subjectsLoadFailed.value = false;
    return;
  }
  isLoadingSubjects.value = true;
  subjectsLoadFailed.value = false;
  try {
    const list = await SubjectService.listForTeacher(tId, 'teaching');
    const ids = new Set(list.map((s) => s.id));
    teacherSubjects.value = list.map((s) => ({
      id: s.id,
      name: s.name,
      code: s.code ?? null,
    }));
    if (subjectId.value && !ids.has(subjectId.value)) subjectId.value = '';
  } catch {
    subjectsLoadFailed.value = true;
    teacherSubjects.value = [];
  } finally {
    isLoadingSubjects.value = false;
  }
}

async function loadLessonHours() {
  isLoadingHours.value = true;
  hoursLoadFailed.value = false;
  try {
    lessonHours.value = await LessonHourService.list();
  } catch {
    hoursLoadFailed.value = true;
    lessonHours.value = [];
  } finally {
    isLoadingHours.value = false;
  }
}

async function probeConflicts() {
  if (
    !teacherId.value ||
    !classId.value ||
    !dayId.value ||
    !lessonHourId.value ||
    !semesterId.value ||
    !academicYearId.value
  ) {
    conflicts.value = [];
    return;
  }
  isProbingConflicts.value = true;
  try {
    conflicts.value = await ScheduleService.getConflicts({
      teacher_id: teacherId.value,
      class_id: classId.value,
      semester_id: semesterId.value,
      academic_year_id: academicYearId.value,
      lesson_hour_id: lessonHourId.value,
      days_ids: [dayId.value],
      exclude_id: props.row?.id,
    });
  } catch {
    conflicts.value = [];
  } finally {
    isProbingConflicts.value = false;
  }
}

/**
 * Fetch the slots already taken for the selected class on the selected
 * day (+ term / academic year). Mirrors the legacy behaviour: each
 * occupied row's lesson hour gets marked "Terisi" + disabled in the
 * Jam Pelajaran picker so the admin can't double-book a slot.
 */
async function fetchOccupiedSlots() {
  if (!classId.value || !dayId.value || !semesterId.value) {
    occupiedSlots.value = [];
    return;
  }
  try {
    const res = await ScheduleService.list({
      class_id: classId.value,
      day_id: dayId.value,
      semester_id: semesterId.value,
      academic_year_id: academicYearId.value || undefined,
      per_page: 100,
    });
    occupiedSlots.value = props.row?.id
      ? res.items.filter((s) => s.id !== props.row?.id)
      : res.items;
  } catch {
    occupiedSlots.value = [];
  }
}

/**
 * Slot-filtered teacher list. Only asked once the four inputs the
 * backend needs are all set — otherwise the list stays cleared and the
 * dropdown surfaces its "isi Kelas + Slot dulu" hint.
 */
async function loadAvailableTeachers() {
  if (!classId.value || !dayId.value || !lessonHourId.value) {
    availableTeachers.value = [];
    availableTeachersError.value = null;
    hasFetchedAvailableTeachers.value = false;
    return;
  }
  isLoadingAvailableTeachers.value = true;
  availableTeachersError.value = null;
  // The previous answer belonged to the previous slot — retire it now so a
  // stale "nobody free" can't be shown against the slot we're about to ask for.
  hasFetchedAvailableTeachers.value = false;
  try {
    const list = await ScheduleService.getAvailableTeachers({
      classId: classId.value,
      dayId: dayId.value,
      lessonHourId: lessonHourId.value,
      semesterId: semesterId.value || undefined,
      academicYearId: academicYearId.value || undefined,
    });
    // Sort wali kelas first, then subjects_count desc (more-versatile
    // teachers surface earlier), then name.
    list.sort((a, b) => {
      if (a.is_wali_kelas_of_this_class !== b.is_wali_kelas_of_this_class) {
        return a.is_wali_kelas_of_this_class ? -1 : 1;
      }
      if (a.subjects_count !== b.subjects_count) {
        return b.subjects_count - a.subjects_count;
      }
      return a.name.localeCompare(b.name, 'id');
    });
    availableTeachers.value = list;
    hasFetchedAvailableTeachers.value = true;
    // If the previously-picked teacher is no longer in the free list
    // (e.g. slot changed), clear the selection so the admin doesn't
    // submit a stale pick that will re-conflict.
    if (
      teacherId.value &&
      !list.some((tt) => tt.id === teacherId.value)
    ) {
      teacherId.value = '';
      subjectId.value = '';
    }
  } catch (e) {
    availableTeachersError.value = (e as Error).message;
    availableTeachers.value = [];
  } finally {
    isLoadingAvailableTeachers.value = false;
  }
}

// ── Setup-first gate ────────────────────────────────────────────────
async function runPrereqCheck() {
  mode.value = 'checking';
  setupError.value = null;
  try {
    const p = await ScheduleService.checkPrereq();
    prereq.value = p;
    mode.value = p.ready ? 'form' : 'setup';
  } catch {
    // The service already fail-safes to `ready: true` on error, so
    // we're unlikely to land here. If we do, let the form load.
    mode.value = 'form';
  }
}

async function onSeed(preset: LessonHourSeedPreset) {
  isSeeding.value = true;
  setupError.value = null;
  try {
    const res: LessonHourSeedResponse = await ScheduleService.seedLessonHours({
      preset,
      overwrite: false,
    });
    if (res.status === 'SUCCESS') {
      toast.value = {
        message: t('admin.schedule.setup.seededToast', { count: res.created }),
        tone: 'success',
      };
    } else {
      toast.value = {
        message: t('admin.schedule.setup.seededSkippedToast'),
        tone: 'success',
      };
    }
    // Refresh the checklist so the "done" tick renders in place. Also
    // refresh the local lessonHours cache so the Jam Ke- dropdown has
    // options once the admin lands on the form.
    await Promise.all([runPrereqCheck(), loadLessonHours()]);
  } catch (e) {
    setupError.value = (e as Error).message;
  } finally {
    isSeeding.value = false;
  }
}

function onOpenTeachersFromSetup() {
  emit('close');
  void router.push({ name: 'admin.teachers' });
}

function onOpenClassesFromSetup() {
  emit('close');
  void router.push({ name: 'admin.classes' });
}

function onContinueFromSetup() {
  // Prereq-check is the gate; the button is disabled unless ready.
  mode.value = 'form';
}

// Local toast so seed feedback surfaces without needing the parent to
// wire another prop through — we still bubble `saved` up like before.
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Lifecycle ───────────────────────────────────────────────────────
onMounted(async () => {
  await loadAllSubjects();
  await loadLessonHours();
  if (teacherId.value) await loadSubjectsForTeacher(teacherId.value);
  await fetchOccupiedSlots();

  // Rehydrate last-used room for this class ONLY on create — on edit
  // the row already has its own room value we mustn't overwrite.
  if (!isEdit.value && classId.value && !room.value) {
    room.value = readLastRoomForClass(classId.value);
  }

  // Kick off the FIRST slot-filtered teacher fetch.
  //
  // The watcher below is change-only, but this modal routinely opens with the
  // slot ALREADY filled (the timetable grid pre-fills class/day/hour from the
  // clicked cell). Nothing then changes, so the watcher never fired, the
  // request was never sent, `availableTeachers` stayed [] — and the picker
  // announced "Tidak ada guru yang tersedia untuk slot ini" for a slot it had
  // never asked about. Nudging the day was what finally triggered the first
  // fetch, which is why re-picking the same slot appeared to "fix" it.
  //
  // Create-only, deliberately: /available-teachers takes no exclude_id, so in
  // edit mode the row's OWN teacher is reported busy (by this very row) and
  // would be filtered out — fetching on open would then wipe the admin's
  // existing pick the moment the drawer appeared. Edit keeps the old
  // behaviour: the list loads only once the admin actually changes the slot,
  // which is the point at which invalidating the teacher is correct.
  if (!isEdit.value) {
    await loadAvailableTeachers();
  }

  if (isEdit.value || props.skipSetupCheck) {
    // Existing row implies the prereqs pass; timetable-grid pre-fill
    // implies the caller already saw a populated matrix. Either way we
    // skip the gate and land straight on the form.
    mode.value = 'form';
  } else {
    await runPrereqCheck();
  }
});

// Teacher change: refresh their subject list + kill any stale
// quick-add UI so we don't leak state onto a different teacher.
watch(teacherId, async (v) => {
  quickAddOpen.value = false;
  quickAddName.value = '';
  quickAddCode.value = '';
  quickAddErr.value = null;
  quickAddSimilar.value = { matches: [], has_similar: false, existing_grades: [] };
  quickAddTab.value = 'pick';
  quickAddSelectedExistingId.value = '';
  quickAddExistingSearch.value = '';
  await loadSubjectsForTeacher(v);
});

// Re-hydrate last-used room whenever the picked class changes (create
// only). If the new class has no memorised value we blank the field
// rather than dragging the previous class's room across.
watch(classId, (newId, oldId) => {
  if (newId === oldId) return;
  // Re-scope the mapel catalogue to the new class's grade (9B → grade 9).
  void loadAllSubjects();
  if (isEdit.value) return;
  room.value = newId ? readLastRoomForClass(newId) : '';
});

// Re-fetch occupied slots whenever the class / day / term context changes.
watch(
  [classId, dayId, semesterId, academicYearId],
  () => void fetchOccupiedSlots(),
);

// Re-fetch slot-filtered teachers whenever class + slot inputs change.
// NOTE: change-only on purpose — the initial fetch is kicked off explicitly in
// onMounted (create only). See the comment there for why `immediate: true`
// would be wrong for edit mode.
watch(
  [classId, dayId, lessonHourId, semesterId, academicYearId],
  () => void loadAvailableTeachers(),
);

// Debounced conflict probe
let probeTimer: ReturnType<typeof setTimeout> | null = null;
watch(
  [teacherId, classId, lessonHourId, dayId, semesterId, academicYearId],
  () => {
    if (probeTimer) clearTimeout(probeTimer);
    probeTimer = setTimeout(() => void probeConflicts(), 250);
  },
);

// ── Derived ────────────────────────────────────────────────────────
const days = computed(() => props.filterOptions?.days ?? []);
const classes = computed(() => props.filterOptions?.classes ?? []);
const semesters = computed(() => props.filterOptions?.semesters ?? []);

/** grade_level of the picked class, e.g. '9' for 9B — scopes the catalogue. */
const selectedClassGrade = computed<string | null>(() => {
  const c = classes.value.find((x) => x.id === classId.value) as
    | { grade_level?: string | number | null }
    | undefined;
  const g = c?.grade_level;
  return g === null || g === undefined || g === '' ? null : String(g);
});

// The set of subject ids the picked guru is already linked to — used by the
// "Pilih Existing" panel to hide mapel the teacher already teaches.
const ownSubjectIds = computed(
  () => new Set(teacherSubjects.value.map((s) => s.id)),
);

// The Mapel dropdown lists ONLY the mapel the picked guru is linked to teach —
// the same "mata pelajaran yang diampu" shown on the teacher profile. It must
// reflect reality, not the whole catalogue: showing an unlinked mapel here
// (which an earlier iteration did) looked like the dropdown was lying, since
// the guru doesn't teach it yet. To add one, the admin uses the "Tautkan"
// panel below (Pilih Existing from the grade-scoped catalogue, or Buat Baru) —
// which attaches it, after which it appears here. On a load error we fall back
// to the full catalogue so a network blip can't strand the picker.
const subjectOptions = computed(() =>
  subjectsLoadFailed.value ? allSubjects.value : teacherSubjects.value,
);

/**
 * Extra validity check for combined mode: at least 2 classes must be
 * picked before the "Simpan" button un-disables. A 1-class group is a
 * plain schedule wearing a hat — we short-circuit to the single flow
 * rather than let the admin accidentally mint a 1-member group.
 */
const combinedClassesValid = computed(
  () => !combinedMode.value || classIds.value.length >= 2,
);

const formValid = computed(() => {
  const classSideValid = combinedMode.value
    ? classIds.value.length > 0
    : Boolean(classId.value);
  return (
    teacherId.value &&
    subjectId.value &&
    classSideValid &&
    semesterId.value &&
    academicYearId.value &&
    dayId.value &&
    lessonHourId.value
  );
});

const hasConflict = computed(() => conflicts.value.length > 0);
const canSubmit = computed(() => {
  if (!formValid.value || isSaving.value) return false;
  if (!combinedClassesValid.value) return false;
  if (hasConflict.value && !forceSave.value) return false;
  return true;
});

// ── Combined-mode derived options ──────────────────────────────────
// Full class list minus the ones already added — the source list for
// the "+ kelas" chip picker in combined mode.
const combinedRemainingClasses = computed(() => {
  const already = new Set(classIds.value);
  return classes.value.filter((c) => !already.has(c.id));
});

// Chip labels for the picked-classes strip. Reads through
// filterOptions.classes so we get the display name even for classes
// that were pre-loaded on an edit-of-grouped-row path (backend sends
// `grouped_class_names` with `{id, name}` so this is also a valid
// fallback source when the class list is late-hydrating).
const combinedPickedClasses = computed(() => {
  return classIds.value.map((id) => {
    const c = classes.value.find((cc) => cc.id === id);
    if (c) return { id: c.id, name: c.name };
    // Fallback for edit mode: the grouped_class_names ref may carry
    // classes that aren't in the AY's active class list (edge case:
    // class was archived after the group was created).
    const fromRow = props.row?.grouped_class_names?.find(
      (gc) => gc.id === id,
    );
    return { id, name: fromRow?.name ?? id };
  });
});

// ── Save ───────────────────────────────────────────────────────────
async function save(opts: { continueAfter?: boolean } = {}) {
  if (!formValid.value) {
    err.value = 'Lengkapi semua kolom.';
    return;
  }
  isSaving.value = true;
  err.value = null;
  try {
    // Combined mode always sends `class_ids` (jadwal-gabung backend
    // fan-out); plain mode keeps sending the single `class_id` scalar
    // — the service normaliser wraps either shape into `class_ids`
    // for the wire but preserving the caller-intent shape here makes
    // the payload readable in the network inspector.
    const classPayload: { class_id?: string; class_ids?: string[] } =
      combinedMode.value && classIds.value.length > 0
        ? { class_ids: [...classIds.value] }
        : { class_id: classId.value };

    if (isEdit.value && props.row?.id) {
      const updated = await ScheduleService.update(props.row.id, {
        teacher_id: teacherId.value,
        subject_id: subjectId.value,
        ...classPayload,
        days_ids: [dayId.value],
        lesson_hour_id: lessonHourId.value,
        semester_id: semesterId.value,
        academic_year_id: academicYearId.value,
        room: room.value || null,
      });
      persistRoomForClass();
      emit('saved', [updated]);
      emit('close');
    } else {
      const created = await ScheduleService.create({
        teacher_id: teacherId.value,
        subject_id: subjectId.value,
        ...classPayload,
        days_ids: [dayId.value],
        lesson_hour_id: lessonHourId.value,
        semester_id: semesterId.value,
        academic_year_id: academicYearId.value,
        room: room.value || null,
      });
      persistRoomForClass();
      emit('saved', created);
      if (opts.continueAfter) {
        advanceToNextSlotAndReset();
      } else {
        emit('close');
      }
    }
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Combined-mode helpers ──────────────────────────────────────────
// When the toggle flips ON, we seed the multi-picker with whatever the
// single-class picker already had so the admin doesn't lose that pick.
// When it flips OFF, we collapse back to the first class in the array
// (or clear) so the single-picker again reads a valid value.
function onToggleCombined(next: boolean) {
  combinedMode.value = next;
  if (next) {
    // Seed multi-picker from single picker if empty (avoid duplicating
    // an id that's already in the array — the toggle can be flipped
    // repeatedly during a single edit).
    if (
      classId.value &&
      !classIds.value.includes(classId.value)
    ) {
      classIds.value = [classId.value, ...classIds.value];
    }
  } else {
    // Collapse to the first picked class so the plain single-select
    // form stays consistent. If nothing was picked either way, leave
    // both empty and let the admin start fresh.
    if (classIds.value.length > 0) {
      classId.value = classIds.value[0];
    }
    classIds.value = [];
  }
}

/** Add a class to the multi-select group (chip picker "+ kelas"). */
function addClassToGroup(newId: string) {
  if (!newId) return;
  if (classIds.value.includes(newId)) return;
  classIds.value = [...classIds.value, newId];
}

/** Remove a class from the multi-select group (chip × click). */
function removeClassFromGroup(removeId: string) {
  classIds.value = classIds.value.filter((id) => id !== removeId);
}

// The single-picker `classId` stays load-bearing even in combined
// mode: it drives grade-scoping (`selectedClassGrade`), room memory,
// and the slot-filtered teacher lookup — all of which key on ONE
// class at a time (the primary/anchor class). We mirror the first id
// in `classIds` into `classId` so those computeds stay correct as
// the admin adds/removes members.
watch(classIds, (list) => {
  if (!combinedMode.value) return;
  const first = list[0] ?? '';
  if (first !== classId.value) classId.value = first;
});

/**
 * "Buat + Tambah Lagi" tail: preserve Kelas + Semester + Slot day,
 * bump Jam Ke- to the next hour on the same day if one exists, and
 * wipe Guru + Mapel so the admin picks fresh for the new slot. If
 * we're already at the day's last hour we clear the hour instead and
 * toast so the admin knows they've hit the end of that day.
 */
function advanceToNextSlotAndReset() {
  const currentHour = filteredHours.value.find((h) => h.id === lessonHourId.value);
  const nextHour = currentHour
    ? filteredHours.value.find((h) => h.hour_number > currentHour.hour_number && !isHourOccupied(h))
    : null;

  // Reset teacher + subject regardless — the next slot needs its own
  // slot-filtered teacher lookup.
  teacherId.value = '';
  subjectId.value = '';
  availableTeachers.value = [];
  conflicts.value = [];
  forceSave.value = false;
  err.value = null;

  if (nextHour) {
    lessonHourId.value = nextHour.id;
    toast.value = {
      message: t('admin.schedule.formB.createdToast'),
      tone: 'success',
    };
  } else {
    lessonHourId.value = '';
    toast.value = {
      message: t('admin.schedule.formB.createdToastLast'),
      tone: 'success',
    };
  }
}

// ── Room memory (per-class localStorage) ────────────────────────────
function roomStorageKey(cId: string): string {
  return `schedule_last_room_${cId}`;
}

function readLastRoomForClass(cId: string): string {
  try {
    const v = storage.get<string>(roomStorageKey(cId));
    return typeof v === 'string' ? v : '';
  } catch {
    return '';
  }
}

function persistRoomForClass() {
  if (!classId.value) return;
  const value = room.value.trim();
  if (value) {
    storage.set(roomStorageKey(classId.value), value);
  } else {
    // Clearing the field also clears the memory so a subsequent open
    // doesn't zombie-populate a room the admin deliberately blanked.
    storage.remove(roomStorageKey(classId.value));
  }
}

// ── Quick-Add mapel (from MR!866) ──────────────────────────────────
/**
 * The picked teacher's display name — pulled from availableTeachers
 * first (that's the source of truth for Pola B), falling back to the
 * hub's full teacher roster if the slot-filter is empty (e.g. edit
 * mode restored a teacher who is themself the conflict).
 */
const selectedTeacherName = computed(() => {
  const fromAvail = availableTeachers.value.find((x) => x.id === teacherId.value);
  if (fromAvail) return fromAvail.name;
  const fromFilter = props.filterOptions?.teachers.find((x) => x.id === teacherId.value);
  return fromFilter?.name ?? '';
});

const teacherHasNoSubjects = computed(
  () =>
    !!teacherId.value &&
    !isLoadingSubjects.value &&
    !subjectsLoadFailed.value &&
    teacherSubjects.value.length === 0,
);

// Whether to offer the link ("Tautkan") panel: any time a guru is picked and
// we know their linked mapel. For a guru with none it's the primary CTA; for
// one who already teaches some it's the quieter way to link ANOTHER mapel that
// isn't in the dropdown yet — the only path to grow that list under the
// link-first model.
const canLinkSubject = computed(
  () =>
    !!teacherId.value && !isLoadingSubjects.value && !subjectsLoadFailed.value,
);

/**
 * Subjects in the school catalogue (allSubjects, already grade-scoped
 * via loadAllSubjects) that the picked teacher does NOT already own —
 * the source list for the Quick-Add "Pilih Existing" tab. When teacher
 * has zero own mapel this collapses to `allSubjects`, but subtracting
 * is defensive if we later relax the panel gate.
 */
const quickAddExistingCandidates = computed(() => {
  const own = ownSubjectIds.value;
  return allSubjects.value
    .filter((s) => !own.has(s.id))
    .slice()
    .sort((a, b) => subjectLabel(a).localeCompare(subjectLabel(b), 'id'));
});

const quickAddFilteredCandidates = computed(() => {
  const q = quickAddExistingSearch.value.trim().toLowerCase();
  if (!q) return quickAddExistingCandidates.value;
  return quickAddExistingCandidates.value.filter((s) => {
    const name = s.name.toLowerCase();
    const code = (s.code ?? '').toString().toLowerCase();
    return name.includes(q) || code.includes(q);
  });
});

// Auto-flip to "Buat Baru" when there's literally nothing to pick —
// otherwise the admin lands on an empty tab and thinks Quick-Add is
// broken. Fires whenever the candidates list transitions to empty
// while the panel is open (e.g. all subjects already attached, or
// school catalogue actually empty).
watch(
  [quickAddOpen, quickAddExistingCandidates],
  ([open, candidates]) => {
    if (
      open &&
      quickAddTab.value === 'pick' &&
      candidates.length === 0 &&
      !isQuickAddAttaching.value
    ) {
      quickAddTab.value = 'create';
    }
  },
);

/**
 * Attach the selected school subject to the picked teacher via
 * `POST /teacher/{id}/subjects` (mode=attach) and pre-select it in the
 * dropdown so the admin can save the schedule row immediately.
 */
async function submitQuickAddAttach() {
  const subjectPickId = quickAddSelectedExistingId.value;
  if (!subjectPickId || !teacherId.value) return;
  isQuickAddAttaching.value = true;
  quickAddErr.value = null;
  try {
    await ScheduleService.attachSubjectsToTeacher({
      teacherId: teacherId.value,
      subjectIds: [subjectPickId],
    });
    // Refresh teacher's own list so the star badge + gate transition
    // reflect reality on the next render.
    try {
      await loadSubjectsForTeacher(teacherId.value);
    } catch {
      // Best-effort — the attach itself already succeeded server-side.
      const picked = allSubjects.value.find((s) => s.id === subjectPickId);
      if (picked) {
        teacherSubjects.value = [
          ...teacherSubjects.value,
          { id: picked.id, name: picked.name, code: picked.code ?? null },
        ];
      }
    }
    subjectId.value = subjectPickId;
    quickAddOpen.value = false;
    quickAddSelectedExistingId.value = '';
    quickAddExistingSearch.value = '';
  } catch (e) {
    quickAddErr.value = (e as Error).message;
  } finally {
    isQuickAddAttaching.value = false;
  }
}

async function submitQuickAdd() {
  const name = quickAddName.value.trim();
  if (!name || !teacherId.value) {
    quickAddErr.value = 'Nama mapel wajib diisi.';
    return;
  }
  isQuickAdding.value = true;
  quickAddErr.value = null;
  try {
    const created = await ScheduleService.createSubjectAndAssign({
      name,
      code: quickAddCode.value.trim() || undefined,
      teacherId: teacherId.value,
      // Stamp the class's grade so a genuinely-new mapel lands in the right
      // bucket and obeys the unique(school, LOWER(name), grade) index —
      // instead of the old grade-less row that collided with 7/8/9 variants.
      grade: selectedClassGrade.value ?? undefined,
    });
    try {
      await loadSubjectsForTeacher(teacherId.value);
    } catch {
      teacherSubjects.value = [
        ...teacherSubjects.value,
        { id: created.id, name: created.name, code: created.code ?? null },
      ];
    }
    subjectId.value = created.id;
    quickAddOpen.value = false;
    quickAddName.value = '';
    quickAddCode.value = '';
    quickAddSimilar.value = { matches: [], has_similar: false, existing_grades: [] };
  } catch (e) {
    quickAddErr.value = (e as Error).message;
  } finally {
    isQuickAdding.value = false;
  }
}

function cancelQuickAdd() {
  quickAddOpen.value = false;
  quickAddErr.value = null;
  quickAddSimilar.value = { matches: [], has_similar: false, existing_grades: [] };
  quickAddSelectedExistingId.value = '';
  quickAddExistingSearch.value = '';
}

// ── Display helpers ────────────────────────────────────────────────
const groupedHours = computed(() => {
  const grouped = new Map<string, LessonHour[]>();
  for (const h of lessonHours.value) {
    const k = h.day_id;
    const list = grouped.get(k) ?? [];
    list.push(h);
    grouped.set(k, list);
  }
  for (const list of grouped.values()) {
    list.sort((a, b) => a.hour_number - b.hour_number);
  }
  return grouped;
});

const filteredHours = computed(() => {
  if (!dayId.value) return [];
  return groupedHours.value.get(dayId.value) ?? [];
});

const occupiedHourIds = computed<Set<string>>(() => {
  const ids = new Set<string>();
  for (const s of occupiedSlots.value) {
    if (s.lesson_hour_days_id) ids.add(s.lesson_hour_days_id);
  }
  return ids;
});

function isHourOccupied(hour: LessonHour): boolean {
  return occupiedHourIds.value.has(hour.id);
}

const hasNoLessonHours = computed(
  () => !isLoadingHours.value && !hoursLoadFailed.value && lessonHours.value.length === 0,
);

const dayHasNoLessonHours = computed(
  () =>
    !isLoadingHours.value &&
    !hoursLoadFailed.value &&
    lessonHours.value.length > 0 &&
    !!dayId.value &&
    filteredHours.value.length === 0,
);

function goToLessonHourSettings() {
  emit('close');
  void router.push({ name: 'admin.schedule.lesson-hours' });
}

// ── Modal shell ────────────────────────────────────────────────────
const modalTitle = computed(() => {
  if (mode.value === 'setup' || mode.value === 'checking') {
    return t('admin.schedule.setup.modalTitle');
  }
  if (isEdit.value) {
    return combinedMode.value
      ? t('admin.schedule.combined.editTitle')
      : t('admin.schedule.formB.editTitle');
  }
  return combinedMode.value
    ? t('admin.schedule.combined.createTitle')
    : t('admin.schedule.formB.createTitle');
});

const modalSubtitle = computed(() => {
  if (mode.value === 'setup' || mode.value === 'checking') {
    return t('admin.schedule.setup.modalSubtitle');
  }
  return isEdit.value
    ? t('admin.schedule.formB.editSubtitle')
    : t('admin.schedule.formB.createSubtitle');
});

const teacherPickerLocked = computed(
  () => !classId.value || !dayId.value || !lessonHourId.value,
);
</script>

<template>
  <Modal
    :title="modalTitle"
    :subtitle="modalSubtitle"
    size="lg"
    @close="emit('close')"
  >
    <!-- ── Checking prereqs ────────────────────────────────────── -->
    <div v-if="mode === 'checking'" class="py-8 flex flex-col items-center text-center gap-3">
      <NavIcon name="loader" :size="18" class="animate-spin text-slate-400" />
      <p class="text-2xs text-slate-500">
        {{ t('admin.schedule.setup.checking') }}
      </p>
    </div>

    <!-- ── Setup checklist ────────────────────────────────────── -->
    <ScheduleSetupChecklist
      v-else-if="mode === 'setup' && prereq"
      :prereq="prereq"
      :is-checking="false"
      :is-seeding="isSeeding"
      :error="setupError"
      @seed="onSeed"
      @open-teachers="onOpenTeachersFromSetup"
      @open-classes="onOpenClassesFromSetup"
      @continue="onContinueFromSetup"
      @close="emit('close')"
    />

    <!-- ── Pola B reordered form ─────────────────────────────── -->
    <div v-else class="space-y-3">
      <!-- Kelas + Semester. In plain mode the Kelas picker is a
           single-select alongside Semester (2-col grid). In combined
           mode the Kelas picker widens to full width (chip strip)
           and Semester drops to a full-width row below. -->
      <div class="grid gap-3" :class="combinedMode ? 'grid-cols-1' : 'grid-cols-2'">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{
              combinedMode
                ? t('admin.schedule.combined.classesLabel')
                : t('admin.schedule.formB.classLabel')
            }}
          </label>
          <!-- Plain single-select — the pre-combined-toggle form. -->
          <select
            v-if="!combinedMode"
            v-model="classId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">{{ t('admin.schedule.formB.classPlaceholder') }}</option>
            <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
          <!-- Combined mode — chip strip: each picked class becomes a
               violet chip with × to remove, plus a "+ kelas" dropdown
               that appends the next class to the group. -->
          <div v-else class="mt-1 flex flex-wrap items-center gap-1.5">
            <span
              v-for="c in combinedPickedClasses"
              :key="c.id"
              class="inline-flex items-center gap-1.5 pl-2.5 pr-1.5 py-1 rounded-full bg-violet-100 text-violet-800 border border-violet-200 text-[12px] font-bold"
            >
              {{ c.name }}
              <button
                type="button"
                class="w-4 h-4 rounded-full hover:bg-violet-200 text-violet-700 hover:text-violet-900 flex items-center justify-center leading-none"
                :aria-label="
                  t('admin.schedule.combined.removeClassAria', { name: c.name })
                "
                @click="removeClassFromGroup(c.id)"
              >
                <NavIcon name="x" :size="10" />
              </button>
            </span>
            <select
              v-if="combinedRemainingClasses.length > 0"
              :value="''"
              class="bg-white border border-dashed border-violet-300 rounded-full px-2.5 py-1 text-[12px] font-bold text-violet-700 outline-none focus:border-violet-500 cursor-pointer"
              @change="(e) => { addClassToGroup((e.target as HTMLSelectElement).value); (e.target as HTMLSelectElement).value = ''; }"
            >
              <option value="" disabled>
                {{ t('admin.schedule.combined.addClassPlaceholder') }}
              </option>
              <option
                v-for="c in combinedRemainingClasses"
                :key="c.id"
                :value="c.id"
              >
                {{ c.name }}
              </option>
            </select>
            <p
              v-if="classIds.length === 0"
              class="text-2xs text-violet-700 italic"
            >
              {{ t('admin.schedule.combined.pickAtLeastTwo') }}
            </p>
          </div>
        </div>
        <div v-if="!combinedMode">
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.schedule.formB.semesterLabel') }}
          </label>
          <select
            v-model="semesterId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">{{ t('admin.schedule.formB.semesterPlaceholder') }}</option>
            <option v-for="s in semesters" :key="s.id" :value="s.id">{{ semesterLabel(s.name) }}</option>
          </select>
        </div>
      </div>

      <!-- "Jadwalkan bareng kelas lain" toggle row. Violet-tint
           background so it visually anchors the "extra thing" outside
           the regular field grid. Rendered right after Kelas so the
           toggle's effect (widening the picker above) is spatially
           adjacent to its cause. -->
      <label
        class="flex items-start gap-3 rounded-xl border border-violet-200 bg-violet-50/50 hover:bg-violet-50 px-3 py-2.5 cursor-pointer transition-colors"
      >
        <input
          type="checkbox"
          class="mt-0.5 w-4 h-4 accent-violet-600 flex-shrink-0"
          :checked="combinedMode"
          @change="(e) => onToggleCombined((e.target as HTMLInputElement).checked)"
        />
        <div class="min-w-0 flex-1">
          <p class="text-[13px] font-bold text-violet-900 leading-tight">
            <span class="mr-1">⚭</span>
            {{ t('admin.schedule.combined.toggleLabel') }}
          </p>
          <p class="text-2xs text-violet-700 mt-0.5 leading-snug">
            {{ t('admin.schedule.combined.toggleHint') }}
          </p>
        </div>
      </label>

      <!-- Combined-mode: Semester falls out of the Kelas row and lives
           on its own here so the layout stays two-line even when Kelas
           expanded to full width. -->
      <div v-if="combinedMode">
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          {{ t('admin.schedule.formB.semesterLabel') }}
        </label>
        <select
          v-model="semesterId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">{{ t('admin.schedule.formB.semesterPlaceholder') }}</option>
          <option v-for="s in semesters" :key="s.id" :value="s.id">{{ semesterLabel(s.name) }}</option>
        </select>
      </div>

      <!-- Slot (Hari × Jam Ke-) — always paired to make the "one slot"
           metaphor obvious. -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          {{ t('admin.schedule.formB.slotLabel') }}
        </label>
        <div class="mt-1 grid grid-cols-2 gap-3">
          <select
            v-model="dayId"
            class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">{{ t('admin.schedule.formB.dayPlaceholder') }}</option>
            <option v-for="d in days" :key="d.id" :value="d.id">{{ formatDayName(d.name) }}</option>
          </select>

          <!-- Jam Ke- — surfaces the same empty-hours guidance from the
               legacy form when the school hasn't seeded any. Since the
               setup-first gate now catches "no hours at all", this
               branch mostly serves the narrower "hours exist but none
               for the picked day" case. -->
          <template v-if="hasNoLessonHours">
            <button
              type="button"
              class="w-full text-left rounded-xl border border-dashed border-amber-300 bg-amber-50 px-3 py-2 hover:bg-amber-100 transition-colors"
              @click="goToLessonHourSettings"
            >
              <p class="text-3xs font-bold uppercase tracking-widest text-amber-700 flex items-center gap-1.5">
                <NavIcon name="alert-triangle" :size="12" />
                {{ t('admin.schedule.emptyLessonHours.badge') }}
              </p>
            </button>
          </template>
          <!-- Skeleton while the /lesson-hours GET is in flight so the
               admin sees "loading" instead of a disabled empty box. Same
               height + border as the real select so the layout is
               stable when it swaps in. -->
          <div
            v-else-if="isLoadingHours && lessonHours.length === 0"
            class="h-9 w-full rounded-xl bg-slate-100 animate-pulse motion-reduce:animate-none"
            aria-hidden="true"
          />
          <select
            v-else
            v-model="lessonHourId"
            :disabled="!dayId"
            class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
          >
            <option value="">{{ t('admin.schedule.formB.hourPlaceholder') }}</option>
            <option
              v-for="h in filteredHours"
              :key="h.id"
              :value="h.id"
              :disabled="isHourOccupied(h)"
            >
              {{ t('common.lessonHour', { n: h.hour_number }) }} · {{ h.start_time }}–{{ h.end_time }}{{ isHourOccupied(h) ? ` (${t('common.occupied')})` : '' }}
            </option>
          </select>
        </div>
        <p v-if="dayHasNoLessonHours" class="text-2xs text-amber-700 mt-1.5 leading-relaxed">
          {{ t('admin.schedule.emptyLessonHours.dayEmpty') }}
          <button
            type="button"
            class="font-bold underline hover:text-amber-900"
            @click="goToLessonHourSettings"
          >
            {{ t('admin.schedule.emptyLessonHours.cta') }}
          </button>
        </p>
      </div>

      <!-- Guru — slot-filtered. Locked until Kelas + Slot are set so
           the admin knows the picker will populate once they finish
           the setup above. -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          {{ t('admin.schedule.formB.teacherLabel') }}
          <span
            v-if="isLoadingAvailableTeachers"
            class="text-slate-400 normal-case font-normal ml-1"
          >
            {{ t('admin.schedule.formB.teacherLoading') }}
          </span>
        </label>

        <p v-if="teacherPickerLocked" class="mt-1 text-2xs text-slate-500 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2">
          <NavIcon name="lock" :size="11" class="inline text-slate-400" />
          {{ t('admin.schedule.formB.teacherLocked') }}
        </p>

        <template v-else>
          <!-- Skeleton while /available-teachers is in flight. Replaces
               the disabled empty select so the admin sees "loading"
               rather than a picker that looks broken. Same 9-unit
               height as the real select keeps layout stable. -->
          <div
            v-if="isLoadingAvailableTeachers && availableTeachers.length === 0"
            class="mt-1 h-9 w-full rounded-xl bg-slate-100 animate-pulse motion-reduce:animate-none"
            aria-hidden="true"
          />
          <select
            v-else
            v-model="teacherId"
            :disabled="availableTeachers.length === 0"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
          >
            <option value="">{{ t('admin.schedule.formB.teacherPlaceholder') }}</option>
            <option
              v-for="tt in availableTeachers"
              :key="tt.id"
              :value="tt.id"
            >
              {{ tt.is_wali_kelas_of_this_class ? '★ ' : '' }}{{ tt.name }}{{ tt.is_wali_kelas_of_this_class ? ` · ${t('admin.schedule.formB.waliBadge')}` : '' }}
            </option>
          </select>

          <!-- Only claim "nobody is free" once the server has actually said so
               (hasFetchedAvailableTeachers). An un-asked slot must never be
               reported as a full one. -->
          <p
            v-if="hasFetchedAvailableTeachers && !isLoadingAvailableTeachers && availableTeachers.length === 0 && !availableTeachersError"
            class="text-2xs text-amber-700 mt-1.5 leading-relaxed"
          >
            <NavIcon name="alert-circle" :size="11" class="inline" />
            {{ t('admin.schedule.formB.teacherEmpty') }}
            <span class="block text-slate-500 font-normal">
              {{ t('admin.schedule.formB.teacherEmptyHint') }}
            </span>
          </p>

          <p
            v-if="availableTeachersError"
            class="text-2xs text-red-700 mt-1.5 leading-relaxed"
          >
            {{ availableTeachersError }}
          </p>
        </template>
      </div>

      <!-- Mapel — filtered by picked guru (existing from MR!866). -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          {{ t('common.subject') }}
          <span v-if="isLoadingSubjects" class="text-slate-400 normal-case font-normal ml-1">memuat...</span>
        </label>
        <!-- Skeleton while the teacher's linked-subjects list is being
             fetched. The greyed-out disabled select was ambiguous
             (looked like "empty + broken"); the pulsing bar is
             unambiguously "loading". -->
        <div
          v-if="isLoadingSubjects && !!teacherId"
          class="mt-1 h-9 w-full rounded-xl bg-slate-100 animate-pulse motion-reduce:animate-none"
          aria-hidden="true"
        />
        <select
          v-else
          v-model="subjectId"
          :disabled="!teacherId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
        >
          <option value="">— pilih mapel —</option>
          <option v-for="s in subjectOptions" :key="s.id" :value="s.id">
            {{ subjectLabel(s) }}
          </option>
        </select>

        <!-- Link-first mapel management. The dropdown above shows only the mapel
             the guru is linked to; this panel is how you grow that list. For a
             guru with none it's the primary CTA (amber "tautkan dulu"); for one
             who already teaches some it's a quieter "tautkan mapel lain". -->
        <div v-if="canLinkSubject" class="mt-1.5">
          <button
            type="button"
            class="w-full flex items-center gap-2 rounded-xl border px-3 py-2 text-2xs font-bold transition-colors text-left"
            :class="teacherHasNoSubjects
              ? 'bg-amber-50 border-amber-200 hover:border-amber-400 text-amber-800'
              : 'bg-slate-50 border-slate-200 hover:border-slate-300 text-slate-600'"
            :aria-expanded="quickAddOpen"
            @click="quickAddOpen = !quickAddOpen"
          >
            <NavIcon :name="quickAddOpen ? 'chevron-down' : 'chevron-right'" :size="12" />
            <span class="flex-1 leading-relaxed">
              <template v-if="teacherHasNoSubjects">
                {{ selectedTeacherName || 'Guru ini' }} belum punya mapel · tautkan dulu
              </template>
              <template v-else>
                + Tautkan mapel lain ke {{ selectedTeacherName || 'guru ini' }}
              </template>
            </span>
          </button>

          <div
            v-if="quickAddOpen"
            class="mt-2 rounded-xl border border-amber-200 bg-amber-50/40 p-3 space-y-3 animate-in fade-in slide-in-from-top-1 duration-150"
          >
            <!-- Tab strip — "Pilih Existing" default, "Buat Baru" escape -->
            <div class="flex gap-1 rounded-xl bg-white border border-amber-200 p-1">
              <button
                type="button"
                class="flex-1 rounded-lg px-3 py-1.5 text-2xs font-bold transition-colors"
                :class="quickAddTab === 'pick'
                  ? 'bg-amber-500 text-white'
                  : 'text-amber-800 hover:bg-amber-50'"
                :disabled="isQuickAddAttaching || isQuickAdding"
                @click="quickAddTab = 'pick'; quickAddSelectedExistingId = ''"
              >
                Pilih Existing
              </button>
              <button
                type="button"
                class="flex-1 rounded-lg px-3 py-1.5 text-2xs font-bold transition-colors"
                :class="quickAddTab === 'create'
                  ? 'bg-amber-500 text-white'
                  : 'text-amber-800 hover:bg-amber-50'"
                :disabled="isQuickAddAttaching || isQuickAdding"
                @click="quickAddTab = 'create'"
              >
                Buat Baru
              </button>
            </div>

            <!-- Tab: Pilih Existing -->
            <template v-if="quickAddTab === 'pick'">
              <template v-if="quickAddExistingCandidates.length > 0">
                <p class="text-2xs text-slate-700 leading-relaxed">
                  Tautkan mapel sekolah yang sudah ada ke
                  <span class="font-bold">{{ selectedTeacherName || 'guru ini' }}</span>:
                </p>
                <!-- Search — only when list is long enough to warrant it -->
                <input
                  v-if="quickAddExistingCandidates.length > 5"
                  v-model="quickAddExistingSearch"
                  type="text"
                  placeholder="Cari mapel..."
                  autocomplete="off"
                  :disabled="isQuickAddAttaching"
                  class="w-full bg-white border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-medium text-slate-900 outline-none focus:border-role-admin"
                />
                <div class="max-h-56 overflow-y-auto rounded-xl border border-slate-200 bg-white divide-y divide-slate-100">
                  <template v-if="quickAddFilteredCandidates.length > 0">
                    <label
                      v-for="s in quickAddFilteredCandidates"
                      :key="s.id"
                      class="flex items-start gap-2.5 px-3 py-2 cursor-pointer hover:bg-amber-50/60"
                    >
                      <input
                        v-model="quickAddSelectedExistingId"
                        type="radio"
                        name="quickAddExisting"
                        :value="s.id"
                        :disabled="isQuickAddAttaching"
                        class="mt-1 accent-amber-500"
                      />
                      <div class="min-w-0 flex-1">
                        <div class="text-[13px] font-bold text-slate-900 truncate">
                          {{ s.name }}
                        </div>
                        <div
                          v-if="s.code || s.grade"
                          class="text-3xs text-slate-500 mt-0.5"
                        >
                          <span v-if="s.code">{{ s.code }}</span>
                          <span v-if="s.code && s.grade"> · </span>
                          <span v-if="s.grade">Kelas {{ s.grade }}</span>
                        </div>
                      </div>
                    </label>
                  </template>
                  <p
                    v-else
                    class="px-3 py-4 text-2xs text-slate-500 text-center"
                  >
                    Tidak ada mapel yang cocok.
                  </p>
                </div>
                <p
                  v-if="quickAddErr"
                  class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl px-3 py-2"
                >
                  {{ quickAddErr }}
                </p>
                <div class="grid grid-cols-2 gap-2">
                  <Button variant="secondary" size="sm" block @click="cancelQuickAdd">
                    Batal
                  </Button>
                  <Button
                    variant="primary"
                    size="sm"
                    block
                    :loading="isQuickAddAttaching"
                    :disabled="!quickAddSelectedExistingId || isQuickAddAttaching"
                    @click="submitQuickAddAttach"
                  >
                    Tautkan
                  </Button>
                </div>
              </template>
              <p
                v-else
                class="text-2xs text-slate-600 leading-relaxed py-2"
              >
                Sekolah belum punya mapel. Buat sekarang di tab
                <span class="font-bold">Buat Baru</span>.
              </p>
            </template>

            <!-- Tab: Buat Baru -->
            <template v-else>
              <p class="text-3xs font-bold uppercase tracking-widest text-amber-800 flex items-center gap-1.5">
                <NavIcon name="plus" :size="12" />
                Tambah mapel baru
              </p>
              <div>
                <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Nama mapel</label>
                <input
                  v-model="quickAddName"
                  type="text"
                  placeholder="Matematika"
                  autocomplete="off"
                  class="mt-1 w-full bg-white border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
                  @keydown.enter.prevent="submitQuickAdd"
                />
              </div>
              <div>
                <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
                  Kode <span class="text-slate-400 normal-case font-normal">(opsional)</span>
                </label>
                <input
                  v-model="quickAddCode"
                  type="text"
                  placeholder="MTK"
                  autocomplete="off"
                  class="mt-1 w-full bg-white border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
                  @keydown.enter.prevent="submitQuickAdd"
                />
              </div>
              <!-- Smart-hint: mapel with this name already exists at
                   grade-scoped rows. Purely informational here — Quick-Add
                   has no grade field and always creates a universal row. -->
              <div
                v-if="quickAddSimilar.has_similar"
                class="rounded-xl border border-amber-300 bg-amber-100/60 p-2.5 flex gap-2"
                role="alert"
              >
                <NavIcon name="alert-circle" :size="14" class="flex-none mt-0.5 text-amber-800" />
                <div class="min-w-0 flex-1">
                  <p class="text-2xs font-bold text-amber-900 leading-snug">
                    {{
                      $t('admin.subjects.form.similarWarnTitle', {
                        count: quickAddSimilar.matches.length,
                        name: quickAddName.trim(),
                      })
                    }}
                  </p>
                  <ul class="mt-1 space-y-0.5 text-3xs text-amber-900">
                    <li v-for="m in quickAddSimilar.matches" :key="m.id" class="leading-snug">
                      <span class="inline-block w-3 text-amber-600">·</span>
                      <span v-if="m.grade !== null">
                        {{ $t('admin.subjects.form.similarWarnItem', { name: m.name, grade: m.grade }) }}
                      </span>
                      <span v-else>
                        {{ $t('admin.subjects.form.similarWarnItemNoGrade', { name: m.name }) }}
                      </span>
                    </li>
                  </ul>
                </div>
              </div>
              <p class="text-3xs text-slate-500 leading-relaxed">
                Mapel akan otomatis di-assign ke {{ selectedTeacherName || 'guru ini' }} dan langsung dipakai di slot ini.
              </p>
              <p
                v-if="quickAddErr"
                class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl px-3 py-2"
              >
                {{ quickAddErr }}
              </p>
              <div class="grid grid-cols-2 gap-2">
                <Button variant="secondary" size="sm" block @click="cancelQuickAdd">Batal</Button>
                <Button
                  variant="primary"
                  size="sm"
                  block
                  :loading="isQuickAdding"
                  :disabled="!quickAddName.trim() || isQuickAdding"
                  @click="submitQuickAdd"
                >
                  Simpan &amp; pakai
                </Button>
              </div>
            </template>
          </div>
        </div>
      </div>

      <!-- Ruangan (optional, remembered per-class) -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          {{ t('admin.schedule.formB.roomLabel') }}
        </label>
        <input
          v-model="room"
          type="text"
          :placeholder="t('admin.schedule.formB.roomPlaceholder')"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        />
        <p class="text-3xs text-slate-500 mt-1">{{ t('admin.schedule.formB.roomHint') }}</p>
      </div>

      <!-- Combined-mode info banner. Sits between the form fields and
           the conflict preview so it reads as a "here's what will
           happen" summary once the multi-select is populated. Only
           surfaces when the group has 2+ classes — the "please pick
           at least 2" hint above the chip picker covers the 0/1 case. -->
      <div
        v-if="combinedMode && classIds.length >= 2"
        class="rounded-xl border border-violet-200 bg-violet-50 p-3 flex gap-2.5"
      >
        <NavIcon name="info" :size="14" class="flex-none mt-0.5 text-violet-700" />
        <div class="min-w-0 flex-1 space-y-1">
          <p class="text-2xs font-bold text-violet-900 leading-snug">
            {{
              t('admin.schedule.combined.infoBannerTitle', {
                count: classIds.length,
              })
            }}
          </p>
          <p class="text-2xs text-violet-800 leading-snug">
            {{ t('admin.schedule.combined.infoBannerHint') }}
          </p>
        </div>
      </div>

      <!-- Conflict preview -->
      <div
        v-if="isProbingConflicts"
        class="text-2xs text-slate-500 bg-slate-50 rounded-xl p-3"
      >
        Memeriksa bentrok...
      </div>
      <div
        v-else-if="hasConflict"
        class="bg-red-50 border border-red-200 rounded-xl p-3 space-y-2"
      >
        <p class="text-2xs font-bold text-red-700 uppercase tracking-widest flex items-center gap-1.5">
          <NavIcon name="alert-triangle" :size="12" />
          {{ conflicts.length }} bentrok terdeteksi
        </p>
        <ul class="text-2xs text-red-700 space-y-1">
          <li v-for="c in conflicts" :key="c.id" class="leading-relaxed">
            <strong>{{ formatDayName(c.day_name) }} · {{ c.start_time }}–{{ c.end_time }}</strong>:
            {{ c.subject_name ?? 'Mapel' }}
            <span v-if="c.teacher_name"> · {{ c.teacher_name }}</span>
            <span v-if="c.class_name"> · {{ c.class_name }}</span>
          </li>
        </ul>
        <label class="flex items-center gap-2 text-2xs text-red-800 font-bold mt-2 cursor-pointer">
          <input v-model="forceSave" type="checkbox" class="accent-red-600" />
          Paksa simpan meski bentrok
        </label>
      </div>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <p
        v-if="toast"
        class="text-2xs font-bold rounded-xl px-3 py-2"
        :class="toast.tone === 'success' ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-red-50 text-red-800 border border-red-200'"
      >
        {{ toast.message }}
      </p>

      <!-- Action row. Layout:
             1 col Batal · 2 col primary — on edit
             1 col Batal · 2 col primary · optional 'Tambah Lagi' — on create
           The "Tambah Lagi" tail is create-only because editing a
           single row through the form doesn't need a fan-out variant. -->
      <div v-if="isEdit" class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!canSubmit"
          @click="save()"
        >
          {{
            combinedMode
              ? t('admin.schedule.combined.primaryEdit')
              : t('admin.schedule.formB.primaryEdit')
          }}
        </Button>
      </div>
      <div v-else class="grid grid-cols-6 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')" class="col-span-2">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!canSubmit"
          class="col-span-2"
          @click="save()"
        >
          {{
            combinedMode
              ? t('admin.schedule.combined.primaryCreate', {
                  count: classIds.length,
                })
              : t('admin.schedule.formB.primaryCreate')
          }}
        </Button>
        <Button
          variant="success"
          block
          :loading="isSaving"
          :disabled="!canSubmit"
          class="col-span-2"
          @click="save({ continueAfter: true })"
        >
          <NavIcon name="plus" :size="12" />
          {{ t('admin.schedule.formB.createAndContinue') }}
        </Button>
      </div>
    </div>
  </Modal>
</template>

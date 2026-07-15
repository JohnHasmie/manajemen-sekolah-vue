<!--
  ScheduleFormModal.vue — admin add/edit schedule sheet (Mockup Frame D).

  Cascading dropdowns:
    Teacher → Subject (filtered to teacher's mapel) → Class → Day(s) →
    Lesson hour.

  Live conflict probe: when teacher + class + days + lesson_hour are
  all set, hits `GET /teaching-schedule/conflicts` and surfaces
  conflicts inline. The Save button still enables — the server enforces
  with a 409 + Paksa Simpan flow on submit.

  Multi-day on create (one POST per day, server fans out via
  `days_ids[] + lesson_hour_id`). Single-day on edit (uses PUT against
  the picked slot).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { ScheduleService } from '@/services/schedule.service';
import { LessonHourService } from '@/services/lesson-hour.service';
import { SubjectService } from '@/services/subjects.service';
import { api } from '@/lib/http';
import type {
  LessonHour,
  ScheduleConflict,
  ScheduleFilterOptions,
  ScheduleRow,
} from '@/types/schedule';
import { useAcademicYearStore } from '@/stores/academic-year';
import { semesterLabel, subjectLabel } from '@/lib/labels';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Pass a row to edit; omit/null to create. */
  row?: ScheduleRow | null;
  /** Pre-loaded filter options (admin hub already fetched them). */
  filterOptions?: ScheduleFilterOptions | null;
  /** Pre-filled semester id (defaults to first option). */
  defaultSemesterId?: string;
}>();

const emit = defineEmits<{
  close: [];
  saved: [ScheduleRow[]];
}>();

const ayStore = useAcademicYearStore();
const { t } = useI18n();
const router = useRouter();

const isEdit = computed(() => Boolean(props.row?.id));

// ── Form state ──────────────────────────────────────────────────────
const teacherId = ref<string>(props.row?.teacher_id ?? '');
const subjectId = ref<string>(props.row?.subject_id ?? '');
const classId = ref<string>(props.row?.class_id ?? '');
const semesterId = ref<string>(
  props.row?.semester_id ?? props.defaultSemesterId ?? '',
);
const academicYearId = ref<string | number>(
  props.row?.academic_year_id ?? ayStore.selectedYearId ?? '',
);
/** UUIDs of selected days. Multi for create, single for edit. */
const selectedDayIds = ref<string[]>(
  props.row?.day_id ? [props.row.day_id] : [],
);
/** UUID of the reference lesson_hour row (defines hour_number). */
const lessonHourId = ref<string>(
  props.row?.lesson_hour_days_id ?? '',
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
/** True only when the teacher-subjects request errored (not when it
 * succeeded but returned an empty list). Mirrors Flutter: on error we
 * fall back to showing all subjects; on a genuine empty result we show
 * none so the picker is scoped strictly to the teacher's mapel. */
const subjectsLoadFailed = ref(false);
/** True only when the lesson-hours request errored. Same rationale as
 * `subjectsLoadFailed`: a genuine empty list means the school hasn't set
 * its Jam Pelajaran up yet (actionable — we point the admin at the
 * settings page), whereas a failed request means we simply don't know.
 * Telling an admin "belum diatur" after a network blip would be a lie. */
const hoursLoadFailed = ref(false);

const isLoadingSubjects = ref(false);
// Starts true: the modal always loads hours on mount, and `onMounted`
// awaits loadAllSubjects() first, so there is a real window before
// loadLessonHours() even starts. Seeding this false would make the
// "belum diatur" empty state flash on every open — including schools
// that have hours — until the request resolves.
const isLoadingHours = ref(true);
const isProbingConflicts = ref(false);
const isSaving = ref(false);
const err = ref<string | null>(null);
const forceSave = ref(false);

// ── Inline Quick-Add mapel state ────────────────────────────────────
// When a picked teacher has no subjects, expose an inline expandable
// panel so the admin can create + assign a mapel without leaving the
// drawer (Sprint 1 pola A — see UX proposal 01/06). Emit the created
// subject via `created` for callers; we also refresh the teacher's
// subject list and auto-select the new one.
const quickAddOpen = ref(false);
const quickAddName = ref('');
const quickAddCode = ref('');
const isQuickAdding = ref(false);
const quickAddErr = ref<string | null>(null);

// ── Loaders ─────────────────────────────────────────────────────────
async function loadAllSubjects() {
  try {
    const res = await api.get('/subject', { params: { per_page: 200 } });
    const body = res.data;
    const list = Array.isArray(body?.data) ? body.data : Array.isArray(body) ? body : [];
    // `code` distinguishes same-named subjects (Al Qur'an Hadis 7/8/9).
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
    // Reuse SubjectService.listForTeacher — returns the teacher's own
    // mapel (full {id,name} rows, not just IDs). scope='teaching' drops
    // the parent-kelas homeroom-class curriculum, so picking a homeroom
    // teacher lists only the subjects they actually teach (not every
    // subject offered in their class).
    const list = await SubjectService.listForTeacher(tId, 'teaching');
    const ids = new Set(list.map((s) => s.id));
    teacherSubjects.value = list.map((s) => ({
      id: s.id,
      name: s.name,
      code: s.code ?? null,
    }));
    // Clear subject if it's no longer in the teacher's set.
    if (subjectId.value && !ids.has(subjectId.value)) subjectId.value = '';
  } catch {
    // On error only, fall back to all subjects (mirrors Flutter mixin).
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
    selectedDayIds.value.length === 0 ||
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
      days_ids: selectedDayIds.value,
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
 * day (+ term / academic year). Mirrors Flutter's `fetchOccupiedSlots`:
 * each occupied row's lesson hour gets marked "Terisi" + disabled in the
 * Jam Pelajaran picker so the admin can't double-book a slot.
 */
async function fetchOccupiedSlots() {
  if (
    !classId.value ||
    selectedDayIds.value.length === 0 ||
    !semesterId.value
  ) {
    occupiedSlots.value = [];
    return;
  }
  try {
    const res = await ScheduleService.list({
      class_id: classId.value,
      day_id: selectedDayIds.value[0],
      semester_id: semesterId.value,
      academic_year_id: academicYearId.value || undefined,
      per_page: 100,
    });
    // Exclude the row currently being edited — its own slot isn't "taken".
    occupiedSlots.value = props.row?.id
      ? res.items.filter((s) => s.id !== props.row?.id)
      : res.items;
  } catch {
    occupiedSlots.value = [];
  }
}

onMounted(async () => {
  await loadAllSubjects();
  await loadLessonHours();
  if (teacherId.value) await loadSubjectsForTeacher(teacherId.value);
  await fetchOccupiedSlots();
});

watch(teacherId, async (v) => {
  // Fold the panel + reset its inputs whenever the teacher changes so
  // we don't leak "Simpan & pakai" state onto a different teacher.
  quickAddOpen.value = false;
  quickAddName.value = '';
  quickAddCode.value = '';
  quickAddErr.value = null;
  await loadSubjectsForTeacher(v);
});

// Re-fetch occupied slots whenever the class / day / term context changes.
watch(
  [classId, selectedDayIds, semesterId, academicYearId],
  () => void fetchOccupiedSlots(),
  { deep: true },
);

// Debounced conflict probe
let probeTimer: ReturnType<typeof setTimeout> | null = null;
watch(
  [teacherId, classId, lessonHourId, selectedDayIds, semesterId, academicYearId],
  () => {
    if (probeTimer) clearTimeout(probeTimer);
    probeTimer = setTimeout(() => void probeConflicts(), 250);
  },
  { deep: true },
);

// ── Derived ────────────────────────────────────────────────────────
// Scope the mapel picker strictly to the selected teacher's subjects.
// Only fall back to the full catalogue when the teacher-subjects request
// errored — a successful-but-empty result means the teacher has no mapel,
// so we show none (matching the Flutter behaviour).
const subjectOptions = computed(() =>
  subjectsLoadFailed.value ? allSubjects.value : teacherSubjects.value,
);

const days = computed(() => props.filterOptions?.days ?? []);
const teachers = computed(() => props.filterOptions?.teachers ?? []);
const classes = computed(() => props.filterOptions?.classes ?? []);
const semesters = computed(() => props.filterOptions?.semesters ?? []);

function toggleDay(id: string) {
  if (isEdit.value) {
    selectedDayIds.value = [id]; // edit = single
    return;
  }
  const set = new Set(selectedDayIds.value);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  selectedDayIds.value = Array.from(set);
}

const formValid = computed(
  () =>
    teacherId.value &&
    subjectId.value &&
    classId.value &&
    semesterId.value &&
    academicYearId.value &&
    selectedDayIds.value.length > 0 &&
    lessonHourId.value,
);

const hasConflict = computed(() => conflicts.value.length > 0);
const canSubmit = computed(() => {
  if (!formValid.value || isSaving.value) return false;
  if (hasConflict.value && !forceSave.value) return false;
  return true;
});

// ── Save ───────────────────────────────────────────────────────────
async function save() {
  if (!formValid.value) {
    err.value = 'Lengkapi semua kolom.';
    return;
  }
  isSaving.value = true;
  err.value = null;
  try {
    if (isEdit.value && props.row?.id) {
      const updated = await ScheduleService.update(props.row.id, {
        teacher_id: teacherId.value,
        subject_id: subjectId.value,
        class_id: classId.value,
        days_ids: selectedDayIds.value,
        lesson_hour_id: lessonHourId.value,
        semester_id: semesterId.value,
        academic_year_id: academicYearId.value,
        room: room.value || null,
      });
      emit('saved', [updated]);
    } else {
      const created = await ScheduleService.create({
        teacher_id: teacherId.value,
        subject_id: subjectId.value,
        class_id: classId.value,
        days_ids: selectedDayIds.value,
        lesson_hour_id: lessonHourId.value,
        semester_id: semesterId.value,
        academic_year_id: academicYearId.value,
        room: room.value || null,
      });
      emit('saved', created);
    }
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Quick-Add mapel ────────────────────────────────────────────────
/** Human name of the selected teacher, used in the empty-state copy. */
const selectedTeacherName = computed(() => {
  const t = teachers.value.find((x) => x.id === teacherId.value);
  return t?.name ?? '';
});

/**
 * True when the picked teacher genuinely has no mapel assigned — the
 * only case where we surface the inline Quick-Add CTA. A load error
 * (subjectsLoadFailed) or an in-flight request are both excluded so we
 * don't offer the CTA when the empty list is a transient state.
 */
const teacherHasNoSubjects = computed(
  () =>
    !!teacherId.value &&
    !isLoadingSubjects.value &&
    !subjectsLoadFailed.value &&
    teacherSubjects.value.length === 0,
);

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
    });
    // Refresh the teacher's subject list from the server so the picker
    // reflects every attach the backend just committed (not just the
    // one we optimistically added). Fall back to a local push if the
    // refresh fails so the newly-created row is still selectable.
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
  } catch (e) {
    quickAddErr.value = (e as Error).message;
  } finally {
    isQuickAdding.value = false;
  }
}

function cancelQuickAdd() {
  quickAddOpen.value = false;
  quickAddErr.value = null;
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
  // If a day is selected, show only hours for that day (the reference
  // hour determines hour_number — backend will map to each day's
  // matching hour_number row).
  if (selectedDayIds.value.length === 0) return lessonHours.value;
  const first = selectedDayIds.value[0];
  return groupedHours.value.get(first) ?? [];
});

/** Lesson-hour slot ids that are already booked for the picked class/day.
 * Mirrors Flutter's match on `lesson_hour_days_id`. */
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

/**
 * The school has no Jam Pelajaran at all. Without one the Jam Pelajaran
 * picker has nothing to offer, `lessonHourId` can never be set, and so
 * `formValid` can never become true — the Buat Jadwal button would sit
 * disabled forever with no stated reason. Surface the cause + the fix
 * instead of letting the admin conclude the feature is broken.
 */
const hasNoLessonHours = computed(
  () => !isLoadingHours.value && !hoursLoadFailed.value && lessonHours.value.length === 0,
);

/**
 * Hours exist, but none for the day the admin picked (e.g. the school
 * set Senin–Jumat and they picked Sabtu). Same dead-end, narrower cause.
 */
const dayHasNoLessonHours = computed(
  () =>
    !isLoadingHours.value &&
    !hoursLoadFailed.value &&
    lessonHours.value.length > 0 &&
    selectedDayIds.value.length > 0 &&
    filteredHours.value.length === 0,
);

/** Leave the modal behind — the fix lives on the settings page. */
function goToLessonHourSettings() {
  emit('close');
  void router.push({ name: 'admin.schedule.lesson-hours' });
}
</script>

<template>
  <Modal
    :title="isEdit ? 'Edit Jadwal' : 'Tambah Jadwal'"
    :subtitle="
      isEdit
        ? 'Perubahan langsung diterapkan ke jadwal pekan ini.'
        : 'Pilih guru, mapel, kelas, hari, lalu jam pelajaran.'
    "
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Teacher -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Guru</label>
        <select
          v-model="teacherId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">— pilih guru —</option>
          <option v-for="t in teachers" :key="t.id" :value="t.id">{{ t.name }}</option>
        </select>
      </div>

      <!-- Subject (filtered by teacher) -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Mata Pelajaran
          <span v-if="isLoadingSubjects" class="text-slate-400 normal-case font-normal ml-1">memuat...</span>
        </label>
        <select
          v-model="subjectId"
          :disabled="!teacherId || isLoadingSubjects"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
        >
          <option value="">— pilih mapel —</option>
          <option v-for="s in subjectOptions" :key="s.id" :value="s.id">{{ subjectLabel(s) }}</option>
        </select>

        <!-- Inline Quick-Add: teacher-with-no-mapel dead-end handled in
             the drawer instead of forcing a navigate-away. Toggle button
             expands a panel that creates the mapel + assigns it to the
             teacher atomically (POST /subject with assign_to_teacher_id).
             Wireframe: 01 (Pola A) / 03 (web drawer). -->
        <div v-if="teacherHasNoSubjects" class="mt-1.5">
          <button
            type="button"
            class="w-full flex items-center gap-2 rounded-xl bg-amber-50 border border-amber-200 hover:border-amber-400 px-3 py-2 text-2xs text-amber-800 font-bold transition-colors text-left"
            :aria-expanded="quickAddOpen"
            @click="quickAddOpen = !quickAddOpen"
          >
            <NavIcon :name="quickAddOpen ? 'chevron-down' : 'chevron-right'" :size="12" />
            <span class="flex-1 leading-relaxed">
              {{ selectedTeacherName || 'Guru ini' }} belum punya mapel · tambahkan
            </span>
          </button>

          <div
            v-if="quickAddOpen"
            class="mt-2 rounded-xl border border-amber-200 bg-amber-50/40 p-3 space-y-3 animate-in fade-in slide-in-from-top-1 duration-150"
          >
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
          </div>
        </div>
      </div>

      <!-- Class + Semester -->
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Kelas</label>
          <select
            v-model="classId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">— pilih kelas —</option>
            <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Semester</label>
          <select
            v-model="semesterId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">— pilih semester —</option>
            <option v-for="s in semesters" :key="s.id" :value="s.id">{{ semesterLabel(s.name) }}</option>
          </select>
        </div>
      </div>

      <!-- Days (multi for create, single for edit) -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Hari {{ isEdit ? '(pilih satu)' : '(boleh banyak)' }}
        </label>
        <div class="mt-1 flex flex-wrap gap-1.5">
          <button
            v-for="d in days"
            :key="d.id"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold border transition-colors"
            :class="
              selectedDayIds.includes(d.id)
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="toggleDay(d.id)"
          >
            {{ d.name }}
          </button>
        </div>
      </div>

      <!-- Lesson hour -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Jam Pelajaran (referensi)
        </label>

        <!-- No Jam Pelajaran configured at all — the picker would be an
             empty dead-end, so explain it and hand over the fix. -->
        <button
          v-if="hasNoLessonHours"
          type="button"
          class="mt-1 w-full text-left rounded-xl border border-dashed border-amber-300 bg-amber-50 p-3 hover:bg-amber-100 transition-colors"
          @click="goToLessonHourSettings"
        >
          <p class="text-3xs font-bold uppercase tracking-widest text-amber-700 flex items-center gap-1.5">
            <NavIcon name="alert-triangle" :size="12" />
            {{ t('admin.schedule.emptyLessonHours.badge') }}
          </p>
          <p class="text-[13px] font-bold text-amber-900 mt-1">
            {{ t('admin.schedule.emptyLessonHours.formDesc') }}
          </p>
          <p class="text-2xs text-amber-700 mt-1.5 font-bold">
            {{ t('admin.schedule.emptyLessonHours.cta') }} ·
            <span class="font-normal">{{ t('admin.schedule.emptyLessonHours.menuHint') }}</span>
          </p>
        </button>

        <template v-else>
          <select
            v-model="lessonHourId"
            :disabled="selectedDayIds.length === 0 || isLoadingHours"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
          >
            <option value="">— pilih jam —</option>
            <option
              v-for="h in filteredHours"
              :key="h.id"
              :value="h.id"
              :disabled="isHourOccupied(h)"
            >
              {{ t('common.lessonHour', { n: h.hour_number }) }} · {{ h.start_time }}–{{ h.end_time }}{{ isHourOccupied(h) ? ` (${t('common.occupied')})` : '' }}
            </option>
          </select>
          <!-- Hours exist, but none on the picked day — same dead-end,
               narrower cause, so name the day and offer the same fix. -->
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
          <p v-if="!isEdit && selectedDayIds.length > 1" class="text-3xs text-slate-500 mt-1">
            Setiap hari akan dibuat di jam ke-{{ filteredHours.find((h) => h.id === lessonHourId)?.hour_number ?? '?' }}.
          </p>
        </template>
      </div>

      <!-- Room (optional) -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Ruangan (opsional)</label>
        <input
          v-model="room"
          type="text"
          placeholder="R-101"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        />
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
            <strong>{{ c.day_name }} · {{ c.start_time }}–{{ c.end_time }}</strong>:
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

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!canSubmit"
          @click="save"
        >
          {{ isEdit ? 'Simpan perubahan' : 'Buat jadwal' }}
        </Button>
      </div>
    </div>
  </Modal>
</template>

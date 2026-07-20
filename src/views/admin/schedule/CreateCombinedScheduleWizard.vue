<!--
  CreateCombinedScheduleWizard.vue — dedicated 3-step wizard for
  creating a "jadwal gabung" (multi-class schedule row).

  Rendered as a modal (via <Modal>) from the FAB dropdown in
  AdminScheduleManagementView. This is the "second entry point" for
  combined scheduling — the ScheduleFormModal already offers an
  in-place toggle (Opsi keduanya per plan), but a first-timer who has
  never done a jadwal gabung benefits from the step-by-step wizard
  that spells out the flow:

    Step 1: Pilih min 2 kelas
    Step 2: Pilih slot (hari + jam) + guru + mapel + ruangan
    Step 3: Konfirmasi ringkasan sebelum simpan

  Reuses the same ScheduleService endpoints as ScheduleFormModal —
  the difference is UX (step-guided vs form) not backend.

  Reuses form patterns / options loading from ScheduleFormModal but
  intentionally does NOT compose it — the wizard's step gating +
  progress bar don't fit inside the modal's field-flat layout, and
  duplicating the ~50 lines of picker markup is cheaper than
  refactoring the modal into a slot-based mess.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import {
  ScheduleService,
  type AvailableTeacher,
} from '@/services/schedule.service';
import { LessonHourService } from '@/services/lesson-hour.service';
import { SubjectService } from '@/services/subjects.service';
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
  /** Pre-loaded filter options (admin hub already fetched them). */
  filterOptions?: ScheduleFilterOptions | null;
  /** Pre-filled semester id (defaults to first option). */
  defaultSemesterId?: string;
}>();

const emit = defineEmits<{
  close: [];
  saved: [ScheduleRow[]];
}>();

const { t } = useI18n();
const router = useRouter();
const ayStore = useAcademicYearStore();

// ── Step state ─────────────────────────────────────────────────────
// 1 = pick classes, 2 = pick slot/teacher/subject/room, 3 = review
type Step = 1 | 2 | 3;
const step = ref<Step>(1);

// ── Step 1 — Classes ───────────────────────────────────────────────
const classIds = ref<string[]>([]);
const semesterId = ref<string>(props.defaultSemesterId ?? '');
const academicYearId = ref<string | number>(ayStore.selectedYearId ?? '');

// ── Step 2 — Slot + teacher + subject + room ───────────────────────
const dayId = ref<string>('');
const lessonHourId = ref<string>('');
const teacherId = ref<string>('');
const subjectId = ref<string>('');
const room = ref<string>('');

// ── Loaded data ────────────────────────────────────────────────────
const lessonHours = ref<LessonHour[]>([]);
const isLoadingHours = ref(false);
const availableTeachers = ref<AvailableTeacher[]>([]);
const isLoadingAvailableTeachers = ref(false);
const availableTeachersError = ref<string | null>(null);
const teacherSubjects = ref<
  Array<{ id: string; name: string; code?: string | null }>
>([]);
const isLoadingSubjects = ref(false);
const conflicts = ref<ScheduleConflict[]>([]);
const isProbingConflicts = ref(false);
const forceSave = ref(false);
const isSaving = ref(false);
const err = ref<string | null>(null);

// ── Derived ────────────────────────────────────────────────────────
const classes = computed(() => props.filterOptions?.classes ?? []);
const semesters = computed(() => props.filterOptions?.semesters ?? []);
const days = computed(() => props.filterOptions?.days ?? []);

const combinedRemainingClasses = computed(() => {
  const already = new Set(classIds.value);
  return classes.value.filter((c) => !already.has(c.id));
});

const pickedClasses = computed(() =>
  classIds.value.map((id) => {
    const c = classes.value.find((cc) => cc.id === id);
    return { id, name: c?.name ?? id };
  }),
);

const groupedHours = computed(() => {
  const grouped = new Map<string, LessonHour[]>();
  for (const h of lessonHours.value) {
    const list = grouped.get(h.day_id) ?? [];
    list.push(h);
    grouped.set(h.day_id, list);
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

const pickedDayName = computed(() => {
  const d = days.value.find((dd) => dd.id === dayId.value);
  return d?.name ?? '';
});
const pickedHour = computed(() => {
  const h = lessonHours.value.find((hh) => hh.id === lessonHourId.value);
  return h ?? null;
});
const pickedTeacher = computed(() => {
  const found = availableTeachers.value.find((tt) => tt.id === teacherId.value);
  if (found) return { id: found.id, name: found.name };
  const fallback = props.filterOptions?.teachers.find(
    (tt) => tt.id === teacherId.value,
  );
  return fallback ? { id: fallback.id, name: fallback.name } : null;
});
const pickedSubject = computed(() =>
  teacherSubjects.value.find((s) => s.id === subjectId.value) ?? null,
);
const pickedSemesterName = computed(() => {
  const s = semesters.value.find((ss) => ss.id === semesterId.value);
  return s?.name ?? '';
});

/** Anchor class used for slot-filtered teacher lookup + subject grade
 *  scoping. Backend groups by teacher+slot, so any one class in the
 *  group is a valid anchor for the /available-teachers call. */
const anchorClassId = computed(() => classIds.value[0] ?? '');

const step1Valid = computed(
  () => classIds.value.length >= 2 && !!semesterId.value,
);
const step2Valid = computed(
  () =>
    !!dayId.value &&
    !!lessonHourId.value &&
    !!teacherId.value &&
    !!subjectId.value,
);
const canSubmit = computed(() => {
  if (isSaving.value) return false;
  if (!step1Valid.value || !step2Valid.value) return false;
  if (conflicts.value.length > 0 && !forceSave.value) return false;
  return true;
});

// ── Loaders ────────────────────────────────────────────────────────
async function loadLessonHours() {
  isLoadingHours.value = true;
  try {
    lessonHours.value = await LessonHourService.list();
  } catch {
    lessonHours.value = [];
  } finally {
    isLoadingHours.value = false;
  }
}

async function loadAvailableTeachers() {
  if (!anchorClassId.value || !dayId.value || !lessonHourId.value) {
    availableTeachers.value = [];
    return;
  }
  isLoadingAvailableTeachers.value = true;
  availableTeachersError.value = null;
  try {
    const list = await ScheduleService.getAvailableTeachers({
      classId: anchorClassId.value,
      dayId: dayId.value,
      lessonHourId: lessonHourId.value,
      semesterId: semesterId.value || undefined,
      academicYearId: academicYearId.value || undefined,
    });
    list.sort((a, b) => {
      // Wali kelas of anchor first, then more-versatile, then name.
      if (a.is_wali_kelas_of_this_class !== b.is_wali_kelas_of_this_class) {
        return a.is_wali_kelas_of_this_class ? -1 : 1;
      }
      if (a.subjects_count !== b.subjects_count) {
        return b.subjects_count - a.subjects_count;
      }
      return a.name.localeCompare(b.name, 'id');
    });
    availableTeachers.value = list;
    // If prev teacher pick no longer in the list, blank it.
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

async function loadSubjectsForTeacher(tId: string) {
  if (!tId) {
    teacherSubjects.value = [];
    return;
  }
  isLoadingSubjects.value = true;
  try {
    const list = await SubjectService.listForTeacher(tId, 'teaching');
    teacherSubjects.value = list.map((s) => ({
      id: s.id,
      name: s.name,
      code: s.code ?? null,
    }));
    const ids = new Set(list.map((s) => s.id));
    if (subjectId.value && !ids.has(subjectId.value)) subjectId.value = '';
  } catch {
    teacherSubjects.value = [];
  } finally {
    isLoadingSubjects.value = false;
  }
}

async function probeConflicts() {
  if (
    !teacherId.value ||
    !anchorClassId.value ||
    !dayId.value ||
    !lessonHourId.value ||
    !semesterId.value
  ) {
    conflicts.value = [];
    return;
  }
  isProbingConflicts.value = true;
  try {
    conflicts.value = await ScheduleService.getConflicts({
      teacher_id: teacherId.value,
      class_id: anchorClassId.value,
      semester_id: semesterId.value,
      academic_year_id: academicYearId.value,
      lesson_hour_id: lessonHourId.value,
      days_ids: [dayId.value],
    });
  } catch {
    conflicts.value = [];
  } finally {
    isProbingConflicts.value = false;
  }
}

// ── Chip picker actions ────────────────────────────────────────────
function addClass(newId: string) {
  if (!newId) return;
  if (classIds.value.includes(newId)) return;
  classIds.value = [...classIds.value, newId];
}
function removeClass(removeId: string) {
  classIds.value = classIds.value.filter((id) => id !== removeId);
}

// ── Watchers ───────────────────────────────────────────────────────
watch([anchorClassId, dayId, lessonHourId, semesterId, academicYearId], () => {
  void loadAvailableTeachers();
});
watch(teacherId, (v) => void loadSubjectsForTeacher(v));

let probeTimer: ReturnType<typeof setTimeout> | null = null;
watch(
  [teacherId, anchorClassId, dayId, lessonHourId, semesterId, academicYearId],
  () => {
    if (probeTimer) clearTimeout(probeTimer);
    probeTimer = setTimeout(() => void probeConflicts(), 250);
  },
);

onMounted(async () => {
  await loadLessonHours();
  if (!semesterId.value && semesters.value.length > 0) {
    semesterId.value = props.defaultSemesterId ?? semesters.value[0].id;
  }
  if (!academicYearId.value) {
    academicYearId.value = ayStore.selectedYearId ?? '';
  }
});

// ── Step navigation ────────────────────────────────────────────────
function goNext() {
  if (step.value === 1 && step1Valid.value) step.value = 2;
  else if (step.value === 2 && step2Valid.value) step.value = 3;
}
function goBack() {
  if (step.value === 3) step.value = 2;
  else if (step.value === 2) step.value = 1;
  else emit('close');
}

// ── Save ───────────────────────────────────────────────────────────
async function save() {
  if (!canSubmit.value) return;
  isSaving.value = true;
  err.value = null;
  try {
    const created = await ScheduleService.create({
      teacher_id: teacherId.value,
      subject_id: subjectId.value,
      class_ids: [...classIds.value],
      days_ids: [dayId.value],
      lesson_hour_id: lessonHourId.value,
      semester_id: semesterId.value,
      academic_year_id: academicYearId.value,
      room: room.value || null,
    });
    emit('saved', created);
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

function goToLessonHourSettings() {
  emit('close');
  void router.push({ name: 'admin.schedule.lesson-hours' });
}

// ── Header display ─────────────────────────────────────────────────
const stepTitle = computed(() => {
  if (step.value === 1) return t('admin.schedule.combined.wizardStep1Title');
  if (step.value === 2) return t('admin.schedule.combined.wizardStep2Title');
  return t('admin.schedule.combined.wizardStep3Title');
});
</script>

<template>
  <Modal
    :title="t('admin.schedule.combined.wizardTitle')"
    :subtitle="t('admin.schedule.combined.wizardSubtitle')"
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- Progress strip: STEP N/3 with three dots. Reads immediately
           without a large stepper widget. -->
      <div class="flex items-center gap-3">
        <p class="text-3xs font-bold text-violet-700 uppercase tracking-widest">
          {{
            t('admin.schedule.combined.wizardStepIndicator', { step: step })
          }}
        </p>
        <div class="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden">
          <div
            class="h-full bg-violet-500 transition-all"
            :style="{ width: `${(step / 3) * 100}%` }"
          />
        </div>
        <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
          {{ stepTitle }}
        </p>
      </div>

      <!-- ── STEP 1: Pick classes ─────────────────────────────── -->
      <div v-if="step === 1" class="space-y-3">
        <p class="text-2xs text-slate-600 leading-relaxed">
          {{ t('admin.schedule.combined.wizardStep1Hint') }}
        </p>

        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.schedule.combined.classesLabel') }}
          </label>
          <div class="mt-1.5 rounded-xl border border-violet-200 bg-violet-50/40 p-3 flex flex-wrap items-center gap-1.5 min-h-[52px]">
            <span
              v-for="c in pickedClasses"
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
                @click="removeClass(c.id)"
              >
                <NavIcon name="x" :size="10" />
              </button>
            </span>
            <select
              v-if="combinedRemainingClasses.length > 0"
              :value="''"
              class="bg-white border border-dashed border-violet-300 rounded-full px-2.5 py-1 text-[12px] font-bold text-violet-700 outline-none focus:border-violet-500 cursor-pointer"
              @change="(e) => { addClass((e.target as HTMLSelectElement).value); (e.target as HTMLSelectElement).value = ''; }"
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
          </div>
          <p
            v-if="classIds.length < 2"
            class="mt-1.5 text-2xs text-violet-700 italic"
          >
            {{ t('admin.schedule.combined.pickAtLeastTwo') }}
          </p>
        </div>

        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.schedule.formB.semesterLabel') }}
          </label>
          <select
            v-model="semesterId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">
              {{ t('admin.schedule.formB.semesterPlaceholder') }}
            </option>
            <option v-for="s in semesters" :key="s.id" :value="s.id">
              {{ semesterLabel(s.name) }}
            </option>
          </select>
        </div>
      </div>

      <!-- ── STEP 2: Slot + teacher + subject + room ──────────── -->
      <div v-else-if="step === 2" class="space-y-3">
        <p class="text-2xs text-slate-600 leading-relaxed">
          {{ t('admin.schedule.combined.wizardStep2Hint') }}
        </p>

        <!-- Slot: hari × jam. -->
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.schedule.formB.slotLabel') }}
          </label>
          <div class="mt-1 grid grid-cols-2 gap-3">
            <select
              v-model="dayId"
              class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
            >
              <option value="">
                {{ t('admin.schedule.formB.dayPlaceholder') }}
              </option>
              <option v-for="d in days" :key="d.id" :value="d.id">
                {{ d.name }}
              </option>
            </select>
            <div
              v-if="isLoadingHours"
              class="h-9 w-full rounded-xl bg-slate-100 animate-pulse"
              aria-hidden="true"
            />
            <select
              v-else-if="lessonHours.length === 0"
              disabled
              class="w-full bg-amber-50 border border-amber-200 rounded-xl px-3 py-2 text-[13px] font-bold text-amber-800 outline-none"
            >
              <option>{{ t('admin.schedule.emptyLessonHours.badge') }}</option>
            </select>
            <select
              v-else
              v-model="lessonHourId"
              :disabled="!dayId"
              class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
            >
              <option value="">
                {{ t('admin.schedule.formB.hourPlaceholder') }}
              </option>
              <option v-for="h in filteredHours" :key="h.id" :value="h.id">
                {{ t('common.lessonHour', { n: h.hour_number }) }} ·
                {{ h.start_time }}–{{ h.end_time }}
              </option>
            </select>
          </div>
          <button
            v-if="!isLoadingHours && lessonHours.length === 0"
            type="button"
            class="mt-1.5 text-2xs font-bold text-amber-700 hover:text-amber-900 underline"
            @click="goToLessonHourSettings"
          >
            {{ t('admin.schedule.emptyLessonHours.cta') }} →
          </button>
        </div>

        <!-- Guru — slot-filtered against anchor class. -->
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
          <p
            v-if="!dayId || !lessonHourId"
            class="mt-1 text-2xs text-slate-500 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2"
          >
            <NavIcon name="lock" :size="11" class="inline text-slate-400" />
            {{ t('admin.schedule.formB.teacherLocked') }}
          </p>
          <div
            v-else-if="isLoadingAvailableTeachers && availableTeachers.length === 0"
            class="mt-1 h-9 w-full rounded-xl bg-slate-100 animate-pulse"
            aria-hidden="true"
          />
          <select
            v-else
            v-model="teacherId"
            :disabled="availableTeachers.length === 0"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
          >
            <option value="">
              {{ t('admin.schedule.formB.teacherPlaceholder') }}
            </option>
            <option v-for="tt in availableTeachers" :key="tt.id" :value="tt.id">
              {{ tt.is_wali_kelas_of_this_class ? '★ ' : '' }}{{ tt.name }}
            </option>
          </select>
          <p
            v-if="availableTeachersError"
            class="text-2xs text-red-700 mt-1.5 leading-relaxed"
          >
            {{ availableTeachersError }}
          </p>
        </div>

        <!-- Mapel — filtered by picked guru. -->
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('common.subject') }}
            <span
              v-if="isLoadingSubjects"
              class="text-slate-400 normal-case font-normal ml-1"
              >memuat...</span
            >
          </label>
          <div
            v-if="isLoadingSubjects && !!teacherId"
            class="mt-1 h-9 w-full rounded-xl bg-slate-100 animate-pulse"
            aria-hidden="true"
          />
          <select
            v-else
            v-model="subjectId"
            :disabled="!teacherId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
          >
            <option value="">— pilih mapel —</option>
            <option v-for="s in teacherSubjects" :key="s.id" :value="s.id">
              {{ subjectLabel(s) }}
            </option>
          </select>
          <p
            v-if="teacherId && !isLoadingSubjects && teacherSubjects.length === 0"
            class="text-2xs text-amber-700 mt-1.5 leading-relaxed"
          >
            {{ t('admin.schedule.combined.teacherNoSubjects') }}
          </p>
        </div>

        <!-- Ruangan (optional) -->
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
        </div>

        <!-- Conflict preview (same shape as ScheduleFormModal) -->
        <div
          v-if="isProbingConflicts"
          class="text-2xs text-slate-500 bg-slate-50 rounded-xl p-3"
        >
          Memeriksa bentrok...
        </div>
        <div
          v-else-if="conflicts.length > 0"
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
      </div>

      <!-- ── STEP 3: Review + confirm ─────────────────────────── -->
      <div v-else class="space-y-3">
        <p class="text-2xs text-slate-600 leading-relaxed">
          {{ t('admin.schedule.combined.wizardStep3Hint') }}
        </p>

        <div class="rounded-2xl border border-violet-200 bg-violet-50/40 p-4 space-y-2.5">
          <div class="flex items-start gap-2">
            <NavIcon name="users" :size="14" class="text-violet-700 mt-0.5 flex-none" />
            <div class="flex-1">
              <p class="text-3xs font-bold text-violet-700 uppercase tracking-widest">
                {{ t('admin.schedule.combined.reviewClassesLabel') }}
              </p>
              <div class="mt-1 flex flex-wrap gap-1">
                <span
                  v-for="c in pickedClasses"
                  :key="c.id"
                  class="inline-flex items-center px-2 py-0.5 rounded-full bg-violet-100 text-violet-800 border border-violet-200 text-[12px] font-bold"
                >
                  {{ c.name }}
                </span>
              </div>
            </div>
          </div>

          <div class="flex items-start gap-2">
            <NavIcon name="calendar" :size="14" class="text-violet-700 mt-0.5 flex-none" />
            <div class="flex-1">
              <p class="text-3xs font-bold text-violet-700 uppercase tracking-widest">
                {{ t('admin.schedule.combined.reviewSlotLabel') }}
              </p>
              <p class="text-[13px] font-bold text-slate-900">
                {{ pickedDayName }}
                <span v-if="pickedHour">
                  · {{ t('common.lessonHour', { n: pickedHour.hour_number }) }} ·
                  {{ pickedHour.start_time }}–{{ pickedHour.end_time }}
                </span>
              </p>
            </div>
          </div>

          <div class="flex items-start gap-2">
            <NavIcon name="user" :size="14" class="text-violet-700 mt-0.5 flex-none" />
            <div class="flex-1">
              <p class="text-3xs font-bold text-violet-700 uppercase tracking-widest">
                {{ t('admin.schedule.combined.reviewTeacherLabel') }}
              </p>
              <p class="text-[13px] font-bold text-slate-900">
                {{ pickedTeacher?.name ?? '—' }}
              </p>
            </div>
          </div>

          <div class="flex items-start gap-2">
            <NavIcon name="book-open" :size="14" class="text-violet-700 mt-0.5 flex-none" />
            <div class="flex-1">
              <p class="text-3xs font-bold text-violet-700 uppercase tracking-widest">
                {{ t('common.subject') }}
              </p>
              <p class="text-[13px] font-bold text-slate-900">
                {{ pickedSubject ? subjectLabel(pickedSubject) : '—' }}
                <span v-if="room" class="text-slate-500 font-normal"
                  > · {{ room }}</span
                >
              </p>
              <p class="text-2xs text-slate-500 mt-0.5">
                {{ semesterLabel(pickedSemesterName) }}
              </p>
            </div>
          </div>
        </div>

        <div class="rounded-xl border border-violet-200 bg-violet-50 p-3 flex gap-2.5">
          <NavIcon name="info" :size="14" class="flex-none mt-0.5 text-violet-700" />
          <p class="text-2xs text-violet-800 leading-snug">
            {{
              t('admin.schedule.combined.wizardCreateSummary', {
                count: classIds.length,
              })
            }}
          </p>
        </div>
      </div>

      <p
        v-if="err"
        class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3"
      >
        {{ err }}
      </p>

      <!-- Action row — Back always shown; Next/Simpan swaps per step. -->
      <div class="grid grid-cols-3 gap-2 pt-2">
        <Button variant="secondary" block @click="goBack">
          {{
            step === 1
              ? t('common.cancel')
              : t('admin.schedule.combined.wizardBack')
          }}
        </Button>
        <Button
          v-if="step < 3"
          variant="primary"
          block
          :disabled="step === 1 ? !step1Valid : !step2Valid"
          class="col-span-2"
          @click="goNext"
        >
          {{ t('admin.schedule.combined.wizardNext') }}
          <NavIcon name="chevron-right" :size="12" />
        </Button>
        <Button
          v-else
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!canSubmit"
          class="col-span-2"
          @click="save"
        >
          {{
            t('admin.schedule.combined.wizardSubmit', { count: classIds.length })
          }}
        </Button>
      </div>
    </div>
  </Modal>
</template>

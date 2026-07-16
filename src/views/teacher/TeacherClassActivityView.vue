<!--
  TeacherClassActivityView.vue — Activity Kelas (Catat Activity).

  Web port of Flutter's `teacher_class_activity_screen.dart`.

  Layout (matches Gradebook / Presensi / Schedule chrome):
    1. <BrandPageHeader> (teacher tint) — kicker + title + meta
    2. <KpiStripCards> — Total / Minggu ini / Perlu Catat / Dengan Refleksi
    3. <PageFilterToolbar> — Kelas + Mapel chips + Type tabs + search
    4. Date-grouped timeline (Hari Ini / Kemarin / Minggu Lalu / dst)
       - Each card is <ActivityCard role="teacher">
       - Tap card → <ActivityDetailModal>
       - Detail's "Catat Submit" CTA → <ActivitySubmissionPickerModal>
    5. Floating FAB "+ Tambah" → edit form modal

  Endpoints used (mirrors Flutter):
    GET  /class-activities/teacher-summary    list + KPI block
    GET  /class-activity/{id}                  full detail on open
    POST /class-activity                       create
    PUT  /class-activity/{id}                  update
    DELETE /class-activity/{id}                delete
    GET  /class-activity/{id}/submissions      seed Catat Submit roster
    POST /class-activity/{id}/submissions      bulk-upsert submissions
-->
<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { ClassActivityService } from '@/services/class-activity.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { ScheduleService } from '@/services/schedule.service';
import { MaterialService } from '@/services/materials.service';
import { localISODate } from '@/lib/format';
import type {
  ActivitySubmissionRow,
  ActivityType,
  ClassActivity,
} from '@/types/class-activity';
import { ACTIVITY_TYPE_LABELS } from '@/types/class-activity';
import type { Classroom, Subject } from '@/types/entities';
import type { ScheduleSession } from '@/types/schedule';
import { normalizeDayKey, type DayKey } from '@/types/schedule';
import type { Chapter, SubChapter } from '@/types/materials';
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
import ActivityCard from '@/components/feature/ActivityCard.vue';
import ActivityDetailModal from '@/components/feature/ActivityDetailModal.vue';
import ActivitySubmissionPickerModal from '@/components/feature/ActivitySubmissionPickerModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Toast from '@/components/ui/Toast.vue';
import { useQuickAction } from '@/composables/useQuickAction';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { subjectLabel } from '@/lib/labels';

const auth = useAuthStore();
const { fromQuickAction, queryString } = useQuickAction();
const { t } = useI18n();

// ── Role toggle (Mengajar / Wali kelas per homeroom) ──
// Mirrors the pattern TeacherGradeRecapView.vue:51-78 uses so guru with
// a homeroom class can toggle between "kegiatan yang saya ajarkan"
// (default) and "semua kegiatan di kelas X yang saya wali" (per homeroom).
// Backend already supports view=homeroom_teacher on the same
// /class-activities/teacher-summary endpoint (GetTeacherSummaryAction.php:51);
// only the frontend was missing the wiring.
const selectedRoleId = ref<string>('mengajar');
const roleOptions = computed<RoleOption[]>(() => {
  const out: RoleOption[] = [
    {
      id: 'mengajar',
      shortName: 'Mengajar',
      subLabel: 'Kegiatan yang saya ajarkan',
      avatarInitials: 'M',
    },
  ];
  for (const hc of auth.homeroomClasses) {
    const name = hc.name || hc.id;
    out.push({
      id: `wali:${hc.id}`,
      shortName: `Wali ${name}`,
      subLabel: 'Semua kegiatan di kelas ini',
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
const typeFilter = ref<ActivityType | 'all'>('all');
const rangeKey = ref<string>('30');
const searchQuery = ref<string>('');

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);

const activeClass = computed(
  () => classes.value.find((c) => c.id === classFilter.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectFilter.value) ?? null,
);

// ── List state ──
const items = ref<ClassActivity[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

// Server-computed KPI (preferred); falls back to derived stats on
// first paint or when the summary endpoint isn't available.
const serverKpi = ref<{
  total: number;
  this_week: number;
  pending_action: number;
} | null>(null);

// ── Detail / form / submission modals ──
const detailTarget = ref<ClassActivity | null>(null);
const detailSubmissions = ref<ActivitySubmissionRow[]>([]);
const isDetailLoading = ref(false);

const editTarget = ref<ClassActivity | null | undefined>(undefined);
const deleteTarget = ref<ClassActivity | null>(null);
const submissionPickerFor = ref<ClassActivity | null>(null);
const submissionPickerRows = ref<ActivitySubmissionRow[]>([]);
const isSaving = ref(false);

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const rangeOptions = computed(() => [
  { key: '7', label: t('teacher.activity.sevenDays') },
  { key: '30', label: t('teacher.activity.thirtyDays') },
  { key: '90', label: t('teacher.activity.ninetyDays') },
]);

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
  } catch {
    // ignore — pickers degrade to empty list
  }
}

function mapPeriod(key: string): 'today' | '7d' | '30d' | 'semester' | 'year' {
  if (key === '7') return '7d';
  if (key === '30') return '30d';
  if (key === '90') return 'semester';
  return '30d';
}

async function reload() {
  const teacherId = auth.teacherId ?? auth.user?.id;
  if (!teacherId) {
    isLoading.value = false;
    loadError.value = 'Profil guru belum termuat';
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    // Prefer the dedicated teacher-summary endpoint (KPI + scoped
    // list). Falls back to the legacy /class-activity list on 404 /
    // backend-not-yet-deployed.
    try {
      const resp = await ClassActivityService.getTeacherSummary({
        teacher_id: teacherId,
        period: mapPeriod(rangeKey.value),
        // Wali mode pins class_id to the selected homeroom (the
        // teacher-summary backend uses class_id-without-teacher_id
        // as an alternate wali trigger; passing both view + class_id
        // is redundant but harmless and keeps the wire honest).
        class_id: activeHomeroomId.value || classFilter.value || undefined,
        subject_id: subjectFilter.value || undefined,
        type: typeFilter.value === 'all' ? undefined : typeFilter.value,
        search: searchQuery.value || undefined,
        view: isWaliMode.value ? 'homeroom_teacher' : 'teaching',
        per_page: 100,
      });
      items.value = resp.items;
      serverKpi.value = resp.kpi;
    } catch {
      // Legacy fallback
      const res = await ClassActivityService.list({
        teacher_id: teacherId,
        class_id: classFilter.value || undefined,
        subject_id: subjectFilter.value || undefined,
        range_days: Number(rangeKey.value),
        type: typeFilter.value === 'all' ? undefined : typeFilter.value,
        search: searchQuery.value || undefined,
        per_page: 100,
      });
      items.value = res.items;
      serverKpi.value = null;
    }
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await reload();
});

// Toggling role pins/unpins the class filter to the homeroom class,
// matching TeacherGradeRecapView.vue:242-249.
watch(selectedRoleId, () => {
  if (isWaliMode.value && activeHomeroomId.value) {
    classFilter.value = activeHomeroomId.value;
  } else {
    classFilter.value = '';
  }
  reload();
});
watch([classFilter, subjectFilter, rangeKey, typeFilter], () => reload());
let searchTimer: ReturnType<typeof setTimeout> | null = null;
watch(searchQuery, () => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => reload(), 350);
});

useAcademicYearWatcher(() => reload());

// ── Date-grouped timeline ──
//
// Buckets: today / yesterday / thisWeek / earlier — same vocabulary
// as Flutter's `teacher_class_activity_screen.dart` group headers.
interface ActivityGroup {
  key: string;
  label: string;
  items: ClassActivity[];
}

function daysAgo(dateIso: string): number {
  if (!dateIso) return Infinity;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const d = new Date(dateIso);
  d.setHours(0, 0, 0, 0);
  return Math.round((today.getTime() - d.getTime()) / 86_400_000);
}

const groupedItems = computed<ActivityGroup[]>(() => {
  const sorted = [...items.value].sort((a, b) =>
    String(b.date ?? '').localeCompare(String(a.date ?? '')),
  );
  const buckets: Record<string, ClassActivity[]> = {
    today: [],
    yesterday: [],
    thisWeek: [],
    thisMonth: [],
    earlier: [],
  };
  for (const it of sorted) {
    const d = daysAgo(it.date);
    if (d <= 0) buckets.today.push(it);
    else if (d === 1) buckets.yesterday.push(it);
    else if (d <= 7) buckets.thisWeek.push(it);
    else if (d <= 30) buckets.thisMonth.push(it);
    else buckets.earlier.push(it);
  }
  const groups: ActivityGroup[] = [
    { key: 'today', label: t('common.today'), items: buckets.today },
    { key: 'yesterday', label: t('teacher.activity.yesterday'), items: buckets.yesterday },
    { key: 'thisWeek', label: t('teacher.activity.thisWeek'), items: buckets.thisWeek },
    { key: 'thisMonth', label: t('teacher.activity.thisMonth'), items: buckets.thisMonth },
    { key: 'earlier', label: t('teacher.activity.older'), items: buckets.earlier },
  ];
  return groups.filter((g) => g.items.length > 0);
});

const listState = computed<AsyncState<ActivityGroup[]>>(() => {
  if (isLoading.value && items.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (groupedItems.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: groupedItems.value };
});

// ── KPI strip ──
//
// Server values win when present; otherwise derive from the loaded
// items. Pending action = activities of scored types (tugas/ulangan)
// with at least one student still "pending".
const kpiCards = computed<KpiCard[]>(() => {
  const total = serverKpi.value?.total ?? items.value.length;
  const thisWeek =
    serverKpi.value?.this_week ??
    items.value.filter((i) => daysAgo(i.date) <= 7).length;

  let pendingAction =
    serverKpi.value?.pending_action ??
    items.value.filter(
      (i) =>
        (i.type === 'tugas' || i.type === 'ujian') &&
        i.submissions.total_students > 0 &&
        i.submissions.pending > 0,
    ).length;
  // Clamp to non-negative — backend might ship null
  if (pendingAction < 0) pendingAction = 0;

  const withReflection = items.value.filter((i) => i.has_reflection).length;

  return [
    {
      icon: 'activity',
      label: 'Total',
      value: total,
      suffix: 'kegiatan',
      tone: 'brand',
    },
    {
      icon: 'calendar',
      label: 'Minggu Ini',
      value: thisWeek,
      tone: 'violet',
    },
    {
      icon: 'check-square',
      label: 'Perlu Catat',
      value: pendingAction,
      suffix: 'submit',
      tone: pendingAction > 0 ? 'amber' : 'green',
      accented: pendingAction > 0,
    },
    {
      icon: 'edit',
      label: 'Refleksi',
      value: withReflection,
      suffix: 'catatan',
      tone: 'green',
    },
  ];
});

// Filter tabs (toolbar) — the 4 mobile types + an "all" option.
const typeTabs: { key: ActivityType | 'all'; label: string }[] = [
  { key: 'all', label: 'Semua' },
  { key: 'tugas', label: 'Tugas' },
  { key: 'aktivitas', label: 'Aktivitas' },
  { key: 'ujian', label: 'Ujian' },
  { key: 'catatan', label: 'Catatan' },
];

// Add/Edit form tiles — same 4 types + the mobile descriptions
// (`activity_form_sheet.dart`). Sends the raw mobile value as the
// `type` payload field.
const typeOptions: { key: ActivityType; label: string; desc: string }[] = [
  { key: 'tugas', label: 'Tugas', desc: 'Pemberian tugas / PR' },
  { key: 'aktivitas', label: 'Aktivitas', desc: 'Diskusi / praktik' },
  { key: 'ujian', label: 'Ujian', desc: 'Kuis / penilaian' },
  { key: 'catatan', label: 'Catatan', desc: 'Catatan kelas umum' },
];

// ── Edit form state ──
//
// The form now carries its own kelas + mapel (mirroring the Flutter
// `activity_form_sheet.dart`): the toolbar selection only seeds the
// defaults — the teacher can change them in-form (add mode). In edit
// mode kelas + mapel are locked (history consistency, same as mobile).
//
// `lessonHourId` persists the exact lesson-hour slot the teacher picked
// from the schedule-derived "Jam ke-N" session list; `chapterId` /
// `subChapterId` carry the optional Bab + Sub-bab linkage pulled from
// the Materi service.
const form = reactive<{
  classId: string;
  subjectId: string;
  title: string;
  date: string;
  lessonHourId: string;
  time: string;
  type: ActivityType;
  chapterId: string;
  subChapterId: string;
  description: string;
  reflection: string;
}>({
  classId: '',
  subjectId: '',
  title: '',
  date: todayIso(),
  lessonHourId: '',
  time: '',
  type: 'tugas',
  chapterId: '',
  subChapterId: '',
  description: '',
  reflection: '',
});

function todayIso(): string {
  return localISODate();
}

// ── Teacher schedule (drives the in-form Mapel + Jam pickers) ──
//
// Loaded lazily the first time the form opens; the same per-class /
// per-day / per-lesson-hour source the Schedule screen uses. Mirrors
// Flutter's `ActivityScheduleOptions`.
const schedules = ref<ScheduleSession[]>([]);
const schedulesLoaded = ref(false);
const isLoadingSchedules = ref(false);

async function ensureSchedules() {
  if (schedulesLoaded.value || isLoadingSchedules.value) return;
  isLoadingSchedules.value = true;
  try {
    const teacherId = auth.teacherId ?? auth.user?.id;
    schedules.value = await ScheduleService.myWeek(teacherId ?? undefined);
  } catch {
    schedules.value = [];
  } finally {
    schedulesLoaded.value = true;
    isLoadingSchedules.value = false;
  }
}

const hasScheduleContext = computed(() => schedules.value.length > 0);

// True while openAdd / openEdit are seeding the form — see the
// `form.date` watcher for why the date→Jam reset must pause.
const isHydratingForm = ref(false);

// Classes the teacher actually teaches (de-duped). Falls back to the
// full reference list when no schedule context is available so the
// picker never goes empty.
const formClasses = computed<{ id: string; name: string }[]>(() => {
  if (!hasScheduleContext.value) {
    return classes.value.map((c) => ({ id: c.id, name: c.name }));
  }
  const seen = new Set<string>();
  const out: { id: string; name: string }[] = [];
  for (const s of schedules.value) {
    if (!s.class_id || seen.has(s.class_id)) continue;
    seen.add(s.class_id);
    out.push({ id: s.class_id, name: s.class_name || '-' });
  }
  // Edit mode: keep the locked class visible even if not in the
  // derived list (e.g. an old activity the teacher no longer teaches).
  if (form.classId && !seen.has(form.classId)) {
    out.push({ id: form.classId, name: formClassName(form.classId) });
  }
  return out;
});

// Subjects scoped to what the teacher teaches in the selected class
// (Bug 1a). Without schedule context, falls back to the full list.
type FormSubjectOption = { id: string; name: string; code?: string | null };

/**
 * Schedule rows carry no subject code, so resolve it from the subject
 * catalogue by id — same `subject_schools` source, just the other shape.
 * Null when the subject isn't in the catalogue: the label then renders
 * name-only rather than showing an invented code.
 */
function formSubjectCode(id: string): string | null {
  return subjects.value.find((s) => s.id === id)?.code ?? null;
}

const formSubjects = computed<FormSubjectOption[]>(() => {
  if (!hasScheduleContext.value) {
    return subjects.value.map((s) => ({
      id: s.id,
      name: s.name,
      code: s.code ?? null,
    }));
  }
  const seen = new Set<string>();
  const out: FormSubjectOption[] = [];
  for (const s of schedules.value) {
    if (!s.subject_id) continue;
    if (form.classId && s.class_id !== form.classId) continue;
    if (seen.has(s.subject_id)) continue;
    seen.add(s.subject_id);
    out.push({
      id: s.subject_id,
      name: s.subject_name || '-',
      code: formSubjectCode(s.subject_id),
    });
  }
  if (form.subjectId && !seen.has(form.subjectId)) {
    out.push({
      id: form.subjectId,
      name: formSubjectName(form.subjectId),
      code: formSubjectCode(form.subjectId),
    });
  }
  return out;
});

function formClassName(id: string): string {
  return (
    classes.value.find((c) => c.id === id)?.name ??
    schedules.value.find((s) => s.class_id === id)?.class_name ??
    '-'
  );
}
function formSubjectName(id: string): string {
  return (
    subjects.value.find((s) => s.id === id)?.name ??
    schedules.value.find((s) => s.subject_id === id)?.subject_name ??
    '-'
  );
}

// ── Lesson-hour ("Jam ke-N") session options ──
//
// One option per lesson-hour slot the teacher has for (selected class,
// selected subject) on the selected date's weekday. Mirrors Flutter's
// `ActivityScheduleOptions.lessonHoursFor` (de-dupe by lesson_hour_id,
// sort by hour number then start time).
interface LessonHourOption {
  lessonHourId: string;
  hourNumber?: number;
  startTime: string;
  endTime: string;
  /** "Jam ke-3 · 09:00–09:45". */
  label: string;
}

function weekdayKey(dateIso: string): DayKey | null {
  if (!dateIso) return null;
  // Parse as local date (yyyy-mm-dd) — avoid UTC drift.
  const [y, m, d] = dateIso.split('-').map((n) => Number(n));
  if (!y || !m || !d) return null;
  const dow = new Date(y, m - 1, d).getDay(); // 0=Sun..6=Sat
  const map: Record<number, DayKey | null> = {
    0: null, // Sunday — no school sessions
    1: 'mon',
    2: 'tue',
    3: 'wed',
    4: 'thu',
    5: 'fri',
    6: 'sat',
  };
  return map[dow] ?? null;
}

const lessonHourOptions = computed<LessonHourOption[]>(() => {
  if (!hasScheduleContext.value || !form.classId) return [];
  const dayKey = weekdayKey(form.date);
  if (!dayKey) return [];
  const seen = new Set<string>();
  const out: LessonHourOption[] = [];
  for (const s of schedules.value) {
    if (s.class_id !== form.classId) continue;
    if (form.subjectId && s.subject_id !== form.subjectId) continue;
    // Match the slot's weekday against the selected date's weekday.
    const sDay = s.day ?? normalizeDayKey(s.day_name);
    if (sDay !== dayKey) continue;
    const key =
      s.lesson_hour_id && s.lesson_hour_id.length > 0
        ? s.lesson_hour_id
        : `h${s.hour_index ?? ''}-${s.start_time}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      lessonHourId: s.lesson_hour_id ?? '',
      hourNumber: s.hour_index,
      startTime: s.start_time,
      endTime: s.end_time,
      label: lessonHourLabel(s.hour_index, s.start_time, s.end_time),
    });
  }
  out.sort((a, b) => {
    const ah = a.hourNumber ?? 9999;
    const bh = b.hourNumber ?? 9999;
    if (ah !== bh) return ah - bh;
    return a.startTime.localeCompare(b.startTime);
  });
  return out;
});

function lessonHourLabel(
  hour: number | undefined,
  start: string,
  end: string,
): string {
  const parts: string[] = [];
  if (hour) parts.push(`Jam ke-${hour}`);
  const window = start && end ? `${start}–${end}` : start || end;
  if (window) parts.push(window);
  return parts.length ? parts.join(' · ') : 'Jam pelajaran';
}

// Apply the picked lesson-hour: stores both the slot UUID and the
// derived HH:MM start (so the legacy `time` column stays populated).
function pickLessonHour(opt: LessonHourOption) {
  form.lessonHourId = opt.lessonHourId;
  form.time = opt.startTime || '';
}

// ── Bab + Sub-bab pickers (from the Materi service) ──
//
// Chapters load once a subject is chosen; sub-chapters come along
// nested in the chapter tree (`getTree` eager-loads them), so no
// second fetch is needed. Both fields are optional.
const chapters = ref<Chapter[]>([]);
const isLoadingChapters = ref(false);

async function loadChapters() {
  const subjectId = form.subjectId;
  if (!subjectId) {
    chapters.value = [];
    return;
  }
  isLoadingChapters.value = true;
  try {
    // Scope the bab list to the chosen kelas' grade so an aktivitas
    // for kelas 7 doesn't surface kelas 8 chapters. Backend also
    // returns legacy universal (grade IS NULL) rows so nothing goes
    // missing during the per-grade migration.
    const cls = classes.value.find((c) => c.id === form.classId);
    const tree = await MaterialService.getTree({
      subject_id: subjectId,
      grade_level: cls?.grade_level ?? null,
    });
    chapters.value = tree.chapters;
  } catch {
    chapters.value = [];
  } finally {
    isLoadingChapters.value = false;
  }
}

const activeChapter = computed<Chapter | null>(
  () => chapters.value.find((c) => c.id === form.chapterId) ?? null,
);
const subChapterOptions = computed<SubChapter[]>(
  () => activeChapter.value?.sub_chapters ?? [],
);

function onChapterChange(id: string) {
  if (id === form.chapterId) return;
  form.chapterId = id;
  form.subChapterId = '';
}

// Reset Jam + Bab when the class changes (slots + chapter list are
// class/subject-scoped, so a previous pick may no longer apply).
function onFormClassChange(id: string) {
  if (id === form.classId) return;
  form.classId = id;
  form.subjectId = '';
  form.lessonHourId = '';
  form.time = '';
  form.chapterId = '';
  form.subChapterId = '';
  chapters.value = [];
}

function onFormSubjectChange(id: string) {
  if (id === form.subjectId) return;
  form.subjectId = id;
  // Jam slots are subject-scoped; chapter list is subject-scoped.
  form.lessonHourId = '';
  form.time = '';
  form.chapterId = '';
  form.subChapterId = '';
  loadChapters();
}

// When the date's weekday changes, a previously picked Jam may no
// longer exist for the new day — clear it so the teacher re-picks.
// Suppressed while a form is being hydrated (openAdd / openEdit set
// date + lessonHourId together; the watcher must not wipe the just-set
// slot when the edit's weekday differs from the prior form state).
watch(
  () => form.date,
  (next, prev) => {
    if (isHydratingForm.value) return;
    if (!prev || !next) return;
    if (weekdayKey(next) !== weekdayKey(prev)) {
      form.lessonHourId = '';
      form.time = '';
    }
  },
);

function resetForm() {
  form.classId = classFilter.value || '';
  form.subjectId = subjectFilter.value || '';
  form.title = '';
  form.date = todayIso();
  form.lessonHourId = '';
  form.time = '';
  form.type = 'tugas';
  form.chapterId = '';
  form.subChapterId = '';
  form.description = '';
  form.reflection = '';
  chapters.value = [];
}

async function openAdd() {
  isHydratingForm.value = true;
  resetForm();
  editTarget.value = null;
  await ensureSchedules();
  if (form.subjectId) loadChapters();
  // Release the date→Jam guard after watchers flush.
  await nextTick();
  isHydratingForm.value = false;
}

async function openEdit(a: ClassActivity) {
  // Pull the full detail first so chapter_id / sub_chapter_id /
  // lesson_hour_id (table columns absent from the list payload) are
  // available to pre-select the pickers.
  isHydratingForm.value = true;
  detailTarget.value = null;
  editTarget.value = a;
  await ensureSchedules();
  let full: ClassActivity | null = a;
  try {
    full = (await ClassActivityService.getDetail(a.id)) ?? a;
  } catch {
    full = a;
  }
  form.classId = full.class_id || a.class_id || '';
  form.subjectId = full.subject_id || a.subject_id || '';
  form.title = full.title;
  form.date = full.date;
  form.lessonHourId = full.lesson_hour_id ?? '';
  form.time = full.time ?? '';
  form.type = full.type;
  form.chapterId = full.chapter_id ?? '';
  form.subChapterId = full.sub_chapter_id ?? '';
  form.description = full.description ?? '';
  form.reflection = full.reflection ?? '';
  if (form.subjectId) await loadChapters();
  await nextTick();
  isHydratingForm.value = false;
}

async function saveActivity() {
  if (!form.classId || !form.subjectId) {
    toast.value = {
      message: 'Pilih kelas & mata pelajaran terlebih dahulu.',
      tone: 'error',
    };
    return;
  }
  if (!form.title.trim()) {
    toast.value = { message: 'Judul kegiatan wajib diisi.', tone: 'error' };
    return;
  }
  isSaving.value = true;
  try {
    const isEdit = !!(editTarget.value && editTarget.value.id);
    // Bab + Sub-bab are optional. Send `null` when cleared so the
    // backend treats it as "remove the link" on update (same as mobile).
    const payload: Record<string, unknown> = {
      title: form.title.trim(),
      date: form.date,
      time: form.time || null,
      type: form.type,
      description: form.description.trim() || null,
      reflection: form.reflection.trim() || null,
      chapter_id: form.chapterId || null,
      sub_chapter_id: form.subChapterId || null,
    };
    if (isEdit) {
      await ClassActivityService.update(editTarget.value!.id, payload);
    } else {
      // Create requires class/subject/teacher + the lesson-hour slot.
      // (The update path locks kelas+mapel and ignores lesson_hour_id,
      // mirroring the mobile edit form.)
      await ClassActivityService.create({
        ...payload,
        class_id: form.classId,
        subject_id: form.subjectId,
        teacher_id: auth.teacherId ?? auth.user?.id,
        lesson_hour_id: form.lessonHourId || null,
      });
    }
    editTarget.value = undefined;
    toast.value = { message: 'Kegiatan tersimpan.', tone: 'success' };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// Label for the Jam picker's selected state.
const selectedLessonHourLabel = computed<string>(() => {
  if (!form.lessonHourId && !form.time) return '';
  const match = lessonHourOptions.value.find(
    (o) => o.lessonHourId && o.lessonHourId === form.lessonHourId,
  );
  if (match) return match.label;
  // Fall back to the stored time when the slot isn't in the current
  // day's list (e.g. editing an old activity).
  return form.time ? `Jam · ${form.time}` : '';
});

// ── Detail flow ──
async function openDetail(a: ClassActivity) {
  detailTarget.value = a;
  detailSubmissions.value = [];
  isDetailLoading.value = true;
  // Try to enrich with full detail + per-student submissions in
  // parallel. Both endpoints are optional — if backend doesn't ship
  // either, the detail modal still renders the summary from the
  // list payload.
  try {
    const [full, rows] = await Promise.all([
      ClassActivityService.getDetail(a.id),
      ClassActivityService.listSubmissions(a.id),
    ]);
    if (full) detailTarget.value = full;
    detailSubmissions.value = rows;
  } catch {
    // graceful — modal still shows summary
  } finally {
    isDetailLoading.value = false;
  }
}

async function confirmDelete() {
  if (!deleteTarget.value) return;
  isSaving.value = true;
  try {
    await ClassActivityService.remove(deleteTarget.value.id);
    deleteTarget.value = null;
    detailTarget.value = null;
    toast.value = { message: 'Kegiatan dihapus.', tone: 'success' };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// ── Catat Submit flow ──
async function openSubmissionPicker(a: ClassActivity) {
  submissionPickerFor.value = a;
  submissionPickerRows.value = [];
  try {
    const rows = await ClassActivityService.listSubmissions(a.id);
    submissionPickerRows.value = rows;
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
    submissionPickerFor.value = null;
  }
}

async function saveSubmissions(rows: ActivitySubmissionRow[]) {
  if (!submissionPickerFor.value) return;
  isSaving.value = true;
  try {
    const resp = await ClassActivityService.upsertSubmissions(
      submissionPickerFor.value.id,
      rows,
    );
    if (resp.success === false) {
      toast.value = { message: resp.error ?? 'Gagal menyimpan', tone: 'error' };
      return;
    }
    submissionPickerFor.value = null;
    toast.value = {
      message: `${resp.saved ?? rows.length} siswa tersimpan.`,
      tone: 'success',
    };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
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
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="teacher"
      kicker="Akademik · Kegiatan Kelas"
      title="Catat Kegiatan Kelas"
      meta="Rekap pembelajaran harian, tugas, dan refleksi"
      :live-dot="false"
    >
      <template v-if="roleOptions.length > 1" #role-toggle>
        <RoleToggleChipRow
          :selected-role-id="selectedRoleId"
          :roles="roleOptions"
          @update:selected-role-id="selectedRoleId = $event"
        />
      </template>
      <Button variant="primary" size="sm" @click="openAdd">
        <NavIcon name="plus" :size="14" />
        Tambah
      </Button>
    </BrandPageHeader>

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" :loading="isLoading" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      search-placeholder="Cari judul atau catatan…"
    >
      <template #chips>
        <AppFilterChip
          label="Kelas"
          :value="activeClass?.name ?? 'Semua kelas'"
          :is-active="!!classFilter"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          label="Mapel"
          :value="activeSubject?.name ?? 'Semua mapel'"
          :is-active="!!subjectFilter"
          @click="showSubjectPicker = true"
        />
      </template>
      <template #segmented>
        <div class="flex items-center gap-2">
          <span class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Rentang
          </span>
          <SegmentedControl v-model="rangeKey" :options="rangeOptions" size="sm" />
        </div>
      </template>
    </PageFilterToolbar>

    <!-- TYPE TABS — labelled segmented control matching the RENTANG
         row inside PageFilterToolbar's #segmented slot above. Adding
         the JENIS prefix makes the two segmented filters visually
         parallel (label + control) instead of the naked chip row that
         read as a separate UI element. -->
    <div class="flex items-center gap-2 overflow-x-auto">
      <span class="text-3xs font-bold text-slate-400 uppercase tracking-widest whitespace-nowrap">
        Jenis
      </span>
      <SegmentedControl
        :model-value="typeFilter"
        :options="typeTabs"
        size="sm"
        @update:model-value="typeFilter = $event as ActivityType | 'all'"
      />
    </div>

    <!-- TIMELINE -->
    <AsyncView
      :state="listState"
      empty-title="Belum ada catatan kegiatan"
      empty-description="Klik “Tambah” untuk mencatat kegiatan kelas hari ini."
      empty-icon="activity"
      @retry="reload"
    >
      <div class="space-y-5">
        <section
          v-for="group in groupedItems"
          :key="group.key"
          class="space-y-2"
        >
          <div class="flex items-center gap-2 px-1">
            <span class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
              {{ group.label }}
            </span>
            <span class="text-3xs text-slate-400 tabular-nums">
              · {{ group.items.length }}
            </span>
            <span class="flex-1 border-t border-dashed border-slate-200 ml-2"></span>
          </div>
          <div class="space-y-2">
            <ActivityCard
              v-for="it in group.items"
              :key="it.id"
              :activity="it"
              role="teacher"
              @click="openDetail"
            />
          </div>
        </section>
      </div>
    </AsyncView>

    <!-- DETAIL MODAL -->
    <ActivityDetailModal
      v-if="detailTarget"
      :activity="detailTarget"
      :submissions="detailSubmissions"
      role="teacher"
      :busy="isSaving || isDetailLoading"
      @close="detailTarget = null"
      @edit="openEdit"
      @delete="deleteTarget = $event"
      @record-submissions="openSubmissionPicker"
    />

    <!-- CATAT SUBMIT MODAL -->
    <ActivitySubmissionPickerModal
      v-if="submissionPickerFor"
      :activity="submissionPickerFor"
      :rows="submissionPickerRows"
      :busy="isSaving"
      @close="submissionPickerFor = null"
      @save="saveSubmissions"
    />

    <!-- DELETE CONFIRM -->
    <ConfirmationDialog
      v-if="deleteTarget"
      title="Hapus Kegiatan"
      :message="`Hapus kegiatan “${deleteTarget.title}”? Tindakan ini tidak dapat dibatalkan.`"
      confirm-label="Hapus"
      danger
      :loading="isSaving"
      @close="deleteTarget = null"
      @confirm="confirmDelete"
    />

    <!-- EDIT FORM MODAL -->
    <Modal
      v-if="editTarget !== undefined"
      :title="editTarget ? 'Edit Kegiatan' : 'Tambah Kegiatan'"
      :subtitle="
        editTarget
          ? 'Kelas & mapel terkunci untuk konsistensi riwayat'
          : 'Pilih kelas, mapel, dan sesi jam pelajaran'
      "
      @close="editTarget = undefined"
    >
      <div class="space-y-3">
        <!-- KELAS + MAPEL (in-form; locked in edit mode) -->
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
              Kelas
            </label>
            <select
              :value="form.classId"
              :disabled="!!editTarget || isSaving"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2 bg-white disabled:bg-slate-50 disabled:text-slate-500"
              @change="onFormClassChange(($event.target as HTMLSelectElement).value)"
            >
              <option value="" disabled>Pilih kelas…</option>
              <option v-for="c in formClasses" :key="c.id" :value="c.id">
                {{ c.name }}
              </option>
            </select>
          </div>
          <div>
            <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
              Mapel
            </label>
            <select
              :value="form.subjectId"
              :disabled="!!editTarget || isSaving || (!editTarget && !form.classId)"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2 bg-white disabled:bg-slate-50 disabled:text-slate-500"
              @change="onFormSubjectChange(($event.target as HTMLSelectElement).value)"
            >
              <option value="" disabled>
                {{ !form.classId ? 'Pilih kelas dulu' : 'Pilih mapel…' }}
              </option>
              <option v-for="s in formSubjects" :key="s.id" :value="s.id">
                {{ subjectLabel(s) }}
              </option>
            </select>
          </div>
        </div>

        <div>
          <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
            Judul
          </label>
          <input
            v-model="form.title"
            type="text"
            placeholder="Misal: Praktek bab 3 — Energi"
            class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          />
        </div>

        <!-- TANGGAL + JAM (session picker) -->
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
              Tanggal
            </label>
            <input
              v-model="form.date"
              type="date"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
            />
          </div>
          <div>
            <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
              Jam / Sesi
            </label>
            <select
              v-if="hasScheduleContext && lessonHourOptions.length > 0"
              :value="form.lessonHourId"
              :disabled="isSaving"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2 bg-white"
              @change="
                pickLessonHour(
                  lessonHourOptions.find(
                    (o) => o.lessonHourId === ($event.target as HTMLSelectElement).value,
                  ) ?? lessonHourOptions[0],
                )
              "
            >
              <option value="" disabled>Pilih jam ke-…</option>
              <option
                v-for="o in lessonHourOptions"
                :key="o.lessonHourId || o.label"
                :value="o.lessonHourId"
              >
                {{ o.label }}
              </option>
            </select>
            <!-- No schedule slots for this class/day → time fallback so
                 the field never blocks saving. -->
            <input
              v-else
              v-model="form.time"
              type="time"
              :disabled="isSaving"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
            />
            <p
              v-if="hasScheduleContext && form.classId && lessonHourOptions.length === 0"
              class="mt-1 text-3xs text-slate-400"
            >
              Tidak ada jadwal jam pelajaran di hari ini — isi waktu manual.
            </p>
            <p
              v-else-if="selectedLessonHourLabel && form.lessonHourId"
              class="mt-1 text-3xs text-emerald-600 font-semibold"
            >
              {{ selectedLessonHourLabel }}
            </p>
          </div>
        </div>

        <div>
          <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
            Tipe
          </label>
          <!-- 4 mobile types (Tugas / Activity / Ujian / Catatan) with
               the same descriptions as the Flutter form. Sends the raw
               value (form.type) the backend expects. -->
          <div class="grid grid-cols-2 gap-2 mt-1">
            <button
              v-for="opt in typeOptions"
              :key="opt.key"
              type="button"
              class="text-left px-3 py-2 rounded-xl transition border"
              :class="
                form.type === opt.key
                  ? 'bg-brand-cobalt/5 border-brand-cobalt'
                  : 'bg-white border-slate-200 hover:border-brand-cobalt/40'
              "
              @click="form.type = opt.key"
            >
              <span
                class="block text-[12px] font-bold"
                :class="form.type === opt.key ? 'text-brand-cobalt' : 'text-slate-700'"
              >
                {{ opt.label }}
              </span>
              <span class="block text-3xs text-slate-500 truncate">
                {{ opt.desc }}
              </span>
            </button>
          </div>
        </div>

        <!-- MATERI TERKAIT → Bab + Sub-bab (from Materi page). Optional;
             only shown once a Mapel is chosen (chapter list is
             subject-scoped). Saving without a Bab still works. -->
        <div v-if="form.subjectId" class="grid grid-cols-2 gap-2">
          <div>
            <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
              Bab (opsional)
            </label>
            <select
              :value="form.chapterId"
              :disabled="isSaving || isLoadingChapters"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2 bg-white"
              @change="onChapterChange(($event.target as HTMLSelectElement).value)"
            >
              <option value="">
                {{ isLoadingChapters ? 'Memuat bab…' : '— Tanpa bab —' }}
              </option>
              <option v-for="c in chapters" :key="c.id" :value="c.id">
                {{ c.label }}{{ c.name ? ` · ${c.name}` : '' }}
              </option>
            </select>
          </div>
          <div>
            <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
              Sub-bab (opsional)
            </label>
            <select
              v-model="form.subChapterId"
              :disabled="isSaving || !form.chapterId || subChapterOptions.length === 0"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2 bg-white disabled:bg-slate-50"
            >
              <option value="">
                {{
                  !form.chapterId
                    ? 'Pilih bab dulu'
                    : subChapterOptions.length === 0
                      ? 'Tidak ada sub-bab'
                      : '— Tanpa sub-bab —'
                }}
              </option>
              <option v-for="s in subChapterOptions" :key="s.id" :value="s.id">
                {{ s.number ? `${s.number} ` : '' }}{{ s.name }}
              </option>
            </select>
          </div>
        </div>

        <div>
          <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
            Deskripsi
          </label>
          <textarea
            v-model="form.description"
            rows="3"
            placeholder="Apa yang dipelajari hari ini?"
            class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          />
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
            Refleksi (opsional)
          </label>
          <textarea
            v-model="form.reflection"
            rows="2"
            placeholder="Catatan guru: yang berhasil / butuh perbaikan…"
            class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          />
        </div>
        <div class="flex justify-end gap-2 pt-2 border-t border-slate-100">
          <Button variant="ghost" :disabled="isSaving" @click="editTarget = undefined">
            Batal
          </Button>
          <Button variant="primary" :disabled="isSaving" @click="saveActivity">
            {{ isSaving ? 'Menyimpan…' : editTarget ? 'Update' : 'Simpan' }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- CLASS PICKER -->
    <Modal v-if="showClassPicker" title="Pilih Kelas" @close="showClassPicker = false">
      <ul class="space-y-1 max-h-[60vh] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="!classFilter ? 'bg-brand-cobalt/5 font-bold text-brand-cobalt' : ''"
            @click="pickClass('')"
          >
            Semua kelas
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="c.id === classFilter ? 'bg-brand-cobalt/5 font-bold text-brand-cobalt' : ''"
            @click="pickClass(c.id)"
          >
            {{ c.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- SUBJECT PICKER -->
    <Modal v-if="showSubjectPicker" title="Pilih Mapel" @close="showSubjectPicker = false">
      <ul class="space-y-1 max-h-[60vh] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="!subjectFilter ? 'bg-brand-cobalt/5 font-bold text-brand-cobalt' : ''"
            @click="pickSubject('')"
          >
            Semua mapel
          </button>
        </li>
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="s.id === subjectFilter ? 'bg-brand-cobalt/5 font-bold text-brand-cobalt' : ''"
            @click="pickSubject(s.id)"
          >
            {{ subjectLabel(s) }}
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

    <!-- Suppress unused-warning for static label map referenced from
         shared components via prop binding -->
    <span v-if="false">{{ ACTIVITY_TYPE_LABELS }}</span>
  </div>
</template>

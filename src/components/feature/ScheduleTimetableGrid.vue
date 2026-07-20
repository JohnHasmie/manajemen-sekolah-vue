<!--
  ScheduleTimetableGrid.vue — Sprint 3 Pola C timetable entry mode.

  Renders a per-class week×hour grid backed by
  `GET /teaching-schedules/matrix`. The grid is the primary "look at
  the class's whole week + tap the hole" data-entry surface — a strict
  alternative to the existing sticky-day list on the same page.

  Layout:
    - Class selector at the top (required, no "All" mode — the matrix
      only makes sense for a single class at a time).
    - Sticky left column: hour_number + start–end time.
    - Right side: one column per day, horizontally scrollable so a
      6-day school on a mobile viewport still fits.
    - Filled cell → chip with subject.code + teacher.name, click to
      EMIT `edit` with the schedule_id.
    - Empty cell → dashed "+" button, click to EMIT `create` with the
      pre-fill payload (class_id, day_id, lesson_hour_id, semester_id,
      academic_year_id) so ScheduleFormModal can skip the setup gate
      and the admin can skip re-picking the slot they just clicked.
    - Bottom counter: "12 dari 40 slot terisi".

  Loading / error / empty states:
    - Skeleton while the matrix fetch is in flight.
    - Retry button on error.
    - "Belum ada kelas — buat dulu" when the school has no classes.
    - Selecting a class but the school has no lesson hours falls
      through to the same admin-facing empty banner the list view
      shows (`admin.schedule.emptyLessonHours.*`).

  Refresh: the parent view calls the exposed `refresh()` method after
  ScheduleFormModal emits `saved` — the grid then re-fetches the
  matrix so the just-created/edited cell shows up in place.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import {
  ScheduleService,
  type TimetableMatrix,
} from '@/services/schedule.service';
import type { ScheduleFilterOptions } from '@/types/schedule';
import { useAcademicYearStore } from '@/stores/academic-year';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { storage } from '@/lib/storage';
import { semesterLabel } from '@/lib/labels';

/** Payload emitted when the admin clicks an empty cell. Feeds the
 *  ScheduleFormModal pre-fill props verbatim. */
export interface TimetableCreatePayload {
  class_id: string;
  day_id: string;
  lesson_hour_id: string;
  semester_id: string;
  academic_year_id: string | number;
}

const props = defineProps<{
  /** Pre-loaded filter options (admin hub already fetched them).
   *  Used to populate the class + semester dropdowns without a
   *  second network call. */
  filterOptions?: ScheduleFilterOptions | null;
  /** Optional default semester id (defaults to the first option). */
  defaultSemesterId?: string;
  /**
   * True while the parent's filter-options fetch is in flight. The
   * grid uses this to distinguish "school genuinely has no classes"
   * (fire the amber "Belum ada kelas" banner) from "parent hasn't
   * resolved filterOptions yet" (render a skeleton picker instead of
   * the banner, so the admin doesn't see a false alarm on cold open).
   */
  optionsLoading?: boolean;
}>();

const emit = defineEmits<{
  /** Filled-cell click — the parent opens ScheduleFormModal in edit
   *  mode preloaded with this schedule row. */
  edit: [scheduleId: string];
  /** Empty-cell click — the parent opens ScheduleFormModal in create
   *  mode with these fields pre-filled + skipSetupCheck=true. */
  create: [payload: TimetableCreatePayload];
}>();

const { t } = useI18n();
const router = useRouter();
const ayStore = useAcademicYearStore();

// ── Persistence key for the last-picked class ──────────────────────
//
// Users stay on one class for long stretches (finishing one class's
// week before moving to the next). Remembering the last pick lets a
// page reload land on the same grid instead of a blank "pilih kelas"
// prompt. Scoped globally (not per-school) — switching schools clears
// storage anyway during the school-switch flow.
const STORAGE_LAST_CLASS = 'schedule_timetable_last_class_id';

// ── State ──────────────────────────────────────────────────────────
const classId = ref<string>('');
const semesterId = ref<string>(props.defaultSemesterId ?? '');
const matrix = ref<TimetableMatrix | null>(null);
const isLoading = ref(false);
const error = ref<string | null>(null);

// Derived from the filter-options prop. Both are computeds so a late
// prop resolution (parent hydrates filterOptions after mount)
// automatically populates the dropdowns.
const classes = computed(() => props.filterOptions?.classes ?? []);
const semesters = computed(() => props.filterOptions?.semesters ?? []);

// The user-visible "class chosen" state. Distinct from `matrix !== null`
// because we only fire the fetch after classId + semesterId + AY are
// all set — a race where the class dropdown resolved but semester
// hadn't shouldn't render an inconsistent "loaded matrix from wrong
// term" flash.
const hasClassSelected = computed(() => classId.value.length > 0);

// ── Fetch ───────────────────────────────────────────────────────────
async function loadMatrix() {
  if (!classId.value) {
    matrix.value = null;
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    matrix.value = await ScheduleService.getTimetableMatrix({
      classId: classId.value,
      semesterId: semesterId.value || undefined,
      academicYearId: ayStore.selectedYearId ?? undefined,
    });
  } catch (e) {
    error.value = (e as Error).message;
    matrix.value = null;
  } finally {
    isLoading.value = false;
  }
}

/** Public — the parent view calls this after ScheduleFormModal saves
 *  so the just-created / just-edited cell shows in place. */
function refresh(): Promise<void> {
  return loadMatrix();
}

defineExpose({ refresh });

// ── Lifecycle ───────────────────────────────────────────────────────
onMounted(() => {
  // Rehydrate the last-picked class, if it's still in the class list
  // for the current AY (the school may have deleted / archived it).
  const remembered = storage.get<string>(STORAGE_LAST_CLASS);
  if (
    typeof remembered === 'string' &&
    remembered &&
    classes.value.some((c) => c.id === remembered)
  ) {
    classId.value = remembered;
  }
  if (!semesterId.value && semesters.value.length > 0) {
    semesterId.value = props.defaultSemesterId ?? semesters.value[0].id;
  }
  if (classId.value) void loadMatrix();
});

// Persist the picked class + trigger a re-fetch on any driver change.
watch(classId, (v) => {
  if (v) {
    storage.set(STORAGE_LAST_CLASS, v);
  } else {
    storage.remove(STORAGE_LAST_CLASS);
  }
  void loadMatrix();
});
watch(semesterId, () => void loadMatrix());

// If the parent hasn't picked a semester yet but the filter-options
// prop resolved later (parent async-fetched them post-mount), fill in
// the default silently rather than surfacing an empty picker.
watch(
  () => props.filterOptions,
  (fo) => {
    if (!semesterId.value && fo?.semesters?.[0]) {
      semesterId.value = props.defaultSemesterId ?? fo.semesters[0].id;
    }
  },
);

// ── Derived helpers ─────────────────────────────────────────────────
const days = computed(() => matrix.value?.days ?? []);

/** Unique hour_number list, sorted asc — one grid ROW per hour number.
 *  Different days can share the same hour_number (JP 1 is the same
 *  ordinal everywhere), so we don't render one row per hour UUID. */
const hourRows = computed(() => {
  const seen = new Map<
    number,
    { hour_number: number; name: string; start_time: string; end_time: string }
  >();
  for (const h of matrix.value?.hours ?? []) {
    if (!seen.has(h.hour_number)) {
      seen.set(h.hour_number, {
        hour_number: h.hour_number,
        name: h.name,
        start_time: h.start_time,
        end_time: h.end_time,
      });
    }
  }
  return Array.from(seen.values()).sort(
    (a, b) => a.hour_number - b.hour_number,
  );
});

/** Look up the LessonHour uuid for a given (day, hour_number) tuple —
 *  we need it to pre-fill the CREATE modal so the admin isn't asked to
 *  re-pick the slot they just clicked. */
function findHourIdFor(dayId: string, hourNumber: number): string | null {
  const match = (matrix.value?.hours ?? []).find(
    (h) => h.day_id === dayId && h.hour_number === hourNumber,
  );
  return match?.id ?? null;
}

/** Fetch the cell at (day, hour_number) — returns undefined for empty
 *  slots so the template can branch on it cleanly. */
function cellAt(dayId: string, hourNumber: number) {
  return matrix.value?.cells[`${dayId}:${hourNumber}`];
}

/**
 * Group-cell lookup by hour_number: return the first cell at this
 * hour that carries a `schedule_group_id`. The "⚭ GABUNG" virtual
 * column shows one card per hour_number rather than one-per-day —
 * a group is a slot × teacher × subject fanning across N classes,
 * and per-class cells already share the same group_id, so any one
 * of them is a valid representative.
 *
 * When the group's actual day differs from the day the row is
 * rendered on (rare — the group typically lives in one slot), the
 * timetable's own kolom-kelas rendering still shows the plain
 * cell; the ⚭ column deliberately only surfaces groups whose day
 * is one of the visible day columns.
 */
function groupCellAt(hourNumber: number) {
  const cells = matrix.value?.cells;
  if (!cells) return undefined;
  for (const d of days.value) {
    const cell = cells[`${d.id}:${hourNumber}`];
    if (cell?.schedule_group_id) return cell;
  }
  return undefined;
}

/**
 * True if the given (day, hour_number) cell belongs to a group.
 * The class's own column suppresses the plain card in that case —
 * the ⚭ virtual column renders the group card instead, so showing
 * the row twice (once per column) would double-count the same
 * slot to the reader.
 */
function isGroupMember(dayId: string, hourNumber: number): boolean {
  const c = cellAt(dayId, hourNumber);
  return !!c?.schedule_group_id;
}


// ── Click handlers ─────────────────────────────────────────────────
function onCellClick(dayId: string, hourNumber: number) {
  const cell = cellAt(dayId, hourNumber);
  if (cell) {
    emit('edit', cell.schedule_id);
    return;
  }
  const lessonHourId = findHourIdFor(dayId, hourNumber);
  if (!lessonHourId) {
    // The (day × hour_number) tuple doesn't have a lesson_hour row —
    // this shouldn't happen because empty slots ARE rendered from the
    // hour list, but guard anyway rather than emit a corrupt payload.
    return;
  }
  emit('create', {
    class_id: classId.value,
    day_id: dayId,
    lesson_hour_id: lessonHourId,
    semester_id: semesterId.value,
    academic_year_id: ayStore.selectedYearId ?? '',
  });
}

/**
 * Click on the group card in the "⚭ GABUNG" virtual column —
 * routes to `edit` with the group's schedule_id. The parent's edit
 * handler pulls the row from cache; if it's grouped, the form modal
 * opens in group-aware mode (chip picker pre-populated with
 * `grouped_class_names`) so the admin can add/remove classes as a
 * unit rather than editing one sibling in isolation.
 */
function onGroupCardClick(hourNumber: number) {
  const cell = groupCellAt(hourNumber);
  if (cell) emit('edit', cell.schedule_id);
}

// ── Counter ────────────────────────────────────────────────────────
const counterLabel = computed(() => {
  const m = matrix.value;
  if (!m) return '';
  return t('admin.schedule.timetable.slotsFilled', {
    filled: m.meta.total_filled,
    total: m.meta.total_slots,
  });
});

// ── Empty-state helpers ────────────────────────────────────────────
// Only fires when we've actually observed the class list (filterOptions
// resolved and its `classes` array is empty). If the parent is still
// fetching, `filterOptions` is null → we treat it as "unknown, don't
// alarm yet" and show the skeleton instead of the amber banner.
const hasNoClasses = computed(
  () =>
    !props.optionsLoading &&
    props.filterOptions !== null &&
    props.filterOptions !== undefined &&
    props.filterOptions.classes.length === 0,
);
// True while filterOptions hasn't arrived yet — the picker + counters
// render as skeleton bars so the admin sees "loading" rather than a
// prematurely-empty state.
const isPickerSkeleton = computed(
  () =>
    props.optionsLoading === true ||
    props.filterOptions === null ||
    props.filterOptions === undefined,
);

function goToClasses() {
  void router.push({ name: 'admin.classes' });
}
function goToLessonHours() {
  void router.push({ name: 'admin.schedule.lesson-hours' });
}

const classPickerId = 'schedule-timetable-class-picker';
const semesterPickerId = 'schedule-timetable-semester-picker';
</script>

<template>
  <section class="space-y-3">
    <!-- Class + semester pickers. Class is the primary driver; the
         semester defaults to the active AY's first semester so the
         admin doesn't need to touch it in the common case. While the
         parent's filter-options fetch is in flight we render the label
         + a skeleton bar in place of the <select> so the admin sees
         "loading" rather than a disabled dropdown that reads like a
         dead state. -->
    <div class="flex flex-wrap items-end gap-3">
      <div class="min-w-[240px] flex-1">
        <label
          :for="classPickerId"
          class="text-3xs font-bold text-slate-400 uppercase tracking-widest"
        >
          {{ t('admin.schedule.timetable.classPickerLabel') }}
          <span class="text-red-500 ml-0.5">*</span>
        </label>
        <div
          v-if="isPickerSkeleton"
          class="mt-1 h-10 w-full rounded-xl bg-slate-100 animate-pulse"
          aria-hidden="true"
        />
        <select
          v-else
          :id="classPickerId"
          v-model="classId"
          :disabled="hasNoClasses"
          class="mt-1 w-full bg-white border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
        >
          <option value="">
            {{ t('admin.schedule.timetable.classPickerPlaceholder') }}
          </option>
          <option v-for="c in classes" :key="c.id" :value="c.id">
            {{ c.name }}
          </option>
        </select>
      </div>
      <div v-if="!isPickerSkeleton && semesters.length > 1" class="min-w-[160px]">
        <label
          :for="semesterPickerId"
          class="text-3xs font-bold text-slate-400 uppercase tracking-widest"
        >
          {{ t('admin.schedule.timetable.semesterLabel') }}
        </label>
        <select
          :id="semesterPickerId"
          v-model="semesterId"
          class="mt-1 w-full bg-white border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option v-for="s in semesters" :key="s.id" :value="s.id">
            {{ semesterLabel(s.name) }}
          </option>
        </select>
      </div>
    </div>

    <!-- Body skeleton while filter-options still loading — replaces the
         picker-prompt / empty banner. Full grid skeleton lives further
         down (gated on `isLoading && !matrix`). -->
    <div
      v-if="isPickerSkeleton"
      class="rounded-2xl border border-dashed border-slate-200 bg-slate-50 p-6"
      aria-hidden="true"
    >
      <div class="h-3 w-40 rounded bg-slate-200 animate-pulse mx-auto" />
      <div class="h-2 w-72 rounded bg-slate-200 animate-pulse mx-auto mt-2" />
    </div>

    <!-- Empty state: no classes at all → CTA to Data Kelas -->
    <div
      v-else-if="hasNoClasses"
      class="rounded-2xl border border-dashed border-amber-300 bg-amber-50 p-6 text-center"
    >
      <NavIcon name="alert-triangle" :size="20" class="text-amber-600 mx-auto" />
      <p class="text-[13px] font-bold text-amber-900 mt-2">
        {{ t('admin.schedule.timetable.noClassesTitle') }}
      </p>
      <p class="text-2xs text-amber-700 mt-1 leading-relaxed">
        {{ t('admin.schedule.timetable.noClassesDesc') }}
      </p>
      <Button variant="primary" size="sm" class="mt-3" @click="goToClasses">
        <NavIcon name="plus" :size="12" />
        {{ t('admin.schedule.timetable.noClassesCta') }}
      </Button>
    </div>

    <!-- Prompt to pick a class -->
    <div
      v-else-if="!hasClassSelected"
      class="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-6 text-center"
    >
      <NavIcon name="calendar" :size="20" class="text-slate-400 mx-auto" />
      <p class="text-[13px] font-bold text-slate-700 mt-2">
        {{ t('admin.schedule.timetable.pickClassTitle') }}
      </p>
      <p class="text-2xs text-slate-500 mt-1 leading-relaxed">
        {{ t('admin.schedule.timetable.pickClassDesc') }}
      </p>
    </div>

    <!-- Loading skeleton — mimics the grid shape so the swap on load
         doesn't collapse the layout. -->
    <div
      v-else-if="isLoading && !matrix"
      class="rounded-2xl border border-slate-200 bg-white overflow-hidden"
    >
      <div class="overflow-x-auto">
        <table class="w-full text-2xs border-collapse">
          <thead>
            <tr class="bg-slate-50">
              <th class="min-w-[90px] sticky left-0 bg-slate-50 z-10 px-3 py-3">
                <div class="h-3 w-8 bg-slate-200 rounded animate-pulse"></div>
              </th>
              <th v-for="i in 6" :key="i" class="min-w-[140px] px-2 py-3">
                <div class="h-3 w-16 bg-slate-200 rounded animate-pulse mx-auto"></div>
              </th>
              <th class="min-w-[180px] px-2 py-3 bg-violet-50">
                <div class="h-3 w-20 bg-violet-200 rounded animate-pulse mx-auto"></div>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in 6" :key="r" class="border-t border-slate-100">
              <td class="px-3 py-2 sticky left-0 bg-white z-10">
                <div class="h-3 w-10 bg-slate-100 rounded animate-pulse"></div>
                <div class="h-2 w-14 bg-slate-100 rounded animate-pulse mt-1"></div>
              </td>
              <td v-for="i in 6" :key="i" class="p-1">
                <div class="h-14 rounded-lg bg-slate-100 animate-pulse"></div>
              </td>
              <td class="p-1 bg-violet-50/30">
                <div class="h-14 rounded-lg bg-violet-100 animate-pulse"></div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Error state -->
    <div
      v-else-if="error"
      class="rounded-2xl border border-red-200 bg-red-50 p-6 text-center"
    >
      <NavIcon name="alert-triangle" :size="20" class="text-red-500 mx-auto" />
      <p class="text-[13px] font-bold text-red-800 mt-2">
        {{ t('admin.schedule.timetable.errorTitle') }}
      </p>
      <p class="text-2xs text-red-600 mt-1 leading-relaxed">{{ error }}</p>
      <Button variant="secondary" size="sm" class="mt-3" @click="loadMatrix">
        <NavIcon name="refresh-cw" :size="12" />
        {{ t('common.retry') }}
      </Button>
    </div>

    <!-- Loaded matrix -->
    <template v-else-if="matrix">
      <!-- Empty state: the class exists but the school has zero lesson
           hours. The list view already surfaces a banner for this
           school-wide; we surface it here too so the grid doesn't
           render as a bare 0-row skeleton. -->
      <div
        v-if="hourRows.length === 0"
        class="rounded-2xl border border-dashed border-amber-300 bg-amber-50 p-6 text-center"
      >
        <NavIcon name="alert-triangle" :size="20" class="text-amber-600 mx-auto" />
        <p class="text-[13px] font-bold text-amber-900 mt-2">
          {{ t('admin.schedule.emptyLessonHours.badge') }}
        </p>
        <p class="text-2xs text-amber-700 mt-1 leading-relaxed">
          {{ t('admin.schedule.emptyLessonHours.pageDesc') }}
        </p>
        <Button
          variant="primary"
          size="sm"
          class="mt-3"
          @click="goToLessonHours"
        >
          <NavIcon name="clock" :size="12" />
          {{ t('admin.schedule.emptyLessonHours.cta') }}
        </Button>
      </div>

      <template v-else>
        <!-- Grid — sticky left column, horizontal-scroll body. The
             final column "⚭ GABUNG" is virtual: it houses jadwal-
             gabung entries so a group card doesn't fight for space
             inside the class's own column. When a per-class cell is
             part of a group, its column shows a subtle
             "↗ lihat kolom gabung" placeholder instead of the plain
             card so the reader isn't invited to click into a stale
             per-class view. -->
        <div class="rounded-2xl border border-slate-200 bg-white overflow-x-auto">
          <table class="w-full text-2xs border-collapse">
            <thead>
              <tr class="bg-slate-50">
                <th
                  class="text-4xs font-bold text-slate-400 uppercase tracking-widest px-3 py-3 text-left min-w-[90px] sticky left-0 bg-slate-50 z-10"
                >
                  {{ t('admin.schedule.timetable.hourColumnHeader') }}
                </th>
                <th
                  v-for="d in days"
                  :key="d.id"
                  class="text-4xs font-bold text-slate-500 uppercase tracking-widest px-2 py-3 min-w-[140px]"
                >
                  {{ d.display_name || d.name }}
                </th>
                <!-- Virtual "⚭ GABUNG" column at the end. Violet header
                     so it visually separates from the per-day columns
                     without a heavy divider line. -->
                <th
                  class="text-4xs font-black text-violet-700 uppercase tracking-widest px-2 py-3 min-w-[180px] bg-violet-50 border-l-2 border-violet-200"
                >
                  <span class="mr-1">⚭</span>
                  {{ t('admin.schedule.combined.gridColumnHeader') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in hourRows"
                :key="row.hour_number"
                class="border-t border-slate-100"
              >
                <td
                  class="px-3 py-2 align-top sticky left-0 bg-white z-10 border-r border-slate-100"
                >
                  <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
                    {{ t('admin.schedule.jpAbbrev') }}{{ row.hour_number }}
                  </p>
                  <p class="text-2xs font-bold text-slate-900 tabular-nums">
                    {{ row.start_time }}
                  </p>
                  <p class="text-4xs text-slate-400 tabular-nums">
                    {{ row.end_time }}
                  </p>
                </td>
                <td
                  v-for="d in days"
                  :key="`${d.id}-${row.hour_number}`"
                  class="p-1 align-top"
                >
                  <!-- Class-column plain cell — only rendered when the
                       cell exists AND is NOT part of a group. Grouped
                       cells route their render into the ⚭ column so we
                       show a "lihat kolom gabung" placeholder here. -->
                  <template v-if="cellAt(d.id, row.hour_number) && !isGroupMember(d.id, row.hour_number)">
                    <button
                      type="button"
                      class="w-full text-left rounded-lg p-2 bg-role-admin/5 border border-role-admin/20 hover:bg-role-admin/10 transition-all"
                      :aria-label="
                        t('admin.schedule.timetable.editCellAria', {
                          subject: cellAt(d.id, row.hour_number)!.subject.name,
                          day: d.display_name || d.name,
                          hour: row.hour_number,
                        })
                      "
                      @click="onCellClick(d.id, row.hour_number)"
                    >
                      <p class="text-3xs font-bold text-slate-900 truncate">
                        <span
                          v-if="cellAt(d.id, row.hour_number)!.subject.code"
                          class="text-role-admin"
                        >
                          [{{ cellAt(d.id, row.hour_number)!.subject.code }}]
                        </span>
                        <span>
                          {{ cellAt(d.id, row.hour_number)!.subject.name }}
                        </span>
                      </p>
                      <p class="text-4xs text-slate-500 truncate">
                        {{ cellAt(d.id, row.hour_number)!.teacher.name }}
                      </p>
                      <p
                        v-if="cellAt(d.id, row.hour_number)!.room"
                        class="text-4xs text-slate-400 truncate"
                      >
                        {{ cellAt(d.id, row.hour_number)!.room }}
                      </p>
                    </button>
                  </template>
                  <!-- Group-member ghost placeholder — cell exists but
                       lives in the ⚭ column. Clicking still routes to
                       the group's edit so muscle memory doesn't miss. -->
                  <template v-else-if="isGroupMember(d.id, row.hour_number)">
                    <button
                      type="button"
                      class="w-full h-14 rounded-lg border border-dashed border-violet-300 bg-violet-50/40 hover:bg-violet-50 text-violet-600 hover:text-violet-800 transition-colors flex items-center justify-center gap-1 text-3xs font-bold"
                      :aria-label="
                        t('admin.schedule.combined.gridGhostAria', {
                          day: d.display_name || d.name,
                          hour: row.hour_number,
                        })
                      "
                      @click="onCellClick(d.id, row.hour_number)"
                    >
                      <span>↗</span>
                      <span>{{ t('admin.schedule.combined.gridGhostLabel') }}</span>
                    </button>
                  </template>
                  <template v-else>
                    <button
                      type="button"
                      class="w-full h-14 rounded-lg border border-dashed border-slate-200 hover:border-role-admin hover:bg-role-admin/5 text-slate-300 hover:text-role-admin transition-colors text-lg font-bold flex items-center justify-center"
                      :aria-label="
                        t('admin.schedule.timetable.createCellAria', {
                          day: d.display_name || d.name,
                          hour: row.hour_number,
                        })
                      "
                      @click="onCellClick(d.id, row.hour_number)"
                    >
                      +
                    </button>
                  </template>
                </td>
                <!-- "⚭ GABUNG" virtual column cell. Renders the group
                     card (2px violet border, chip row for members) OR
                     an empty placeholder if this hour has no group. -->
                <td class="p-1 align-top bg-violet-50/30 border-l-2 border-violet-200">
                  <template v-if="groupCellAt(row.hour_number)">
                    <button
                      type="button"
                      class="w-full text-left rounded-lg p-2 bg-white border-2 border-violet-400 hover:border-violet-500 hover:bg-violet-50 transition-all shadow-sm"
                      :aria-label="
                        t('admin.schedule.combined.gridCardAria', {
                          subject: groupCellAt(row.hour_number)!.subject.name,
                          hour: row.hour_number,
                        })
                      "
                      @click="onGroupCardClick(row.hour_number)"
                    >
                      <p class="text-3xs font-bold text-slate-900 truncate flex items-center gap-1">
                        <span class="text-violet-700">⚭</span>
                        <span
                          v-if="groupCellAt(row.hour_number)!.subject.code"
                          class="text-violet-700"
                        >
                          [{{ groupCellAt(row.hour_number)!.subject.code }}]
                        </span>
                        <span class="truncate">
                          {{ groupCellAt(row.hour_number)!.subject.name }}
                        </span>
                      </p>
                      <p class="text-4xs text-slate-500 truncate">
                        {{ groupCellAt(row.hour_number)!.teacher.name }}
                      </p>
                      <div class="mt-1 flex flex-wrap gap-1">
                        <span
                          v-for="m in groupCellAt(row.hour_number)!.grouped_class_names ?? []"
                          :key="m.id"
                          class="inline-flex items-center px-1.5 py-0 rounded bg-violet-100 text-violet-800 border border-violet-200 text-[10px] font-bold leading-tight"
                        >
                          {{ m.name }}
                        </span>
                      </div>
                      <p
                        v-if="groupCellAt(row.hour_number)!.room"
                        class="text-4xs text-slate-400 truncate mt-0.5"
                      >
                        {{ groupCellAt(row.hour_number)!.room }}
                      </p>
                    </button>
                  </template>
                  <div
                    v-else
                    class="w-full h-14 rounded-lg border border-dashed border-violet-100"
                    aria-hidden="true"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Slot counter. Right-aligned so it reads like a page footer,
             not another content block. -->
        <p class="text-3xs font-bold text-slate-500 text-right px-1">
          {{ counterLabel }}
        </p>
      </template>
    </template>
  </section>
</template>

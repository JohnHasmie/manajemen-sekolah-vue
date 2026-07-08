<!--
  CheckInShiftPicker.vue — MR 4d.

  Self-contained radio-card list for picking which shift a check-in
  applies to. Consumes a `shifts` prop (the caller sources it from
  /teacher-attendance/config so this widget makes zero requests) plus
  `completedShiftIds` (rows the user already checked in for today).

  Behavior contract:
    - Auto-picks the shift whose window includes `now` on mount.
    - If the user has already completed that shift, auto-selection
      falls through to the next uncompleted shift covering `now`, then
      the first uncompleted shift on today's day-of-week.
    - The user can override the auto-pick with a click (props answer:
      overridable). Completed shifts are visibly muted and not
      selectable.
    - Emits `update:modelValue` with the chosen shift id (or `null`
      when the school has no shifts and the caller should proceed
      single-shift-style).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import type { AttendanceShift } from '@/services/attendance-shifts.service';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Shifts available for this school, from /config bootstrap. */
  shifts: AttendanceShift[];
  /**
   * Shift ids the user has already checked in for today. These get
   * muted + disabled — one shift = one check-in per day.
   */
  completedShiftIds?: string[];
  /** Current selected shift id (v-model). */
  modelValue: string | null;
  /**
   * Optional override for "now" (mostly for tests / storybook). Falls
   * back to the browser clock. Format: 'HH:MM'.
   */
  now?: string;
}>();

const emit = defineEmits<{
  'update:modelValue': [id: string | null];
}>();

/** JS getDay(): 0 = Sunday..6 = Saturday. */
const todayDayOfWeek = new Date().getDay();

const nowHHMM = computed<string>(() => {
  if (props.now) return props.now;
  const d = new Date();
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
});

const completedSet = computed<Set<string>>(
  () => new Set(props.completedShiftIds ?? []),
);

const applicableShifts = computed<AttendanceShift[]>(() =>
  props.shifts.filter((s) => s.days_of_week.includes(todayDayOfWeek)),
);

function isActiveNow(shift: AttendanceShift): boolean {
  return (
    shift.start_time <= nowHHMM.value && nowHHMM.value <= shift.end_time
  );
}

function isCompleted(shift: AttendanceShift): boolean {
  return completedSet.value.has(shift.id);
}

function pickInitial(): string | null {
  // Priority: (1) active-now uncompleted, (2) any uncompleted today,
  // (3) null so the caller shows the empty state.
  const activeUncompleted = applicableShifts.value.find(
    (s) => isActiveNow(s) && !isCompleted(s),
  );
  if (activeUncompleted) return activeUncompleted.id;
  const anyUncompleted = applicableShifts.value.find((s) => !isCompleted(s));
  return anyUncompleted?.id ?? null;
}

function select(shift: AttendanceShift): void {
  if (isCompleted(shift)) return;
  emit('update:modelValue', shift.id);
}

const autoPickedId = ref<string | null>(null);

onMounted(() => {
  autoPickedId.value = pickInitial();
  // Only auto-fill when the parent hasn't already picked something.
  if (props.modelValue === null && autoPickedId.value !== null) {
    emit('update:modelValue', autoPickedId.value);
  }
});

function fmtWindow(shift: AttendanceShift): string {
  return `${shift.start_time} – ${shift.end_time}`;
}
</script>

<template>
  <!-- No shifts configured → caller falls back to single-shift flow.
       We render nothing so the mobile view stays clean. -->
  <div v-if="applicableShifts.length === 0" />

  <div v-else class="space-y-2">
    <header class="flex items-center gap-2 text-2xs text-slate-500">
      <NavIcon name="clock" :size="14" />
      <span>Pilih shift untuk absen ini</span>
      <span v-if="autoPickedId" class="ml-auto text-brand-cobalt font-bold">
        Auto-pilih aktif
      </span>
    </header>

    <ul class="space-y-2">
      <li
        v-for="shift in applicableShifts"
        :key="shift.id"
        class="rounded-xl border-2 p-3 transition-colors"
        :class="[
          isCompleted(shift)
            ? 'bg-slate-100 border-slate-200 opacity-60 cursor-not-allowed'
            : modelValue === shift.id
              ? 'bg-brand-cobalt/5 border-brand-cobalt cursor-pointer'
              : 'bg-white border-slate-200 hover:border-brand-cobalt/50 cursor-pointer',
        ]"
        @click="select(shift)"
      >
        <div class="flex items-center gap-3">
          <div
            class="w-5 h-5 rounded-full border-2 flex items-center justify-center flex-none"
            :class="
              modelValue === shift.id && !isCompleted(shift)
                ? 'border-brand-cobalt'
                : 'border-slate-300'
            "
          >
            <div
              v-if="modelValue === shift.id && !isCompleted(shift)"
              class="w-2.5 h-2.5 rounded-full bg-brand-cobalt"
            />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <p class="text-sm font-bold text-slate-800">{{ shift.name }}</p>
              <span
                v-if="isActiveNow(shift) && !isCompleted(shift)"
                class="text-2xs font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-800"
              >
                Aktif sekarang
              </span>
              <span
                v-if="isCompleted(shift)"
                class="text-2xs font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800"
              >
                Sudah absen
              </span>
            </div>
            <p class="text-2xs text-slate-500 tabular-nums mt-0.5">
              {{ fmtWindow(shift) }}
            </p>
          </div>
        </div>
      </li>
    </ul>

    <p class="text-2xs text-slate-400 text-center">
      Ketuk shift lain jika ingin mengganti pilihan otomatis.
    </p>
  </div>
</template>

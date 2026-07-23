<!--
  SingleRescheduleModal.vue — admin "Pindah Slot" sheet for one schedule.

  Picks a new day + lesson hour. Submits to
  PATCH /teaching-schedule/{id}/reschedule. On 409 the modal shows the
  conflicts inline and reveals a "Paksa Simpan" checkbox.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { ScheduleService } from '@/services/schedule.service';
import { LessonHourService } from '@/services/lesson-hour.service';
import type {
  LessonHour,
  ScheduleConflict,
  ScheduleFilterOptions,
  ScheduleRow,
} from '@/types/schedule';
import { formatDayName } from '@/lib/day-name';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();

const props = defineProps<{
  row: ScheduleRow;
  filterOptions?: ScheduleFilterOptions | null;
}>();

const emit = defineEmits<{
  close: [];
  done: [ScheduleRow];
}>();

const dayId = ref<string>(props.row.day_id ?? '');
const lessonHourId = ref<string>(props.row.lesson_hour_days_id);
const lessonHours = ref<LessonHour[]>([]);
const isLoadingHours = ref(false);
const conflicts = ref<ScheduleConflict[]>([]);
const forceSave = ref(false);
const isSaving = ref(false);
const err = ref<string | null>(null);

async function loadHours() {
  isLoadingHours.value = true;
  try {
    lessonHours.value = await LessonHourService.list();
  } catch {
    lessonHours.value = [];
  } finally {
    isLoadingHours.value = false;
  }
}

onMounted(loadHours);

const days = computed(() => props.filterOptions?.days ?? []);

const filteredHours = computed(() => {
  if (!dayId.value) return [];
  return lessonHours.value
    .filter((h) => h.day_id === dayId.value)
    .sort((a, b) => a.hour_number - b.hour_number);
});

// Auto-pick the same hour_number on the new day when day changes.
watch(dayId, (newDay) => {
  if (!newDay) return;
  const currentHourNumber = props.row.hour_number;
  const match = lessonHours.value.find(
    (h) => h.day_id === newDay && h.hour_number === currentHourNumber,
  );
  if (match) {
    lessonHourId.value = match.id;
  } else if (filteredHours.value.length > 0) {
    lessonHourId.value = filteredHours.value[0].id;
  } else {
    lessonHourId.value = '';
  }
  conflicts.value = [];
  forceSave.value = false;
});

const selectedHour = computed(() =>
  lessonHours.value.find((h) => h.id === lessonHourId.value),
);

const hasChanged = computed(() => lessonHourId.value !== props.row.lesson_hour_days_id);
const canSubmit = computed(() => {
  if (!lessonHourId.value || isSaving.value || !hasChanged.value) return false;
  if (conflicts.value.length > 0 && !forceSave.value) return false;
  return true;
});

async function save() {
  if (!lessonHourId.value) return;
  isSaving.value = true;
  err.value = null;
  try {
    const updated = await ScheduleService.reschedule(props.row.id, {
      lesson_hour_days_id: lessonHourId.value,
      force: forceSave.value || undefined,
    });
    emit('done', updated);
    emit('close');
  } catch (e) {
    const annotated = e as Error & { conflicts?: ScheduleConflict[] };
    if (annotated.conflicts && annotated.conflicts.length > 0) {
      conflicts.value = annotated.conflicts;
      err.value = annotated.message;
    } else {
      err.value = annotated.message;
    }
  } finally {
    isSaving.value = false;
  }
}

const dayLabel = computed(() => {
  if (!dayId.value) return '—';
  return props.filterOptions?.days.find((d) => d.id === dayId.value)?.name ?? '—';
});
</script>

<template>
  <Modal
    title="Pindah Slot"
    :subtitle="`${row.subject_name} · ${row.class_name}`"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Current slot -->
      <section class="bg-slate-50 rounded-xl p-3">
        <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Slot sekarang</p>
        <p class="text-[13px] font-bold text-slate-900 mt-1">
          {{ formatDayName(row.day_name) }} ·
          {{ t('common.lessonHour', { n: row.hour_number }) }} · {{ row.start_time }}–{{ row.end_time }}
        </p>
      </section>

      <!-- Day picker -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Hari baru</label>
        <div class="mt-1 flex flex-wrap gap-1.5">
          <button
            v-for="d in days"
            :key="d.id"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold border transition-colors"
            :class="
              dayId === d.id
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="dayId = d.id"
          >
            {{ formatDayName(d.name) }}
          </button>
        </div>
      </div>

      <!-- Lesson hour picker -->
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Jam pelajaran ({{ dayLabel }})
          <span v-if="isLoadingHours" class="text-slate-400 normal-case font-normal ml-1">memuat...</span>
        </label>
        <!-- Skeleton while /lesson-hours is in flight — matches the
             pattern used across ScheduleFormModal so a reschedule
             open reads as "loading", not "empty picker". -->
        <div
          v-if="isLoadingHours && filteredHours.length === 0"
          class="mt-1 h-9 w-full rounded-xl bg-slate-100 animate-pulse motion-reduce:animate-none"
          aria-hidden="true"
        />
        <select
          v-else
          v-model="lessonHourId"
          :disabled="!dayId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin disabled:opacity-50"
        >
          <option value="">— pilih jam —</option>
          <option v-for="h in filteredHours" :key="h.id" :value="h.id">
            {{ t('common.lessonHour', { n: h.hour_number }) }} · {{ h.start_time }}–{{ h.end_time }}
          </option>
        </select>
        <p v-if="dayId && filteredHours.length === 0 && !isLoadingHours" class="text-3xs text-amber-700 mt-1">
          Hari ini belum punya jam pelajaran terdaftar.
        </p>
      </div>

      <!-- Preview new slot -->
      <section v-if="selectedHour" class="bg-emerald-50 border border-emerald-200 rounded-xl p-3">
        <p class="text-3xs font-bold text-emerald-700 uppercase tracking-widest">Slot baru</p>
        <p class="text-[13px] font-bold text-emerald-900 mt-1">
          {{ dayLabel }} · {{ t('common.lessonHour', { n: selectedHour.hour_number }) }} ·
          {{ selectedHour.start_time }}–{{ selectedHour.end_time }}
        </p>
      </section>

      <!-- Conflicts -->
      <section
        v-if="conflicts.length > 0"
        class="bg-red-50 border border-red-200 rounded-xl p-3 space-y-2"
      >
        <p class="text-2xs font-bold text-red-700 uppercase tracking-widest flex items-center gap-1.5">
          <NavIcon name="alert-triangle" :size="12" />
          {{ conflicts.length }} bentrok terdeteksi
        </p>
        <ul class="text-2xs text-red-700 space-y-1">
          <li v-for="c in conflicts" :key="c.id">
            {{ c.subject_name }} · {{ c.teacher_name ?? '—' }} · {{ c.class_name ?? '—' }}
          </li>
        </ul>
        <label class="flex items-center gap-2 text-2xs text-red-800 font-bold cursor-pointer">
          <input v-model="forceSave" type="checkbox" class="accent-red-600" />
          Paksa pindah meski bentrok
        </label>
      </section>

      <p v-if="err && conflicts.length === 0" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
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
          Pindahkan
        </Button>
      </div>
    </div>
  </Modal>
</template>

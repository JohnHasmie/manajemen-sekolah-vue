<!--
  AttendanceKalenderPanel.vue — MR 3c.

  Self-contained holiday CRUD + workweek chip control. Consumes:
    - AttendanceHolidaysService for list / createOrUpdate / destroy
    - TeacherAttendanceService.updateSettings (existing) for the
      workweek_days_bitmask patch

  Drop into a new tab of AdminAttendanceConfigView — the parent just
  mounts <AttendanceKalenderPanel :school-id="…" /> and passes its
  current workweek bitmask. Settings save on toggle (debounced),
  holiday list is fetched on mount + refetched after each add/remove.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import {
  AttendanceHolidaysService,
  type AttendanceHoliday,
  type AttendanceHolidayType,
} from '@/services/attendance-holidays.service';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /**
   * Initial workweek bitmask (Sunday=bit0..Saturday=bit6). Default 62
   * = Mon..Fri. Patched via TeacherAttendanceService.updateSettings
   * when the admin toggles a day chip.
   */
  initialWorkweekBitmask?: number;
}>();

const emit = defineEmits<{
  /** Optional — emitted so the parent can update its own state cache. */
  'workweek-changed': [bitmask: number];
}>();

const DAY_LABELS = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'] as const;

// Workweek — bits map to Sunday=0..Saturday=6 so the FE agrees with
// JS getDay() and the backend uses the same convention. See MR 3's
// migration for the layout.
const workweek = ref<number>(props.initialWorkweekBitmask ?? 62);

const dayOn = (dayIndex: number): boolean =>
  (workweek.value & (1 << dayIndex)) !== 0;

async function toggleDay(dayIndex: number): Promise<void> {
  const nextMask = workweek.value ^ (1 << dayIndex);
  // Optimistic UI — persist first, revert on error so the admin
  // isn't left with a stale visual if the network burps.
  const prev = workweek.value;
  workweek.value = nextMask;
  try {
    await TeacherAttendanceService.updateSettings({
      workweek_days_bitmask: nextMask,
    });
    emit('workweek-changed', nextMask);
  } catch {
    workweek.value = prev;
  }
}

// Holiday list ---------------------------------------------------------

const holidays = ref<AttendanceHoliday[]>([]);
const isLoadingHolidays = ref<boolean>(false);

const currentYear = ref<number>(new Date().getFullYear());
const yearOptions = computed<number[]>(() => {
  const y = currentYear.value;
  return [y - 1, y, y + 1];
});

const holidaysInYear = computed<AttendanceHoliday[]>(() =>
  holidays.value.filter(
    (h) => new Date(h.date).getFullYear() === currentYear.value,
  ),
);

async function loadHolidays(): Promise<void> {
  isLoadingHolidays.value = true;
  try {
    holidays.value = await AttendanceHolidaysService.list({
      start_date: `${currentYear.value - 1}-01-01`,
      end_date: `${currentYear.value + 1}-12-31`,
    });
  } finally {
    isLoadingHolidays.value = false;
  }
}

// Quick-add form -------------------------------------------------------

const formDate = ref<string>('');
const formName = ref<string>('');
const formType = ref<AttendanceHolidayType>('school');
const isSaving = ref<boolean>(false);
const formError = ref<string | null>(null);

const canSave = computed<boolean>(
  () => !!formDate.value && formName.value.trim().length > 0 && !isSaving.value,
);

async function saveHoliday(): Promise<void> {
  if (!canSave.value) return;
  isSaving.value = true;
  formError.value = null;
  try {
    await AttendanceHolidaysService.createOrUpdate({
      date: formDate.value,
      name: formName.value.trim(),
      type: formType.value,
    });
    formDate.value = '';
    formName.value = '';
    formType.value = 'school';
    await loadHolidays();
  } catch (e) {
    formError.value = (e as Error).message ?? 'Gagal menyimpan libur.';
  } finally {
    isSaving.value = false;
  }
}

async function removeHoliday(id: string): Promise<void> {
  // Optimistic remove — kills the row from the local list immediately,
  // reloads authoritative list after the API confirms. On error the
  // reload puts the row back.
  const backup = [...holidays.value];
  holidays.value = holidays.value.filter((h) => h.id !== id);
  try {
    await AttendanceHolidaysService.destroy(id);
  } catch {
    holidays.value = backup;
  }
}

// Type badge helpers ---------------------------------------------------

const TYPE_LABEL: Record<AttendanceHolidayType, string> = {
  national: 'Nasional',
  school: 'Sekolah',
  religious: 'Keagamaan',
};
const TYPE_CLASS: Record<AttendanceHolidayType, string> = {
  national: 'bg-rose-100 text-rose-700',
  school: 'bg-sky-100 text-sky-700',
  religious: 'bg-amber-100 text-amber-700',
};

function fmtLongDate(iso: string): string {
  return new Date(iso).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}
function fmtWeekday(iso: string): string {
  return new Date(iso).toLocaleDateString('id-ID', { weekday: 'long' });
}

onMounted(loadHolidays);
watch(currentYear, loadHolidays);
</script>

<template>
  <div class="space-y-3">
    <!-- Workweek chip row. Toggling a chip PATCHes settings
         immediately — no separate save button in this panel. -->
    <section
      class="bg-sky-50 border border-sky-200 rounded-xl p-3 flex items-center gap-2 flex-wrap"
    >
      <span class="text-xs font-bold text-brand-cobalt whitespace-nowrap">
        Hari kerja
      </span>
      <button
        v-for="(label, i) in DAY_LABELS"
        :key="label"
        type="button"
        class="text-xs font-bold px-2.5 py-1 rounded-full border transition-colors"
        :class="
          dayOn(i)
            ? 'bg-brand-cobalt text-white border-transparent'
            : 'bg-white text-slate-500 border-slate-200'
        "
        @click="toggleDay(i)"
      >
        {{ label }}
      </button>
      <span class="text-2xs text-brand-cobalt ml-auto">
        Otomatis tersimpan
      </span>
    </section>

    <!-- Year tabs -->
    <section class="flex items-center gap-2 flex-wrap">
      <div class="inline-flex bg-white border border-slate-200 rounded-full p-0.5">
        <button
          v-for="y in yearOptions"
          :key="y"
          type="button"
          class="text-xs font-bold px-3 py-1 rounded-full"
          :class="
            currentYear === y
              ? 'bg-brand-cobalt text-white'
              : 'text-slate-500'
          "
          @click="currentYear = y"
        >
          {{ y }}
        </button>
      </div>
      <span class="text-2xs text-slate-400 tabular-nums">
        {{ holidaysInYear.length }} libur di {{ currentYear }}
      </span>
    </section>

    <!-- Holiday list -->
    <section class="bg-white border border-slate-200 rounded-xl overflow-hidden">
      <div
        v-if="isLoadingHolidays && holidays.length === 0"
        class="p-6 text-center text-xs text-slate-400"
      >
        Memuat…
      </div>
      <div
        v-else-if="holidaysInYear.length === 0"
        class="p-8 text-center"
      >
        <NavIcon name="calendar-off" :size="24" class="text-slate-300 mx-auto" />
        <p class="text-xs text-slate-500 mt-2">Belum ada libur untuk {{ currentYear }}.</p>
        <p class="text-2xs text-slate-400 mt-1">
          Tambah lewat form di bawah atau impor CSV.
        </p>
      </div>
      <ul v-else class="divide-y divide-slate-100">
        <li
          v-for="h in holidaysInYear"
          :key="h.id"
          class="grid grid-cols-[100px_1fr_auto_auto] gap-3 items-center px-4 py-2.5 text-xs"
        >
          <div>
            <p class="font-bold tabular-nums">{{ fmtLongDate(h.date) }}</p>
            <p class="text-2xs text-slate-400">{{ fmtWeekday(h.date) }}</p>
          </div>
          <p class="font-medium text-slate-800">{{ h.name }}</p>
          <span
            class="text-2xs font-bold px-2 py-0.5 rounded-full"
            :class="TYPE_CLASS[h.type]"
          >
            {{ TYPE_LABEL[h.type] }}
          </span>
          <button
            type="button"
            class="text-2xs text-rose-700 border border-rose-200 rounded px-2 py-1 font-bold"
            @click="removeHoliday(h.id)"
          >
            Hapus
          </button>
        </li>
      </ul>
    </section>

    <!-- Quick-add form -->
    <section
      class="bg-amber-50 border border-amber-200 rounded-xl p-3 grid grid-cols-[1fr_2fr_1fr_auto] gap-2 items-end"
    >
      <div class="col-span-full text-2xs font-bold text-amber-900 uppercase tracking-wider">
        Tambah libur cepat
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-2xs font-bold text-amber-900">Tanggal</label>
        <input
          v-model="formDate"
          type="date"
          class="rounded border border-amber-200 px-2 py-1 text-xs bg-white"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-2xs font-bold text-amber-900">Nama libur</label>
        <input
          v-model="formName"
          type="text"
          placeholder="Contoh: Tahun Baru"
          class="rounded border border-amber-200 px-2 py-1 text-xs bg-white"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-2xs font-bold text-amber-900">Tipe</label>
        <select
          v-model="formType"
          class="rounded border border-amber-200 px-2 py-1 text-xs bg-white"
        >
          <option value="school">Sekolah</option>
          <option value="national">Nasional</option>
          <option value="religious">Keagamaan</option>
        </select>
      </div>
      <button
        type="button"
        class="text-xs font-bold px-3 py-2 rounded bg-amber-900 text-white disabled:opacity-50"
        :disabled="!canSave"
        @click="saveHoliday"
      >
        Simpan
      </button>
      <p
        v-if="formError"
        class="col-span-full text-2xs text-rose-700 font-bold"
      >
        {{ formError }}
      </p>
    </section>
  </div>
</template>

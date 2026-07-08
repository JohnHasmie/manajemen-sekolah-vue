<!--
  AttendanceShiftPanel.vue — MR 4c.

  Self-contained shift CRUD + settings (auto-pick + max daily shifts).
  Consumed by the Attendance Config wizard as a new step. Backend MR 4
  landed the /attendance-shifts endpoints and the two settings columns
  (auto_pick_shift_enabled, max_daily_shifts_per_person).

  Parent responsibility: mount when the tenant is bimbel OR when the
  Umum step has "multi-shift" toggled on. Initial values for the two
  settings come in as props; changes are debounced and PATCHed via the
  existing TeacherAttendanceService.updateSettings endpoint.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import {
  AttendanceShiftsService,
  type AttendanceShift,
  type AttendanceShiftInput,
} from '@/services/attendance-shifts.service';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Initial daily-cap value from settings. Defaults to 1. */
  initialMaxDailyShifts?: number;
}>();

const emit = defineEmits<{
  'settings-changed': [
    payload: { max_daily_shifts_per_person: number },
  ];
}>();

const DAY_LABELS = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'] as const;

const shifts = ref<AttendanceShift[]>([]);
const isLoading = ref<boolean>(false);

// Form state — one form is shown at a time; edit reuses the same form
// with `editingId` set. Keeping this simple avoids modal juggling.
const editingId = ref<string | null>(null);
const formName = ref<string>('');
const formStart = ref<string>('07:00');
const formEnd = ref<string>('12:00');
const formDays = ref<number[]>([1, 2, 3, 4, 5]);
const isSaving = ref<boolean>(false);
const formError = ref<string | null>(null);

// Settings — debounced write through TeacherAttendanceService.
const maxDailyShifts = ref<number>(props.initialMaxDailyShifts ?? 1);
let settingsTimer: ReturnType<typeof setTimeout> | null = null;

const isEditing = computed<boolean>(() => editingId.value !== null);
const canSave = computed<boolean>(
  () =>
    formName.value.trim().length > 0 &&
    formStart.value < formEnd.value &&
    formDays.value.length > 0 &&
    !isSaving.value,
);

async function loadShifts(): Promise<void> {
  isLoading.value = true;
  try {
    shifts.value = await AttendanceShiftsService.list();
  } finally {
    isLoading.value = false;
  }
}

function resetForm(): void {
  editingId.value = null;
  formName.value = '';
  formStart.value = '07:00';
  formEnd.value = '12:00';
  formDays.value = [1, 2, 3, 4, 5];
  formError.value = null;
}

function beginEdit(shift: AttendanceShift): void {
  editingId.value = shift.id;
  formName.value = shift.name;
  formStart.value = shift.start_time;
  formEnd.value = shift.end_time;
  formDays.value = [...shift.days_of_week];
  formError.value = null;
}

function toggleDay(day: number): void {
  formDays.value = formDays.value.includes(day)
    ? formDays.value.filter((d) => d !== day)
    : [...formDays.value, day].sort();
}

async function saveShift(): Promise<void> {
  if (!canSave.value) return;
  isSaving.value = true;
  formError.value = null;
  const payload: AttendanceShiftInput = {
    name: formName.value.trim(),
    start_time: formStart.value,
    end_time: formEnd.value,
    days_of_week: [...formDays.value],
  };
  try {
    if (editingId.value) {
      await AttendanceShiftsService.update(editingId.value, payload);
    } else {
      await AttendanceShiftsService.create(payload);
    }
    resetForm();
    await loadShifts();
  } catch (e) {
    formError.value = (e as Error).message ?? 'Gagal menyimpan shift.';
  } finally {
    isSaving.value = false;
  }
}

async function removeShift(id: string): Promise<void> {
  const backup = [...shifts.value];
  shifts.value = shifts.value.filter((s) => s.id !== id);
  try {
    await AttendanceShiftsService.destroy(id);
    if (editingId.value === id) resetForm();
  } catch {
    shifts.value = backup;
  }
}

// Settings debouncer — batches the auto-pick + cap into one PATCH so
// a quick toggle-and-adjust doesn't fire two requests.
function scheduleSettingsFlush(): void {
  if (settingsTimer) clearTimeout(settingsTimer);
  settingsTimer = setTimeout(async () => {
    const payload = { max_daily_shifts_per_person: maxDailyShifts.value };
    try {
      await TeacherAttendanceService.updateSettings(payload);
      emit('settings-changed', payload);
    } catch {
      /* leave local state; next successful write will realign */
    }
  }, 400);
}

watch(maxDailyShifts, scheduleSettingsFlush);

function fmtDays(days: number[]): string {
  return days.map((d) => DAY_LABELS[d]).join(', ');
}

onMounted(loadShifts);
</script>

<template>
  <div class="space-y-3">
    <!-- Existing shifts -->
    <section class="bg-white border border-slate-200 rounded-xl overflow-hidden">
      <header class="px-4 py-2 border-b border-slate-200 flex items-center justify-between">
        <h4 class="text-xs font-bold text-brand-cobalt uppercase tracking-wider">
          Daftar shift
        </h4>
        <span class="text-2xs text-slate-400 tabular-nums">
          {{ shifts.length }} shift terdaftar
        </span>
      </header>
      <div
        v-if="isLoading && shifts.length === 0"
        class="p-6 text-center text-xs text-slate-400"
      >
        Memuat…
      </div>
      <div v-else-if="shifts.length === 0" class="p-8 text-center">
        <NavIcon name="clock" :size="24" class="text-slate-300 mx-auto" />
        <p class="text-xs text-slate-500 mt-2">
          Belum ada shift. Isi form di bawah untuk menambah.
        </p>
        <p class="text-2xs text-slate-400 mt-1">
          Contoh: Pagi 07:00–12:00, Sore 13:00–17:00.
        </p>
      </div>
      <ul v-else class="divide-y divide-slate-100">
        <li
          v-for="s in shifts"
          :key="s.id"
          class="grid grid-cols-[1fr_auto_auto] items-center gap-3 px-4 py-2.5 text-xs"
        >
          <div>
            <p class="font-bold">{{ s.name }}</p>
            <p class="text-2xs text-slate-400 tabular-nums">
              {{ s.start_time }} – {{ s.end_time }} · {{ fmtDays(s.days_of_week) }}
            </p>
          </div>
          <button
            type="button"
            class="text-2xs font-bold text-brand-cobalt border border-brand-cobalt/40 rounded px-2 py-1"
            @click="beginEdit(s)"
          >
            Ubah
          </button>
          <button
            type="button"
            class="text-2xs font-bold text-rose-700 border border-rose-200 rounded px-2 py-1"
            @click="removeShift(s.id)"
          >
            Hapus
          </button>
        </li>
      </ul>
    </section>

    <!-- Add / edit form -->
    <section class="bg-sky-50 border border-sky-200 rounded-xl p-3">
      <div
        class="flex items-center justify-between mb-2 text-2xs font-bold text-brand-cobalt uppercase tracking-wider"
      >
        <span>{{ isEditing ? 'Ubah shift' : 'Tambah shift' }}</span>
        <button
          v-if="isEditing"
          type="button"
          class="text-2xs font-bold text-slate-500"
          @click="resetForm"
        >
          Batal
        </button>
      </div>

      <div class="grid grid-cols-[2fr_1fr_1fr_auto] gap-2 items-end">
        <div class="flex flex-col gap-1">
          <label class="text-2xs font-bold text-brand-cobalt">Nama shift</label>
          <input
            v-model="formName"
            type="text"
            placeholder="Pagi / Sore / Malam"
            class="rounded border border-sky-200 px-2 py-1 text-xs bg-white"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-2xs font-bold text-brand-cobalt">Mulai</label>
          <input
            v-model="formStart"
            type="time"
            class="rounded border border-sky-200 px-2 py-1 text-xs bg-white tabular-nums"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-2xs font-bold text-brand-cobalt">Selesai</label>
          <input
            v-model="formEnd"
            type="time"
            class="rounded border border-sky-200 px-2 py-1 text-xs bg-white tabular-nums"
          />
        </div>
        <button
          type="button"
          class="text-xs font-bold px-3 py-2 rounded bg-brand-cobalt text-white disabled:opacity-50"
          :disabled="!canSave"
          @click="saveShift"
        >
          {{ isEditing ? 'Simpan' : 'Tambah' }}
        </button>
      </div>

      <div class="mt-3">
        <p class="text-2xs font-bold text-brand-cobalt mb-1">Hari berlaku</p>
        <div class="flex gap-1 flex-wrap">
          <button
            v-for="(label, i) in DAY_LABELS"
            :key="label"
            type="button"
            class="text-2xs font-bold px-2 py-1 rounded-full border"
            :class="
              formDays.includes(i)
                ? 'bg-brand-cobalt text-white border-transparent'
                : 'bg-white text-slate-500 border-slate-200'
            "
            @click="toggleDay(i)"
          >
            {{ label }}
          </button>
        </div>
      </div>

      <p
        v-if="formError"
        class="text-2xs text-rose-700 font-bold mt-2"
      >
        {{ formError }}
      </p>
    </section>

    <!-- Settings row. Auto-pick is always on (client-side) — schools
         don't get a toggle because turning it off would just mean
         "start with nothing selected" which is worse UX. Only the
         daily cap is a real persisted knob. -->
    <section
      class="bg-white border border-slate-200 rounded-xl p-3 flex items-center justify-between gap-4 flex-wrap"
    >
      <div class="text-2xs text-slate-500">
        Saat absen, sistem otomatis memilih shift yang sedang aktif.
        Pengguna bisa ganti pilihan sebelum menekan Absen.
      </div>
      <label class="flex items-center gap-2 text-xs">
        <span class="font-bold whitespace-nowrap">Maks shift / orang / hari</span>
        <input
          v-model.number="maxDailyShifts"
          type="number"
          min="1"
          max="6"
          class="w-16 rounded border border-slate-200 px-2 py-1 text-xs tabular-nums text-center"
        />
      </label>
    </section>
  </div>
</template>

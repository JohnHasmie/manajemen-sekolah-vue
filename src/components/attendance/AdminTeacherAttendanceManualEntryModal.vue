<!--
  AdminTeacherAttendanceManualEntryModal.vue — the "Catat Manual" modal
  behind the primary CTA on AdminTeacherAttendanceView (Kehadiran Pegawai).

  What it does: admin backfills a daily attendance row for one pegawai
  (teacher OR staff) via POST /teacher-attendance/manual. Bypasses
  camera/GPS/geofence — the whole point of manual entry.

  Fields, in the order the spec requires:
    1. Pegawai       — autocomplete against /personnel-search
    2. Tanggal       — native date, defaults to today, max = today
    3. Status        — segmented (Hadir · Izin · Sakit · Alfa)
    4. Jam Masuk / Jam Pulang — TIME inputs, visible only when Status=Hadir
    5. Alasan        — textarea (max 500), hidden when Status=Alfa
    6. Catatan admin — small text input, always optional

  A 409 duplicate response is rendered inline (banner) — the modal
  stays open so the admin can adjust the target person/date. Every other
  error path routes through the shared toast.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import { toLocalYmd } from '@/lib/local-date';
import {
  TeacherAttendanceService,
  type ManualEntryPersonnelOption,
  type ManualEntryPayload,
} from '@/services/teacher-attendance.service';
import { useToast } from '@/composables/useToast';

const props = defineProps<{
  open: boolean;
}>();

const emit = defineEmits<{
  close: [];
  /** Fired after a successful 201 create so the parent view can
   *  re-fetch its report data. Payload is the freshly-created row's
   *  ISO date, useful if the parent wants to jump the periode filter. */
  created: [date: string];
}>();

const { t } = useI18n();
const toast = useToast();

const REASON_MAX = 500;
const NOTE_MAX = 500;

// ── Personnel picker state ────────────────────────────────────────
const personnelQuery = ref('');
const personnelOptions = ref<ManualEntryPersonnelOption[]>([]);
const personnelLoading = ref(false);
const personnelDropdownOpen = ref(false);
const selectedPersonnel = ref<ManualEntryPersonnelOption | null>(null);
let searchTimer: ReturnType<typeof setTimeout> | null = null;

async function fetchPersonnel(q: string): Promise<void> {
  personnelLoading.value = true;
  try {
    personnelOptions.value = await TeacherAttendanceService.searchPersonnel(q, 20);
  } catch (e) {
    // Search errors are non-fatal for the modal — the picker just shows
    // an empty list. The initial-mount 403 (missing ability) surfaces
    // via toast so the admin sees why the list is empty.
    toast.error((e as Error).message);
    personnelOptions.value = [];
  } finally {
    personnelLoading.value = false;
  }
}

/**
 * Debounce the search so a fast typer doesn't spawn N in-flight
 * requests. 220 ms is the same value the shared PageFilterToolbar
 * uses on other admin screens.
 */
function scheduleSearch(q: string): void {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    fetchPersonnel(q.trim());
  }, 220);
}

function onPersonnelInput(): void {
  personnelDropdownOpen.value = true;
  // Typing after picking someone unpicks them until they pick again.
  if (
    selectedPersonnel.value &&
    personnelQuery.value !== selectedPersonnel.value.name
  ) {
    selectedPersonnel.value = null;
  }
  scheduleSearch(personnelQuery.value);
}

function pickPersonnel(opt: ManualEntryPersonnelOption): void {
  selectedPersonnel.value = opt;
  personnelQuery.value = opt.name;
  personnelDropdownOpen.value = false;
  duplicateBanner.value = null;
}

// ── Form state ────────────────────────────────────────────────────
const todayYmd = () => toLocalYmd(new Date());
const date = ref(todayYmd());
type StatusKey = 'present' | 'permission' | 'sick' | 'absent';
const status = ref<StatusKey>('present');
const checkInAt = ref('');
const checkOutAt = ref('');
const reason = ref('');
const note = ref('');
const saving = ref(false);
const duplicateBanner = ref<string | null>(null);

const statusOptions = computed(() => [
  {
    key: 'present',
    label: t('admin.sekolah.teacher_attendance.manual.status_present'),
  },
  {
    key: 'permission',
    label: t('admin.sekolah.teacher_attendance.manual.status_permission'),
  },
  { key: 'sick', label: t('admin.sekolah.teacher_attendance.manual.status_sick') },
  {
    key: 'absent',
    label: t('admin.sekolah.teacher_attendance.manual.status_absent'),
  },
]);

const timesVisible = computed(() => status.value === 'present');
const reasonVisible = computed(() => status.value !== 'absent');
const timeOrderError = computed(() => {
  if (!timesVisible.value) return false;
  if (!checkInAt.value || !checkOutAt.value) return false;
  return checkOutAt.value <= checkInAt.value;
});

const formValid = computed<boolean>(() => {
  if (!selectedPersonnel.value) return false;
  if (!date.value) return false;
  if (date.value > todayYmd()) return false;
  if (timesVisible.value) {
    if (!checkInAt.value || !checkOutAt.value) return false;
    if (timeOrderError.value) return false;
  }
  if (reason.value.length > REASON_MAX) return false;
  if (note.value.length > NOTE_MAX) return false;
  return true;
});

function resetForm(): void {
  personnelQuery.value = '';
  personnelOptions.value = [];
  personnelDropdownOpen.value = false;
  selectedPersonnel.value = null;
  date.value = todayYmd();
  status.value = 'present';
  checkInAt.value = '';
  checkOutAt.value = '';
  reason.value = '';
  note.value = '';
  duplicateBanner.value = null;
  saving.value = false;
}

// Prefetch the initial (empty q) list the first time the modal opens
// so the dropdown never renders "kosong" on the very first focus.
// Also resets any stale form state from a previous open/close cycle.
watch(
  () => props.open,
  (isOpen) => {
    if (isOpen) {
      resetForm();
      fetchPersonnel('');
    }
  },
);

async function save(): Promise<void> {
  if (!formValid.value || !selectedPersonnel.value || saving.value) return;
  saving.value = true;
  duplicateBanner.value = null;
  try {
    const payload: ManualEntryPayload = {
      user_id: selectedPersonnel.value.user_id,
      date: date.value,
      status: status.value,
      reason: reason.value.trim() || undefined,
      note: note.value.trim() || undefined,
    };
    if (timesVisible.value) {
      payload.check_in_at = checkInAt.value;
      payload.check_out_at = checkOutAt.value;
    }
    const result = await TeacherAttendanceService.storeManual(payload);
    if (result.status === 'duplicate') {
      duplicateBanner.value = t(
        'admin.sekolah.teacher_attendance.manual.duplicate_error',
      );
      return;
    }
    toast.success(t('admin.sekolah.teacher_attendance.manual.toast_saved'));
    emit('created', date.value);
    emit('close');
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    saving.value = false;
  }
}

function close(): void {
  if (saving.value) return;
  emit('close');
}
</script>

<template>
  <Modal
    v-if="open"
    size="lg"
    :title="t('admin.sekolah.teacher_attendance.manual.title')"
    :subtitle="t('admin.sekolah.teacher_attendance.manual.subtitle')"
    @close="close"
  >
    <form class="space-y-md" @submit.prevent="save">
      <!-- ─── Pegawai autocomplete ───────────────────────────── -->
      <div class="relative">
        <label class="block text-sm font-bold text-slate-700 mb-1">
          {{ t('admin.sekolah.teacher_attendance.manual.field_personnel') }}
          <span class="text-role-admin">*</span>
        </label>
        <input
          v-model="personnelQuery"
          type="text"
          :placeholder="
            t('admin.sekolah.teacher_attendance.manual.personnel_placeholder')
          "
          class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          :disabled="saving"
          @input="onPersonnelInput"
          @focus="personnelDropdownOpen = true"
        />
        <div
          v-if="personnelDropdownOpen && (personnelOptions.length > 0 || personnelLoading)"
          class="absolute left-0 right-0 mt-1 max-h-64 overflow-y-auto rounded-xl bg-white border border-slate-200 shadow-lg z-30"
        >
          <div
            v-if="personnelLoading && personnelOptions.length === 0"
            class="px-3 py-4 text-center text-3xs text-slate-500"
          >
            <NavIcon name="loader" :size="14" class="animate-spin" />
          </div>
          <ul v-else class="divide-y divide-slate-100">
            <li v-for="opt in personnelOptions" :key="opt.user_id">
              <button
                type="button"
                class="w-full text-left px-3 py-2 hover:bg-slate-50 flex items-center justify-between gap-2"
                :class="{
                  'bg-role-admin/5':
                    selectedPersonnel && selectedPersonnel.user_id === opt.user_id,
                }"
                @click="pickPersonnel(opt)"
              >
                <span class="min-w-0">
                  <span class="block text-sm font-bold text-slate-800 truncate">
                    {{ opt.name }}
                  </span>
                  <span
                    v-if="opt.employee_number || opt.position"
                    class="block text-3xs text-slate-500 truncate"
                  >
                    <template v-if="opt.employee_number">NIP {{ opt.employee_number }}</template>
                    <template v-if="opt.employee_number && opt.position"> · </template>
                    <template v-if="opt.position">{{ opt.position }}</template>
                  </span>
                </span>
                <span
                  class="text-3xs font-bold px-1.5 py-0.5 rounded-full whitespace-nowrap"
                  :class="
                    opt.personnel_type === 'staff'
                      ? 'bg-violet-100 text-violet-700'
                      : 'bg-sky-100 text-sky-700'
                  "
                >
                  {{
                    opt.personnel_type === 'staff'
                      ? t(
                          'admin.sekolah.teacher_attendance.manual.personnel_type_staff',
                        )
                      : t(
                          'admin.sekolah.teacher_attendance.manual.personnel_type_teacher',
                        )
                  }}
                </span>
              </button>
            </li>
          </ul>
        </div>
        <p
          v-if="
            personnelDropdownOpen &&
            !personnelLoading &&
            personnelOptions.length === 0 &&
            personnelQuery.trim() !== ''
          "
          class="mt-1 text-3xs text-slate-500"
        >
          {{ t('admin.sekolah.teacher_attendance.manual.personnel_empty') }}
        </p>
      </div>

      <!-- ─── Tanggal + Status side by side ────────────────────── -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1">
            {{ t('admin.sekolah.teacher_attendance.manual.field_date') }}
            <span class="text-role-admin">*</span>
          </label>
          <input
            v-model="date"
            type="date"
            :max="todayYmd()"
            class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
            :disabled="saving"
          />
        </div>
        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1">
            {{ t('admin.sekolah.teacher_attendance.manual.field_status') }}
            <span class="text-role-admin">*</span>
          </label>
          <SegmentedControl
            :model-value="status"
            :options="statusOptions"
            size="sm"
            @update:model-value="(v) => (status = v as StatusKey)"
          />
        </div>
      </div>

      <!-- ─── Jam Masuk / Jam Pulang (only for status=present) ─── -->
      <div v-if="timesVisible" class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1">
            {{ t('admin.sekolah.teacher_attendance.manual.field_check_in') }}
            <span class="text-role-admin">*</span>
          </label>
          <input
            v-model="checkInAt"
            type="time"
            class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
            :disabled="saving"
          />
        </div>
        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1">
            {{ t('admin.sekolah.teacher_attendance.manual.field_check_out') }}
            <span class="text-role-admin">*</span>
          </label>
          <input
            v-model="checkOutAt"
            type="time"
            class="w-full rounded-xl border px-3 py-2.5 text-sm text-slate-800 focus:outline-none focus:ring-2"
            :class="
              timeOrderError
                ? 'border-rose-300 focus:ring-rose-200'
                : 'border-slate-200 focus:ring-role-admin/30'
            "
            :disabled="saving"
          />
          <p
            v-if="timeOrderError"
            class="mt-1 text-3xs text-rose-600 font-bold"
          >
            {{
              t('admin.sekolah.teacher_attendance.manual.checkout_after_checkin')
            }}
          </p>
        </div>
      </div>

      <!-- ─── Alasan (hidden on Alfa) ──────────────────────────── -->
      <div v-if="reasonVisible">
        <label class="block text-sm font-bold text-slate-700 mb-1">
          {{ t('admin.sekolah.teacher_attendance.manual.field_reason') }}
        </label>
        <textarea
          v-model="reason"
          rows="2"
          :maxlength="REASON_MAX"
          :placeholder="
            t('admin.sekolah.teacher_attendance.manual.reason_placeholder')
          "
          class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30 resize-none"
          :disabled="saving"
        ></textarea>
        <p class="mt-1 text-3xs text-slate-400 text-right">
          {{
            t('admin.sekolah.teacher_attendance.manual.char_counter', {
              used: reason.length,
              max: REASON_MAX,
            })
          }}
        </p>
      </div>

      <!-- ─── Catatan admin ────────────────────────────────────── -->
      <div>
        <label class="block text-sm font-bold text-slate-700 mb-1">
          {{ t('admin.sekolah.teacher_attendance.manual.field_note') }}
        </label>
        <input
          v-model="note"
          type="text"
          :maxlength="NOTE_MAX"
          :placeholder="
            t('admin.sekolah.teacher_attendance.manual.note_placeholder')
          "
          class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          :disabled="saving"
        />
      </div>

      <!-- ─── 409 duplicate banner ─────────────────────────────── -->
      <div
        v-if="duplicateBanner"
        class="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-3xs font-bold text-amber-800 flex items-start gap-2"
      >
        <NavIcon name="alert-triangle" :size="14" class="mt-0.5 shrink-0" />
        <span>{{ duplicateBanner }}</span>
      </div>

      <BottomSheetFooter
        :primary-label="t('admin.sekolah.teacher_attendance.manual.save')"
        :secondary-label="t('admin.sekolah.teacher_attendance.manual.cancel')"
        :primary-loading="saving"
        :primary-disabled="!formValid"
        @primary="save"
        @secondary="close"
      />
    </form>
  </Modal>
</template>

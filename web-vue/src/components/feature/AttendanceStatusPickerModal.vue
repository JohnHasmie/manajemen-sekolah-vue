<!--
  AttendanceStatusPickerModal.vue — per-student status picker with
  notes field. Mirrors Flutter's `per_student_status_picker.dart`.

  Tap a status tile → tile fills with the role color, others fade.
  Notes textarea is optional (trimmed empty → null on apply).
  Footer: Batal + Terapkan.

  Used from TeacherAttendanceDetailView when the user taps a
  student's status pill — the picker captures the new status + an
  optional note, then emits `apply` with both. The caller pushes
  the change into the controller's edited-status map and persists.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type {
  AttendanceRow,
  AttendanceStatus,
} from '@/types/attendance';
import { ATTENDANCE_LABELS } from '@/types/attendance';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';

const props = withDefaults(
  defineProps<{
    student: AttendanceRow;
    initialStatus?: AttendanceStatus;
    initialNote?: string;
    isSaving?: boolean;
  }>(),
  { initialStatus: null, initialNote: '', isSaving: false },
);

const emit = defineEmits<{
  close: [];
  apply: [{ status: NonNullable<AttendanceStatus>; note: string | null }];
}>();

// ── Local edit state ──
const selected = ref<AttendanceStatus>(props.initialStatus ?? 'hadir');
const note = ref<string>(props.initialNote ?? '');

watch(
  () => props.initialStatus,
  (v) => {
    selected.value = v ?? 'hadir';
  },
);
watch(
  () => props.initialNote,
  (v) => {
    note.value = v ?? '';
  },
);

// ── Tile palette mirrors AttendancePicker ──
const TILE_PALETTE: Record<
  NonNullable<AttendanceStatus>,
  { active: string; ring: string; icon: string; iconColor: string }
> = {
  hadir: {
    active: 'bg-emerald-600 text-white border-emerald-600',
    ring: 'ring-emerald-200',
    icon: '✓',
    iconColor: 'text-emerald-600',
  },
  sakit: {
    active: 'bg-amber-600 text-white border-amber-600',
    ring: 'ring-amber-200',
    icon: '⚕',
    iconColor: 'text-amber-600',
  },
  izin: {
    active: 'bg-sky-600 text-white border-sky-600',
    ring: 'ring-sky-200',
    icon: '📝',
    iconColor: 'text-sky-600',
  },
  alpa: {
    active: 'bg-red-600 text-white border-red-600',
    ring: 'ring-red-200',
    icon: '✕',
    iconColor: 'text-red-600',
  },
};

const STATUSES: NonNullable<AttendanceStatus>[] = [
  'hadir',
  'sakit',
  'izin',
  'alpa',
];

const canApply = computed(() => selected.value !== null);

function pick(s: NonNullable<AttendanceStatus>) {
  selected.value = s;
}

function apply() {
  if (!canApply.value) return;
  const trimmed = note.value.trim();
  emit('apply', {
    status: selected.value as NonNullable<AttendanceStatus>,
    note: trimmed.length === 0 ? null : trimmed,
  });
}
</script>

<template>
  <Modal
    :title="`Status Kehadiran`"
    subtitle="Pilih status dan tambahkan catatan bila perlu."
    @close="emit('close')"
  >
    <!-- Student identity strip -->
    <header class="flex items-center gap-3 -mt-2 mb-4">
      <InitialsAvatar
        :name="student.student_name"
        :size="44"
        :border-radius="12"
        color="#1B6FB8"
      />
      <div class="min-w-0">
        <p class="text-[14px] font-black text-slate-900 truncate">
          {{ student.student_name || 'Tanpa nama' }}
        </p>
        <p class="text-[11px] text-slate-500">
          NIS {{ student.student_number || '—' }}
          <span v-if="student.alert" class="ml-1.5 text-amber-700">· {{ student.alert }}</span>
        </p>
      </div>
    </header>

    <!-- Status tiles — 2x2 grid for desktop -->
    <div class="grid grid-cols-2 gap-2.5 mb-4">
      <button
        v-for="s in STATUSES"
        :key="s"
        type="button"
        class="rounded-xl border-2 px-3 py-3 transition-all text-left focus:outline-none focus:ring-2"
        :class="
          selected === s
            ? TILE_PALETTE[s].active + ' ' + TILE_PALETTE[s].ring + ' shadow-sm'
            : 'bg-white border-slate-200 text-slate-700 hover:border-slate-300'
        "
        @click="pick(s)"
      >
        <div class="flex items-center justify-between mb-1">
          <span
            class="w-7 h-7 rounded-lg grid place-items-center text-base font-black"
            :class="
              selected === s
                ? 'bg-white/20 text-white'
                : 'bg-slate-50 ' + TILE_PALETTE[s].iconColor
            "
          >
            {{ TILE_PALETTE[s].icon }}
          </span>
          <span
            v-if="selected === s"
            class="text-[10px] font-bold uppercase tracking-widest text-white/90"
            >Aktif</span
          >
        </div>
        <p
          class="text-[13px] font-bold"
          :class="selected === s ? 'text-white' : 'text-slate-900'"
        >
          {{ ATTENDANCE_LABELS[s] }}
        </p>
        <p
          class="text-[10.5px] mt-0.5"
          :class="selected === s ? 'text-white/85' : 'text-slate-500'"
        >
          {{
            s === 'hadir'
              ? 'Hadir tepat waktu / terlambat'
              : s === 'sakit'
                ? 'Tidak hadir karena sakit'
                : s === 'izin'
                  ? 'Tidak hadir dengan izin'
                  : 'Tidak hadir tanpa keterangan'
          }}
        </p>
      </button>
    </div>

    <!-- Notes -->
    <div class="mb-4">
      <label class="block text-[12px] font-bold text-slate-700 mb-1.5">
        Catatan
        <span class="text-slate-400 font-medium">(opsional)</span>
      </label>
      <textarea
        v-model="note"
        rows="3"
        placeholder="Contoh: Demam · sudah lapor wali kelas pagi ini"
        class="w-full rounded-xl border border-slate-300 px-3 py-2 text-[13px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none resize-none"
        :disabled="isSaving"
        :maxlength="500"
      ></textarea>
      <p class="text-[10.5px] text-slate-400 mt-1 text-right">
        {{ note.length }}/500
      </p>
    </div>

    <!-- Footer -->
    <footer class="flex items-center gap-2">
      <Button variant="secondary" size="sm" :disabled="isSaving" @click="emit('close')">
        Batal
      </Button>
      <span class="flex-1"></span>
      <Button
        variant="primary"
        size="sm"
        :loading="isSaving"
        :disabled="!canApply || isSaving"
        @click="apply"
      >
        Terapkan
      </Button>
    </footer>
  </Modal>
</template>

<!--
  ActivitySubmissionPickerModal.vue — teacher's "Catat Submit"
  per-student status picker.

  Mirrors Flutter's `activity_submission_picker_sheet.dart`:
    • Draggable modal listing every student in the activity's class
    • Each row: name · 4-state status pill (Belum/Sudah/Telat/Izin)
    • For scored types (tugas/ujian): inline score input 0..100
    • Optional note input (collapsed by default)
    • Bulk action: tap a status chip header to apply to all unset rows
    • Search box at the top for fast scrolling in big classes
    • Dirty tracking — only changed rows get sent on save

  Backend (`POST /class-activity/{id}/submissions`) wraps the rows
  in a single upsert so a class of 40 students = 1 round trip.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import {
  SUBMISSION_STATUS_LABELS,
  SUBMISSION_STATUS_TONES,
  type ActivitySubmissionRow,
  type ClassActivity,
  type SubmissionStatus,
} from '@/types/class-activity';

interface Props {
  activity: ClassActivity;
  rows: ActivitySubmissionRow[];
  /** True while POST is in flight. */
  busy?: boolean;
}

const props = withDefaults(defineProps<Props>(), { busy: false });

const emit = defineEmits<{
  close: [];
  save: [rows: ActivitySubmissionRow[]];
}>();

const STATUS_ORDER: SubmissionStatus[] = [
  'pending',
  'submitted',
  'late',
  'excused',
];

// Local working copy — never mutate the prop. We diff against `props.rows`
// in `dirtyRows` to skip unchanged students on save.
const draft = ref<ActivitySubmissionRow[]>([]);

watch(
  () => props.rows,
  (next) => {
    draft.value = next.map((r) => ({ ...r }));
  },
  { immediate: true },
);

const searchQuery = ref('');

const filteredRows = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return draft.value;
  return draft.value.filter((r) => r.student_name.toLowerCase().includes(q));
});

const dirtyRows = computed(() =>
  draft.value.filter((r, i) => {
    const orig = props.rows[i];
    if (!orig) return true;
    return (
      orig.status !== r.status ||
      (orig.score ?? null) !== (r.score ?? null) ||
      (orig.notes ?? null) !== (r.notes ?? null)
    );
  }),
);

const dirtyCount = computed(() => dirtyRows.value.length);

// Scored activities surface the score input. Backend ignores `score`
// for non-scored types but rendering it for "aktivitas" / "catatan"
// would confuse teachers, so we hide proactively.
const showScoreColumn = computed(
  () => props.activity.type === 'tugas' || props.activity.type === 'ujian',
);

const statusCounts = computed(() => {
  const out: Record<SubmissionStatus, number> = {
    pending: 0,
    submitted: 0,
    late: 0,
    excused: 0,
  };
  for (const r of draft.value) out[r.status] += 1;
  return out;
});

function setStatus(rowIdx: number, next: SubmissionStatus) {
  const row = draft.value[rowIdx];
  if (!row || row.status === next) return;
  row.status = next;
  // When moving away from a scored state, keep the score; teacher may
  // toggle back. Only clear on Belum/Izin to keep the row valid.
  if (next === 'pending' || next === 'excused') {
    // leave score as-is — backend ignores when status doesn't expect it
  }
}

function cycleStatus(rowIdx: number) {
  const row = draft.value[rowIdx];
  if (!row) return;
  const i = STATUS_ORDER.indexOf(row.status);
  const next = STATUS_ORDER[(i + 1) % STATUS_ORDER.length];
  setStatus(rowIdx, next);
}

function bulkApply(status: SubmissionStatus) {
  // Apply to rows that are currently `pending` only — avoid stomping
  // teacher's earlier deliberate Telat/Izin entries.
  for (const r of draft.value) {
    if (r.status === 'pending') r.status = status;
  }
}

function setScore(rowIdx: number, raw: string) {
  const row = draft.value[rowIdx];
  if (!row) return;
  if (raw === '') {
    row.score = null;
    return;
  }
  const n = Number(raw);
  if (!Number.isFinite(n)) return;
  row.score = Math.max(0, Math.min(100, n));
}

function tone(status: SubmissionStatus) {
  return SUBMISSION_STATUS_TONES[status];
}
function label(status: SubmissionStatus) {
  return SUBMISSION_STATUS_LABELS[status];
}

function handleSave() {
  if (dirtyCount.value === 0) {
    emit('close');
    return;
  }
  emit('save', dirtyRows.value);
}
</script>

<template>
  <Modal
    title="Catat Submit"
    :subtitle="`${activity.title} · ${activity.class_name}`"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Search + counter -->
      <div class="relative">
        <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400">
          <NavIcon name="search" :size="14" />
        </span>
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Cari nama siswa…"
          class="w-full pl-9 pr-3 py-2 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-brand-cobalt"
        />
      </div>

      <!-- Status summary + bulk-apply chips -->
      <div class="grid grid-cols-4 gap-1.5 text-center">
        <button
          v-for="s in STATUS_ORDER"
          :key="s"
          type="button"
          class="rounded-lg border px-2 py-1.5 hover:bg-slate-50 transition"
          :class="[tone(s).bg, tone(s).border]"
          :title="`Terapkan ${label(s)} ke semua yang masih Belum`"
          @click="bulkApply(s)"
        >
          <p
            class="text-[9px] font-bold uppercase tracking-widest"
            :class="tone(s).text"
          >
            {{ label(s) }}
          </p>
          <p class="text-base font-black tabular-nums" :class="tone(s).text">
            {{ statusCounts[s] }}
          </p>
        </button>
      </div>

      <p class="text-[10px] text-slate-400 italic">
        Klik chip di atas untuk terapkan ke siswa yang masih
        <strong>Belum</strong> · Klik pill di tiap baris untuk siklus status
      </p>

      <!-- Per-student list -->
      <div
        class="border border-slate-200 rounded-xl overflow-hidden max-h-[55vh] overflow-y-auto"
      >
        <ul class="divide-y divide-slate-100">
          <li
            v-for="row in filteredRows"
            :key="row.student_class_id"
            class="px-3 py-2.5 flex items-center gap-3"
          >
            <span class="flex-1 min-w-0">
              <p class="text-[13px] font-semibold text-slate-900 truncate">
                {{ row.student_name }}
              </p>
            </span>

            <input
              v-if="showScoreColumn"
              type="number"
              min="0"
              max="100"
              step="1"
              :value="row.score ?? ''"
              placeholder="—"
              class="w-14 text-center text-[12px] font-semibold rounded-md border border-slate-200 focus:border-brand-cobalt focus:outline-none px-1 py-1 tabular-nums"
              @input="
                setScore(
                  draft.indexOf(row),
                  ($event.target as HTMLInputElement).value,
                )
              "
            />

            <button
              type="button"
              class="text-[10px] font-bold px-2.5 py-1 rounded-full border min-w-[64px] transition"
              :class="[tone(row.status).bg, tone(row.status).text, tone(row.status).border]"
              @click="cycleStatus(draft.indexOf(row))"
            >
              {{ label(row.status) }}
            </button>
          </li>
        </ul>
      </div>

      <!-- Footer -->
      <footer class="flex items-center gap-2 pt-2 border-t border-slate-100">
        <p class="text-[11px] text-slate-500 flex-1">
          <template v-if="dirtyCount > 0">
            <span class="font-bold text-amber-700">{{ dirtyCount }}</span>
            perubahan
          </template>
          <template v-else>Belum ada perubahan</template>
        </p>
        <Button variant="ghost" :disabled="busy" @click="emit('close')">
          Batal
        </Button>
        <Button
          variant="primary"
          :disabled="busy || dirtyCount === 0"
          @click="handleSave"
        >
          {{ busy ? 'Menyimpan…' : 'Simpan' }}
        </Button>
      </footer>
    </div>
  </Modal>
</template>

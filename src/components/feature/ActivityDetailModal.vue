<!--
  ActivityDetailModal.vue — full-screen detail dialog for one
  Activity Kelas record.

  Mirrors Flutter's `teacher_activity_detail_screen.dart` +
  `admin_activity_detail_screen.dart` collapsed into one role-aware
  modal:

    Header        title · subject·class·date (auto from props.activity)
    KPI strip     Student / Submit / Belum  (hidden when no tracking)
    Informasi     tipe pill, deskripsi, materi terkait, lampiran count
    Submissions   per-student status table (admin + teacher), if loaded
    Footer        role-specific actions
                    teacher → Catat Submit · Edit · Hapus
                    admin   → Hapus (only when isAdmin can manage)
                    parent  → (none)

  Loading the per-student submissions roster is the parent screen's
  job — pass the resolved list in via `submissions` so this modal
  stays a dumb presenter.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import {
  ACTIVITY_TYPE_COLORS,
  ACTIVITY_TYPE_LABELS,
  SUBMISSION_STATUS_LABELS,
  SUBMISSION_STATUS_TONES,
  submissionHasTracking,
  type ActivitySubmissionRow,
  type ClassActivity,
} from '@/types/class-activity';
import { formatDateLong } from '@/lib/format';

interface Props {
  activity: ClassActivity;
  role?: 'teacher' | 'admin' | 'parent';
  /** Per-student rows shown in List Student section (admin + teacher). */
  submissions?: ActivitySubmissionRow[];
  /** When true, hides Edit/Hapus on the footer (teacher viewing an
   *  archived/past activity). */
  readOnly?: boolean;
  /** Loading flag — disables footer buttons during save/delete. */
  busy?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  role: 'teacher',
  submissions: () => [],
  readOnly: false,
  busy: false,
});

const emit = defineEmits<{
  close: [];
  edit: [activity: ClassActivity];
  delete: [activity: ClassActivity];
  recordSubmissions: [activity: ClassActivity];
}>();

const accent = computed(() => ACTIVITY_TYPE_COLORS[props.activity.type]);
const typeLabel = computed(() => ACTIVITY_TYPE_LABELS[props.activity.type]);
const hasTracking = computed(() =>
  submissionHasTracking(props.activity.submissions),
);

const subtitle = computed(() => {
  const parts: string[] = [];
  if (props.activity.class_name) parts.push(props.activity.class_name);
  if (props.activity.subject_name) parts.push(props.activity.subject_name);
  parts.push(formatDateLong(props.activity.date));
  if (props.activity.time) parts.push(props.activity.time);
  return parts.join(' · ');
});

function statusTone(s: ActivitySubmissionRow['status']) {
  return SUBMISSION_STATUS_TONES[s];
}
function statusLabel(s: ActivitySubmissionRow['status']) {
  return SUBMISSION_STATUS_LABELS[s];
}
</script>

<template>
  <Modal :title="activity.title" :subtitle="subtitle" @close="emit('close')">
    <div class="space-y-4">
      <!-- KPI strip (only when tracking enabled) -->
      <div
        v-if="hasTracking"
        class="grid grid-cols-3 gap-2 bg-slate-50 rounded-xl p-3"
      >
        <div class="text-center">
          <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">
            Siswa
          </p>
          <p class="text-lg font-black text-slate-900 tabular-nums">
            {{ activity.submissions.total_students }}
          </p>
        </div>
        <div class="text-center">
          <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">
            Submit
          </p>
          <p class="text-lg font-black text-emerald-700 tabular-nums">
            {{ activity.submissions.submitted + activity.submissions.late }}
          </p>
        </div>
        <div class="text-center">
          <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">
            Belum
          </p>
          <p
            class="text-lg font-black tabular-nums"
            :class="activity.submissions.pending > 0 ? 'text-red-700' : 'text-emerald-700'"
          >
            {{ activity.submissions.pending }}
          </p>
        </div>
      </div>

      <!-- Informasi section -->
      <section class="space-y-2.5">
        <div class="flex items-center gap-2 flex-wrap">
          <span
            class="text-3xs font-bold px-2 py-0.5 rounded uppercase tracking-wider"
            :style="{ backgroundColor: accent + '1a', color: accent }"
          >
            {{ typeLabel }}
          </span>
          <span
            v-if="activity.is_specific_target"
            class="text-3xs font-bold px-2 py-0.5 rounded bg-violet-100 text-violet-700 uppercase tracking-wider"
          >
            Khusus
          </span>
          <span v-if="activity.session" class="text-3xs text-slate-500">
            · {{ activity.session }}
          </span>
        </div>

        <div v-if="activity.teacher_name && role !== 'teacher'" class="text-[12px] text-slate-600">
          Guru: <span class="font-semibold text-slate-800">{{ activity.teacher_name }}</span>
        </div>

        <div v-if="activity.description">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-1">
            Deskripsi
          </p>
          <p class="text-[13px] text-slate-700 leading-relaxed whitespace-pre-line">
            {{ activity.description }}
          </p>
        </div>

        <div v-if="activity.material">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-1">
            Materi Terkait
          </p>
          <div
            class="inline-flex items-center gap-2 px-3 py-2 rounded-xl border border-slate-200 bg-slate-50 text-[12px] text-slate-700"
          >
            <NavIcon name="book" :size="14" class="text-brand-cobalt" />
            {{ activity.material }}
          </div>
        </div>

        <div v-if="activity.attachment_count > 0">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-1">
            Lampiran
          </p>
          <p class="text-[12px] text-slate-600">
            {{ activity.attachment_count }} berkas terlampir
          </p>
        </div>

        <div v-if="activity.reflection && role === 'teacher'">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-1">
            Refleksi
          </p>
          <p class="text-[12px] text-slate-700 leading-relaxed italic whitespace-pre-line">
            {{ activity.reflection }}
          </p>
        </div>
      </section>

      <!-- List Student (when submissions roster loaded) -->
      <section v-if="role !== 'parent' && submissions.length > 0">
        <div class="flex items-center justify-between mb-2">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Daftar Siswa
          </p>
          <span class="text-3xs text-slate-500 tabular-nums">
            {{ submissions.length }} siswa
          </span>
        </div>
        <div
          class="border border-slate-200 rounded-xl overflow-hidden max-h-72 overflow-y-auto"
        >
          <ul class="divide-y divide-slate-100">
            <li
              v-for="(row, idx) in submissions"
              :key="row.student_class_id"
              class="px-3 py-2 flex items-center gap-3 text-[12px]"
            >
              <span class="text-3xs text-slate-400 w-5 text-right tabular-nums">
                {{ idx + 1 }}
              </span>
              <span class="flex-1 truncate font-medium text-slate-900">
                {{ row.student_name }}
              </span>
              <span
                v-if="row.score !== null && row.score !== undefined"
                class="text-2xs font-bold tabular-nums text-slate-700"
              >
                {{ row.score }}
              </span>
              <span
                class="text-3xs font-bold px-2 py-0.5 rounded-full border"
                :class="[statusTone(row.status).bg, statusTone(row.status).text, statusTone(row.status).border]"
              >
                {{ statusLabel(row.status) }}
              </span>
            </li>
          </ul>
        </div>
      </section>

      <!-- Footer actions -->
      <footer
        v-if="role === 'teacher' && !readOnly"
        class="flex items-center gap-2 pt-2 border-t border-slate-100"
      >
        <Button
          variant="ghost"
          class="!text-red-600 hover:!bg-red-50"
          :disabled="busy"
          @click="emit('delete', activity)"
        >
          <NavIcon name="trash-2" :size="14" />
          Hapus
        </Button>
        <span class="flex-1"></span>
        <Button variant="ghost" :disabled="busy" @click="emit('edit', activity)">
          <NavIcon name="edit" :size="14" />
          Edit
        </Button>
        <Button
          variant="primary"
          :disabled="busy"
          @click="emit('recordSubmissions', activity)"
        >
          <NavIcon name="check-square" :size="14" />
          Catat Submit
        </Button>
      </footer>

      <footer
        v-else-if="role === 'admin' && !readOnly"
        class="flex items-center justify-end gap-2 pt-2 border-t border-slate-100"
      >
        <Button variant="ghost" @click="emit('close')">Tutup</Button>
      </footer>
    </div>
  </Modal>
</template>

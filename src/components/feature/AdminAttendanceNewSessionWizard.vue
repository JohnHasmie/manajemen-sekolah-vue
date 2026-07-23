<!--
  AdminAttendanceNewSessionWizard.vue — admin "Mulai Presensi" wizard.

  Mirrors Flutter's `TeacherSelectionSheet` → `AttendancePage` flow,
  ported to a single 3-step modal:
    1. Pilih Teacher (TeacherSelectionSheet)
    2. Pilih Kelas + Mapel
    3. Pilih Tanggal + Jam Pelajaran

  On submit, emits the assembled session params so the host view can
  navigate to the detail/input route.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { LessonHourService } from '@/services/lesson-hour.service';
import type { Classroom, Subject, Teacher } from '@/types/entities';
import type { LessonHour } from '@/types/schedule';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import TeacherSelectionSheet from './TeacherSelectionSheet.vue';
import { localISODate } from '@/lib/format';
import { formatDayName } from '@/lib/day-name';

const emit = defineEmits<{
  close: [];
  done: [{
    teacher_id: string;
    teacher_name: string;
    class_id: string;
    subject_id: string;
    date: string;
    lesson_hour_id?: string;
  }];
}>();

type Step = 'teacher' | 'class_subject' | 'date_hour';
const step = ref<Step>('teacher');

const selectedTeacher = ref<Teacher | null>(null);
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const lessonHours = ref<LessonHour[]>([]);

const classId = ref<string>('');
const subjectId = ref<string>('');
// Local (WIB) calendar date — NOT UTC. This default is submitted as the
// new session's attendance date; `toISOString()` would default it to
// yesterday for admins opening the wizard before 07:00 WIB.
const date = ref<string>(localISODate());
const lessonHourId = ref<string>('');

const isLoading = ref(false);
const showTeacherSheet = ref(true);

async function loadRefs() {
  isLoading.value = true;
  try {
    const [cls, subs, hours] = await Promise.all([
      ClassroomService.list({ per_page: 200 }),
      SubjectService.list({ per_page: 200 }),
      LessonHourService.list(),
    ]);
    classes.value = cls.items;
    // If teacher has subjects assigned, narrow the subject list to those.
    if (selectedTeacher.value?.subject_ids?.length) {
      const ids = new Set(selectedTeacher.value.subject_ids);
      subjects.value = subs.items.filter((s) => ids.has(s.id));
    } else {
      subjects.value = subs.items;
    }
    lessonHours.value = hours;
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => {
  // The teacher picker sheet opens first.
});

function onTeacherSelect(t: Teacher) {
  selectedTeacher.value = t;
  showTeacherSheet.value = false;
  step.value = 'class_subject';
  void loadRefs();
}

function backStep() {
  if (step.value === 'date_hour') step.value = 'class_subject';
  else if (step.value === 'class_subject') {
    selectedTeacher.value = null;
    step.value = 'teacher';
    showTeacherSheet.value = true;
  }
}

function nextStep() {
  if (step.value === 'class_subject' && classId.value && subjectId.value) {
    step.value = 'date_hour';
  }
}

function submit() {
  if (!selectedTeacher.value || !classId.value || !subjectId.value || !date.value) return;
  emit('done', {
    teacher_id: selectedTeacher.value.id,
    teacher_name: selectedTeacher.value.name,
    class_id: classId.value,
    subject_id: subjectId.value,
    date: date.value,
    lesson_hour_id: lessonHourId.value || undefined,
  });
  emit('close');
}

const canSubmit = computed(
  () =>
    Boolean(selectedTeacher.value) &&
    Boolean(classId.value) &&
    Boolean(subjectId.value) &&
    Boolean(date.value),
);

const stepTitle = computed(() => {
  switch (step.value) {
    case 'teacher':
      return 'Pilih Guru';
    case 'class_subject':
      return 'Pilih Kelas & Mapel';
    case 'date_hour':
      return 'Tanggal & Jam Pelajaran';
  }
  return '';
});

const stepSubtitle = computed(() => {
  if (!selectedTeacher.value) return 'Langkah 1 dari 3';
  if (step.value === 'class_subject') return `Langkah 2 dari 3 · ${selectedTeacher.value.name}`;
  return `Langkah 3 dari 3 · ${selectedTeacher.value.name}`;
});
</script>

<template>
  <!-- Step 1: Teacher picker sheet (separate component) -->
  <TeacherSelectionSheet
    v-if="showTeacherSheet"
    title="Pilih Guru"
    subtitle="Pilih guru untuk memulai presensi atas namanya"
    @close="emit('close')"
    @select="onTeacherSelect"
  />

  <!-- Steps 2 & 3: wizard modal -->
  <Modal
    v-if="!showTeacherSheet && selectedTeacher"
    :title="stepTitle"
    :subtitle="stepSubtitle"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Step indicator -->
      <div class="flex items-center justify-between gap-2">
        <div
          v-for="(label, idx) in ['Guru', 'Kelas/Mapel', 'Tanggal']"
          :key="idx"
          class="flex-1 flex items-center gap-2"
        >
          <div
            class="w-6 h-6 rounded-full grid place-items-center text-3xs font-black flex-shrink-0"
            :class="
              (idx === 0 && selectedTeacher) ||
              (idx === 1 && (step === 'date_hour' || (classId && subjectId))) ||
              (idx === 2 && step === 'date_hour' && canSubmit)
                ? 'bg-emerald-500 text-white'
                : ((step === 'class_subject' && idx === 1) || (step === 'date_hour' && idx === 2))
                  ? 'bg-role-admin text-white'
                  : 'bg-slate-200 text-slate-500'
            "
          >
            <span>{{ idx + 1 }}</span>
          </div>
          <span
            class="text-3xs font-bold uppercase tracking-widest"
            :class="
              (idx === 0 && selectedTeacher) ||
              (idx === 1 && step !== 'teacher') ||
              (idx === 2 && step === 'date_hour')
                ? 'text-role-admin'
                : 'text-slate-400'
            "
          >
            {{ label }}
          </span>
          <div
            v-if="idx < 2"
            class="flex-1 h-0.5"
            :class="
              (idx === 0 && step !== 'teacher') ||
              (idx === 1 && step === 'date_hour')
                ? 'bg-emerald-500'
                : 'bg-slate-200'
            "
          ></div>
        </div>
      </div>

      <!-- Step 2: Class + Subject -->
      <section v-if="step === 'class_subject'" class="space-y-3">
        <div v-if="isLoading" class="text-[12px] text-slate-500 text-center py-4">
          Memuat referensi...
        </div>
        <template v-else>
          <div>
            <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
              Kelas
            </label>
            <select
              v-model="classId"
              class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
            >
              <option value="">— pilih kelas —</option>
              <option v-for="c in classes" :key="c.id" :value="c.id">
                {{ c.name }}{{ c.grade_level ? ` · Tingkat ${c.grade_level}` : '' }}
              </option>
            </select>
          </div>
          <div>
            <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
              Mata Pelajaran
              <span v-if="selectedTeacher?.subject_ids?.length" class="text-slate-400 normal-case font-normal ml-1">
                (mapel yang diampu)
              </span>
            </label>
            <select
              v-model="subjectId"
              class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
            >
              <option value="">— pilih mapel —</option>
              <option v-for="s in subjects" :key="s.id" :value="s.id">
                {{ s.name }}{{ s.code ? ` (${s.code})` : '' }}
              </option>
            </select>
            <p v-if="subjects.length === 0 && !isLoading" class="text-3xs text-amber-700 mt-1">
              Guru ini belum punya mapel terdaftar.
            </p>
          </div>
        </template>
      </section>

      <!-- Step 3: Date + Lesson Hour -->
      <section v-else-if="step === 'date_hour'" class="space-y-3">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Tanggal
          </label>
          <input
            v-model="date"
            type="date"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          />
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Jam Pelajaran (opsional)
          </label>
          <select
            v-model="lessonHourId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">— Tanpa JP spesifik —</option>
            <option v-for="h in lessonHours" :key="h.id" :value="h.id">
              JP {{ h.hour_number }} · {{ h.start_time }}–{{ h.end_time }}
              <template v-if="h.day_name"> · {{ formatDayName(h.day_name) }}</template>
            </option>
          </select>
        </div>
      </section>

      <!-- Footer -->
      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="backStep">
          <NavIcon name="chevron-left" :size="12" />
          Kembali
        </Button>
        <Button
          v-if="step === 'class_subject'"
          variant="primary"
          block
          :disabled="!classId || !subjectId"
          @click="nextStep"
        >
          Lanjut
          <NavIcon name="chevron-right" :size="12" />
        </Button>
        <Button
          v-else
          variant="primary"
          block
          :disabled="!canSubmit"
          @click="submit"
        >
          <NavIcon name="check" :size="12" />
          Buka Sesi
        </Button>
      </div>
    </div>
  </Modal>
</template>

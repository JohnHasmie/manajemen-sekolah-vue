<!--
  ClassPromotionWizard.vue — admin class promotion wizard (4-step).

  Mirrors Flutter's `ClassPromotionWizard`. Promotes selected students
  from a source class to a target class in the next academic year via
  POST /promotion/promote.

  Steps:
    1. Source class — pick the class the students currently belong to
    2. Students — multi-select roster (auto-checked by default)
    3. Target — pick destination class + academic year
    4. Konfirmasi — summary review + submit
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { ClassroomService, ClassPromotionService } from '@/services/classrooms.service';
import { StudentService } from '@/services/students.service';
import { AcademicYearService } from '@/services/academic-year.service';
import type { Classroom, Student } from '@/types/entities';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const emit = defineEmits<{
  close: [];
  done: [{ promoted: number; failed: number }];
}>();

// ── Step state ─────────────────────────────────────────────────────
const step = ref<1 | 2 | 3 | 4>(1);

// Step 1 — source
const classrooms = ref<Classroom[]>([]);
const sourceClassId = ref<string>('');

// Step 2 — students
const roster = ref<Student[]>([]);
const selectedStudentIds = ref<Set<string>>(new Set());
const isLoadingRoster = ref(false);

// Step 3 — target
const targetClassId = ref<string>('');
const targetAyId = ref<string | number>('');
const availableYears = ref<Array<{ id: string | number; year: string; current?: boolean }>>([]);

// Step 4 — submit
const isSubmitting = ref(false);
const err = ref<string | null>(null);

// ── Loaders ────────────────────────────────────────────────────────
async function loadClasses() {
  try {
    const res = await ClassroomService.list({ per_page: 200 });
    classrooms.value = res.items;
  } catch {
    classrooms.value = [];
  }
}

async function loadRoster() {
  if (!sourceClassId.value) {
    roster.value = [];
    return;
  }
  isLoadingRoster.value = true;
  try {
    roster.value = await StudentService.byClass(sourceClassId.value);
    // Auto-select all
    selectedStudentIds.value = new Set(roster.value.map((s) => s.id));
  } catch {
    roster.value = [];
  } finally {
    isLoadingRoster.value = false;
  }
}

async function loadYears() {
  try {
    availableYears.value = await AcademicYearService.list();
  } catch {
    availableYears.value = [];
  }
}

onMounted(async () => {
  await Promise.all([loadClasses(), loadYears()]);
});

watch(sourceClassId, () => {
  void loadRoster();
});

// ── Derived ────────────────────────────────────────────────────────
const sourceClass = computed(() =>
  classrooms.value.find((c) => c.id === sourceClassId.value) ?? null,
);
const targetClass = computed(() =>
  classrooms.value.find((c) => c.id === targetClassId.value) ?? null,
);
const targetYearLabel = computed(() => {
  const y = availableYears.value.find((y) => String(y.id) === String(targetAyId.value));
  return y?.year ?? '—';
});

// Target class list excludes the source.
const targetClassOptions = computed(() =>
  classrooms.value.filter((c) => c.id !== sourceClassId.value),
);

// ── Step gating ───────────────────────────────────────────────────
const canStep2 = computed(() => Boolean(sourceClassId.value));
const canStep3 = computed(() => selectedStudentIds.value.size > 0);
const canStep4 = computed(() => Boolean(targetClassId.value && targetAyId.value));

// ── Actions ───────────────────────────────────────────────────────
function toggleStudent(id: string) {
  const set = new Set(selectedStudentIds.value);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  selectedStudentIds.value = set;
}

function toggleAll() {
  if (selectedStudentIds.value.size === roster.value.length) {
    selectedStudentIds.value = new Set();
  } else {
    selectedStudentIds.value = new Set(roster.value.map((s) => s.id));
  }
}

function next() {
  if (step.value === 1 && canStep2.value) step.value = 2;
  else if (step.value === 2 && canStep3.value) step.value = 3;
  else if (step.value === 3 && canStep4.value) step.value = 4;
}

function back() {
  if (step.value > 1) step.value = (step.value - 1) as 1 | 2 | 3 | 4;
}

async function submit() {
  if (!canStep4.value) return;
  isSubmitting.value = true;
  err.value = null;
  try {
    const res = await ClassPromotionService.promote({
      source_class_id: sourceClassId.value,
      target_class_id: targetClassId.value,
      target_academic_year_id: targetAyId.value,
      student_ids: Array.from(selectedStudentIds.value),
    });
    emit('done', { promoted: res.promoted, failed: res.failed });
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isSubmitting.value = false;
  }
}

const stepTitle = computed(() => {
  switch (step.value) {
    case 1: return 'Pilih Kelas Sumber';
    case 2: return 'Pilih Siswa';
    case 3: return 'Pilih Kelas Tujuan';
    case 4: return 'Konfirmasi Promosi';
  }
  return '';
});

const stepSubtitle = computed(() => {
  switch (step.value) {
    case 1: return 'Langkah 1 dari 4 · Kelas asal siswa';
    case 2: return 'Langkah 2 dari 4 · Centang siswa yang akan dipromosi';
    case 3: return 'Langkah 3 dari 4 · Kelas dan tahun ajaran tujuan';
    case 4: return 'Langkah 4 dari 4 · Periksa kembali sebelum simpan';
  }
  return '';
});
</script>

<template>
  <Modal :title="stepTitle" :subtitle="stepSubtitle" size="lg" @close="emit('close')">
    <div class="space-y-3">
      <!-- Step indicator -->
      <div class="flex items-center justify-between gap-2">
        <div
          v-for="(label, idx) in ['Sumber', 'Siswa', 'Tujuan', 'Konfirmasi']"
          :key="idx"
          class="flex-1 flex items-center gap-2"
        >
          <div
            class="w-6 h-6 rounded-full grid place-items-center text-3xs font-black flex-shrink-0"
            :class="
              step > idx + 1
                ? 'bg-emerald-500 text-white'
                : step === idx + 1
                  ? 'bg-role-admin text-white'
                  : 'bg-slate-200 text-slate-500'
            "
          >
            <NavIcon v-if="step > idx + 1" name="check" :size="11" />
            <span v-else>{{ idx + 1 }}</span>
          </div>
          <span
            class="text-3xs font-bold uppercase tracking-widest"
            :class="step >= idx + 1 ? 'text-role-admin' : 'text-slate-400'"
          >
            {{ label }}
          </span>
          <div
            v-if="idx < 3"
            class="flex-1 h-0.5"
            :class="step > idx + 1 ? 'bg-emerald-500' : 'bg-slate-200'"
          ></div>
        </div>
      </div>

      <!-- Step 1: source class -->
      <section v-if="step === 1" class="space-y-2">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Kelas sumber (asal siswa)
          </label>
          <select
            v-model="sourceClassId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">— pilih kelas —</option>
            <option v-for="c in classrooms" :key="c.id" :value="c.id">
              {{ c.name }}{{ c.grade_level ? ` · Tingkat ${c.grade_level}` : '' }}
            </option>
          </select>
        </div>
        <p v-if="sourceClass" class="text-2xs text-slate-500">
          {{ sourceClass.student_count }} siswa terdaftar di kelas ini.
        </p>
      </section>

      <!-- Step 2: students -->
      <section v-else-if="step === 2" class="space-y-2">
        <header class="flex items-center justify-between">
          <p class="text-2xs font-bold text-slate-700">
            {{ selectedStudentIds.size }} / {{ roster.length }} siswa dipilih
          </p>
          <button
            type="button"
            class="text-2xs font-bold text-role-admin hover:underline"
            @click="toggleAll"
          >
            {{
              selectedStudentIds.size === roster.length
                ? 'Batal pilih semua'
                : 'Pilih semua'
            }}
          </button>
        </header>
        <div
          v-if="isLoadingRoster"
          class="text-center text-[12px] text-slate-500 py-8"
        >Memuat siswa...</div>
        <div
          v-else-if="roster.length === 0"
          class="text-center text-[12px] text-slate-500 py-8"
        >Belum ada siswa di kelas ini.</div>
        <div
          v-else
          class="max-h-72 overflow-y-auto bg-slate-50 rounded-xl divide-y divide-slate-100"
        >
          <label
            v-for="s in roster"
            :key="s.id"
            class="flex items-center gap-2 px-3 py-2 cursor-pointer hover:bg-white"
          >
            <input
              type="checkbox"
              class="w-4 h-4 accent-role-admin"
              :checked="selectedStudentIds.has(s.id)"
              @change="toggleStudent(s.id)"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">{{ s.name }}</p>
              <p v-if="s.student_number" class="text-3xs text-slate-500">
                NIS {{ s.student_number }}
              </p>
            </div>
          </label>
        </div>
      </section>

      <!-- Step 3: target -->
      <section v-else-if="step === 3" class="space-y-3">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Kelas tujuan
          </label>
          <select
            v-model="targetClassId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">— pilih kelas tujuan —</option>
            <option v-for="c in targetClassOptions" :key="c.id" :value="c.id">
              {{ c.name }}{{ c.grade_level ? ` · Tingkat ${c.grade_level}` : '' }}
            </option>
          </select>
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Tahun ajaran tujuan
          </label>
          <select
            v-model="targetAyId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">— pilih tahun ajaran —</option>
            <option v-for="ay in availableYears" :key="ay.id" :value="ay.id">
              {{ ay.year }}{{ ay.current ? ' (aktif)' : '' }}
            </option>
          </select>
        </div>
      </section>

      <!-- Step 4: confirmation -->
      <section v-else class="space-y-3">
        <div class="bg-slate-50 rounded-xl p-3 space-y-2 text-[12px]">
          <div class="flex justify-between gap-2">
            <span class="text-slate-500">Dari</span>
            <span class="font-bold text-slate-900 text-right">
              {{ sourceClass?.name ?? '—' }}
            </span>
          </div>
          <div class="flex justify-between gap-2">
            <span class="text-slate-500">Ke</span>
            <span class="font-bold text-slate-900 text-right">
              {{ targetClass?.name ?? '—' }}
            </span>
          </div>
          <div class="flex justify-between gap-2">
            <span class="text-slate-500">Tahun ajaran</span>
            <span class="font-bold text-slate-900 text-right">{{ targetYearLabel }}</span>
          </div>
          <div class="flex justify-between gap-2 border-t border-slate-200 pt-2 mt-2">
            <span class="text-slate-500">Jumlah siswa</span>
            <span class="font-black text-role-admin text-right">
              {{ selectedStudentIds.size }} siswa
            </span>
          </div>
        </div>
        <p class="text-2xs text-slate-500 leading-relaxed">
          Setelah klik "Simpan promosi", siswa terpilih akan dipindahkan ke
          {{ targetClass?.name }} di tahun ajaran {{ targetYearLabel }}.
          Tindakan ini bisa dibatalkan dengan menghapus enrolment baru via menu kelas.
        </p>
        <p
          v-if="err"
          class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3"
        >
          {{ err }}
        </p>
      </section>

      <!-- Footer -->
      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button
          v-if="step > 1"
          variant="secondary"
          block
          :disabled="isSubmitting"
          @click="back"
        >
          Kembali
        </Button>
        <Button v-else variant="secondary" block @click="emit('close')">
          Batal
        </Button>
        <Button
          v-if="step < 4"
          variant="primary"
          block
          :disabled="
            (step === 1 && !canStep2) ||
            (step === 2 && !canStep3) ||
            (step === 3 && !canStep4)
          "
          @click="next"
        >
          Lanjut
        </Button>
        <Button
          v-else
          variant="primary"
          block
          :loading="isSubmitting"
          @click="submit"
        >
          Simpan Promosi
        </Button>
      </div>
    </div>
  </Modal>
</template>

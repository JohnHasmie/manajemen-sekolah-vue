<!--
  GradeRecapSourcePickerModal.vue — "Sumber Nilai" picker for one recap
  column.

  Web port of Flutter's `column_source_picker_sheet.dart` (+ the source
  step of `add_chapter_sheet.dart`). The Rekap Nilai matrix has fixed
  columns (UTS / UAS / Skill) and per-Bab columns; mobile lets the
  teacher choose *which assessment type* (jenis nilai) from the Buku
  Nilai a column's value is pulled from, instead of typing every cell by
  hand. This modal is the web equivalent.

  Flow (mirrors mobile):
    1. On open, fetch the assessment pool for this (class, subject, year)
       via `GradeService.getMatrix` — same `/grades/teacher` source the
       Buku Nilai matrix reads. Each assessment carries a per-student
       score map (cells keyed by student_id).
    2. Filter the pool to the assessment types that semantically belong
       to the target column (see `ELIGIBLE_TYPES`).
    3. Teacher picks "Input Manual" (clear the column) or one assessment
       (pull every student's score from it).
    4. Emit `apply` with `{ scoresByStudentId }` — null map means clear.
       The parent writes the values into the column and marks rows dirty.

  Canonical assessment-type keys (post-rename, see `types/grades.ts`):
    assignment | daily_test | midterm | final_exam | quiz | other.
    UTS column → midterm · UAS column → final_exam · Skill/Bab → the rest.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { GradeService } from '@/services/grades.service';
import {
  ASSESSMENT_LABELS,
  type Assessment,
  type AssessmentType,
  type GradeMatrix,
} from '@/types/grades';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';

/** Logical recap column this picker fills. */
export type RecapColumnKind = 'midterm' | 'final_exam' | 'skill' | 'bab';

const props = defineProps<{
  /** Which recap column we're sourcing values for. */
  column: RecapColumnKind;
  /** Human label shown in the header (e.g. "UTS", "Bab 2"). */
  columnLabel: string;
  classId: string;
  /** subject_schools.id — the same UUID `/grades/teacher` accepts. */
  subjectId: string;
  academicYearId: number;
  teacherId: string | null;
}>();

const emit = defineEmits<{
  close: [];
  /**
   * `scoresByStudentId === null` → Input Manual (clear the column).
   * Otherwise a student_id → score map pulled from the chosen
   * assessment (students with no cell are simply absent from the map).
   */
  apply: [payload: { scoresByStudentId: Map<string, number> | null }];
}>();

// ── Eligible assessment types per column ──
//
// Mirror `column_source_picker_sheet.dart`'s `_typeMap` / Keterampilan
// fallthrough, translated to the canonical English keys:
//   • UTS  → midterm        (mobile uts/pts)
//   • UAS  → final_exam     (mobile uas/pas)
//   • Skill/Bab → everything that isn't midterm/final_exam, since
//     Indonesian schools record practical / chapter work under many
//     labels (assignment, daily_test, quiz, other).
const ELIGIBLE_TYPES: Record<RecapColumnKind, AssessmentType[] | null> = {
  midterm: ['midterm'],
  final_exam: ['final_exam'],
  // null = "all except midterm/final_exam" (computed below).
  skill: null,
  bab: null,
};

const NON_EXAM_TYPES: AssessmentType[] = [
  'assignment',
  'daily_test',
  'quiz',
  'other',
];

// Display order for grouping — preferred types first, matching the
// mobile sheet's `_groupByType` ordering.
const TYPE_ORDER: AssessmentType[] = [
  'assignment',
  'daily_test',
  'quiz',
  'midterm',
  'final_exam',
  'other',
];

// ── State ──
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const matrix = ref<GradeMatrix | null>(null);

// `null` selection === Input Manual (the default, like mobile).
const selectedId = ref<string | null>(null);
const isManual = ref(true);

onMounted(load);

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    matrix.value = await GradeService.getMatrix({
      class_id: props.classId,
      subject_id: props.subjectId,
      academic_year_id: String(props.academicYearId),
      teacher_id: props.teacherId ?? undefined,
    });
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

// ── Eligible + grouped assessments ──
const eligible = computed<Assessment[]>(() => {
  const all = matrix.value?.assessments ?? [];
  const allowed = ELIGIBLE_TYPES[props.column] ?? NON_EXAM_TYPES;
  const allowedSet = new Set(allowed);
  return all.filter((a) => allowedSet.has(a.type));
});

const grouped = computed<{ type: AssessmentType; items: Assessment[] }[]>(
  () => {
    const byType = new Map<AssessmentType, Assessment[]>();
    for (const a of eligible.value) {
      const bucket = byType.get(a.type) ?? [];
      bucket.push(a);
      byType.set(a.type, bucket);
    }
    const orderedKeys: AssessmentType[] = [
      ...TYPE_ORDER.filter((t) => byType.has(t)),
      ...[...byType.keys()].filter((t) => !TYPE_ORDER.includes(t)),
    ];
    return orderedKeys.map((type) => ({
      type,
      // Date ascending within a type, matching the mobile sort.
      items: (byType.get(type) ?? [])
        .slice()
        .sort((x, y) => (x.date ?? '').localeCompare(y.date ?? '')),
    }));
  },
);

function pickManual() {
  isManual.value = true;
  selectedId.value = null;
}

function pickAssessment(a: Assessment) {
  isManual.value = false;
  selectedId.value = a.id;
}

function apply() {
  if (isManual.value || !selectedId.value) {
    emit('apply', { scoresByStudentId: null });
    return;
  }
  // Build the student_id → score map from the chosen assessment's cells.
  const aid = selectedId.value;
  const map = new Map<string, number>();
  for (const row of matrix.value?.rows ?? []) {
    const cell = row.cells[aid];
    if (cell && typeof cell.score === 'number') {
      map.set(row.student_id, cell.score);
    }
  }
  emit('apply', { scoresByStudentId: map });
}

function typeLabel(t: AssessmentType): string {
  return ASSESSMENT_LABELS[t] ?? String(t).toUpperCase();
}
</script>

<template>
  <Modal
    :title="`Sumber Nilai ${columnLabel}`"
    subtitle="Pilih nilai yang sudah ada di Buku Nilai untuk mengisi kolom ini."
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- LOADING -->
      <div
        v-if="isLoading"
        class="flex items-center justify-center gap-2 py-10 text-slate-500"
      >
        <Spinner size="md" />
        <span class="text-sm">Memuat nilai dari Buku Nilai…</span>
      </div>

      <!-- ERROR -->
      <div
        v-else-if="loadError"
        class="rounded-xl border border-red-200 bg-red-50 px-3 py-3 text-sm text-red-700"
      >
        Gagal memuat nilai: {{ loadError }}
        <button
          type="button"
          class="ml-2 font-bold underline"
          @click="load"
        >
          Coba lagi
        </button>
      </div>

      <template v-else>
        <!-- INPUT MANUAL -->
        <button
          type="button"
          class="w-full text-left rounded-xl border p-3 flex items-center gap-3 transition"
          :class="
            isManual
              ? 'border-brand-cobalt bg-brand-cobalt/5'
              : 'border-slate-200 bg-slate-50 hover:bg-slate-100'
          "
          @click="pickManual"
        >
          <span
            class="flex h-9 w-9 items-center justify-center rounded-lg border"
            :class="
              isManual
                ? 'border-brand-cobalt/35 bg-brand-cobalt/15 text-brand-cobalt'
                : 'border-slate-200 bg-white text-slate-600'
            "
          >
            <NavIcon name="edit-3" :size="18" />
          </span>
          <span class="flex-1 min-w-0">
            <span
              class="block text-[13px] font-bold"
              :class="isManual ? 'text-brand-cobalt' : 'text-slate-800'"
            >
              Input Manual
            </span>
            <span class="block text-[11px] text-slate-600 leading-tight">
              Kosongkan kolom; isi nilai per siswa di tabel.
            </span>
          </span>
          <NavIcon
            v-if="isManual"
            name="check-circle"
            :size="18"
            class="text-brand-cobalt"
          />
        </button>

        <!-- EMPTY POOL -->
        <div
          v-if="grouped.length === 0"
          class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-3 text-[12px] leading-relaxed text-slate-600"
        >
          Belum ada nilai yang cocok untuk kolom
          <strong>{{ columnLabel }}</strong> di Buku Nilai. Tambahkan dulu
          di halaman Nilai, atau pilih Input Manual.
        </div>

        <!-- ASSESSMENT GROUPS -->
        <div v-else class="space-y-3">
          <p
            class="text-[10px] font-bold uppercase tracking-wide text-slate-500"
          >
            Ambil dari nilai yang sudah ada
          </p>
          <div
            v-for="group in grouped"
            :key="group.type"
            class="space-y-1.5"
          >
            <p class="text-[11px] font-bold text-slate-600">
              {{ typeLabel(group.type) }}
            </p>
            <button
              v-for="a in group.items"
              :key="a.id"
              type="button"
              class="w-full text-left rounded-lg border px-3 py-2.5 flex items-center gap-2 transition"
              :class="
                !isManual && selectedId === a.id
                  ? 'border-brand-cobalt bg-brand-cobalt/5'
                  : 'border-slate-200 bg-white hover:bg-slate-50'
              "
              @click="pickAssessment(a)"
            >
              <span class="flex-1 min-w-0">
                <span
                  class="block truncate text-[13px] font-semibold"
                  :class="
                    !isManual && selectedId === a.id
                      ? 'text-brand-cobalt'
                      : 'text-slate-800'
                  "
                >
                  {{ a.name }}
                </span>
                <span
                  v-if="a.date"
                  class="block text-[11px] text-slate-500 leading-tight"
                >
                  {{ a.date }}
                </span>
              </span>
              <NavIcon
                v-if="!isManual && selectedId === a.id"
                name="check-circle"
                :size="16"
                class="shrink-0 text-brand-cobalt"
              />
            </button>
          </div>
        </div>

        <!-- ACTIONS -->
        <div class="flex justify-end gap-2 pt-1">
          <Button variant="ghost" @click="emit('close')">Batal</Button>
          <Button variant="primary" @click="apply">Terapkan</Button>
        </div>
      </template>
    </div>
  </Modal>
</template>

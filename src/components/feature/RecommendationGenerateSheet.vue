<!--
  RecommendationGenerateSheet.vue — AI generate sheet (Frame D).

  Web port of `recommendation_generate_sheet.dart`. Violet-themed
  modal that replaces the legacy single-confirmation dialog. Body:

    1. Cakupan Siswa — 3 radio tiles:
         - Hanya berisiko (at_risk, default) — backend's smart filter
         - Semua siswa (all)                 — every active enrolment
         - Pilih per siswa (per_student)     — inline FilterChipGrid
    2. Mata Pelajaran — multi-select chip grid sourced from class.
    3. Periode — read-only chip showing the active academic year
       (when known).
    4. Token estimate banner — violet pill with rough rec count.
    5. Footer: Batal + violet Generate CTA.

  Emits `generate(cfg: GenerateConfig)`. Parent then calls
  `RecommendationService.dispatchGenerate(cfg)` to fan out the API
  calls + polls each `job_id`. Sheet stays open while generating to
  show progress in-place (parent toggles `busy`).
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import type { GenerateConfig, GenerateScope } from '@/types/recommendations';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

interface SubjectOption {
  id: string;
  name: string;
}

interface StudentOption {
  id: string;
  name: string;
  /** Optional — when present, surfaced as a red dot to flag at-risk. */
  at_risk?: boolean;
}

interface Props {
  className: string;
  totalStudents: number;
  /** Backend-computed at-risk students; fallback to high-priority count. */
  atRiskCount: number;
  subjects: SubjectOption[];
  /** Roster — drives the inline "Pilih per siswa" picker. */
  students?: StudentOption[];
  /** "Semester Ganjil 2025/2026" etc. Optional read-only chip. */
  periodeLabel?: string;
  /** Quota counters surfaced as a "X dari Y kuota AI" sub-line. */
  dailyUsage?: number;
  dailyLimit?: number;
  /** Disable submit while a generate run is in flight. */
  busy?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  students: () => [],
  periodeLabel: '',
  dailyUsage: 0,
  dailyLimit: 0,
  busy: false,
});

const emit = defineEmits<{
  close: [];
  generate: [cfg: GenerateConfig];
}>();

// ── Form state ──
const scope = ref<GenerateScope>('at_risk');
const selectedSubjects = ref<Set<string>>(
  new Set(props.subjects.length > 0 ? [props.subjects[0].id] : []),
);
const selectedStudents = ref<Set<string>>(new Set());

const scopeOptions: Array<{
  key: GenerateScope;
  label: string;
  caption: string;
  icon: string;
}> = [
  {
    key: 'at_risk',
    label: 'Hanya siswa berisiko',
    caption: 'Default — AI memilih siswa dengan tren menurun',
    icon: 'bell',
  },
  {
    key: 'all',
    label: 'Semua siswa di kelas',
    caption: 'Termasuk siswa yang sudah on-track (enrichment)',
    icon: 'users',
  },
  {
    key: 'per_student',
    label: 'Pilih per siswa',
    caption: 'Manual pick — fan-out per subject × student',
    icon: 'check-circle',
  },
];

function toggleSubject(id: string) {
  const next = new Set(selectedSubjects.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  selectedSubjects.value = next;
}

function toggleStudent(id: string) {
  const next = new Set(selectedStudents.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  selectedStudents.value = next;
}

function selectAllSubjects() {
  selectedSubjects.value = new Set(props.subjects.map((s) => s.id));
}

function clearStudents() {
  selectedStudents.value = new Set();
}

function selectAllStudents() {
  selectedStudents.value = new Set(props.students.map((s) => s.id));
}

function selectAtRiskStudents() {
  selectedStudents.value = new Set(
    props.students.filter((s) => s.at_risk).map((s) => s.id),
  );
}

// ── Derived ──
const scopeStudentCount = computed(() => {
  switch (scope.value) {
    case 'all':
      return props.totalStudents;
    case 'at_risk':
      return props.atRiskCount;
    case 'per_student':
      return selectedStudents.value.size;
    default:
      return props.totalStudents;
  }
});

const estimatedRecCount = computed(
  () => scopeStudentCount.value * selectedSubjects.value.size,
);

const quotaUsedPct = computed(() => {
  if (!props.dailyLimit) return 0;
  return Math.min(
    100,
    Math.round((props.dailyUsage / props.dailyLimit) * 100),
  );
});

const quotaWillOverflow = computed(() => {
  if (!props.dailyLimit) return false;
  return props.dailyUsage + estimatedRecCount.value > props.dailyLimit;
});

const canGenerate = computed(() => {
  if (props.busy) return false;
  if (selectedSubjects.value.size === 0) return false;
  if (scope.value === 'per_student' && selectedStudents.value.size === 0) {
    return false;
  }
  return true;
});

const error = computed<string | null>(() => {
  if (selectedSubjects.value.size === 0) {
    return 'Pilih minimal satu mata pelajaran.';
  }
  if (scope.value === 'per_student' && selectedStudents.value.size === 0) {
    return 'Pilih minimal satu siswa.';
  }
  if (scope.value === 'at_risk' && props.atRiskCount === 0) {
    return 'Tidak ada siswa yang ter-flag at-risk. Pilih "Semua siswa" atau "Per siswa".';
  }
  return null;
});

function submit() {
  if (!canGenerate.value) return;
  const cfg: GenerateConfig = {
    scope: scope.value,
    subject_ids: Array.from(selectedSubjects.value),
    student_ids:
      scope.value === 'per_student'
        ? Array.from(selectedStudents.value)
        : undefined,
    trigger_source: `ai_button_${scope.value}`,
    include_on_track: scope.value === 'all' ? true : false,
  };
  emit('generate', cfg);
}
</script>

<template>
  <Modal
    title="Generate Rekomendasi AI"
    :subtitle="`Kelas ${className} · pilih cakupan + mata pelajaran`"
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- 1. CAKUPAN SISWA -->
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2">
          Cakupan Siswa
        </label>
        <div class="space-y-1.5">
          <button
            v-for="opt in scopeOptions"
            :key="opt.key"
            type="button"
            class="w-full text-left rounded-xl border p-3 transition flex items-center gap-3"
            :class="
              scope === opt.key
                ? 'bg-violet-50 border-violet-400 ring-2 ring-violet-400/20'
                : 'bg-white border-slate-200 hover:border-violet-200'
            "
            :disabled="busy"
            @click="scope = opt.key"
          >
            <span
              class="w-9 h-9 rounded-xl grid place-items-center flex-shrink-0"
              :class="
                scope === opt.key
                  ? 'bg-violet-600 text-white'
                  : 'bg-slate-100 text-slate-500'
              "
            >
              <NavIcon :name="opt.icon" :size="15" />
            </span>
            <div class="flex-1 min-w-0">
              <p
                class="text-[12.5px] font-bold leading-tight"
                :class="scope === opt.key ? 'text-violet-900' : 'text-slate-900'"
              >
                {{ opt.label }}
              </p>
              <p class="text-[10.5px] text-slate-500 mt-0.5 leading-snug">
                {{ opt.caption }}
              </p>
            </div>
            <span
              v-if="opt.key === 'at_risk'"
              class="text-[10px] font-black text-amber-700 bg-amber-100 px-2 py-1 rounded-lg tabular-nums flex-shrink-0"
            >
              {{ atRiskCount }} siswa
            </span>
            <span
              v-else-if="opt.key === 'all'"
              class="text-[10px] font-black text-brand-cobalt bg-brand-cobalt/10 px-2 py-1 rounded-lg tabular-nums flex-shrink-0"
            >
              {{ totalStudents }} siswa
            </span>
            <span
              v-else-if="opt.key === 'per_student'"
              class="text-[10px] font-black text-violet-700 bg-violet-100 px-2 py-1 rounded-lg tabular-nums flex-shrink-0"
            >
              {{ selectedStudents.size }} dipilih
            </span>
          </button>
        </div>
      </div>

      <!-- Inline student picker (per_student only) -->
      <div v-if="scope === 'per_student'">
        <div class="flex items-center gap-2 mb-1.5">
          <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            Pilih Siswa
          </label>
          <span class="flex-1"></span>
          <button
            v-if="students.some((s) => s.at_risk)"
            type="button"
            class="text-[10px] font-bold text-amber-700 hover:text-amber-900"
            :disabled="busy"
            @click="selectAtRiskStudents"
          >
            Hanya berisiko
          </button>
          <button
            type="button"
            class="text-[10px] font-bold text-violet-700 hover:text-violet-900"
            :disabled="busy"
            @click="selectAllStudents"
          >
            Pilih semua
          </button>
          <button
            v-if="selectedStudents.size > 0"
            type="button"
            class="text-[10px] font-bold text-slate-500 hover:text-slate-900"
            :disabled="busy"
            @click="clearStudents"
          >
            Bersihkan
          </button>
        </div>
        <div
          v-if="students.length === 0"
          class="bg-amber-50 border border-amber-200 rounded-lg px-3 py-2 text-[11.5px] text-amber-800"
        >
          Roster siswa belum termuat. Tutup sheet ini lalu coba lagi.
        </div>
        <div v-else class="flex flex-wrap gap-1.5 max-h-44 overflow-y-auto">
          <button
            v-for="s in students"
            :key="s.id"
            type="button"
            class="px-2.5 py-1 rounded-full text-[11px] font-bold transition border inline-flex items-center gap-1"
            :class="
              selectedStudents.has(s.id)
                ? 'bg-violet-600 text-white border-violet-600'
                : s.at_risk
                  ? 'bg-amber-50 text-amber-800 border-amber-200 hover:border-amber-400'
                  : 'bg-white text-slate-600 border-slate-200 hover:border-violet-400'
            "
            :disabled="busy"
            @click="toggleStudent(s.id)"
          >
            <NavIcon
              v-if="selectedStudents.has(s.id)"
              name="check"
              :size="9"
            />
            <span
              v-else-if="s.at_risk"
              class="w-1.5 h-1.5 rounded-full bg-amber-500"
            />
            {{ s.name }}
          </button>
        </div>
      </div>

      <!-- 2. MATA PELAJARAN -->
      <div>
        <div class="flex items-center gap-2 mb-1.5">
          <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            Mata Pelajaran
          </label>
          <span class="text-[10px] text-slate-400 tabular-nums">
            · {{ selectedSubjects.size }}/{{ subjects.length }} dipilih
          </span>
          <span class="flex-1"></span>
          <button
            type="button"
            class="text-[10px] font-bold text-violet-700 hover:text-violet-900"
            :disabled="busy || subjects.length === 0"
            @click="selectAllSubjects"
          >
            Pilih semua
          </button>
        </div>
        <div
          v-if="subjects.length === 0"
          class="bg-amber-50 border border-amber-200 rounded-lg px-3 py-2 text-[11.5px] text-amber-800"
        >
          Kelas ini belum memiliki mata pelajaran terdaftar.
        </div>
        <div v-else class="flex flex-wrap gap-1.5">
          <button
            v-for="subj in subjects"
            :key="subj.id"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border inline-flex items-center gap-1.5"
            :class="
              selectedSubjects.has(subj.id)
                ? 'bg-violet-600 text-white border-violet-600'
                : 'bg-white text-slate-600 border-slate-200 hover:border-violet-400'
            "
            :disabled="busy"
            @click="toggleSubject(subj.id)"
          >
            <NavIcon
              v-if="selectedSubjects.has(subj.id)"
              name="check"
              :size="10"
            />
            {{ subj.name }}
          </button>
        </div>
      </div>

      <!-- 3. PERIODE -->
      <div v-if="periodeLabel">
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5">
          Periode
        </label>
        <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-slate-100 text-slate-700 text-[11.5px] font-bold">
          <NavIcon name="bell" :size="11" />
          {{ periodeLabel }}
        </span>
      </div>

      <!-- 4. TOKEN ESTIMATE -->
      <div
        class="rounded-xl px-3 py-2.5 border"
        :class="
          quotaWillOverflow
            ? 'bg-red-50 border-red-200'
            : 'bg-violet-50 border-violet-200'
        "
      >
        <div class="flex items-center gap-2">
          <NavIcon
            name="sparkles"
            :size="14"
            :class="quotaWillOverflow ? 'text-red-700' : 'text-violet-700'"
          />
          <div class="flex-1 min-w-0">
            <p
              class="text-[12px] font-bold"
              :class="quotaWillOverflow ? 'text-red-900' : 'text-violet-900'"
            >
              Estimasi {{ estimatedRecCount }} rekomendasi
            </p>
            <p
              class="text-[10.5px] mt-0.5"
              :class="quotaWillOverflow ? 'text-red-700' : 'text-violet-700'"
            >
              {{ scopeStudentCount }} siswa × {{ selectedSubjects.size }} mapel
              <template v-if="dailyLimit">
                · {{ dailyUsage + estimatedRecCount }}/{{ dailyLimit }} kuota AI
              </template>
            </p>
          </div>
          <span
            v-if="dailyLimit"
            class="text-[10px] font-black tabular-nums"
            :class="quotaWillOverflow ? 'text-red-700' : 'text-violet-700'"
          >
            {{ quotaUsedPct }}%
          </span>
        </div>
        <div
          v-if="dailyLimit"
          class="h-1 bg-white/50 rounded-full overflow-hidden mt-2"
        >
          <div
            class="h-full transition-all"
            :class="quotaWillOverflow ? 'bg-red-600' : 'bg-violet-600'"
            :style="{ width: `${quotaUsedPct}%` }"
          />
        </div>
      </div>

      <!-- Error -->
      <div
        v-if="error"
        class="bg-amber-50 border border-amber-200 rounded-lg px-3 py-2 text-[11.5px] text-amber-800"
      >
        {{ error }}
      </div>

      <!-- Footer -->
      <div class="grid grid-cols-2 gap-2 pt-2 border-t border-slate-100">
        <Button
          variant="secondary"
          block
          :disabled="busy"
          @click="emit('close')"
        >
          Batal
        </Button>
        <button
          type="button"
          class="inline-flex items-center justify-center gap-1.5 px-3 py-2.5 rounded-xl text-[12px] font-bold transition"
          :class="[
            canGenerate
              ? 'bg-violet-600 text-white hover:bg-violet-700 shadow-sm'
              : 'bg-slate-100 text-slate-400 cursor-not-allowed',
            busy ? 'opacity-60 cursor-wait' : '',
          ]"
          :disabled="!canGenerate"
          @click="submit"
        >
          <NavIcon
            :name="busy ? 'loader' : 'sparkles'"
            :size="14"
            :class="busy ? 'animate-spin' : ''"
          />
          {{ busy ? 'Memproses…' : `Generate ${estimatedRecCount}` }}
        </button>
      </div>
    </div>
  </Modal>
</template>

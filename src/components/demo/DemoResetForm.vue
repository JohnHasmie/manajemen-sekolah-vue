<!--
  DemoResetForm.vue — inline mini-wizard inside the "Reset Data Demo"
  confirmation flow.

  Two tabs:
    "Konfigurasi sama"  → emits null → caller calls reset() with no
                          payload → backend reuses the original
                          demo_request.school_payload.
    "Ubah konfigurasi"  → narrow override form. Shallow-merges the
                          user's edits on top of `:base-payload` and
                          emits a COMPLETE payload — partial payloads
                          would fail ProvisionDemoSchoolAction's
                          downstream validation.

  Fields in the tweak tab (in roughly the order operators reach for):
    • School name
    • Education level (jenjang)
    • Classes pattern (small / medium / large)
    • Teachers — count + random OR manual list (one name per line)
    • Students per class — count + random OR manual list
    • Subjects — chip multi-select with custom add
    • Scenarios — checklist with descriptions

  The form does NOT mirror every wizard field; schedule templates,
  billing nominal, parent linkage mode, etc. are kept on the full
  wizard at /register-demo/wizard. The mini-form covers the data
  operators actually change at reset time: roster size, roster names,
  what to teach, which scenarios to seed.

  ── Defensive unwrap ────────────────────────────────────────────────
  After a successful provision, DemoWizardState.payload gets augmented
  with `summary` / `credentials` / `wizard_input` (the original wizard
  answers wrapped under `wizard_input`). Callers might pass either the
  wrapped or the unwrapped shape; we detect and unwrap once so the
  form's derived defaults always read from the WIZARD ANSWERS, never
  from the augmented blob.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import {
  SCENARIO_DEFINITIONS,
  type DemoScenarioKey,
  type EducationLevel,
} from '@/types/demo';

const props = defineProps<{
  basePayload: Record<string, unknown> | null;
}>();

const emit = defineEmits<{
  /** Emitted on every change; null = "use base unchanged". */
  change: [payload: Record<string, unknown> | null];
}>();

// ── Unwrap helper ───────────────────────────────────────────────────
const baseWizard = computed<Record<string, unknown> | null>(() => {
  const raw = props.basePayload;
  if (!raw || typeof raw !== 'object') return null;
  const wrapped = (raw as { wizard_input?: unknown }).wizard_input;
  if (wrapped && typeof wrapped === 'object' && !Array.isArray(wrapped)) {
    return wrapped as Record<string, unknown>;
  }
  return raw;
});

// ── Mode toggle ────────────────────────────────────────────────────
const mode = ref<'same' | 'tweak'>('same');

// ── School name + jenjang ──────────────────────────────────────────
const overrideName = ref('');
const overrideJenjang = ref<EducationLevel | ''>('');
const JENJANG_OPTIONS: { value: EducationLevel; label: string }[] = [
  { value: 'SD', label: 'SD' },
  { value: 'SMP', label: 'SMP' },
  { value: 'SMA', label: 'SMA' },
  { value: 'SMK', label: 'SMK' },
];

// ── Teachers ────────────────────────────────────────────────────────
const teachersCount = ref<number>(6);
const teachersMode = ref<'random' | 'manual'>('random');
const teachersManualText = ref<string>('');

// ── Students per class ──────────────────────────────────────────────
const studentsPerClass = ref<number>(20);
const studentsMode = ref<'random' | 'manual'>('random');
const studentsManualText = ref<string>('');

// ── Classes pattern ─────────────────────────────────────────────────
const classesPattern = ref<'small' | 'medium' | 'large'>('medium');
const CLASSES_OPTIONS: {
  value: 'small' | 'medium' | 'large';
  label: string;
  hint: string;
}[] = [
  { value: 'small', label: 'Kecil', hint: '~3 kelas' },
  { value: 'medium', label: 'Sedang', hint: '~6 kelas' },
  { value: 'large', label: 'Besar', hint: '~9 kelas' },
];

// ── Subjects ────────────────────────────────────────────────────────
const subjectsSelected = ref<string[]>([]);
const subjectsCustomInput = ref<string>('');

const SUBJECT_PRESETS = [
  'Pendidikan Agama',
  'Pendidikan Pancasila',
  'Bahasa Indonesia',
  'Matematika',
  'IPA',
  'IPS',
  'Bahasa Inggris',
  'Penjas',
  'Seni Budaya',
  'Informatika',
  'Prakarya',
] as const;

function toggleSubject(name: string) {
  const cur = subjectsSelected.value;
  if (cur.includes(name)) {
    subjectsSelected.value = cur.filter((s) => s !== name);
  } else {
    subjectsSelected.value = [...cur, name];
  }
}

function addCustomSubject() {
  const v = subjectsCustomInput.value.trim();
  if (!v) return;
  if (!subjectsSelected.value.includes(v)) {
    subjectsSelected.value = [...subjectsSelected.value, v];
  }
  subjectsCustomInput.value = '';
}

// ── Scenarios ───────────────────────────────────────────────────────
const overrideScenarios = ref<Set<DemoScenarioKey>>(new Set());
function toggleScenario(key: DemoScenarioKey) {
  const next = new Set(overrideScenarios.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  overrideScenarios.value = next;
}

// ── Hydrate from base whenever it (re-)arrives ──────────────────────
watch(
  baseWizard,
  (b) => {
    if (!b) return;
    const school = (b.school ?? {}) as Record<string, unknown>;
    overrideName.value = String(school.name ?? '');
    const j = String(school.education_level ?? school.jenjang ?? '');
    overrideJenjang.value = ['SD', 'SMP', 'SMA', 'SMK'].includes(j)
      ? (j as EducationLevel)
      : '';

    const teachers = (b.teachers ?? {}) as Record<string, unknown>;
    if (typeof teachers.count === 'number') {
      teachersCount.value = teachers.count;
    }
    const tMode = String(teachers.fill_mode ?? 'random');
    teachersMode.value = tMode === 'manual' ? 'manual' : 'random';
    const tManual = Array.isArray(teachers.manual_list)
      ? (teachers.manual_list as unknown[])
      : [];
    teachersManualText.value = tManual.map((x) => String(x)).join('\n');

    const students = (b.students ?? {}) as Record<string, unknown>;
    if (typeof students.per_class === 'number') {
      studentsPerClass.value = students.per_class;
    }
    const sMode = String(students.fill_mode ?? 'random');
    studentsMode.value = sMode === 'manual' ? 'manual' : 'random';
    const sManual = Array.isArray(students.manual_list)
      ? (students.manual_list as unknown[])
      : [];
    studentsManualText.value = sManual.map((x) => String(x)).join('\n');

    const classes = (b.classes ?? {}) as Record<string, unknown>;
    const cPattern = String(classes.pattern ?? 'medium');
    classesPattern.value = ['small', 'medium', 'large'].includes(cPattern)
      ? (cPattern as 'small' | 'medium' | 'large')
      : 'medium';

    const subjects = (b.subjects ?? {}) as Record<string, unknown>;
    const subjList = Array.isArray(subjects.names)
      ? (subjects.names as unknown[]).map((x) => String(x))
      : [];
    subjectsSelected.value =
      subjList.length > 0 ? subjList : [...SUBJECT_PRESETS];

    const scenarios = (b.scenarios ?? {}) as Record<string, unknown>;
    const enabled = Array.isArray(scenarios.enabled)
      ? (scenarios.enabled as unknown[]).map((x) => String(x))
      : [];
    overrideScenarios.value = new Set(enabled as DemoScenarioKey[]);
  },
  { immediate: true },
);

// ── Emit merged payload on every dependency change ──────────────────
watch(
  [
    mode,
    overrideName,
    overrideJenjang,
    teachersCount,
    teachersMode,
    teachersManualText,
    studentsPerClass,
    studentsMode,
    studentsManualText,
    classesPattern,
    subjectsSelected,
    overrideScenarios,
  ],
  () => {
    if (mode.value === 'same') {
      emit('change', null);
      return;
    }
    const base = baseWizard.value;
    if (!base) {
      emit('change', null);
      return;
    }
    const merged: Record<string, unknown> = JSON.parse(JSON.stringify(base));

    // School
    const school = (merged.school ?? {}) as Record<string, unknown>;
    const nm = overrideName.value.trim();
    if (nm.length > 0) school.name = nm;
    if (overrideJenjang.value) {
      school.education_level = overrideJenjang.value;
    }
    merged.school = school;

    // Teachers — count + mode + manual list
    const teachers = (merged.teachers ?? {}) as Record<string, unknown>;
    teachers.count = Math.max(1, Math.floor(teachersCount.value || 1));
    teachers.fill_mode = teachersMode.value;
    if (teachersMode.value === 'manual') {
      const names = teachersManualText.value
        .split(/\r?\n/)
        .map((x) => x.trim())
        .filter((x) => x.length > 0);
      teachers.manual_list = names;
      // Snap count to the supplied list size so the seed action doesn't
      // honour an out-of-sync `count` field.
      if (names.length > 0) teachers.count = names.length;
    } else {
      teachers.manual_list = [];
    }
    merged.teachers = teachers;

    // Students — per_class + mode + manual list
    const students = (merged.students ?? {}) as Record<string, unknown>;
    students.per_class = Math.max(1, Math.floor(studentsPerClass.value || 1));
    students.fill_mode = studentsMode.value;
    if (studentsMode.value === 'manual') {
      const names = studentsManualText.value
        .split(/\r?\n/)
        .map((x) => x.trim())
        .filter((x) => x.length > 0);
      students.manual_list = names;
    } else {
      students.manual_list = [];
    }
    merged.students = students;

    // Classes pattern
    const classes = (merged.classes ?? {}) as Record<string, unknown>;
    classes.pattern = classesPattern.value;
    merged.classes = classes;

    // Subjects
    const subjects = (merged.subjects ?? {}) as Record<string, unknown>;
    subjects.names = subjectsSelected.value.slice();
    merged.subjects = subjects;

    // Scenarios
    const scenarios = (merged.scenarios ?? {}) as Record<string, unknown>;
    scenarios.enabled = Array.from(overrideScenarios.value);
    merged.scenarios = scenarios;

    emit('change', merged);
  },
  { deep: true, immediate: true },
);

const hasBase = computed(() => baseWizard.value != null);
</script>

<template>
  <div class="space-y-3">
    <!-- Mode toggle pills -->
    <div role="tablist" class="grid grid-cols-2 gap-1.5 rounded-xl bg-slate-100 p-1">
      <button
        type="button"
        role="tab"
        :aria-selected="mode === 'same'"
        class="px-3 py-1.5 rounded-lg text-[11.5px] font-bold transition"
        :class="
          mode === 'same'
            ? 'bg-white text-slate-900 shadow-sm'
            : 'text-slate-500 hover:text-slate-700'
        "
        @click="mode = 'same'"
      >
        Konfigurasi sama
      </button>
      <button
        type="button"
        role="tab"
        :aria-selected="mode === 'tweak'"
        class="px-3 py-1.5 rounded-lg text-[11.5px] font-bold transition"
        :class="
          mode === 'tweak'
            ? 'bg-white text-slate-900 shadow-sm'
            : 'text-slate-500 hover:text-slate-700'
        "
        :disabled="!hasBase"
        :title="!hasBase ? 'Konfigurasi asli belum termuat' : ''"
        @click="hasBase && (mode = 'tweak')"
      >
        Ubah konfigurasi
      </button>
    </div>

    <!-- SAME — explainer only. -->
    <p
      v-if="mode === 'same'"
      class="text-[11.5px] text-slate-500 leading-relaxed"
    >
      Demo akan dibangun ulang persis seperti pertama kali diisi pada wizard pendaftaran. Tidak ada perubahan setup.
    </p>

    <!-- TWEAK — wider override form, scrollable. -->
    <div v-else class="space-y-3 max-h-[60vh] overflow-y-auto pr-1 -mr-1">
      <!-- School name -->
      <div>
        <label class="block text-[11px] font-bold text-slate-500 mb-1">
          Nama sekolah
        </label>
        <input
          v-model="overrideName"
          type="text"
          autocomplete="off"
          placeholder="Contoh: SMP Yahya"
          class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] focus:outline-none focus:ring-2 focus:ring-role-admin/30"
        />
      </div>

      <!-- Jenjang -->
      <div>
        <label class="block text-[11px] font-bold text-slate-500 mb-1">
          Jenjang
        </label>
        <div class="grid grid-cols-4 gap-1.5">
          <button
            v-for="j in JENJANG_OPTIONS"
            :key="j.value"
            type="button"
            class="rounded-lg border px-2 py-1.5 text-[12px] font-bold transition"
            :class="
              overrideJenjang === j.value
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-600 border-slate-200 hover:border-slate-300'
            "
            @click="overrideJenjang = j.value"
          >
            {{ j.label }}
          </button>
        </div>
      </div>

      <!-- Classes pattern -->
      <div>
        <label class="block text-[11px] font-bold text-slate-500 mb-1">
          Jumlah kelas
        </label>
        <div class="grid grid-cols-3 gap-1.5">
          <button
            v-for="c in CLASSES_OPTIONS"
            :key="c.value"
            type="button"
            class="rounded-lg border px-2 py-2 text-center transition"
            :class="
              classesPattern === c.value
                ? 'bg-role-admin/10 border-role-admin text-role-admin'
                : 'bg-white text-slate-600 border-slate-200 hover:border-slate-300'
            "
            @click="classesPattern = c.value"
          >
            <span class="block text-[12px] font-bold">{{ c.label }}</span>
            <span class="block text-[10px] text-slate-400">{{ c.hint }}</span>
          </button>
        </div>
      </div>

      <!-- Teachers -->
      <div class="rounded-xl border border-slate-100 p-3 space-y-2">
        <div class="flex items-center justify-between">
          <label class="text-[11px] font-bold text-slate-500">Guru</label>
          <div class="inline-flex rounded-lg bg-slate-100 p-0.5">
            <button
              type="button"
              class="px-2.5 py-0.5 rounded-md text-[10.5px] font-bold transition"
              :class="
                teachersMode === 'random'
                  ? 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500'
              "
              @click="teachersMode = 'random'"
            >
              Acak otomatis
            </button>
            <button
              type="button"
              class="px-2.5 py-0.5 rounded-md text-[10.5px] font-bold transition"
              :class="
                teachersMode === 'manual'
                  ? 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500'
              "
              @click="teachersMode = 'manual'"
            >
              Input manual
            </button>
          </div>
        </div>
        <div>
          <label class="block text-[10.5px] text-slate-400 mb-1">
            Jumlah guru
          </label>
          <input
            v-model.number="teachersCount"
            type="number"
            min="1"
            max="60"
            class="w-28 rounded-lg border border-slate-200 px-3 py-1.5 text-[13px] focus:outline-none focus:ring-2 focus:ring-role-admin/30"
            :disabled="teachersMode === 'manual'"
          />
          <p
            v-if="teachersMode === 'manual'"
            class="mt-1 text-[10.5px] text-slate-400"
          >
            Jumlah otomatis mengikuti baris nama di bawah.
          </p>
        </div>
        <div v-if="teachersMode === 'manual'">
          <label class="block text-[10.5px] text-slate-400 mb-1">
            Daftar nama guru (1 nama per baris)
          </label>
          <textarea
            v-model="teachersManualText"
            rows="5"
            placeholder="Contoh:&#10;Pak Ahmad&#10;Bu Sari&#10;Pak Budi"
            class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[12px] font-mono focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          ></textarea>
        </div>
      </div>

      <!-- Students -->
      <div class="rounded-xl border border-slate-100 p-3 space-y-2">
        <div class="flex items-center justify-between">
          <label class="text-[11px] font-bold text-slate-500">Siswa per kelas</label>
          <div class="inline-flex rounded-lg bg-slate-100 p-0.5">
            <button
              type="button"
              class="px-2.5 py-0.5 rounded-md text-[10.5px] font-bold transition"
              :class="
                studentsMode === 'random'
                  ? 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500'
              "
              @click="studentsMode = 'random'"
            >
              Acak otomatis
            </button>
            <button
              type="button"
              class="px-2.5 py-0.5 rounded-md text-[10.5px] font-bold transition"
              :class="
                studentsMode === 'manual'
                  ? 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500'
              "
              @click="studentsMode = 'manual'"
            >
              Input manual
            </button>
          </div>
        </div>
        <div>
          <label class="block text-[10.5px] text-slate-400 mb-1">
            Jumlah siswa per kelas
          </label>
          <input
            v-model.number="studentsPerClass"
            type="number"
            min="1"
            max="60"
            class="w-28 rounded-lg border border-slate-200 px-3 py-1.5 text-[13px] focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          />
        </div>
        <div v-if="studentsMode === 'manual'">
          <label class="block text-[10.5px] text-slate-400 mb-1">
            Daftar nama siswa (1 nama per baris) — diisi merata ke tiap kelas
          </label>
          <textarea
            v-model="studentsManualText"
            rows="6"
            placeholder="Contoh:&#10;Andi Saputra&#10;Bunga Mardiana&#10;…"
            class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[12px] font-mono focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          ></textarea>
        </div>
      </div>

      <!-- Subjects -->
      <div class="rounded-xl border border-slate-100 p-3 space-y-2">
        <label class="block text-[11px] font-bold text-slate-500">Mata pelajaran</label>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="s in SUBJECT_PRESETS"
            :key="s"
            type="button"
            class="rounded-full border px-2.5 py-0.5 text-[11px] font-semibold transition"
            :class="
              subjectsSelected.includes(s)
                ? 'bg-role-admin/10 border-role-admin text-role-admin'
                : 'bg-white text-slate-500 border-slate-200 hover:border-slate-300'
            "
            @click="toggleSubject(s)"
          >
            {{ s }}
          </button>
          <span
            v-for="s in subjectsSelected.filter(
              (x) => !(SUBJECT_PRESETS as readonly string[]).includes(x),
            )"
            :key="`custom-${s}`"
            class="inline-flex items-center gap-1 rounded-full border border-role-admin bg-role-admin/10 text-role-admin px-2.5 py-0.5 text-[11px] font-semibold"
          >
            {{ s }}
            <button
              type="button"
              class="text-role-admin/70 hover:text-role-admin"
              @click="toggleSubject(s)"
            >
              ×
            </button>
          </span>
        </div>
        <div class="flex gap-1.5">
          <input
            v-model="subjectsCustomInput"
            type="text"
            placeholder="Tambah mata pelajaran lain…"
            class="flex-1 rounded-lg border border-slate-200 px-3 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-role-admin/30"
            @keyup.enter="addCustomSubject"
          />
          <button
            type="button"
            class="rounded-lg bg-slate-100 hover:bg-slate-200 px-3 py-1.5 text-[12px] font-bold text-slate-700"
            @click="addCustomSubject"
          >
            Tambah
          </button>
        </div>
      </div>

      <!-- Scenarios -->
      <div class="rounded-xl border border-slate-100 p-3 space-y-1.5">
        <label class="block text-[11px] font-bold text-slate-500">
          Skenario yang diisi ulang
        </label>
        <div class="max-h-56 overflow-y-auto pr-1 space-y-1.5">
          <label
            v-for="s in SCENARIO_DEFINITIONS"
            :key="s.key"
            class="flex items-start gap-2.5 rounded-lg border border-slate-100 hover:border-slate-200 hover:bg-slate-50 px-2.5 py-2 cursor-pointer transition"
          >
            <input
              type="checkbox"
              class="mt-0.5 accent-role-admin"
              :checked="overrideScenarios.has(s.key)"
              @change="toggleScenario(s.key)"
            />
            <span class="flex-1 min-w-0">
              <span class="block text-[12px] font-bold text-slate-900">{{ s.label }}</span>
              <span class="block text-[10.5px] text-slate-500 leading-snug">{{ s.description }}</span>
            </span>
          </label>
        </div>
      </div>
    </div>
  </div>
</template>

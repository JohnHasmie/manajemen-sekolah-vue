<!--
  SubjectEditSheet.vue — port of `subject_form_dialog.dart`.

  Adds parity: master_subject_id autocomplete + is_active toggle so the
  admin can reactivate / deactivate subjects from the web.

  Grade field (2026-07): per-school `grade` column on subject_schools
  (nullable smallint 1..12; NULL = grade-agnostic). When the admin picks
  a master row whose `grade` is a single value (e.g. "7"), we mirror it
  into the dropdown to skip the double-entry. Range grades ("10-12") stay
  manual with a helper string so the empty dropdown doesn't look like a
  bug.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import FormSheet from '@/components/ui/FormSheet.vue';
import FormField from '@/components/ui/FormField.vue';
import Toast from '@/components/ui/Toast.vue';
import { SubjectService, type MasterSubject } from '@/services/subjects.service';
import type { Subject } from '@/types/entities';

const props = defineProps<{
  subject?: Subject | null;
  isSaving?: boolean;
}>();

const emit = defineEmits<{
  close: [];
  save: [payload: Record<string, unknown>];
}>();

const { t: $t } = useI18n();

// Widen the reactive type past inferred literal keys so we can assign
// numeric `grade` values (Vue's reactive() would otherwise pin the
// initial `null` and refuse a later number assignment).
type FormShape = {
  name: string;
  code: string;
  kkm: number;
  description: string;
  master_subject_id: string;
  master_subject_name: string;
  grade: number | null;
  is_active: boolean;
};

const form = reactive<FormShape>({
  name: props.subject?.name ?? '',
  code: props.subject?.code ?? '',
  kkm: props.subject?.kkm ?? 70,
  description: props.subject?.description ?? '',
  master_subject_id: props.subject?.master_subject_id ?? '',
  master_subject_name: props.subject?.master_subject_name ?? '',
  // Per-school grade (nullable). Existing rows may carry it in either
  // `grade` (post-migration) or `grade_level` (pre-migration string) —
  // read both, coerce to int, drop invalid values.
  grade: (() => {
    const raw = (props.subject as unknown as Record<string, unknown>)?.grade
      ?? props.subject?.grade_level
      ?? null;
    if (raw === null || raw === undefined || raw === '') return null;
    const n = Number(raw);
    return Number.isFinite(n) && n >= 1 && n <= 12 ? n : null;
  })(),
  is_active: props.subject?.is_active ?? true,
});

const isEdit = computed(() => Boolean(props.subject?.id));
const errors = reactive<Record<string, string>>({});

// Track the last picked master so the "range" hint under the grade
// dropdown can render without another lookup in `masterResults`.
const lastPickedMaster = ref<MasterSubject | null>(null);

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Master subject autocomplete ──────────────────────────────────
const masterQuery = ref(form.master_subject_name ?? '');
const masterResults = ref<MasterSubject[]>([]);
const isLoadingMasters = ref(false);
const showMasterDropdown = ref(false);
let masterTimer: ReturnType<typeof setTimeout> | null = null;

async function loadInitialMasters() {
  isLoadingMasters.value = true;
  try {
    masterResults.value = await SubjectService.listMasterSubjects();
  } finally {
    isLoadingMasters.value = false;
  }
}

onMounted(loadInitialMasters);

watch(masterQuery, (q) => {
  if (masterTimer) clearTimeout(masterTimer);
  masterTimer = setTimeout(async () => {
    isLoadingMasters.value = true;
    try {
      masterResults.value = await SubjectService.listMasterSubjects(q || undefined);
    } finally {
      isLoadingMasters.value = false;
    }
  }, 250);
});

/**
 * Parse the master `grade` cell into a single 1..12 integer, or null.
 *
 * Examples:
 *   "7"     → 7            (single grade → auto-fill)
 *   " 12 "  → 12
 *   "10-12" → null         (range → keep the dropdown untouched)
 *   ""/null → null         (grade-agnostic master; nothing to fill)
 *   "abc"   → null         (defensive; ignore junk)
 */
function parseMasterGrade(raw: string | null | undefined): number | null {
  if (raw === null || raw === undefined) return null;
  const s = String(raw).trim();
  if (s.length === 0) return null;
  if (s.includes('-') || s.includes(',') || s.includes('/')) return null;
  const n = Number(s);
  if (!Number.isFinite(n)) return null;
  if (n < 1 || n > 12) return null;
  return Math.floor(n);
}

function pickMaster(m: MasterSubject) {
  form.master_subject_id = m.id;
  form.master_subject_name = m.name;
  masterQuery.value = m.name;
  lastPickedMaster.value = m;
  // Pre-fill name/code from master if subject is new and fields empty.
  if (!isEdit.value) {
    if (!form.name) form.name = m.name;
    if (!form.code && m.code) form.code = m.code;
  }
  // Auto-fill grade from master when the master carries a single grade
  // ("7" → 7). Range ("10-12") and null are left alone so the admin
  // picks the applicable grade for THIS school.
  const parsed = parseMasterGrade(m.grade ?? m.grade_level ?? null);
  if (parsed !== null) {
    form.grade = parsed;
    toast.value = {
      message: $t('admin.subjects.form.gradeAutoFilled', { grade: parsed }),
      tone: 'success',
    };
  }
  showMasterDropdown.value = false;
}

function clearMaster() {
  form.master_subject_id = '';
  form.master_subject_name = '';
  masterQuery.value = '';
  lastPickedMaster.value = null;
}

/**
 * When a range-grade master ("10-12") is picked, show a small hint under
 * the grade dropdown so the empty state doesn't read as a broken form.
 * Returns null when no master picked, or its grade is single / agnostic.
 */
const masterRangeHint = computed<string | null>(() => {
  const m = lastPickedMaster.value;
  if (!m) return null;
  const raw = m.grade ?? m.grade_level ?? null;
  if (raw === null || raw === undefined) return null;
  const s = String(raw).trim();
  if (!s.includes('-')) return null;
  return $t('admin.subjects.form.gradeRangeHint', { range: s });
});

// Inline `setTimeout(...)` in the template (the previous
// `@blur="setTimeout(() => showMasterDropdown = false, 150)"`) does NOT
// resolve `setTimeout` to the global. Vue compiles template expressions
// against the component proxy, so the call becomes `_ctx.setTimeout(...)`
// — and the component has no such property. Result in prod (minified):
//   TypeError: c.setTimeout is not a function
// blowing up the whole edit-mapel form (Luay 2026-06-29). Hoisting the
// timer into a script-block function avoids that scoping trap and keeps
// the same UX (give the dropdown click 150ms to register before hiding).
function hideMasterDropdownAfterDelay(): void {
  window.setTimeout(() => {
    showMasterDropdown.value = false;
  }, 150);
}

function validate(): boolean {
  Object.keys(errors).forEach((k) => delete errors[k]);
  if (!form.name.trim()) errors.name = 'Nama mata pelajaran wajib diisi.';
  if (form.kkm < 0 || form.kkm > 100) errors.kkm = 'KKM harus antara 0–100.';
  return Object.keys(errors).length === 0;
}

function submit() {
  if (!validate()) return;
  const masterId = form.master_subject_id || null;
  emit('save', {
    name: form.name.trim(),
    code: form.code.trim() || null,
    kkm: form.kkm,
    description: form.description.trim() || null,
    // Send both keys — legacy call sites accept `master_subject_id`,
    // the current backend validator (CreateSubjectRequest) reads
    // `subject_id`. Belt-and-suspenders so a mid-flight schema swap
    // doesn't silently drop the link.
    master_subject_id: masterId,
    subject_id: masterId,
    // Per-school grade (nullable smallint). The backend column is being
    // added by Agent 1's parallel migration; older backends ignore the
    // unknown field silently so shipping this ahead of the schema is
    // safe.
    grade: form.grade,
    status: form.is_active ? 'active' : 'inactive',
    is_active: form.is_active,
  });
}
</script>

<template>
  <FormSheet
    :title="isEdit ? 'Ubah Mata Pelajaran' : 'Tambah Mata Pelajaran'"
    :subtitle="isEdit ? 'Perbarui data mata pelajaran.' : 'Tambah mata pelajaran baru di sekolah ini.'"
    :saving="isSaving"
    :save-label="isEdit ? 'Simpan perubahan' : 'Tambah mata pelajaran'"
    @save="submit"
    @cancel="emit('close')"
  >
      <!-- Master subject autocomplete — bespoke type-ahead, kept inline. -->
      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">
          {{ $t('admin.subjects.form.masterLabel') }}
          <span class="text-slate-400 font-normal">{{ $t('admin.subjects.form.masterOptional') }}</span>
        </label>
        <div class="relative">
          <input
            v-model="masterQuery"
            type="text"
            :placeholder="$t('admin.subjects.form.masterSearchPlaceholder')"
            class="w-full rounded-xl border border-slate-300 px-md py-sm pr-9 text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
            @focus="showMasterDropdown = true"
            @blur="hideMasterDropdownAfterDelay"
          />
          <button
            v-if="form.master_subject_id"
            type="button"
            class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-status-danger text-sm"
            :title="$t('admin.subjects.form.masterClear')"
            @click="clearMaster"
          >
            ×
          </button>
          <div
            v-if="showMasterDropdown && masterResults.length > 0"
            class="absolute left-0 right-0 top-full mt-1 z-10 bg-white border border-slate-200 rounded-xl shadow-lg max-h-48 overflow-y-auto"
          >
            <button
              v-for="m in masterResults"
              :key="m.id"
              type="button"
              class="w-full text-left px-3 py-2 text-[12px] font-bold text-slate-700 hover:bg-slate-50"
              @mousedown="pickMaster(m)"
            >
              <!--
                Show `[Grade badge] name` per option so the admin can pick
                the right variant when a master has multiple grade rows
                (e.g. "Matematika · Kelas 7" vs "· Kelas 10-12").
              -->
              <span
                v-if="m.grade ?? m.grade_level"
                class="inline-block mr-2 px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 text-3xs font-black tracking-wide"
              >{{ m.grade ?? m.grade_level }}</span>
              {{ m.name }}
              <span v-if="m.code" class="text-slate-400 font-normal ml-1">· {{ m.code }}</span>
            </button>
          </div>
          <div
            v-if="isLoadingMasters && showMasterDropdown"
            class="absolute left-0 right-0 top-full mt-1 z-10 bg-white border border-slate-200 rounded-xl shadow-lg p-2 text-2xs text-slate-500 text-center"
          >{{ $t('admin.subjects.form.masterLoading') }}</div>
        </div>
        <p class="text-3xs text-slate-500 mt-1">
          {{ $t('admin.subjects.form.masterHint') }}
        </p>
      </div>

      <!--
        Per-school grade (nullable 1..12). Sits under the master picker so
        the auto-fill flow reads top-to-bottom (pick master → grade lands
        below). NULL is a first-class value ("Semua kelas") for
        grade-agnostic mapel (Olahraga, Seni Budaya, Agama).
      -->
      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">
          {{ $t('admin.subjects.form.gradeLabel') }}
          <span class="text-slate-400 font-normal">{{ $t('admin.subjects.form.gradeOptional') }}</span>
        </label>
        <select
          v-model.number="form.grade"
          :disabled="isSaving"
          class="w-full rounded-xl border border-slate-300 bg-white px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none disabled:bg-slate-50"
        >
          <option :value="null">{{ $t('admin.subjects.form.gradeAll') }}</option>
          <option v-for="g in 12" :key="g" :value="g">
            {{ $t('admin.subjects.form.gradeItem', { grade: g }) }}
          </option>
        </select>
        <p v-if="masterRangeHint" class="text-3xs text-slate-600 mt-1 leading-relaxed">
          {{ masterRangeHint }}
        </p>
        <p v-else class="text-3xs text-slate-500 mt-1 leading-relaxed">
          {{ $t('admin.subjects.form.gradeHint') }}
        </p>
      </div>

      <FormField
        v-model="form.name"
        label="Nama mata pelajaran"
        placeholder="Contoh: Matematika"
        :disabled="isSaving"
        :error="errors.name"
      />

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <FormField
          v-model="form.code"
          placeholder="MAT"
          :disabled="isSaving"
        >
          <template #label>
            Kode <span class="text-slate-400 font-normal">(opsional)</span>
          </template>
        </FormField>
        <FormField
          v-model="form.kkm"
          type="number"
          number-model
          label="KKM (nilai ambang)"
          :min="0"
          :max="100"
          :disabled="isSaving"
          :error="errors.kkm"
        />
      </div>

      <FormField
        v-model="form.description"
        type="textarea"
        :rows="3"
        :disabled="isSaving"
      >
        <template #label>
          Deskripsi <span class="text-slate-400 font-normal">(opsional)</span>
        </template>
      </FormField>

      <label class="flex items-center justify-between gap-3 bg-slate-50 rounded-xl px-3 py-2.5 cursor-pointer">
        <div>
          <p class="text-[12px] font-bold text-slate-900">Status aktif</p>
          <p class="text-3xs text-slate-500">
            Mata pelajaran nonaktif tidak muncul di form jadwal & nilai
          </p>
        </div>
        <input
          v-model="form.is_active"
          type="checkbox"
          class="w-5 h-5 accent-role-admin"
        />
      </label>
  </FormSheet>

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>

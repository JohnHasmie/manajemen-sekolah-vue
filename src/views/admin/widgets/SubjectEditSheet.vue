<!--
  SubjectEditSheet.vue — port of `subject_form_dialog.dart`.

  Adds parity: master_subject_id autocomplete + is_active toggle so the
  admin can reactivate / deactivate subjects from the web.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import FormField from '@/components/ui/FormField.vue';
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

const form = reactive({
  name: props.subject?.name ?? '',
  code: props.subject?.code ?? '',
  kkm: props.subject?.kkm ?? 70,
  description: props.subject?.description ?? '',
  master_subject_id: props.subject?.master_subject_id ?? '',
  master_subject_name: props.subject?.master_subject_name ?? '',
  is_active: props.subject?.is_active ?? true,
});

const isEdit = computed(() => Boolean(props.subject?.id));
const errors = reactive<Record<string, string>>({});

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

function pickMaster(m: MasterSubject) {
  form.master_subject_id = m.id;
  form.master_subject_name = m.name;
  masterQuery.value = m.name;
  // Pre-fill name/code from master if subject is new and fields empty.
  if (!isEdit.value) {
    if (!form.name) form.name = m.name;
    if (!form.code && m.code) form.code = m.code;
  }
  showMasterDropdown.value = false;
}

function clearMaster() {
  form.master_subject_id = '';
  form.master_subject_name = '';
  masterQuery.value = '';
}

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
  emit('save', {
    name: form.name.trim(),
    code: form.code.trim() || null,
    kkm: form.kkm,
    description: form.description.trim() || null,
    master_subject_id: form.master_subject_id || null,
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
          Mata Pelajaran Master <span class="text-slate-400 font-normal">(opsional)</span>
        </label>
        <div class="relative">
          <input
            v-model="masterQuery"
            type="text"
            placeholder="Cari mata pelajaran master..."
            class="w-full rounded-xl border border-slate-300 px-md py-sm pr-9 text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
            @focus="showMasterDropdown = true"
            @blur="hideMasterDropdownAfterDelay"
          />
          <button
            v-if="form.master_subject_id"
            type="button"
            class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-status-danger text-sm"
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
              {{ m.name }}
              <span v-if="m.code" class="text-slate-400 font-normal ml-1">· {{ m.code }}</span>
            </button>
          </div>
          <div
            v-if="isLoadingMasters && showMasterDropdown"
            class="absolute left-0 right-0 top-full mt-1 z-10 bg-white border border-slate-200 rounded-xl shadow-lg p-2 text-2xs text-slate-500 text-center"
          >Memuat...</div>
        </div>
        <p class="text-3xs text-slate-500 mt-1">
          Menautkan ke mapel master memudahkan agregasi nilai antar kelas.
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
</template>

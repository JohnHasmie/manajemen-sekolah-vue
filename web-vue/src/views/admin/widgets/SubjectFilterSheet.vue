<!--
  SubjectFilterSheet.vue — admin subject filter sheet.

  4 facets:
    Status (active / inactive)
    Tingkat (grade_level)
    Status kelas (tertaut / belum tertaut — client-side overlay)
    Search by name (handled by the toolbar)
-->
<script setup lang="ts">
import { reactive, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';

export interface SubjectFilterValues {
  status: 'active' | 'inactive' | null;
  grade_level: string | null;
  classes_status: 'with' | 'without' | null;
}

const props = defineProps<{
  initial: SubjectFilterValues;
  gradeLevels: string[];
}>();

const emit = defineEmits<{
  close: [];
  apply: [SubjectFilterValues];
}>();

const form = reactive<SubjectFilterValues>({
  status: props.initial.status,
  grade_level: props.initial.grade_level,
  classes_status: props.initial.classes_status,
});

watch(
  () => props.initial,
  (v) => {
    form.status = v.status;
    form.grade_level = v.grade_level;
    form.classes_status = v.classes_status;
  },
);

function reset() {
  form.status = null;
  form.grade_level = null;
  form.classes_status = null;
}

function apply() {
  emit('apply', { ...form });
}
</script>

<template>
  <Modal
    title="Filter Mata Pelajaran"
    subtitle="Sempitkan daftar mapel"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <div>
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">
          Status
        </p>
        <div class="flex gap-1.5">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.status === null
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.status = null"
          >
            Semua
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.status === 'active'
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.status = 'active'"
          >
            Aktif
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.status === 'inactive'
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.status = 'inactive'"
          >
            Nonaktif
          </button>
        </div>
      </div>

      <div v-if="gradeLevels.length > 0">
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">
          Tingkat
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.grade_level === null
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.grade_level = null"
          >
            Semua
          </button>
          <button
            v-for="g in gradeLevels"
            :key="g"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.grade_level === g
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.grade_level = g"
          >
            Tingkat {{ g }}
          </button>
        </div>
      </div>

      <div>
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">
          Tertaut ke Kelas
        </p>
        <div class="flex gap-1.5">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.classes_status === null
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.classes_status = null"
          >
            Semua
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.classes_status === 'with'
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.classes_status = 'with'"
          >
            Sudah tertaut
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.classes_status === 'without'
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.classes_status = 'without'"
          >
            Belum tertaut
          </button>
        </div>
      </div>

      <div class="flex items-center justify-between gap-2 pt-1">
        <button
          type="button"
          class="text-[11px] font-bold text-slate-500 hover:text-role-admin"
          @click="reset"
        >
          Reset
        </button>
      </div>

      <BottomSheetFooter
        primary-label="Terapkan filter"
        @primary="apply"
        @secondary="emit('close')"
      />
    </div>
  </Modal>
</template>

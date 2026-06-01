<!--
  ClassroomFilterSheet.vue — admin classroom filter sheet.

  Mirrors Flutter's `ClassroomFilterSheet`. 2 facets:
    Tingkat (grade_level — distinct values pulled from list)
    Homeroom status (with / without homeroom_teacher)
-->
<script setup lang="ts">
import { reactive, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';

export interface ClassroomFilterValues {
  grade_level: string | null;
  has_homeroom: 'yes' | 'no' | null;
}

const props = defineProps<{
  initial: ClassroomFilterValues;
  gradeLevels: string[];
}>();

const emit = defineEmits<{
  close: [];
  apply: [ClassroomFilterValues];
}>();

const form = reactive<ClassroomFilterValues>({
  grade_level: props.initial.grade_level,
  has_homeroom: props.initial.has_homeroom,
});

watch(
  () => props.initial,
  (v) => {
    form.grade_level = v.grade_level;
    form.has_homeroom = v.has_homeroom;
  },
);

function reset() {
  form.grade_level = null;
  form.has_homeroom = null;
}

function apply() {
  emit('apply', { ...form });
}
</script>

<template>
  <Modal
    title="Filter Kelas"
    subtitle="Pilih tingkat atau status wali kelas"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <div>
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
            Semua tingkat
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
          Status Wali Kelas
        </p>
        <div class="flex gap-1.5">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.has_homeroom === null
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.has_homeroom = null"
          >
            Semua
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.has_homeroom === 'yes'
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.has_homeroom = 'yes'"
          >
            Sudah ada wali
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.has_homeroom === 'no'
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.has_homeroom = 'no'"
          >
            Belum ada wali
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

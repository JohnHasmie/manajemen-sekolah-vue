<!--
  StudentFilterSheet.vue — port of `student_filter_sheet.dart`.
-->
<script setup lang="ts">
import { reactive } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import type { Classroom } from '@/types/entities';

export interface StudentFilterValues {
  status: string | null;
  class_ids: string[];
  gender: string | null;
  guardian: string | null;
}

const props = defineProps<{
  classes: Classroom[];
  initial: StudentFilterValues;
}>();

const emit = defineEmits<{ close: []; apply: [v: StudentFilterValues] }>();

const form = reactive<StudentFilterValues>({
  status: props.initial.status,
  class_ids: [...props.initial.class_ids],
  gender: props.initial.gender,
  guardian: props.initial.guardian,
});

function toggleClass(id: string) {
  const idx = form.class_ids.indexOf(id);
  if (idx >= 0) form.class_ids.splice(idx, 1);
  else form.class_ids.push(id);
}

function reset() {
  form.status = null;
  form.class_ids = [];
  form.gender = null;
  form.guardian = null;
}

function apply() {
  emit('apply', { ...form });
}
</script>

<template>
  <Modal title="Filter Siswa" subtitle="Sempitkan daftar berdasarkan kriteria." @close="emit('close')">
    <div class="space-y-md">
      <!-- Status -->
      <div>
        <p class="text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2">
          Status
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-xs font-medium border"
            :class="
              form.status === null
                ? 'bg-brand text-white border-brand'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
            "
            @click="form.status = null"
          >
            Semua
          </button>
          <button
            v-for="s in ['Aktif', 'Lulus', 'Pindah', 'Non-aktif']"
            :key="s"
            type="button"
            class="px-3 py-1.5 rounded-full text-xs font-medium border"
            :class="
              form.status === s
                ? 'bg-brand text-white border-brand'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
            "
            @click="form.status = s"
          >
            {{ s }}
          </button>
        </div>
      </div>

      <!-- Kelas -->
      <div>
        <p class="text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2">
          Kelas
        </p>
        <div class="flex flex-wrap gap-2 max-h-40 overflow-y-auto">
          <button
            v-for="c in classes"
            :key="c.id"
            type="button"
            class="px-3 py-1.5 rounded-full text-xs font-medium border"
            :class="
              form.class_ids.includes(c.id)
                ? 'bg-brand text-white border-brand'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
            "
            @click="toggleClass(c.id)"
          >
            {{ c.name }}
          </button>
        </div>
      </div>

      <!-- Gender -->
      <div>
        <p class="text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2">
          Jenis kelamin
        </p>
        <div class="flex gap-2">
          <button
            type="button"
            class="flex-1 px-3 py-1.5 rounded-xl text-xs font-medium border"
            :class="
              form.gender === null
                ? 'bg-brand text-white border-brand'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
            "
            @click="form.gender = null"
          >
            Semua
          </button>
          <button
            type="button"
            class="flex-1 px-3 py-1.5 rounded-xl text-xs font-medium border"
            :class="
              form.gender === 'L'
                ? 'bg-brand text-white border-brand'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
            "
            @click="form.gender = 'L'"
          >
            Laki-laki
          </button>
          <button
            type="button"
            class="flex-1 px-3 py-1.5 rounded-xl text-xs font-medium border"
            :class="
              form.gender === 'P'
                ? 'bg-brand text-white border-brand'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
            "
            @click="form.gender = 'P'"
          >
            Perempuan
          </button>
        </div>
      </div>

      <div class="flex items-center justify-between pt-md border-t border-slate-100">
        <button
          type="button"
          class="text-sm font-medium text-slate-500 hover:text-slate-700"
          @click="reset"
        >
          Atur ulang
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

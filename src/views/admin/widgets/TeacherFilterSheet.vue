<!--
  TeacherFilterSheet.vue — admin teacher filter sheet.

  Mirrors Flutter's `TeacherFilterSheet`. 5 facets:
    Role (teacher / wali_kelas)
    Kelas Mengajar (single class)
    Gender (L / P)
    Status Kepegawaian (tetap / tidak_tetap / kontrak / honorer)
    Show All (off = hide inactive teachers)
-->
<script setup lang="ts">
import { reactive, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import type { TeacherFilterOptions } from '@/services/teachers.service';

export interface TeacherFilterValues {
  role: 'guru' | 'wali_kelas' | null;
  class_id: string | null;
  gender: 'L' | 'P' | null;
  employment_status: string | null;
  show_all: boolean;
}

const props = defineProps<{
  initial: TeacherFilterValues;
  options: TeacherFilterOptions;
}>();

const emit = defineEmits<{
  close: [];
  apply: [TeacherFilterValues];
}>();

const form = reactive<TeacherFilterValues>({
  role: props.initial.role,
  class_id: props.initial.class_id,
  gender: props.initial.gender,
  employment_status: props.initial.employment_status,
  show_all: props.initial.show_all,
});

watch(
  () => props.initial,
  (v) => {
    form.role = v.role;
    form.class_id = v.class_id;
    form.gender = v.gender;
    form.employment_status = v.employment_status;
    form.show_all = v.show_all;
  },
);

function reset() {
  form.role = null;
  form.class_id = null;
  form.gender = null;
  form.employment_status = null;
  form.show_all = false;
}

function apply() {
  emit('apply', { ...form });
}
</script>

<template>
  <Modal
    title="Filter Guru"
    subtitle="Sempitkan daftar guru sesuai kebutuhan"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- Role -->
      <div>
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">
          Role
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.role === null
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.role = null"
          >
            Semua
          </button>
          <button
            v-for="r in options.roles"
            :key="r.key"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.role === r.key
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.role = r.key as 'guru' | 'wali_kelas'"
          >
            {{ r.label }}
          </button>
        </div>
      </div>

      <!-- Class -->
      <div v-if="options.classes.length > 0">
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">
          Kelas Mengajar
        </p>
        <select
          v-model="form.class_id"
          class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option :value="null">Semua kelas</option>
          <option v-for="c in options.classes" :key="c.id" :value="c.id">
            {{ c.name }}
          </option>
        </select>
      </div>

      <!-- Gender -->
      <div>
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">
          Jenis Kelamin
        </p>
        <div class="flex gap-1.5">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.gender === null
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.gender = null"
          >
            Semua
          </button>
          <button
            v-for="g in options.genders"
            :key="g.key"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.gender === g.key
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.gender = g.key as 'L' | 'P'"
          >
            {{ g.label }}
          </button>
        </div>
      </div>

      <!-- Employment -->
      <div>
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">
          Status Kepegawaian
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.employment_status === null
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.employment_status = null"
          >
            Semua
          </button>
          <button
            v-for="es in options.employment_statuses"
            :key="es.key"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-colors"
            :class="
              form.employment_status === es.key
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="form.employment_status = es.key"
          >
            {{ es.label }}
          </button>
        </div>
      </div>

      <!-- Show all toggle -->
      <label class="flex items-center justify-between gap-3 bg-slate-50 rounded-xl px-3 py-2.5 cursor-pointer">
        <div>
          <p class="text-[12px] font-bold text-slate-900">Tampilkan semua guru</p>
          <p class="text-[10px] text-slate-500">
            Termasuk guru tidak aktif & arsip
          </p>
        </div>
        <input
          v-model="form.show_all"
          type="checkbox"
          class="w-5 h-5 accent-role-admin"
        />
      </label>

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

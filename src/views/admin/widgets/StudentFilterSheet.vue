<!--
  StudentFilterSheet.vue — port of `student_filter_sheet.dart`.
-->
<script setup lang="ts">
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import type { Classroom } from '@/types/entities';

const { t } = useI18n();

const STATUS_OPTIONS = computed(() => [
  { val: 'Aktif', label: t('admin.studentFilter.statusActive') },
  { val: 'Lulus', label: t('admin.studentFilter.statusGraduated') },
  { val: 'Pindah', label: t('admin.studentFilter.statusTransferred') },
  { val: 'Non-aktif', label: t('admin.studentFilter.statusInactive') },
]);

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
  <Modal :title="t('admin.studentFilter.title')" :subtitle="t('admin.studentFilter.subtitle')" @close="emit('close')">
    <div class="space-y-md">
      <!-- Status -->
      <div>
        <p class="text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2">
          {{ t('admin.studentFilter.statusLabel') }}
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
            {{ t('admin.studentFilter.all') }}
          </button>
          <button
            v-for="opt in STATUS_OPTIONS"
            :key="opt.val"
            type="button"
            class="px-3 py-1.5 rounded-full text-xs font-medium border"
            :class="
              form.status === opt.val
                ? 'bg-brand text-white border-brand'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
            "
            @click="form.status = opt.val"
          >
            {{ opt.label }}
          </button>
        </div>
      </div>

      <!-- Kelas -->
      <div>
        <p class="text-xs uppercase tracking-wider text-slate-400 font-semibold mb-2">
          {{ t('admin.studentFilter.classLabel') }}
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
          {{ t('admin.studentFilter.genderLabel') }}
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
            {{ t('admin.studentFilter.all') }}
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
            {{ t('admin.studentFilter.genderMale') }}
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
            {{ t('admin.studentFilter.genderFemale') }}
          </button>
        </div>
      </div>

      <div class="flex items-center justify-between pt-md border-t border-slate-100">
        <button
          type="button"
          class="text-sm font-medium text-slate-500 hover:text-slate-700"
          @click="reset"
        >
          {{ t('admin.studentFilter.reset') }}
        </button>
      </div>

      <BottomSheetFooter
        :primary-label="t('admin.studentFilter.apply')"
        @primary="apply"
        @secondary="emit('close')"
      />
    </div>
  </Modal>
</template>

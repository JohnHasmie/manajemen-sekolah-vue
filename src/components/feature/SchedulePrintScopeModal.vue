<!--
  SchedulePrintScopeModal.vue — admin Print PDF sheet.

  Picks a scope (all / per kelas / per teacher / per hari) + orientation,
  then POSTs to /teaching-schedule/print-pdf (returns a PDF blob).
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { ScheduleService } from '@/services/schedule.service';
import { useAcademicYearStore } from '@/stores/academic-year';
import type {
  PrintScope,
  ScheduleFilterOptions,
} from '@/types/schedule';
import { semesterLabel } from '@/lib/labels';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  filterOptions?: ScheduleFilterOptions | null;
}>();

const emit = defineEmits<{
  close: [];
  done: [];
}>();

const ayStore = useAcademicYearStore();

const scope = ref<PrintScope>('all');
const classId = ref<string>('');
const teacherId = ref<string>('');
const dayId = ref<string>('');
const semesterId = ref<string>('');
const orientation = ref<'landscape' | 'portrait'>('landscape');

const isDownloading = ref(false);
const err = ref<string | null>(null);

const SCOPE_OPTS: { key: PrintScope; label: string; icon: string }[] = [
  { key: 'all', label: 'Semua Jadwal', icon: 'layers' },
  { key: 'class', label: 'Per Kelas', icon: 'users' },
  { key: 'teacher', label: 'Per Guru', icon: 'user' },
  { key: 'day', label: 'Per Hari', icon: 'calendar' },
];

const canSubmit = computed(() => {
  if (isDownloading.value) return false;
  if (scope.value === 'class' && !classId.value) return false;
  if (scope.value === 'teacher' && !teacherId.value) return false;
  if (scope.value === 'day' && !dayId.value) return false;
  return true;
});

async function print() {
  isDownloading.value = true;
  err.value = null;
  try {
    await ScheduleService.downloadPdf(
      {
        scope: scope.value,
        class_id: scope.value === 'class' ? classId.value : undefined,
        teacher_id: scope.value === 'teacher' ? teacherId.value : undefined,
        day_id: scope.value === 'day' ? dayId.value : undefined,
        semester_id: semesterId.value || undefined,
        academic_year_id: ayStore.selectedYearId ?? undefined,
        orientation: orientation.value,
      },
      `jadwal-${scope.value}-${new Date().toISOString().slice(0, 10)}.pdf`,
    );
    emit('done');
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isDownloading.value = false;
  }
}
</script>

<template>
  <Modal
    title="Cetak Jadwal"
    subtitle="Pilih cakupan & orientasi, lalu unduh sebagai PDF"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Cakupan</label>
        <div class="grid grid-cols-2 gap-2 mt-1">
          <button
            v-for="o in SCOPE_OPTS"
            :key="o.key"
            type="button"
            class="rounded-xl p-3 text-left border-2 transition-all"
            :class="
              scope === o.key
                ? 'border-role-admin bg-role-admin/5'
                : 'border-slate-200 hover:border-slate-300'
            "
            @click="scope = o.key"
          >
            <div class="flex items-center gap-2">
              <NavIcon :name="o.icon" :size="16" class="text-role-admin" />
              <span class="text-[12px] font-bold text-slate-900">{{ o.label }}</span>
            </div>
          </button>
        </div>
      </div>

      <div v-if="scope === 'class'">
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Kelas</label>
        <select
          v-model="classId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">— pilih kelas —</option>
          <option v-for="c in filterOptions?.classes ?? []" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>

      <div v-if="scope === 'teacher'">
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Guru</label>
        <select
          v-model="teacherId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">— pilih guru —</option>
          <option v-for="t in filterOptions?.teachers ?? []" :key="t.id" :value="t.id">{{ t.name }}</option>
        </select>
      </div>

      <div v-if="scope === 'day'">
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Hari</label>
        <div class="mt-1 flex flex-wrap gap-1.5">
          <button
            v-for="d in filterOptions?.days ?? []"
            :key="d.id"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold border transition-colors"
            :class="
              dayId === d.id
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="dayId = d.id"
          >
            {{ d.name }}
          </button>
        </div>
      </div>

      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Semester (opsional)</label>
        <select
          v-model="semesterId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">— semua —</option>
          <option v-for="s in filterOptions?.semesters ?? []" :key="s.id" :value="s.id">{{ semesterLabel(s.name) }}</option>
        </select>
      </div>

      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">Orientasi</label>
        <div class="mt-1 inline-flex gap-2 p-1 bg-slate-100 rounded-xl">
          <button
            type="button"
            class="px-3 py-1.5 rounded-lg text-2xs font-bold transition-colors"
            :class="orientation === 'landscape' ? 'bg-role-admin text-white' : 'text-slate-500'"
            @click="orientation = 'landscape'"
          >Landscape</button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-lg text-2xs font-bold transition-colors"
            :class="orientation === 'portrait' ? 'bg-role-admin text-white' : 'text-slate-500'"
            @click="orientation = 'portrait'"
          >Portrait</button>
        </div>
      </div>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isDownloading"
          :disabled="!canSubmit"
          @click="print"
        >
          <NavIcon name="download" :size="13" />
          Unduh PDF
        </Button>
      </div>
    </div>
  </Modal>
</template>

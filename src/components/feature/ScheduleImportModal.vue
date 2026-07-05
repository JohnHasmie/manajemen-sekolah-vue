<!--
  ScheduleImportModal.vue — admin Excel import sheet.

  Downloads the template + accepts an .xlsx upload. POSTs to
  /teaching-schedule/import; backend returns `{ created, skipped }`.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { ScheduleService } from '@/services/schedule.service';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const emit = defineEmits<{
  close: [];
  done: [{ created: number; skipped: number }];
}>();

const file = ref<File | null>(null);
const isUploading = ref(false);
const isDownloadingTpl = ref(false);
const err = ref<string | null>(null);

function onFileChange(e: Event) {
  const target = e.target as HTMLInputElement;
  const picked = target.files?.[0] ?? null;
  if (!picked) {
    file.value = null;
    return;
  }
  if (!/\.(xlsx|xls|csv)$/i.test(picked.name)) {
    err.value = 'Format file harus .xlsx / .xls / .csv.';
    target.value = '';
    return;
  }
  if (picked.size > 10 * 1024 * 1024) {
    err.value = 'Ukuran file maks 10 MB.';
    target.value = '';
    return;
  }
  err.value = null;
  file.value = picked;
}

async function downloadTemplate() {
  isDownloadingTpl.value = true;
  try {
    await ScheduleService.downloadTemplate();
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isDownloadingTpl.value = false;
  }
}

async function upload() {
  if (!file.value) return;
  isUploading.value = true;
  err.value = null;
  try {
    const res = await ScheduleService.importExcel(file.value);
    emit('done', res);
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isUploading.value = false;
  }
}
</script>

<template>
  <Modal
    title="Import Jadwal dari Excel"
    subtitle="Unduh template, isi, lalu unggah kembali"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <section class="bg-slate-50 rounded-xl p-3 space-y-2">
        <p class="text-2xs text-slate-600 leading-relaxed">
          Sebelum upload, pastikan kolom <strong>teacher_id</strong>, <strong>subject_id</strong>,
          <strong>class_id</strong>, <strong>day_id</strong>, <strong>lesson_hour_id</strong> sesuai
          dengan ID yang ada di sistem.
        </p>
        <Button
          variant="secondary"
          size="sm"
          :loading="isDownloadingTpl"
          @click="downloadTemplate"
        >
          <NavIcon name="download" :size="12" />
          Unduh Template
        </Button>
      </section>

      <label
        class="block border-2 border-dashed border-slate-300 hover:border-role-admin rounded-xl p-4 cursor-pointer transition-colors"
        :class="file ? 'bg-role-admin/5 border-role-admin' : 'bg-slate-50'"
      >
        <input
          type="file"
          accept=".xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          class="sr-only"
          @change="onFileChange"
        />
        <div class="flex items-center gap-3">
          <div
            class="w-10 h-10 rounded-xl grid place-items-center"
            :class="file ? 'bg-role-admin/15 text-role-admin' : 'bg-slate-200 text-slate-500'"
          >
            <NavIcon name="upload" :size="18" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ file ? file.name : 'Pilih file Excel' }}
            </p>
            <p class="text-2xs text-slate-500 mt-0.5">
              XLSX / XLS / CSV · maks 10 MB
            </p>
          </div>
        </div>
      </label>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isUploading"
          :disabled="!file || isUploading"
          @click="upload"
        >
          Import
        </Button>
      </div>
    </div>
  </Modal>
</template>

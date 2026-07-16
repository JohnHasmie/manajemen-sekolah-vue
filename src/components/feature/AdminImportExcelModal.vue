<!--
  AdminImportExcelModal.vue — shared Excel import modal for admin
  Manajemen Data pages.

  Mirrors Flutter's `ImportExcelDialog`. Accepts a file (.xlsx/.xls/
  .csv), POSTs to `/{entity}/import`, surfaces the import summary
  with imported/failed counts.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { computed } from 'vue';
import {
  AdminDataExcelService,
  type AdminEntity,
  type ImportReviewRow,
  type ImportDetailRow,
  type ImportWarningRow,
} from '@/services/admin-data-excel.service';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  entity: AdminEntity;
  /** Title shown — defaults to "Import Data". */
  title?: string;
}>();

const emit = defineEmits<{
  close: [];
  done: [{
    imported: number;
    failed: number;
    // Teacher import also reports these; other entities omit them.
    skipped?: number;
    conflicts?: number;
    message?: string;
    review?: ImportReviewRow[];
    // Per-row detail of EVERY processed row — feeds the shared result dialog.
    details?: ImportDetailRow[];
    // Non-blocking per-row annotations (post-!453 subject import). Empty
    // for importers that don't emit warnings.
    warnings?: ImportWarningRow[];
  }];
}>();

/**
 * Per-entity guidance banner. Subject template gained two optional
 * columns after !453 (Kelas + Master) — most admins won't have read
 * the release note so we spell it out at the point-of-use rather than
 * hiding it in the .xlsx alone.
 */
const entityGuidance = computed<string | null>(() => {
  switch (props.entity) {
    case 'subject':
      return (
        'Template mapel sekarang punya 2 kolom opsional: ' +
        'Kelas (1–12) untuk membedakan mapel per tingkat, dan ' +
        'Master untuk menautkan ke master data (opsional, ' +
        'membantu sinkron rekap nilai antar sekolah).'
      );
    default:
      return null;
  }
});

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
    await AdminDataExcelService.downloadTemplate(props.entity);
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
    const res = await AdminDataExcelService.importExcel(props.entity, file.value);
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
    :title="title ?? 'Import Data dari Excel'"
    subtitle="Unduh template, isi, lalu unggah kembali"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <section class="bg-slate-50 rounded-xl p-3 space-y-2">
        <p class="text-2xs text-slate-600 leading-relaxed">
          Pastikan struktur kolom sesuai template. Kolom dengan ID akan
          divalidasi terhadap data yang ada di sistem.
        </p>
        <p
          v-if="entityGuidance"
          class="text-2xs text-amber-800 bg-amber-50 border border-amber-200 rounded-lg p-2 leading-relaxed"
        >
          {{ entityGuidance }}
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

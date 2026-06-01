<!--
  LessonPlanUploadModal.vue — file-format RPP upload (Frame G).

  Mirrors Flutter's `lesson_plan_upload_sheet.dart` (create mode only;
  edit-mode file replacement is a follow-up). Two-step flow:

    1. Pick a PDF / DOCX / PPTX (≤ 10MB) via the styled drop zone.
       The component immediately uploads it via
       `LessonPlanService.uploadFile()`, surfacing a live progress bar.
    2. Once the upload returns metadata (file_path / file_url / mime /
       size), fill in title, kelas, mapel, optional notes + semester.
       Submit POSTs `/rpp` with `format: 'file'` + the stored file
       metadata.

  On success the parent jumps to the new RPP's detail page via
  the `created` event payload.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { LessonPlanService } from '@/services/lesson-plans.service';
import type { LessonPlan } from '@/types/lesson-plans';
import type { Classroom, Subject } from '@/types/entities';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

interface Props {
  teacherId: string;
  classes: Classroom[];
  subjects: Subject[];
  initialClassId?: string;
  initialSubjectId?: string;
}

const props = withDefaults(defineProps<Props>(), {
  initialClassId: '',
  initialSubjectId: '',
});

const emit = defineEmits<{
  close: [];
  created: [plan: LessonPlan];
}>();

// ── Constants ──
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB
const ACCEPT =
  '.pdf,.doc,.docx,.ppt,.pptx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation';

// ── File pick + upload state ──
interface UploadedFile {
  name: string;
  size: number;
  mime: string;
  file_path: string;
  file_url: string;
}

const pickedName = ref<string>('');
const pickedSize = ref<number>(0);
const isUploading = ref(false);
const uploadProgress = ref<number>(0);
const uploaded = ref<UploadedFile | null>(null);
const dragOver = ref(false);

// ── Metadata form ──
const title = ref<string>('');
const classId = ref<string>(props.initialClassId);
const subjectId = ref<string>(props.initialSubjectId);
const semester = ref<string>('Ganjil');
const notes = ref<string>('');
const isSubmitting = ref(false);

const error = ref<string | null>(null);

// ── Helpers ──
function fmtSize(bytes: number): string {
  if (bytes <= 0) return '0 KB';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}

const sizeLabel = computed(() => fmtSize(pickedSize.value));

function clearFile() {
  pickedName.value = '';
  pickedSize.value = 0;
  uploadProgress.value = 0;
  uploaded.value = null;
}

async function handleFile(file: File) {
  error.value = null;
  if (file.size > MAX_BYTES) {
    error.value = `Ukuran maksimum 10 MB. File ini ${fmtSize(file.size)}.`;
    return;
  }
  pickedName.value = file.name;
  pickedSize.value = file.size;
  uploadProgress.value = 0;
  uploaded.value = null;
  isUploading.value = true;
  // Seed the title with the filename minus extension if user hasn't
  // typed anything yet — feels like a sensible default.
  if (!title.value.trim()) {
    title.value = file.name.replace(/\.[^.]+$/, '').trim();
  }
  try {
    const res = await LessonPlanService.uploadFile(file, {
      onProgress: (pct) => {
        uploadProgress.value = pct;
      },
    });
    uploaded.value = {
      name: res.file_name,
      size: res.file_size,
      mime: res.file_mime,
      file_path: res.file_path,
      file_url: res.file_url,
    };
    uploadProgress.value = 100;
  } catch (e) {
    error.value = (e as Error).message;
    clearFile();
  } finally {
    isUploading.value = false;
  }
}

function onFileInput(e: Event) {
  const f = (e.target as HTMLInputElement).files?.[0];
  if (f) handleFile(f);
}

function onDrop(e: DragEvent) {
  dragOver.value = false;
  const f = e.dataTransfer?.files?.[0];
  if (f) handleFile(f);
}

// ── Submit ──
async function submit() {
  error.value = null;
  if (!uploaded.value) {
    error.value = 'Pilih dan unggah file dulu.';
    return;
  }
  if (!title.value.trim()) {
    error.value = 'Judul RPP wajib diisi.';
    return;
  }
  if (!classId.value) {
    error.value = 'Pilih kelas terlebih dahulu.';
    return;
  }
  if (!subjectId.value) {
    error.value = 'Pilih mata pelajaran terlebih dahulu.';
    return;
  }
  isSubmitting.value = true;
  try {
    // Backend reads top-level file_* keys when format=file. Use the
    // dedicated `createFileFormat` service method (matches Flutter's
    // contract — no `format_data` indirection for file rows).
    const plan = await LessonPlanService.createFileFormat({
      teacher_id: props.teacherId,
      title: title.value.trim(),
      class_id: classId.value,
      subject_id: subjectId.value,
      file_path: uploaded.value.file_path,
      file_url: uploaded.value.file_url,
      file_name: uploaded.value.name,
      file_size: uploaded.value.size,
      file_mime: uploaded.value.mime,
      semester: semester.value || null,
      notes: notes.value.trim() || null,
    });
    emit('created', plan);
    emit('close');
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSubmitting.value = false;
  }
}

const canSubmit = computed(
  () =>
    !!uploaded.value &&
    !isUploading.value &&
    !isSubmitting.value &&
    title.value.trim().length > 0 &&
    classId.value.length > 0 &&
    subjectId.value.length > 0,
);
</script>

<template>
  <Modal
    title="Upload File RPP"
    subtitle="PDF / DOCX / PPTX maksimum 10 MB. File langsung diunggah sebelum disimpan."
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- DROP ZONE / FILE STATE -->
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5">
          File RPP
        </label>

        <!-- Empty drop zone -->
        <label
          v-if="!pickedName"
          class="block rounded-2xl border-2 border-dashed px-4 py-8 text-center cursor-pointer transition-colors"
          :class="
            dragOver
              ? 'border-brand-cobalt bg-brand-cobalt/5'
              : 'border-slate-300 hover:border-brand-cobalt/60 bg-slate-50'
          "
          @dragover.prevent="dragOver = true"
          @dragleave.prevent="dragOver = false"
          @drop.prevent="onDrop"
        >
          <input
            type="file"
            class="hidden"
            :accept="ACCEPT"
            @change="onFileInput"
          />
          <span class="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-white shadow-sm text-brand-cobalt">
            <NavIcon name="upload" :size="22" />
          </span>
          <p class="text-[13px] font-bold text-slate-900 mt-3">
            Klik atau seret file ke sini
          </p>
          <p class="text-[11px] text-slate-500 mt-1">
            PDF · DOCX · PPTX · maks 10 MB
          </p>
        </label>

        <!-- Uploading / uploaded file card -->
        <div
          v-else
          class="rounded-2xl border border-slate-200 bg-white px-3 py-3"
        >
          <div class="flex items-center gap-3">
            <span
              class="w-11 h-11 rounded-xl grid place-items-center flex-shrink-0"
              :class="
                uploaded
                  ? 'bg-emerald-100 text-emerald-700'
                  : 'bg-slate-100 text-slate-600'
              "
            >
              <NavIcon
                :name="uploaded ? 'check' : 'file-text'"
                :size="18"
              />
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[12.5px] font-bold text-slate-900 truncate">
                {{ pickedName }}
              </p>
              <p class="text-[11px] text-slate-500 mt-0.5 tabular-nums">
                {{ sizeLabel }}
                <template v-if="isUploading"> · Mengunggah {{ uploadProgress }}%</template>
                <template v-else-if="uploaded"> · Berhasil diunggah</template>
              </p>
            </div>
            <button
              type="button"
              class="text-[11px] font-bold text-slate-500 hover:text-red-600"
              :disabled="isUploading || isSubmitting"
              @click="clearFile"
            >
              Ganti
            </button>
          </div>
          <div
            v-if="isUploading"
            class="h-1 bg-slate-100 rounded-full overflow-hidden mt-2"
          >
            <div
              class="h-full bg-brand-cobalt transition-all"
              :style="{ width: `${uploadProgress}%` }"
            />
          </div>
        </div>
      </div>

      <!-- TITLE -->
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
          Judul RPP
        </label>
        <input
          v-model="title"
          type="text"
          placeholder="Contoh: RPP IPA Bab 3 — Energi"
          class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
          :disabled="isSubmitting"
        />
      </div>

      <!-- KELAS + MAPEL -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
            Kelas
          </label>
          <select
            v-model="classId"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] font-medium focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
            :disabled="isSubmitting"
          >
            <option value="">Pilih kelas…</option>
            <option v-for="c in classes" :key="c.id" :value="c.id">
              {{ c.name }}
            </option>
          </select>
        </div>
        <div>
          <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
            Mata Pelajaran
          </label>
          <select
            v-model="subjectId"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] font-medium focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
            :disabled="isSubmitting"
          >
            <option value="">Pilih mapel…</option>
            <option v-for="s in subjects" :key="s.id" :value="s.id">
              {{ s.name }}
            </option>
          </select>
        </div>
      </div>

      <!-- SEMESTER -->
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5">
          Semester
        </label>
        <div class="flex gap-1.5">
          <button
            v-for="opt in ['Ganjil', 'Genap']"
            :key="opt"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
            :class="
              semester === opt
                ? 'bg-brand-cobalt text-white border-brand-cobalt'
                : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
            "
            :disabled="isSubmitting"
            @click="semester = opt"
          >
            {{ opt }}
          </button>
        </div>
      </div>

      <!-- NOTES (optional) -->
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
          Catatan (opsional)
        </label>
        <textarea
          v-model="notes"
          rows="2"
          placeholder="Misal: file dari workshop Bulan Maret"
          class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white resize-none"
          :disabled="isSubmitting"
        />
      </div>

      <!-- ERROR -->
      <div
        v-if="error"
        class="bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-[12px] text-red-700"
      >
        {{ error }}
      </div>

      <!-- FOOTER -->
      <div class="grid grid-cols-2 gap-2 pt-2 border-t border-slate-100">
        <Button
          variant="secondary"
          block
          :disabled="isSubmitting || isUploading"
          @click="emit('close')"
        >
          Batal
        </Button>
        <Button
          variant="primary"
          block
          :loading="isSubmitting"
          :disabled="!canSubmit"
          @click="submit"
        >
          <NavIcon name="save" :size="14" />
          Simpan RPP
        </Button>
      </div>
    </div>
  </Modal>
</template>

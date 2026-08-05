<!--
  ScheduleImportModal.vue — admin Excel import sheet with transactional validation,
  conflict reporting, and automatic lesson hour creation flow.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import {
  ScheduleService,
  type MissingLessonHourRow,
  type MissingSubjectPerTeacher,
  type ImportValidationDetail,
  type ScheduleImportResults,
} from '@/services/schedule.service';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatDayName } from '@/lib/day-name';

// Re-export ScheduleImportResults so parent views can keep importing it
// from this component (backwards-compat with existing `onImportDone`
// signatures). The canonical definition now lives on the service.
export type { ScheduleImportResults } from '@/services/schedule.service';

const emit = defineEmits<{
  close: [];
  done: [ScheduleImportResults];
}>();

const file = ref<File | null>(null);
const isUploading = ref(false);
const isDownloadingTpl = ref(false);
const err = ref<string | null>(null);

// States for validation result screens
const missingHours = ref<MissingLessonHourRow[]>([]);
const missingSubjects = ref<MissingSubjectPerTeacher[]>([]);
/** Which missing (teacher, subject) rows the admin has opted to create.
 * Keyed by `${teacher_name}__${subject_name}`. Sprint 1 backend only
 * takes a single `create_missing_subjects=1` flag (see MR B contract),
 * so unchecking a row does NOT skip it on the retry — every row still
 * gets created. Kept in state anyway so the UI matches the wireframe
 * (checkbox-per-row, auto-checked) and can drop-in per-pair selection
 * the day the backend adds a `missing_subject_pairs[]` param. */
const selectedMissingSubjects = ref<Set<string>>(new Set());
const validationErrors = ref<ImportValidationDetail[]>([]);
const showReport = ref(false);

function subjectKey(row: MissingSubjectPerTeacher): string {
  return `${row.teacher_name}__${row.subject_name}`;
}

function toggleMissingSubject(row: MissingSubjectPerTeacher) {
  const key = subjectKey(row);
  const next = new Set(selectedMissingSubjects.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  selectedMissingSubjects.value = next;
}

/**
 * Sprint 1 backend creates every listed pair on retry — so the CTA
 * count reads from `missingSubjects.length`, not the checked subset,
 * to avoid lying about the outcome ("Buat 2" while 3 get created).
 * The checkboxes remain interactive for the day the backend gains a
 * per-pair skip param.
 */
const totalMissingSubjects = computed(() => missingSubjects.value.length);

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
  // Reset other states when file changes
  missingHours.value = [];
  missingSubjects.value = [];
  selectedMissingSubjects.value = new Set();
  validationErrors.value = [];
  showReport.value = false;
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

async function upload(
  opts: { createMissingHours?: boolean; createMissingSubjects?: boolean } = {},
) {
  const { createMissingHours = false, createMissingSubjects = false } = opts;
  if (!file.value) return;
  isUploading.value = true;
  err.value = null;
  // Only wipe the intermediate-screen state on a fresh upload — a retry
  // that flips a create-flag must keep the source lists intact so
  // subsequent screens (e.g. missing-subjects after resolving hours)
  // still have data to render.
  if (!createMissingHours && !createMissingSubjects) {
    missingHours.value = [];
    missingSubjects.value = [];
    selectedMissingSubjects.value = new Set();
    validationErrors.value = [];
    showReport.value = false;
  }

  try {
    const res = await ScheduleService.importExcel(file.value, {
      createMissingHours,
      createMissingSubjects,
    });
    if (res.status === 'MISSING_LESSON_HOURS') {
      missingHours.value = res.missing_hours ?? [];
      missingSubjects.value = [];
    } else if (res.status === 'MISSING_SUBJECTS_PER_TEACHER') {
      missingSubjects.value = res.missing_subjects ?? [];
      // Auto-check every row — matches the wireframe (Sprint 1). Admin
      // can uncheck rows they don't want auto-created; unchecked rows
      // will fall through to `failed` in the SUCCESS response.
      selectedMissingSubjects.value = new Set(
        missingSubjects.value.map(subjectKey),
      );
      missingHours.value = [];
    } else if (res.status === 'VALIDATION_FAILED') {
      validationErrors.value = res.results?.details ?? [];
      showReport.value = true;
      missingHours.value = [];
      missingSubjects.value = [];
    } else if (res.status === 'SUCCESS') {
      emit('done', res.results);
      emit('close');
    } else {
      // Unknown status — surface an error instead of silently
      // stopping the spinner with no feedback. Catches any future
      // backend status this client doesn't yet recognise. Cast via
      // unknown because the discriminated union has narrowed to
      // `never` by this point.
      const unknownStatus = (res as unknown as { status?: unknown }).status;
      err.value = `Respons server tidak dikenali (${String(unknownStatus ?? 'null')}). Silakan coba lagi.`;
    }
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isUploading.value = false;
  }
}

function cancelMissingHours() {
  missingHours.value = [];
}

function cancelMissingSubjects() {
  missingSubjects.value = [];
  selectedMissingSubjects.value = new Set();
}

function closeReport() {
  showReport.value = false;
  validationErrors.value = [];
}
</script>

<template>
  <Modal
    title="Import Jadwal dari Excel"
    subtitle="Unduh template, isi, lalu unggah kembali"
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- SCREEN 1: Missing Lesson Hours Dialog -->
      <div v-if="missingHours.length > 0" class="space-y-4 animate-in fade-in zoom-in duration-200">
        <div class="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex gap-3">
          <div class="w-10 h-10 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center shrink-0">
            <NavIcon name="warning" :size="20" />
          </div>
          <div>
            <h4 class="text-sm font-bold text-amber-900">Jam Pelajaran Belum Terdaftar</h4>
            <p class="text-xs text-amber-700 mt-1 leading-relaxed">
              Sistem mendeteksi ada jam pelajaran di file Excel yang belum terdaftar di pengaturan sekolah Anda.
              Apakah Anda ingin mendaftarkan jam-jam pelajaran berikut secara otomatis ke sistem?
            </p>
          </div>
        </div>

        <div class="border border-slate-100 rounded-2xl overflow-hidden max-h-60 overflow-y-auto">
          <table class="w-full text-left text-xs border-collapse">
            <thead>
              <tr class="bg-slate-50 border-b border-slate-100 text-slate-500 font-bold uppercase tracking-wider text-[10px]">
                <th class="px-4 py-2.5">Hari</th>
                <th class="px-4 py-2.5">Jam Ke</th>
                <th class="px-4 py-2.5">Waktu Mulai</th>
                <th class="px-4 py-2.5">Waktu Selesai</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 text-slate-700 font-medium">
              <tr v-for="(lh, index) in missingHours" :key="index" class="hover:bg-slate-50/50">
                <td class="px-4 py-2.5">{{ formatDayName(lh.day_name) }}</td>
                <td class="px-4 py-2.5">Jam ke-{{ lh.hour_number }}</td>
                <td class="px-4 py-2.5">{{ lh.start_time || '-' }}</td>
                <td class="px-4 py-2.5">{{ lh.end_time || '-' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block @click="cancelMissingHours">Batal</Button>
          <Button
            variant="primary"
            block
            :loading="isUploading"
            @click="upload({ createMissingHours: true })"
          >
            Daftarkan & Impor
          </Button>
        </div>
      </div>

      <!-- SCREEN 2: Missing Subjects Per Teacher Dialog -->
      <div v-else-if="missingSubjects.length > 0" class="space-y-4 animate-in fade-in zoom-in duration-200">
        <div class="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex gap-3">
          <div class="w-10 h-10 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center shrink-0">
            <NavIcon name="warning" :size="20" />
          </div>
          <div>
            <h4 class="text-sm font-bold text-amber-900">Mapel Belum Terdaftar</h4>
            <p class="text-xs text-amber-700 mt-1 leading-relaxed">
              {{ missingSubjects.length }} pasangan guru–mapel di file Excel belum terdaftar.
              Buat mapel &amp; assign ke masing-masing guru sekaligus?
              Baris yang tidak dicentang akan dilewati (masuk gagal di hasil akhir).
            </p>
          </div>
        </div>

        <div class="border border-slate-100 rounded-2xl overflow-hidden max-h-60 overflow-y-auto">
          <table class="w-full text-left text-xs border-collapse">
            <thead>
              <tr class="bg-slate-50 border-b border-slate-100 text-slate-500 font-bold uppercase tracking-wider text-[10px]">
                <th class="px-4 py-2.5 w-10"></th>
                <th class="px-4 py-2.5">Guru</th>
                <th class="px-4 py-2.5">Mapel</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 text-slate-700 font-medium">
              <tr
                v-for="row in missingSubjects"
                :key="subjectKey(row)"
                class="hover:bg-slate-50/50 cursor-pointer"
                @click="toggleMissingSubject(row)"
              >
                <td class="px-4 py-2.5">
                  <input
                    type="checkbox"
                    :checked="selectedMissingSubjects.has(subjectKey(row))"
                    class="accent-role-admin cursor-pointer"
                    @click.stop="toggleMissingSubject(row)"
                  />
                </td>
                <td class="px-4 py-2.5 font-bold text-slate-900">{{ row.teacher_name }}</td>
                <td class="px-4 py-2.5">{{ row.subject_name }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block @click="cancelMissingSubjects">Batal</Button>
          <Button
            variant="primary"
            block
            :loading="isUploading"
            :disabled="isUploading"
            @click="upload({ createMissingSubjects: true })"
          >
            Buat {{ totalMissingSubjects }} mapel &amp; lanjut
          </Button>
        </div>
      </div>

      <!-- SCREEN 3: Conflicts & Validation Errors Report -->
      <div v-else-if="showReport" class="space-y-4 animate-in fade-in zoom-in duration-200">
        <div class="bg-red-50 border border-red-200 rounded-2xl p-4 flex gap-3">
          <div class="w-10 h-10 rounded-xl bg-red-100 text-red-700 flex items-center justify-center shrink-0">
            <NavIcon name="warning" :size="20" />
          </div>
          <div>
            <h4 class="text-sm font-bold text-red-900">Gagal Mengimpor (Dibatalkan Transaksional)</h4>
            <p class="text-xs text-red-700 mt-1 leading-relaxed">
              Jadwal di dalam berkas Excel tidak dapat diimpor karena terdapat kesalahan validasi atau bentrok jadwal.
              Seluruh proses telah dibatalkan untuk mencegah data rusak. Silakan perbaiki kesalahan berikut di Excel Anda dan coba lagi.
            </p>
          </div>
        </div>

        <div class="border border-slate-100 rounded-2xl overflow-hidden max-h-80 overflow-y-auto">
          <table class="w-full text-left text-xs border-collapse">
            <thead>
              <tr class="bg-slate-50 border-b border-slate-100 text-slate-500 font-bold uppercase tracking-wider text-[10px]">
                <th class="px-4 py-2.5 w-16">Baris</th>
                <th class="px-4 py-2.5 w-36">Objek</th>
                <th class="px-4 py-2.5 w-32">Konteks</th>
                <th class="px-4 py-2.5">Alasan Kegagalan</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 text-slate-700 font-medium">
              <tr v-for="(err, index) in validationErrors" :key="index" class="hover:bg-slate-50/50">
                <td class="px-4 py-2.5 font-mono text-slate-400">#{{ err.row }}</td>
                <td class="px-4 py-2.5 font-bold text-slate-900">{{ err.label }}</td>
                <td class="px-4 py-2.5 text-slate-500">{{ err.sublabel || '-' }}</td>
                <td class="px-4 py-2.5 text-red-600 leading-normal">{{ err.reason }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="pt-2">
          <Button variant="secondary" block @click="closeReport">Kembali ke Upload</Button>
        </div>
      </div>

      <!-- SCREEN 4: Upload File Picker -->
      <div v-else class="space-y-4">
        <section class="bg-slate-50 rounded-2xl p-4 space-y-3">
          <p class="text-xs text-slate-600 leading-relaxed">
            Gunakan template Excel resmi kami agar struktur kolom sesuai dengan sistem.
            Isi nama guru, nama kelas, mata pelajaran, hari, dan jam pelajaran yang valid.
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
          class="block border-2 border-dashed border-slate-200 hover:border-role-admin rounded-2xl p-6 cursor-pointer transition-colors text-center"
          :class="file ? 'bg-role-admin/5 border-role-admin' : 'bg-slate-50/50 hover:bg-slate-50'"
        >
          <input
            type="file"
            accept=".xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            class="sr-only"
            @change="onFileChange"
          />
          <div class="flex flex-col items-center justify-center space-y-2">
            <div
              class="w-12 h-12 rounded-2xl grid place-items-center"
              :class="file ? 'bg-role-admin/15 text-role-admin' : 'bg-slate-100 text-slate-500'"
            >
              <NavIcon name="upload" :size="20" />
            </div>
            <div class="max-w-xs">
              <p class="text-[13px] font-bold text-slate-900 truncate">
                {{ file ? file.name : 'Pilih berkas Excel jadwal' }}
              </p>
              <p class="text-2xs text-slate-500 mt-1">
                Format XLSX / XLS / CSV · Maks 10 MB
              </p>
            </div>
          </div>
        </label>

        <p v-if="err" class="text-xs text-red-700 bg-red-50 border border-red-200 rounded-2xl p-4 leading-relaxed animate-shake">
          {{ err }}
        </p>

        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block @click="emit('close')">Batal</Button>
          <Button
            variant="primary"
            block
            :loading="isUploading"
            :disabled="!file || isUploading"
            @click="upload()"
          >
            Unggah & Verifikasi
          </Button>
        </div>
      </div>
    </div>
  </Modal>
</template>

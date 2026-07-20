<!--
  TutorTutoring2MaterialUploadView.vue — greenfield tutor "Unggah
  materi" form. MVP-only: the backend endpoint (BE-8) does not exist
  yet, so submit just fires a toast and routes back to the materi
  list.

  Composition mirrors the rest of the tutoring2 tutor screens:
  BrandPageHeader on top, rounded-3xl form surface, `<Button>` footer.
  The file picker is a large dashed drop-zone that opens a hidden
  `<input type="file">` on click — matches how the lesson-plan
  attachment picker reads on mobile.
-->
<script setup lang="ts">
// TODO WEB-4+ add TutoringBimbelService.{listMaterials,createMaterial,deleteMaterial}
// once BE-8 exposes /tutoring-v2/materials. MVP renders a static sample.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

type MaterialKind = 'PDF' | 'VIDEO' | 'DOC' | 'IMG';

const title = ref('');
const description = ref('');
const programId = ref(''); // free text MVP — will become a select once BE-8 exposes program picker
const kind = ref<MaterialKind>('PDF');
const uploading = ref(false);

interface SelectedFileMeta {
  name: string;
  size: number;
  type: string;
}
const selectedFile = ref<SelectedFileMeta | null>(null);
const fileInputRef = ref<HTMLInputElement | null>(null);

// TODO i18n key: kind labels PDF/Video/Dokumen/Gambar
const kindOptions: Array<{ value: MaterialKind; label: string }> = [
  { value: 'PDF', label: 'PDF' },
  { value: 'VIDEO', label: 'Video' },
  { value: 'DOC', label: 'Dokumen' },
  { value: 'IMG', label: 'Gambar' },
];

const sizeLabel = computed<string | null>(() => {
  const bytes = selectedFile.value?.size;
  if (!bytes || bytes <= 0) return null;
  const mb = bytes / (1024 * 1024);
  if (mb >= 1) return `${mb.toFixed(mb >= 10 ? 0 : 1)} MB`;
  const kb = bytes / 1024;
  return `${Math.round(kb)} KB`;
});

const canSubmit = computed(() => title.value.trim().length > 0 && !uploading.value);

function openFilePicker() {
  fileInputRef.value?.click();
}

function onFileChange(event: Event) {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) {
    selectedFile.value = null;
    return;
  }
  selectedFile.value = { name: file.name, size: file.size, type: file.type };
}

function clearFile() {
  selectedFile.value = null;
  if (fileInputRef.value) fileInputRef.value.value = '';
}

async function submit() {
  if (!canSubmit.value) return;
  uploading.value = true;
  // Simulated latency so the loading spinner reads.
  await new Promise((r) => setTimeout(r, 250));
  uploading.value = false;
  toast.success(t('tutoring2.tutor.materialUpload.savedStub'));
  router.push({ name: 'teacher.tutoring2.materials' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.materialUpload.title')"
    />

    <div class="rounded-3xl border border-slate-100 bg-white p-md shadow-sm space-y-md">
      <label class="block space-y-1.5">
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">{{ t('tutoring2.common.title') }}</span>
        <input
          v-model="title"
          type="text"
          placeholder="mis. Ringkasan Vektor.pdf"
          class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
        />
      </label>

      <label class="block space-y-1.5">
        <!-- TODO i18n key: 'Deskripsi' label + placeholder -->
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">Deskripsi</span>
        <textarea
          v-model="description"
          rows="3"
          placeholder="Ringkas isi materi agar mudah ditemukan."
          class="w-full resize-none rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
        />
      </label>

      <label class="block space-y-1.5">
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">{{ t('tutoring2.common.program') }}</span>
        <input
          v-model="programId"
          type="text"
          placeholder="ID / nama program (MVP)"
          class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
        />
      </label>

      <div class="space-y-1.5">
        <!-- TODO i18n key: 'Tipe' -->
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">Tipe</span>
        <div class="inline-flex flex-wrap gap-2">
          <button
            v-for="opt in kindOptions"
            :key="opt.value"
            type="button"
            class="rounded-xl border px-3 py-1.5 text-xs font-bold transition-colors"
            :class="kind === opt.value
              ? 'border-brand-cobalt bg-brand-cobalt/10 text-brand-cobalt'
              : 'border-slate-200 bg-white text-slate-600 hover:border-brand-cobalt/60'"
            @click="kind = opt.value"
          >{{ opt.label }}</button>
        </div>
      </div>

      <div class="space-y-1.5">
        <!-- TODO i18n key: 'Berkas' -->
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">Berkas</span>
        <button
          type="button"
          class="flex w-full flex-col items-center justify-center gap-1 rounded-2xl border-2 border-dashed border-brand-cobalt/40 bg-brand-cobalt/5 px-4 py-8 text-center transition-colors hover:bg-brand-cobalt/10"
          @click="openFilePicker"
        >
          <span class="text-sm font-bold text-brand-cobalt">{{ t('tutoring2.tutor.materialUpload.dropZone') }}</span>
          <!-- TODO i18n key: 'Klik untuk memilih dari perangkat' -->
          <span class="text-2xs text-slate-500">Klik untuk memilih dari perangkat</span>
        </button>
        <input
          ref="fileInputRef"
          type="file"
          class="hidden"
          @change="onFileChange"
        />
        <div
          v-if="selectedFile"
          class="flex items-center justify-between rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-xs"
        >
          <div class="min-w-0 flex-1 pr-2">
            <p class="truncate font-bold text-slate-900">{{ selectedFile.name }}</p>
            <p class="truncate text-2xs text-slate-500">
              <span v-if="selectedFile.type">{{ selectedFile.type }}</span>
              <span v-if="selectedFile.type && sizeLabel"> · </span>
              <span v-if="sizeLabel">{{ sizeLabel }}</span>
            </p>
          </div>
          <!-- TODO i18n key: 'Ganti' -->
          <button
            type="button"
            class="rounded-lg border border-slate-200 bg-white px-2 py-1 text-2xs font-bold text-slate-600 hover:text-slate-900"
            @click="clearFile"
          >Ganti</button>
        </div>
      </div>
    </div>

    <div class="flex items-center justify-end gap-2">
      <Button variant="secondary" @click="router.back()">{{ t('tutoring2.common.cancel') }}</Button>
      <!-- TODO i18n key: 'Unggah' primary button -->
      <Button variant="primary" :loading="uploading" @click="submit">Unggah</Button>
    </div>
  </div>
</template>

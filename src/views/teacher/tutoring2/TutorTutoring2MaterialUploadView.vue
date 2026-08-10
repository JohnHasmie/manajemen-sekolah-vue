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
import { useDataRefresh } from '@/composables/useDataRefresh';
import { MaterialsService } from '@/services/tutoring2/materials';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

type MaterialKind = 'PDF' | 'VIDEO' | 'DOC' | 'IMG';

const title = ref('');
const description = ref('');
/**
 * A learning group, chosen from the tutor's own. This was a free-text
 * field, which could never have worked: the API validates
 * `learning_group_id`/`program_id` as UUIDs, so anything typed here
 * would have been rejected — had the form ever submitted anything.
 */
const learningGroupId = ref('');

const { state: groupsState } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listGroups({ per_page: 100 });
  return items;
});
const groupOptions = computed(() =>
  groupsState.value.status === 'content' || groupsState.value.status === 'empty'
    ? ((groupsState.value.data as Array<{ id: string; name: string }> | undefined) ?? [])
    : [],
);

/**
 * An externally-hosted link, for material too large to upload or already
 * living in Drive. The API accepts either this or an uploaded file, so
 * the form does too — but exactly one is required, because `file_url` is
 * mandatory server-side.
 */
const externalUrl = ref('');
const kind = ref<MaterialKind>('PDF');
const uploading = ref(false);

interface SelectedFileMeta {
  name: string;
  size: number;
  type: string;
}
const selectedFile = ref<SelectedFileMeta | null>(null);
/** The File itself. The old form kept only metadata and dropped this. */
const pickedFile = ref<File | null>(null);
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

/**
 * Every field the API actually requires. The old rule was title-only,
 * which would have produced a guaranteed 422 — a group and a file (or a
 * link) are both mandatory server-side.
 */
const canSubmit = computed(
  () =>
    title.value.trim().length >= 3 &&
    learningGroupId.value !== '' &&
    (pickedFile.value !== null || externalUrl.value.trim() !== '') &&
    !uploading.value,
);

function openFilePicker() {
  fileInputRef.value?.click();
}

function onFileChange(event: Event) {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) {
    selectedFile.value = null;
    pickedFile.value = null;
    return;
  }
  selectedFile.value = { name: file.name, size: file.size, type: file.type };
  pickedFile.value = file;
  // Picking a file and pasting a link are alternatives, not a merge.
  externalUrl.value = '';
}

function clearFile() {
  selectedFile.value = null;
  pickedFile.value = null;
  if (fileInputRef.value) fileInputRef.value.value = '';
}

const submitError = ref('');

/**
 * Upload the file (if any), then create the material.
 *
 * Two calls because a material row needs a title, a kind and a group,
 * none of which a file picker knows. If the create fails the uploaded
 * object is orphaned — acceptable, and far better than the alternative
 * this replaces: the form used to fire a success toast and navigate
 * away WITHOUT CALLING ANYTHING, so a tutor's material was silently
 * discarded while they were told it had saved.
 */
async function submit() {
  if (!canSubmit.value) return;
  submitError.value = '';
  uploading.value = true;

  try {
    let filePayload = {
      file_url: externalUrl.value.trim(),
      file_name: null as string | null,
      file_size: null as number | null,
      file_mime: null as string | null,
    };

    if (pickedFile.value) {
      const uploaded = await MaterialsService.uploadFile(pickedFile.value);
      filePayload = { ...uploaded };
    }

    await MaterialsService.create({
      learning_group_id: learningGroupId.value,
      title: title.value.trim(),
      description: description.value.trim() || null,
      kind: kind.value,
      ...filePayload,
    });

    toast.success(t('tutoring2.tutor.materialUpload.saved'));
    router.push({ name: 'teacher.tutoring2.materials' });
  } catch (e) {
    // Stay on the form with the input intact. Navigating away on failure
    // is how the work got lost in the first place.
    submitError.value = e instanceof Error ? e.message : t('tutoring2.common.error');
  } finally {
    uploading.value = false;
  }
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
        <!-- TODO i18n key: placeholder "Ringkas isi materi agar mudah ditemukan." -->
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">{{ t('tutoring2.common.description') }}</span>
        <textarea
          v-model="description"
          rows="3"
          placeholder="Ringkas isi materi agar mudah ditemukan."
          class="w-full resize-none rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
        />
      </label>

      <!-- A real group, not free text: the API validates this as a UUID. -->
      <label class="block space-y-1.5">
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">{{ t('tutoring2.tutor.materialUpload.group') }}</span>
        <select
          v-model="learningGroupId"
          class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
        >
          <option value="">{{ t('tutoring2.tutor.materialUpload.groupPlaceholder') }}</option>
          <option v-for="g in groupOptions" :key="g.id" :value="g.id">{{ g.name }}</option>
        </select>
      </label>

      <!-- The alternative to uploading: material already hosted elsewhere. -->
      <label v-if="!selectedFile" class="block space-y-1.5">
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">{{ t('tutoring2.tutor.materialUpload.externalUrl') }}</span>
        <input
          v-model="externalUrl"
          type="url"
          placeholder="https://…"
          class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
        />
        <span class="block text-2xs text-slate-400">{{ t('tutoring2.tutor.materialUpload.externalUrlHint') }}</span>
      </label>

      <p v-if="submitError" class="rounded-xl bg-red-50 px-3 py-2 text-2xs text-red-700">
        {{ submitError }}
      </p>

      <div class="space-y-1.5">
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">{{ t('tutoring2.common.type') }}</span>
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
        <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">{{ t('tutoring2.common.file') }}</span>
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
          <button
            type="button"
            class="rounded-lg border border-slate-200 bg-white px-2 py-1 text-2xs font-bold text-slate-600 hover:text-slate-900"
            @click="clearFile"
          >{{ t('tutoring2.common.replace') }}</button>
        </div>
      </div>
    </div>

    <div class="flex items-center justify-end gap-2">
      <Button variant="secondary" @click="router.back()">{{ t('tutoring2.common.cancel') }}</Button>
      <Button variant="primary" :loading="uploading" @click="submit">{{ t('tutoring2.common.upload') }}</Button>
    </div>
  </div>
</template>

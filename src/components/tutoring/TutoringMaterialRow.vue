<!--
  TutoringMaterialRow.vue — one downloadable bimbel material.

  This one is genuinely new — no reusable school equivalent exists.
  Modeled on the lesson-plan `file_*` shape (name + size + size_mb +
  mime), which was the richest file schema in the tree. Rendering
  logic follows the shared card idiom (tinted 8×8 rounded-xl icon
  square + title + meta) so it slots into any list view.

  Delete is soft-gated by `canDelete` (only tutor role uses it); the
  parent decides. The row emits raw events — no side-effects here.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { TutoringMaterial } from '@/types/tutoring-bimbel';

const props = withDefaults(
  defineProps<{
    material: TutoringMaterial;
    /** Controls the delete button visibility. Only 'tutor' typically. */
    role?: 'tutor' | 'student' | 'parent';
    canDelete?: boolean;
  }>(),
  { role: 'student', canDelete: false },
);

const emit = defineEmits<{
  open: [TutoringMaterial];
  download: [TutoringMaterial];
  delete: [TutoringMaterial];
}>();

/**
 * Icon derived from mime → kind → filename extension, in that order of
 * confidence. Ships with the same Tabler-style names the rest of the
 * app uses; parent renders via its icon component if wanted, otherwise
 * we fall back to a short 3-letter label so the row still reads.
 */
const kindLabel = computed<string>(() => {
  const mime = props.material.file_mime?.toLowerCase() ?? '';
  const kind = props.material.kind?.toUpperCase() ?? '';
  if (kind) return kind;
  if (mime.includes('pdf')) return 'PDF';
  if (mime.startsWith('video/')) return 'VIDEO';
  if (mime.startsWith('image/')) return 'IMG';
  if (mime.includes('word') || mime.includes('officedocument.word')) return 'DOC';
  if (mime.includes('sheet') || mime.includes('excel')) return 'XLS';
  const ext = props.material.file_name?.split('.').pop()?.toUpperCase();
  return ext && ext.length <= 4 ? ext : 'FILE';
});

const sizeLabel = computed<string | null>(() => {
  const mb = props.material.file_size_mb;
  if (mb != null && mb > 0) return `${mb.toFixed(mb >= 10 ? 0 : 1)} MB`;
  const bytes = props.material.file_size;
  if (bytes != null && bytes > 0) return `${Math.round(bytes / 1024)} KB`;
  return null;
});

const canDownload = computed(() => Boolean(props.material.file_url));
</script>

<template>
  <div
    class="flex items-center gap-3 rounded-card border-0.5 border-tutoring-border-soft bg-tutoring-panel px-4 py-3"
  >
    <span
      class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#21afe6]/10 text-2xs font-bold uppercase tracking-wide text-[#21afe6]"
      aria-hidden="true"
    >{{ kindLabel }}</span>

    <button
      type="button"
      class="min-w-0 flex-1 text-left"
      @click="emit('open', material)"
    >
      <p class="truncate text-sm font-bold text-tutoring-text-hi">{{ material.title }}</p>
      <p class="truncate text-2xs text-tutoring-text-mid">
        <span v-if="material.program_label">{{ material.program_label }}</span>
        <span v-if="material.program_label && sizeLabel"> · </span>
        <span v-if="sizeLabel">{{ sizeLabel }}</span>
        <span v-if="!material.program_label && !sizeLabel">{{ kindLabel.toLowerCase() }}</span>
      </p>
    </button>

    <div class="flex shrink-0 items-center gap-1">
      <button
        v-if="canDownload"
        type="button"
        :aria-label="`Unduh ${material.title}`"
        class="rounded-lg border-0.5 border-tutoring-border-soft px-2 py-1.5 text-xs font-bold text-tutoring-text-mid hover:text-tutoring-text-hi"
        @click="emit('download', material)"
      >Unduh</button>
      <button
        v-if="canDelete && role === 'tutor'"
        type="button"
        :aria-label="`Hapus ${material.title}`"
        class="rounded-lg border-0.5 border-danger/40 px-2 py-1.5 text-xs font-bold text-danger hover:bg-danger-soft"
        @click="emit('delete', material)"
      >Hapus</button>
    </div>
  </div>
</template>

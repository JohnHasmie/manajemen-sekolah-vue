<!--
  MaterialSectionEditorModal.vue — inline editor untuk satu section
  AI-generated material (Ringkasan / Tujuan / Poin / Cara Mengajar).

  Mirrors Flutter's `material_section_editor_sheet.dart`. Two field
  shapes supported via `mode` prop:
    - 'text'  → single multi-line string (Ringkasan, Cara Mengajar)
    - 'list'  → newline-separated string list (Tujuan, Poin Utama)

  Local-only persistence: the parent updates `detailAi.parsed_content`
  on save. The Flutter version also has no backend PATCH endpoint yet
  (acknowledged in the original source as a TODO), so we keep the same
  contract — edits survive the session but reset on next AI regenerate.

  Dirty tracking guards against accidental discard: closing the modal
  with unsaved changes triggers a confirm() popup.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';

interface Props {
  open: boolean;
  /** Section label shown in modal title (e.g. "Ringkasan Materi"). */
  fieldLabel: string;
  /** Backend key the value will be saved under — purely informational
   *  in this modal; caller does the assign. */
  fieldKey: string;
  /** Seed value. Text mode = string. List mode = joined by '\n'. */
  currentValue: string;
  /** 'text' = plain textarea. 'list' = one item per line. */
  mode?: 'text' | 'list';
  /** Optional helper line shown under the label. */
  helperText?: string;
}

const props = withDefaults(defineProps<Props>(), {
  mode: 'text',
  helperText: '',
});

const emit = defineEmits<{
  close: [];
  save: [value: string];
}>();

const draft = ref('');

// Reset draft each time the modal opens with a new field.
watch(
  () => [props.open, props.currentValue, props.fieldKey] as const,
  ([next]) => {
    if (next) draft.value = props.currentValue;
  },
  { immediate: true },
);

const isDirty = computed(() => draft.value !== props.currentValue);
const isEmpty = computed(() => draft.value.trim().length === 0);

const charCount = computed(() => draft.value.length);

const discardConfirm = ref(false);

function handleClose() {
  if (isDirty.value) {
    discardConfirm.value = true;
    return;
  }
  emit('close');
}

function confirmDiscard() {
  discardConfirm.value = false;
  emit('close');
}

function handleSave() {
  if (!isDirty.value) {
    emit('close');
    return;
  }
  emit('save', draft.value);
}
</script>

<template>
  <Modal
    v-if="open"
    :title="`Edit ${fieldLabel}`"
    :subtitle="
      mode === 'list'
        ? 'Satu item per baris — kosongkan baris untuk hapus item'
        : 'Edit konten yang dihasilkan AI'
    "
    @close="handleClose"
  >
    <div class="space-y-3">
      <p
        v-if="helperText"
        class="text-[12px] text-slate-500 italic leading-relaxed"
      >
        {{ helperText }}
      </p>

      <!-- Editor textarea -->
      <textarea
        v-model="draft"
        :rows="mode === 'list' ? 8 : 6"
        :placeholder="
          mode === 'list'
            ? 'Tujuan 1\nTujuan 2\nTujuan 3'
            : 'Tulis ringkasan atau cara mengajar di sini…'
        "
        class="w-full text-[13px] rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2.5 leading-relaxed resize-y min-h-[120px] tabular-nums"
      />

      <!-- Footer with dirty indicator + actions -->
      <div class="flex items-center gap-2 pt-2 border-t border-slate-100">
        <span class="text-[11px] text-slate-400 tabular-nums">
          {{ charCount }} karakter
        </span>
        <span
          v-if="isDirty"
          class="text-[11px] font-bold text-amber-700 inline-flex items-center gap-1"
        >
          <NavIcon name="edit" :size="11" />
          Belum disimpan
        </span>
        <span class="flex-1"></span>
        <Button variant="ghost" @click="handleClose">Batal</Button>
        <Button
          variant="primary"
          :disabled="!isDirty || isEmpty"
          @click="handleSave"
        >
          Simpan
        </Button>
      </div>
    </div>
  </Modal>

  <ConfirmationDialog
    v-if="discardConfirm"
    title="Buang perubahan?"
    message="Perubahan belum disimpan. Anda yakin ingin menutup tanpa menyimpan?"
    confirm-label="Buang"
    danger
    @close="discardConfirm = false"
    @confirm="confirmDiscard"
  />
</template>

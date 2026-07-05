<!--
  FormSheet — the modal shell every CRUD edit sheet wraps around its
  fields: a titled Modal + a sticky Cancel/Save footer. It's a thin
  composition of the two primitives the edit sheets already use —
  Modal.vue (title/subtitle/backdrop/ESC) and BottomSheetFooter.vue
  (the Batal/Simpan button row) — so the boilerplate

    <Modal :title="…" :subtitle="…" @close="emit('close')">
      <form @submit.prevent="submit">
        … fields …
        <BottomSheetFooter :primary-label="…" :primary-loading="isSaving"
          @primary="submit" @secondary="emit('close')" />
      </form>
    </Modal>

  that repeated in StudentEditSheet / TeacherEditSheet /
  ClassroomEditSheet / SubjectEditSheet collapses to

    <FormSheet :title="…" :subtitle="…" :saving="isSaving"
      :save-label="…" @save="submit" @cancel="emit('close')">
      … fields …
    </FormSheet>

  Fields go in the default slot. The wrapping <form> lives here so
  Enter-to-submit still works: submitting the form emits `save`, exactly
  like clicking the primary footer button.

  Open/close: `open` defaults to `true`, so a parent that keeps its
  existing `v-if="editTarget !== undefined"` gate on the sheet needs no
  change. Parents that prefer a controlled sheet can pass `:open` and
  listen to `update:open` / `@close`. Backdrop-click, ESC, and Cancel
  all emit `cancel`, `close`, and `update:open(false)` together so
  whichever pattern the parent uses just works.
-->
<script setup lang="ts">
import Modal from './Modal.vue';
import BottomSheetFooter from './BottomSheetFooter.vue';

withDefaults(
  defineProps<{
    title: string;
    subtitle?: string;
    /** Controlled visibility. Defaults true so `v-if` gating still works. */
    open?: boolean;
    /** Puts the Save button in its loading state and disables cancel-races. */
    saving?: boolean;
    /** Primary button text, e.g. "Simpan perubahan" / "Tambah guru". */
    saveLabel?: string;
    /** Disables the Save button (independent of `saving`). */
    saveDisabled?: boolean;
    /** Secondary button text; defaults to BottomSheetFooter's "Batal". */
    cancelLabel?: string;
    /** Forwarded to Modal — widen for 2-column field grids, editors, etc. */
    size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
  }>(),
  {
    subtitle: undefined,
    open: true,
    saving: false,
    saveLabel: 'Simpan',
    saveDisabled: false,
    cancelLabel: undefined,
    size: 'md',
  },
);

const emit = defineEmits<{
  save: [];
  cancel: [];
  close: [];
  'update:open': [value: boolean];
}>();

function onCancel() {
  emit('cancel');
  emit('close');
  emit('update:open', false);
}
</script>

<template>
  <Modal
    v-if="open"
    :title="title"
    :subtitle="subtitle"
    :size="size"
    @close="onCancel"
  >
    <form class="space-y-md" @submit.prevent="emit('save')">
      <slot />

      <BottomSheetFooter
        :primary-label="saveLabel"
        :secondary-label="cancelLabel"
        :primary-loading="saving"
        :primary-disabled="saveDisabled"
        @primary="emit('save')"
        @secondary="onCancel"
      />
    </form>
  </Modal>
</template>

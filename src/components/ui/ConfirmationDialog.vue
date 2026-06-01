<!--
  ConfirmationDialog.vue — port of Flutter's ConfirmationDialog.
  Used for destructive actions (Hapus, Arsipkan).
-->
<script setup lang="ts">
import Modal from './Modal.vue';
import BottomSheetFooter from './BottomSheetFooter.vue';

withDefaults(
  defineProps<{
    title: string;
    message: string;
    confirmLabel?: string;
    cancelLabel?: string;
    danger?: boolean;
    loading?: boolean;
  }>(),
  {
    confirmLabel: 'Konfirmasi',
    cancelLabel: 'Batal',
    danger: false,
    loading: false,
  },
);

defineEmits<{ confirm: []; close: [] }>();
</script>

<template>
  <Modal :title="title" @close="$emit('close')">
    <p class="text-sm text-slate-600 leading-relaxed">{{ message }}</p>
    <BottomSheetFooter
      :primary-label="confirmLabel"
      :secondary-label="cancelLabel"
      :primary-loading="loading"
      :danger="danger"
      @primary="$emit('confirm')"
      @secondary="$emit('close')"
    />
  </Modal>
</template>

<!--
  BottomSheetFooter.vue — Cancel/Save row used inside Modal.
  Mirrors Flutter's BottomSheetFooter from `lib/core/widgets/`.

  Usage:
    <Modal title="…">
      <slot />
      <BottomSheetFooter
        primary-label="Simpan"
        :primary-loading="isSaving"
        @primary="save"
        @secondary="close"
      />
    </Modal>
-->
<script setup lang="ts">
import Button from './Button.vue';

withDefaults(
  defineProps<{
    primaryLabel: string;
    secondaryLabel?: string;
    primaryDisabled?: boolean;
    primaryLoading?: boolean;
    danger?: boolean;
  }>(),
  {
    secondaryLabel: 'Batal',
    primaryDisabled: false,
    primaryLoading: false,
    danger: false,
  },
);

defineEmits<{ primary: []; secondary: [] }>();
</script>

<template>
  <div class="grid grid-cols-2 gap-2 mt-md pt-md border-t border-slate-100">
    <Button variant="secondary" block @click="$emit('secondary')">
      {{ secondaryLabel }}
    </Button>
    <Button
      :variant="danger ? 'danger' : 'primary'"
      :disabled="primaryDisabled"
      :loading="primaryLoading"
      block
      @click="$emit('primary')"
    >
      {{ primaryLabel }}
    </Button>
  </div>
</template>

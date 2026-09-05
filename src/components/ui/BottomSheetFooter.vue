<!--
  BottomSheetFooter.vue — Cancel/Save row used inside Modal.
  Mirrors Flutter's BottomSheetFooter from `lib/core/widgets/`.

  Usage (default — an editable sheet, two buttons):
    <Modal title="…">
      <slot />
      <BottomSheetFooter
        primary-label="Simpan"
        :primary-loading="isSaving"
        @primary="save"
        @secondary="close"
      />
    </Modal>

  Usage (`hide-secondary` — a READ-ONLY sheet, one full-width button):
    <Modal :title="row.title">
      <slot />
      <BottomSheetFooter hide-secondary primary-label="Kembali" @primary="close" />
    </Modal>

  Why the flag exists: the secondary Button used to render unconditionally
  and fall back to the hardcoded label below, so a read-only preview — which
  has nothing to cancel and therefore binds no `@secondary` — still got a
  visible, enabled "Batal" whose click was swallowed as an unhandled emit.
  Callers with no cancel semantics must pass `hide-secondary` rather than
  wiring a second button that does what the primary already does.
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
    /** Read-only footers: drop the cancel button, primary spans the row. */
    hideSecondary?: boolean;
  }>(),
  {
    secondaryLabel: 'Batal',
    primaryDisabled: false,
    primaryLoading: false,
    danger: false,
    hideSecondary: false,
  },
);

defineEmits<{ primary: []; secondary: [] }>();
</script>

<template>
  <!-- Every sheet and confirm dialog in the app ends in this footer, so
       these two ids cover cancel/submit everywhere. Targeting the labels
       instead would couple ~200 assertions to locales/id.json, where a
       copy edit would turn the suite red with nothing actually broken. -->
  <!-- Both column classes are spelled out as whole literals so Tailwind's
       scanner still emits them; a computed `grid-cols-${n}` would not. -->
  <div
    class="grid gap-2 mt-md pt-md border-t border-slate-100"
    :class="hideSecondary ? 'grid-cols-1' : 'grid-cols-2'"
  >
    <Button
      v-if="!hideSecondary"
      data-testid="sheet-cancel"
      variant="secondary"
      block
      @click="$emit('secondary')"
    >
      {{ secondaryLabel }}
    </Button>
    <Button
      data-testid="sheet-submit"
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

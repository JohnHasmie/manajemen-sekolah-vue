<!--
  Modal.vue — generic dialog/sheet primitive.
  Web equivalent of Flutter's AppBottomSheet:
    • title (icon optional later)
    • subtitle
    • body via default slot
    • closes on backdrop click + ESC
    • locks body scroll while open
  Samsung-safe-area nuances from the Flutter version don't apply to the
  web. Mobile sheet behaviour can be layered on later.
-->
<script setup lang="ts">
import { onBeforeUnmount, onMounted } from 'vue';

/**
 * `size` controls the max-width class of the card.
 *   sm  → 24rem  (384px)   — short confirm dialogs
 *   md  → 28rem  (448px)   — default, classic form sheet (back-compat)
 *   lg  → 42rem  (672px)   — wide form / 2-column field grid
 *   xl  → 56rem  (896px)   — rich text editor, big tables
 *   full→ 80rem  (1280px)  — near-fullscreen surfaces
 */
const props = withDefaults(
  defineProps<{
    title?: string;
    subtitle?: string;
    size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
    /**
     * Identity for E2E selectors. Every dialog in the app is built on
     * this component, so `role="dialog"` cannot distinguish an edit form
     * from a delete confirmation — wrappers that specialise Modal
     * (FormSheet, ConfirmationDialog) override this so a test can target
     * exactly the one it means.
     */
    testid?: string;
  }>(),
  { size: 'md', testid: 'modal' },
);

const emit = defineEmits<{ close: [] }>();

// Static map so Tailwind's JIT picks the classes up at build time.
const SIZE_CLASS: Record<NonNullable<typeof props.size>, string> = {
  sm: 'max-w-sm',
  md: 'max-w-md',
  lg: 'max-w-2xl',
  xl: 'max-w-4xl',
  full: 'max-w-7xl',
};

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') emit('close');
}

onMounted(() => {
  document.addEventListener('keydown', onKeydown);
  document.body.style.overflow = 'hidden';
});

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKeydown);
  document.body.style.overflow = '';
});
</script>

<template>
  <Teleport to="body">
    <!-- Identity lives on the primitive, not on the ~20 call sites: one
         attribute here is how an E2E suite finds any dialog in the app.
         `role="dialog"` cannot serve that purpose because FormSheet and
         ConfirmationDialog are BOTH built on this component, so
         getByRole('dialog') cannot tell an edit form from a delete
         confirm — hence the overridable `testid`. -->
    <div
      data-testid="modal-backdrop"
      class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/40 px-md py-md sm:p-lg"
      @click.self="emit('close')"
    >
      <div
        :data-testid="props.testid"
        class="w-full form-card max-h-[90vh] overflow-y-auto p-lg sm:p-xl"
        :class="SIZE_CLASS[size]"
        role="dialog"
        aria-modal="true"
      >
        <header v-if="title || subtitle" class="mb-md">
          <h2 v-if="title" class="text-lg font-bold text-slate-900">{{ title }}</h2>
          <p v-if="subtitle" class="text-sm text-slate-500 mt-1">
            {{ subtitle }}
          </p>
        </header>

        <slot />
      </div>
    </div>
  </Teleport>
</template>

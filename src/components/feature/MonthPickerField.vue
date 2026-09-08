<!--
  MonthPickerField.vue — labeled "Periode" control backed by
  <MonthPickerModal>. This is the drop-in replacement for the
  `<input type="month">` / `<input type="text" placeholder="YYYY-MM">`
  fields; see MonthPickerModal.vue for why they had to go.

  It reuses <FormField>'s default slot so the label + error chrome is
  the same component every other admin field already uses — only the
  control itself is bespoke.

  CONTRACT: `modelValue` is a `YYYY-MM` string, in and out. The visible
  text is DERIVED from it ("September 2026"), never independently
  editable, so the two cannot drift apart. `update:modelValue` fires
  once per pick, and not at all when the user re-picks the month that is
  already selected — a host watcher will not double-fetch.

  Hosts that already own their own trigger chrome (the Rekap toolbar's
  prev/next stepper group, for one) should use <MonthPickerModal>
  directly instead of wrapping this.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import FormField from '@/components/ui/FormField.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import MonthPickerModal from '@/components/feature/MonthPickerModal.vue';
import { formatYmLabel } from '@/lib/local-date';

const props = withDefaults(
  defineProps<{
    /** Selected month, `YYYY-MM`. */
    modelValue: string;
    label?: string;
    /** Earliest selectable month, `YYYY-MM` (inclusive). */
    min?: string;
    /** Latest selectable month, `YYYY-MM` (inclusive). */
    max?: string;
    accent?: 'admin' | 'teacher';
    disabled?: boolean;
    /** Red error line beneath the control (forwarded to FormField). */
    error?: string;
    /** E2E handle, forwarded onto the trigger button. */
    field?: string;
  }>(),
  {
    label: '',
    min: '',
    max: '',
    accent: 'admin',
    disabled: false,
    error: '',
    field: 'month',
  },
);

const emit = defineEmits<{ 'update:modelValue': [string] }>();

const { t, locale } = useI18n();

const open = ref(false);

const localeTag = computed(() => (locale.value === 'en' ? 'en-US' : 'id-ID'));

/**
 * Always derived from the model — this is what makes "displayed text
 * and model silently disagree" structurally impossible here.
 */
const displayLabel = computed(() => formatYmLabel(props.modelValue, localeTag.value));

function onApply(ym: string) {
  // Re-picking the current month is a no-op rather than a same-value
  // emit, so a host `watch(month, reload)` cannot be made to refetch by
  // opening the picker and tapping the already-selected cell.
  if (ym === props.modelValue) return;
  emit('update:modelValue', ym);
}
</script>

<template>
  <FormField :label="label" :error="error">
    <button
      type="button"
      :data-testid="field ? `field-${field}` : undefined"
      data-month-trigger
      :disabled="disabled"
      :aria-label="t('common.monthPicker.openLabel', { month: displayLabel })"
      aria-haspopup="dialog"
      :aria-expanded="open"
      class="w-full flex items-center justify-between gap-2 rounded-xl border border-slate-300 px-md py-sm text-sm text-left bg-white text-slate-900 focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none hover:bg-slate-50 disabled:opacity-60 disabled:cursor-not-allowed disabled:hover:bg-white"
      @click="open = true"
    >
      <span class="capitalize truncate">{{ displayLabel }}</span>
      <NavIcon name="calendar" :size="14" class="text-slate-400 flex-shrink-0" />
    </button>

    <!-- Inside the slot only so this component keeps a SINGLE root and
         a host's `class` still falls through. Modal teleports to body,
         so nothing actually renders here. -->
    <MonthPickerModal
      v-if="open"
      :model-value="modelValue"
      :min="min"
      :max="max"
      :accent="accent"
      @apply="onApply"
      @close="open = false"
    />
  </FormField>
</template>

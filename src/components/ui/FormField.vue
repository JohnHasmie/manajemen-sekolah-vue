<!--
  FormField — the single labeled-control unit that every admin edit
  sheet repeats: a `<label>`, one control (text/number/email/tel/date
  input, textarea, or select), and an optional red error line beneath it.

  Before this component, StudentEditSheet / TeacherEditSheet /
  ClassroomEditSheet / SubjectEditSheet each hand-rolled the SAME three
  lines of markup per field — the identical
  `block text-sm font-medium text-slate-700 mb-1` label, the identical
  `w-full rounded-xl border border-slate-300 px-md py-sm text-sm
  focus:border-brand …` control chrome, and the identical
  `text-xs text-status-danger mt-1` error line. Dozens of copies meant
  any tweak to the input look had to be made in dozens of places.

  This is a FAITHFUL extraction, not a redesign: the classes below are
  copied verbatim from the existing sheets so migrating a field to
  <FormField> is pixel-identical. Domain concerns (validation rules,
  which fields exist, submit payload) STAY in the calling sheet; this
  component only owns the label + control + error chrome.

  For controls this component can't express thinly (autocomplete
  dropdowns, toggle switches, multi-select chip grids, an optional
  "(opsional)" suffix in the label), pass your own control via the
  default slot and keep just the label + error wrapper — or leave that
  bespoke field as hand-rolled markup. Don't force an awkward fit.
-->
<script setup lang="ts">
import MoneyInput from './MoneyInput.vue';

export interface FormFieldOption {
  /** The value bound to `modelValue` when this option is chosen. */
  value: string | number;
  /** The visible option text. */
  label: string;
}

const props = withDefaults(
  defineProps<{
    /** Visible label text above the control. */
    label?: string;
    /** v-model value. Number inputs still bind through here. */
    modelValue?: string | number | null;
    /**
     * Which control to render.
     *
     * `'date'` renders a native `<input type="date">` — a real calendar
     * picker over a `YYYY-MM-DD` model. Unlike `type="month"` (see
     * MonthPickerModal.vue, which exists precisely because desktop
     * Safari ships no month picker), `type="date"` IS implemented in
     * every desktop browser this app targets, Safari 14.1+ included, so
     * no bespoke component is warranted. 40-odd raw `<input type="date">`
     * elements across the app already rely on that.
     *
     * The emitted value is the browser's normalised `YYYY-MM-DD`, or
     * `''` when the field is empty OR the user typed something the
     * browser could not parse — a date input never emits a half-typed
     * string. Hosts that treat empty as "open ended" must map that `''`
     * to `null` before it reaches the wire.
     */
    type?: 'text' | 'number' | 'email' | 'tel' | 'date' | 'textarea' | 'select';
    /** Adds the required asterisk to the label (visual only). */
    required?: boolean;
    disabled?: boolean;
    /** Red error line shown beneath the control when non-empty. */
    error?: string;
    placeholder?: string;
    /** Rows for the textarea variant. */
    rows?: number;
    /** Options for the select variant. */
    options?: FormFieldOption[];
    /** Placeholder <option> for select (empty-value first entry). */
    selectPlaceholder?: string;
    /**
     * min/max forwarded to number inputs — and, unchanged, to `date`
     * ones, where the bound is a `YYYY-MM-DD` string that greys out
     * everything outside it in the native picker.
     */
    min?: number | string;
    max?: number | string;
    /**
     * Stable handle for E2E selectors, placed on the rendered control.
     *
     * Forms are the one place the suite genuinely has to reach an
     * individual element, and the alternatives are both bad: label text
     * couples the assertion to `locales/id.json` (switchable at runtime,
     * so a copy edit reddens the suite with nothing broken), and
     * positional selectors break the moment a field is reordered.
     * Callers pass the model key, e.g. `field="guardian_email"`.
     */
    field?: string;
    /** Coerce the emitted value to a Number (mirrors v-model.number). */
    numberModel?: boolean;
    /**
     * Render a rupiah field: thousand separators appear as the user
     * types while the emitted value stays a plain integer (or `null`
     * when the field is cleared). Delegates to `<MoneyInput>`, which
     * owns the caret handling — see that component for the contract.
     *
     * Implies numeric input, so `type` is ignored when this is set.
     */
    money?: boolean;
    /**
     * Turn the thousand separators off for a `money` field that is
     * currently in a non-rupiah mode — a payout rate switched to
     * `percent_revenue`, say. The digits-only behaviour is kept.
     */
    moneyGrouping?: boolean;
  }>(),
  {
    label: '',
    modelValue: '',
    type: 'text',
    required: false,
    disabled: false,
    error: '',
    placeholder: '',
    rows: 2,
    options: () => [],
    selectPlaceholder: '',
    min: undefined,
    max: undefined,
    numberModel: false,
    money: false,
    moneyGrouping: true,
    field: '',
  },
);

// `null` joins the union for the `money` variant: an empty rupiah field
// must stay distinguishable from a zero one. See MoneyInput.vue.
const emit = defineEmits<{ 'update:modelValue': [value: string | number | null] }>();

// Shared control chrome — copied verbatim from the edit sheets so the
// look is byte-for-byte identical after migration.
const CONTROL_BASE =
  'w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none';

function onInput(event: Event) {
  const el = event.target as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement;
  const raw = el.value;
  // Mirror `v-model.number`: emit a Number when asked (or for number
  // inputs), but never coerce '' to 0 — keep the empty string so
  // "cleared" fields stay empty like the hand-rolled `v-model.number` did.
  if ((props.numberModel || props.type === 'number') && raw !== '') {
    const n = Number(raw);
    emit('update:modelValue', Number.isNaN(n) ? raw : n);
    return;
  }
  emit('update:modelValue', raw);
}
</script>

<template>
  <div>
    <label
      v-if="label || $slots.label"
      class="block text-sm font-medium text-slate-700 mb-1"
    >
      <!-- `label` slot lets callers render a rich label — e.g. the
           muted "(opsional)" suffix the sheets use — while still
           reusing this component's control + error chrome. -->
      <slot name="label">{{ label }}</slot>
      <span v-if="required" class="text-status-danger">*</span>
    </label>

    <!-- Escape hatch: caller supplies a bespoke control (autocomplete,
         toggle, chip grid) but reuses the label + error wrapper. -->
    <slot>
      <textarea
        v-if="type === 'textarea'"
        :data-testid="field ? `field-${field}` : undefined"
        :value="modelValue ?? ''"
        :rows="rows"
        :placeholder="placeholder"
        :disabled="disabled"
        :class="[CONTROL_BASE, 'resize-none']"
        @input="onInput"
      ></textarea>

      <select
        v-else-if="type === 'select'"
        :data-testid="field ? `field-${field}` : undefined"
        :value="modelValue ?? ''"
        :disabled="disabled"
        :class="[CONTROL_BASE, 'bg-white']"
        @change="onInput"
      >
        <option v-if="selectPlaceholder" value="">{{ selectPlaceholder }}</option>
        <option v-for="opt in options" :key="opt.value" :value="opt.value">
          {{ opt.label }}
        </option>
      </select>

      <MoneyInput
        v-else-if="money"
        :data-testid="field ? `field-${field}` : undefined"
        :model-value="typeof modelValue === 'number' ? modelValue : null"
        :grouping="moneyGrouping"
        :placeholder="placeholder"
        :disabled="disabled"
        :class="CONTROL_BASE"
        @update:model-value="emit('update:modelValue', $event)"
      />

      <input
        v-else
        :data-testid="field ? `field-${field}` : undefined"
        :value="modelValue ?? ''"
        :type="type"
        :placeholder="placeholder"
        :disabled="disabled"
        :min="min"
        :max="max"
        :class="CONTROL_BASE"
        @input="onInput"
      />
    </slot>

    <p v-if="error" class="text-xs text-status-danger mt-1">{{ error }}</p>
  </div>
</template>

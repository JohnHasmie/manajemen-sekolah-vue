<!--
  MoneyInput — the one rupiah field for the whole app.

  Shows Indonesian thousand separators as the user types (`12000000`
  renders as `12.000.000`) while `v-model` stays a plain integer, so the
  value handed to the API is exactly the value it was before this
  component existed. All of the fiddly parts — caret preservation,
  Backspace across a separator, paste, leading zeros, clearing — live in
  `@/lib/money-input`, which is unit-tested without a DOM.

  It renders a bare `<input>` and nothing else. Every call site here has
  its own chrome (`rounded-xl border-slate-200 …` in one sheet,
  `dcform-in` in another), so styling comes in through fallthrough attrs:

      <MoneyInput v-model="form.amount" class="my-input-classes" />

  `id`, `placeholder`, `disabled`, `data-testid` and friends ride the
  same channel. `type` and `inputmode` are NOT overridable — the field
  must be `type="text"` for separators to be legal contents at all
  (`type="number"` silently rejects them), and `inputmode="numeric"`
  is what raises the digit keypad on a phone.

  MODEL CONTRACT
    number  — a whole, non-negative rupiah amount
    null    — the field is empty

  `null` rather than `0` on an empty field is load-bearing: these amounts
  are all `min:1` server-side, and collapsing "cleared" into "zero" is
  how a half-filled form ends up posting a real 0.

  Fields that are only SOMETIMES money — a voucher that can be a
  percentage or a rupiah amount — pass `:grouping="false"` for the
  non-money mode and keep one set of markup.

  Validation stays with the caller. This component will not clamp to a
  max or reject a below-minimum amount; it only guarantees the value is a
  whole number or null.
-->
<script setup lang="ts">
import { ref, watch } from 'vue';
import {
  MONEY_MAX_DIGITS,
  backspaceAcrossSeparator,
  deleteAcrossSeparator,
  formatMoneyValue,
  normalizeMoneyInput,
} from '@/lib/money-input';

const props = withDefaults(
  defineProps<{
    /** Whole rupiah amount, or `null` when the field is empty. */
    modelValue?: number | null;
    /** Render thousand separators. `false` = digits only. */
    grouping?: boolean;
    /** Digit cap; see `MONEY_MAX_DIGITS`. */
    maxDigits?: number;
  }>(),
  {
    modelValue: null,
    grouping: true,
    maxDigits: MONEY_MAX_DIGITS,
  },
);

const emit = defineEmits<{ 'update:modelValue': [value: number | null] }>();

// Chrome belongs to the caller — see the header comment.
defineOptions({ inheritAttrs: false });

const inputEl = ref<HTMLInputElement | null>(null);
const text = ref(formatMoneyValue(props.modelValue, props.grouping));
const isFocused = ref(false);

function syncFromModel(): void {
  text.value = formatMoneyValue(props.modelValue, props.grouping);
}

/**
 * While the field has focus its own text is the source of truth. A
 * parent that normalises the value it receives (clamping, `?? 0`, a
 * nullability adapter) would otherwise write back a different value
 * mid-keystroke and yank the text out from under the caret. On blur we
 * re-read the model, which also re-canonicalises anything the parent
 * changed behind our back.
 */
watch(
  () => props.modelValue,
  () => {
    if (!isFocused.value) syncFromModel();
  },
);

// A voucher flipping between "percent" and "fixed" changes whether the
// same digits should carry separators.
watch(() => props.grouping, syncFromModel);

/**
 * Push a candidate raw string through the normaliser and write the
 * result back to the DOM.
 *
 * `el.value` is assigned even when `text` is unchanged: typing a stray
 * `.` into `1.000` produces the same normalised text, so Vue would skip
 * the patch and leave the user's `1.0.00` sitting in the field.
 */
function apply(el: HTMLInputElement, raw: string, caret: number): void {
  const next = normalizeMoneyInput(raw, caret, {
    grouping: props.grouping,
    maxDigits: props.maxDigits,
  });
  text.value = next.text;
  el.value = next.text;
  el.setSelectionRange(next.caret, next.caret);
  emit('update:modelValue', next.value);
}

function onInput(event: Event): void {
  const el = event.target as HTMLInputElement;
  apply(el, el.value, el.selectionStart ?? el.value.length);
}

/**
 * Backspace/Delete land ON a separator often enough that leaving them to
 * the browser makes the field feel broken. Only the collapsed-caret,
 * caret-touching-a-separator case is intercepted — a range selection,
 * or a caret next to a digit, already behaves correctly.
 */
function onKeydown(event: KeyboardEvent): void {
  if (!props.grouping) return;
  if (event.key !== 'Backspace' && event.key !== 'Delete') return;

  const el = event.target as HTMLInputElement;
  const start = el.selectionStart;
  if (start === null || start !== el.selectionEnd) return;

  const edit =
    event.key === 'Backspace'
      ? backspaceAcrossSeparator(el.value, start)
      : deleteAcrossSeparator(el.value, start);
  if (!edit) return;

  event.preventDefault();
  apply(el, edit.raw, edit.caret);
}

function onBlur(): void {
  isFocused.value = false;
  syncFromModel();
}

defineExpose({ inputEl });
</script>

<template>
  <input
    ref="inputEl"
    v-bind="$attrs"
    :value="text"
    type="text"
    inputmode="numeric"
    autocomplete="off"
    @input="onInput"
    @keydown="onKeydown"
    @focus="isFocused = true"
    @blur="onBlur"
  />
</template>

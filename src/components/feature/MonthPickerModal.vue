<!--
  MonthPickerModal.vue — pick a calendar month (`YYYY-MM`).

  ── Why this exists ──

  Every "Periode" field in the app used to be `<input type="month">`,
  which is fine on paper — it is exactly the right input type for a
  `YYYY-MM` value. The problem is browser support: desktop Safari ships
  NO picker UI for `type="month"` and degrades it to a plain text box.
  Per MDN, only Chrome/Opera and Edge on desktop have usable
  implementations. (`type="date"` IS supported in Safari 14.1+, so this
  is specific to `month`.)

  A tutor on macOS Safari therefore saw the "Honor Saya" period field as
  a bare text box reading `2026-09`, with no way to browse months — the
  report this component was written for. Two other screens were quietly
  worse: they used `type="text"` with a `YYYY-MM` placeholder, which has
  no picker in ANY browser.

  ── Shape ──

  A year header with prev/next arrows over a 12-month grid. Two clicks
  reaches any month in the allowed range; one click for a month in the
  year already shown. Picking emits `apply` and closes, matching
  FilterFacetPickerModal's single-select idiom.

  ── No free-text entry, deliberately ──

  The model is `YYYY-MM`, a machine format. A text box over it either
  accepts `2026-9` / `Sep 2026` and silently writes a value the API
  cannot read, or rejects them and demands the user know the wire
  format. AdminTutoring2PayoutSettingsView had to carry a hand-rolled
  regex guard + error toast for exactly that. Making the value
  picker-only means the displayed label and the model can never
  disagree, because the label is derived from the model.

  Keyboard access is not lost: the trigger is a button, every month is a
  button in tab order, and Modal already closes on ESC.

  ── `clearable`: the picker as a FILTER, opt-in ──

  A month FIELD ("which month am I paying out?") always holds a value.
  A month FILTER ("show me only September") has a third state: none —
  "Semua". Filter hosts therefore need a way to emit the empty string,
  which the grid alone can never produce.

  That reset is opt-in via `clearable` rather than always-on, because
  the field hosts (Honor Saya, Ringkasan Payout, Setelan Payout, Rekap
  Kehadiran) rely on `apply` never handing them a value their API
  cannot take. With the flag off, `apply` is still always a valid
  `YYYY-MM`; only a host that asked for the reset can be given `''`.

  It renders as the first row of the body, highlighted when nothing is
  selected — the same shape and placement as FilterFacetPickerModal's
  "Semua" row, so the two per-facet pickers read as one family.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import {
  addMonths,
  compareYm,
  defaultMaxMonth,
  defaultMinMonth,
  formatYm,
  formatYmLabel,
  parseYm,
  toLocalYm,
} from '@/lib/local-date';

const props = withDefaults(
  defineProps<{
    /** Currently selected month, `YYYY-MM`. */
    modelValue: string;
    title?: string;
    subtitle?: string;
    /**
     * Earliest selectable month, `YYYY-MM` (inclusive).
     * Empty = the shared 36-month lookback (see `defaultMinMonth`).
     */
    min?: string;
    /**
     * Latest selectable month, `YYYY-MM` (inclusive).
     * Empty = the current local month (see `defaultMaxMonth`).
     */
    max?: string;
    /** Tints the selected cell to match the host page's role. */
    accent?: 'admin' | 'teacher';
    /**
     * Show a "Semua bulan" reset row that emits `''`.
     * Filter hosts only — see the docblock. Off by default so field
     * hosts keep the "`apply` is always a valid `YYYY-MM`" guarantee.
     */
    clearable?: boolean;
  }>(),
  {
    title: '',
    subtitle: '',
    min: '',
    max: '',
    accent: 'admin',
    clearable: false,
  },
);

const emit = defineEmits<{
  close: [];
  /**
   * The picked month — a valid `YYYY-MM`, or `''` from the reset row,
   * which only exists when the host passed `clearable`.
   */
  apply: [string];
}>();

const { t, locale } = useI18n();

/**
 * Intl tag for month names. Driven by the active app locale so the grid
 * reads "Sep"/"September" in EN and "Sep"/"September" in ID rather than
 * being hardcoded to `id-ID` the way the older per-view formatters were.
 */
const localeTag = computed(() => (locale.value === 'en' ? 'en-US' : 'id-ID'));

/** `YYYY-MM` for right now, in LOCAL time (never a UTC round-trip). */
const thisMonth = toLocalYm();

/**
 * Bounds actually enforced. Resolved at mount (the modal is `v-if`'d by
 * its hosts, so it re-mounts per open) rather than at module load, so a
 * tab left open across a month rollover gets the new ceiling.
 */
const effectiveMin = computed(() => props.min || defaultMinMonth());
const effectiveMax = computed(() => props.max || defaultMaxMonth());

/**
 * The year the grid is showing. Seeded from the model, falling back to
 * the current LOCAL year when the host handed us a malformed value —
 * never to a UTC-derived one.
 */
const viewYear = ref<number>(parseYm(props.modelValue)?.year ?? new Date().getFullYear());

/** Static map so Tailwind's JIT sees both class strings at build time. */
const ACCENT_CLASS: Record<'admin' | 'teacher', string> = {
  admin: 'bg-role-admin text-white border-role-admin',
  teacher: 'bg-role-teacher text-white border-role-teacher',
};

const months = computed(() =>
  Array.from({ length: 12 }, (_, i) => {
    const ym = formatYm(viewYear.value, i + 1);
    return {
      ym,
      short: new Date(viewYear.value, i, 1).toLocaleDateString(localeTag.value, {
        month: 'short',
      }),
      long: formatYmLabel(ym, localeTag.value),
      selected: ym === props.modelValue,
      current: ym === thisMonth,
      disabled: isOutOfRange(ym),
    };
  }),
);

function isOutOfRange(ym: string): boolean {
  if (compareYm(ym, effectiveMin.value) < 0) return true;
  if (compareYm(ym, effectiveMax.value) > 0) return true;
  return false;
}

/**
 * A year is reachable when it holds at least one selectable month —
 * checking only January/December would wrongly disable the boundary
 * year when a bound falls mid-year.
 */
function yearHasSelectableMonth(year: number): boolean {
  for (let m = 1; m <= 12; m++) {
    if (!isOutOfRange(formatYm(year, m))) return true;
  }
  return false;
}

const canStepBack = computed(() => yearHasSelectableMonth(viewYear.value - 1));
const canStepForward = computed(() => yearHasSelectableMonth(viewYear.value + 1));

/** "Bulan ini" is hidden rather than shown-disabled when out of range. */
const canJumpToThisMonth = computed(() => !isOutOfRange(thisMonth));

function stepYear(delta: number) {
  const next = viewYear.value + delta;
  if (!yearHasSelectableMonth(next)) return;
  viewYear.value = next;
}

function pick(ym: string) {
  if (isOutOfRange(ym)) return;
  emit('apply', ym);
  emit('close');
}

function jumpToThisMonth() {
  pick(thisMonth);
}

/** "Semua bulan" — the no-month-selected state. `clearable` hosts only. */
function clearSelection() {
  emit('apply', '');
  emit('close');
}

/** Left/right arrows walk months; the grid is a calendar, not a list. */
function onGridKeydown(event: KeyboardEvent, ym: string) {
  const delta = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0;
  if (delta === 0) return;
  const target = addMonths(ym, delta);
  if (isOutOfRange(target)) return;
  event.preventDefault();
  const parsed = parseYm(target);
  if (parsed) viewYear.value = parsed.year;
  // Focus follows the value across a year boundary once the grid re-renders.
  requestAnimationFrame(() => {
    document.querySelector<HTMLButtonElement>(`[data-month="${target}"]`)?.focus();
  });
}
</script>

<template>
  <Modal
    :title="title || t('common.monthPicker.title')"
    :subtitle="subtitle"
    size="sm"
    testid="month-picker-modal"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- "Semua bulan" reset. First row + selected-when-empty styling
           mirrors FilterFacetPickerModal's "Semua". -->
      <button
        v-if="clearable"
        type="button"
        data-testid="month-picker-all"
        class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
        :class="
          modelValue === ''
            ? 'bg-role-admin/10 text-role-admin'
            : 'text-slate-700 hover:bg-slate-50'
        "
        :aria-pressed="modelValue === ''"
        @click="clearSelection"
      >
        {{ t('common.monthPicker.allMonths') }}
      </button>

      <!-- Year header -->
      <div class="flex items-center justify-between">
        <button
          type="button"
          data-testid="month-picker-prev-year"
          class="w-9 h-9 rounded-lg grid place-items-center text-slate-500 hover:bg-slate-100 disabled:opacity-30 disabled:cursor-not-allowed"
          :disabled="!canStepBack"
          :aria-label="t('common.monthPicker.prevYear')"
          @click="stepYear(-1)"
        >
          <NavIcon name="chevron-left" :size="14" />
        </button>
        <p
          data-testid="month-picker-year"
          class="text-[15px] font-black text-slate-900 tabular-nums"
          aria-live="polite"
        >
          {{ viewYear }}
        </p>
        <button
          type="button"
          data-testid="month-picker-next-year"
          class="w-9 h-9 rounded-lg grid place-items-center text-slate-500 hover:bg-slate-100 disabled:opacity-30 disabled:cursor-not-allowed"
          :disabled="!canStepForward"
          :aria-label="t('common.monthPicker.nextYear')"
          @click="stepYear(1)"
        >
          <NavIcon name="chevron-right" :size="14" />
        </button>
      </div>

      <!-- 12-month grid -->
      <div class="grid grid-cols-3 gap-2" role="group" :aria-label="t('common.monthPicker.title')">
        <button
          v-for="m in months"
          :key="m.ym"
          type="button"
          :data-month="m.ym"
          data-testid="month-picker-cell"
          class="py-2.5 rounded-xl border text-[13px] font-bold capitalize transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
          :class="
            m.selected
              ? ACCENT_CLASS[accent]
              : m.current
                ? 'border-slate-300 bg-slate-50 text-slate-900'
                : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50 disabled:hover:bg-white'
          "
          :disabled="m.disabled"
          :aria-label="m.long"
          :aria-pressed="m.selected"
          :aria-current="m.current ? 'date' : undefined"
          @click="pick(m.ym)"
          @keydown="onGridKeydown($event, m.ym)"
        >
          {{ m.short }}
        </button>
      </div>

      <footer class="pt-2 flex items-center gap-2">
        <button
          v-if="canJumpToThisMonth"
          type="button"
          data-testid="month-picker-this-month"
          class="text-[12px] font-bold text-slate-500 hover:text-slate-800 hover:underline"
          @click="jumpToThisMonth"
        >
          {{ t('common.monthPicker.thisMonth') }}
        </button>
        <button
          type="button"
          data-testid="month-picker-close"
          class="ml-auto px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-[12px] font-bold"
          @click="emit('close')"
        >
          {{ t('common.close') }}
        </button>
      </footer>
    </div>
  </Modal>
</template>

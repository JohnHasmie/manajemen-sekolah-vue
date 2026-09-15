/**
 * The SELECTED attendance chip must actually be visible.
 *
 * ── The defect ──
 *
 * The product owner picked "Hadir" and "Hadir" disappeared — a blank gap
 * with no border and no text where the chip had been.
 *
 * The button carried its colours in TWO places at once: a static
 * `class` with `bg-white text-slate-500 border-slate-200`, and a
 * `:class` adding `bg-emerald-700 text-white border-transparent` when
 * selected. Both landed in the rendered class list, every utility is a
 * single-class selector (specificity 0,1,0), so CSS SOURCE ORDER broke
 * the tie — independently for each property.
 *
 * Tailwind v3 emits colour utilities in LEXICOGRAPHIC order of the
 * class-name suffix, not palette order, which is what splits the three
 * properties apart. Byte offsets measured in the emitted bundle:
 *
 *   background-color   .bg-emerald-700 @240784  <  .bg-white @249662
 *   color              .text-slate-500 @271711  <  .text-white @273948
 *   border-color       .border-slate-200 @232889 < .border-transparent @234020
 *
 * The STATIC `bg-white` won the background; the CONDITIONAL `text-white`
 * and `border-transparent` won the text and the border. White text on a
 * white background inside a transparent border — invisible. All four
 * statuses shared it; only the selected one vanished.
 *
 * ── Why these assertions and not a style assertion ──
 *
 * jsdom has no Tailwind stylesheet, so `getComputedStyle` here would
 * report nothing useful and an assertion on it would pass vacuously.
 * What IS observable in jsdom — and what the whole defect reduces to —
 * is the rendered class list: the bug exists precisely when both
 * members of a conflicting pair appear on one element. So the pairs are
 * asserted directly.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The REAL component is mounted. Asserting that a prop was passed
 *    would prove nothing: the defect is in what gets rendered.
 * 2. Every "must not contain" is paired with a "must contain", so a
 *    component that rendered no classes at all — or no buttons at all —
 *    cannot pass. The `toHaveLength(4)` guard catches the latter.
 * 3. The unselected assertions are what stop the fix from being "delete
 *    the colours": the resting chip must still be readable slate-on-
 *    white, and must NOT pick up `text-white`.
 * 4. The four hues and the check icon are pinned too — this was a
 *    rendering fix, not a redesign, and a silent palette change would
 *    otherwise slip through.
 */
import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import AttendancePicker from './AttendancePicker.vue';
import type { AttendanceStatus } from '@/types/attendance';

const STATUSES = ['hadir', 'sakit', 'izin', 'alpa'] as const;

/** The hue each status paints when selected — unchanged by the fix. */
const SELECTED_BG: Record<(typeof STATUSES)[number], string> = {
  hadir: 'bg-emerald-700',
  sakit: 'bg-amber-700',
  izin: 'bg-blue-700',
  alpa: 'bg-red-700',
};

function mountPicker(modelValue: AttendanceStatus) {
  return mount(AttendancePicker, { props: { modelValue } });
}

/** The rendered class list of one chip, as an array of class names. */
function classesOf(wrapper: ReturnType<typeof mountPicker>, status: string): string[] {
  const el = wrapper.get(`[data-testid="attendance-chip-${status}"]`);
  return (el.attributes('class') ?? '').split(/\s+/).filter(Boolean);
}

describe('AttendancePicker — the selected chip must be visible', () => {
  it('renders all four chips regardless of selection', () => {
    // Guards every "does not contain" assertion below: a component that
    // rendered nothing would otherwise satisfy all of them.
    const w = mountPicker('hadir');
    expect(w.findAll('[role="radio"]')).toHaveLength(4);
  });

  it.each(STATUSES)(
    'the selected "%s" chip never carries both bg-white and its status hue',
    (status) => {
      const w = mountPicker(status);
      const cls = classesOf(w, status);

      // The pair that made the chip invisible.
      expect(cls).toContain(SELECTED_BG[status]);
      expect(cls).not.toContain('bg-white');
    },
  );

  it.each(STATUSES)(
    'the selected "%s" chip never carries both text-white and text-slate-500',
    (status) => {
      const w = mountPicker(status);
      const cls = classesOf(w, status);

      expect(cls).toContain('text-white');
      expect(cls).not.toContain('text-slate-500');
    },
  );

  it.each(STATUSES)(
    'the selected "%s" chip never carries both border-transparent and border-slate-200',
    (status) => {
      const w = mountPicker(status);
      const cls = classesOf(w, status);

      expect(cls).toContain('border-transparent');
      expect(cls).not.toContain('border-slate-200');
    },
  );

  it('keeps the unselected chips readable: slate on white, never white-on-white', () => {
    const w = mountPicker('hadir');

    for (const other of STATUSES.filter((s) => s !== 'hadir')) {
      const cls = classesOf(w, other);
      // The readable resting pair survives...
      expect(cls, `${other} lost its resting background`).toContain('bg-white');
      expect(cls, `${other} lost its resting text colour`).toContain('text-slate-500');
      expect(cls, `${other} lost its resting border`).toContain('border-slate-200');
      // ...and none of the selected-state colours leak onto it.
      expect(cls, `${other} wrongly painted as selected`).not.toContain('text-white');
      expect(cls, `${other} wrongly painted as selected`).not.toContain('border-transparent');
      expect(cls, `${other} wrongly painted as selected`).not.toContain(SELECTED_BG[other]);
    }
  });

  it('paints nothing as selected when modelValue is null', () => {
    const w = mountPicker(null);

    for (const status of STATUSES) {
      const cls = classesOf(w, status);
      expect(cls).toContain('bg-white');
      expect(cls).not.toContain('text-white');
      expect(cls).not.toContain(SELECTED_BG[status]);
    }
  });

  it('still renders the check icon on the selected chip only', () => {
    // The icon was the ONLY selection signal left under the dark theme,
    // where `!important` overrides keyed off the static classes made the
    // selected and unselected chips byte-identical. It must survive.
    const w = mountPicker('izin');

    expect(w.get('[data-testid="attendance-chip-izin"]').find('svg').exists()).toBe(true);
    for (const other of STATUSES.filter((s) => s !== 'izin')) {
      expect(
        w.get(`[data-testid="attendance-chip-${other}"]`).find('svg').exists(),
        `${other} should not show a check icon`,
      ).toBe(false);
    }
  });

  it('marks the selected chip with aria-checked so it is announced too', () => {
    const w = mountPicker('alpa');

    expect(w.get('[data-testid="attendance-chip-alpa"]').attributes('aria-checked')).toBe('true');
    expect(w.get('[data-testid="attendance-chip-hadir"]').attributes('aria-checked')).toBe('false');
  });
});

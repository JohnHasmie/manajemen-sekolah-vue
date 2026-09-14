/**
 * AppFilterChip — the `active` prop contract.
 *
 * ── Why this file exists ──
 *
 * `active` is the only signal that an applied filter is legible at a
 * glance: it swaps the chip's root <button> onto the cobalt-ring +
 * role-admin-soft branch. Nothing else in the component reads it.
 *
 * Ten call sites used to spell it `:is-active`, which Vue does NOT map
 * to this prop — it is undeclared, so it fell through `$attrs` onto the
 * root <button> as a dead `is-active="true"` DOM attribute while the
 * prop stayed at its `false` default. The chips rendered inert grey
 * forever, even with a filter applied.
 *
 * This spec pins the COMPONENT contract (which classes each state
 * paints). It is deliberately NOT the regression test for that bug — a
 * misspelling at a call site cannot be caught from in here, because
 * this file passes the prop correctly by construction. The wiring
 * regression lives in AdminClassActivityView.active-chip.spec.ts.
 *
 * ── Anti-vacuity notes ──
 *
 * Assertions are on `.classes()`, which returns EXACT tokens. That
 * matters: the idle branch contains `hover:border-brand-cobalt`, so a
 * substring match on 'border-brand-cobalt' would pass in both states
 * and the test would prove nothing. Exact-token `toContain` does not.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import AppFilterChip from './AppFilterChip.vue';

/** The four classes the `active` branch adds. */
const ACTIVE_CLASSES = [
  'bg-role-admin-soft',
  'border-brand-cobalt',
  'ring-2',
  'ring-brand-cobalt/30',
];

function mountChip(props = {}) {
  return mount(AppFilterChip, {
    props: { label: 'KELAS', value: '7A', ...props },
    global: { stubs: { NavIcon: true } },
  });
}

describe('AppFilterChip active styling', () => {
  it('paints the cobalt ring + role-admin-soft fill when active', () => {
    const classes = mountChip({ active: true }).find('button').classes();

    for (const c of ACTIVE_CLASSES) expect(classes).toContain(c);
    // The idle border must be gone, not merely overridden.
    expect(classes).not.toContain('border-slate-200');
  });

  it('paints the inert grey state when not active', () => {
    const classes = mountChip({ active: false }).find('button').classes();

    expect(classes).toContain('border-slate-200');
    expect(classes).not.toContain('border-brand-cobalt');
    expect(classes).not.toContain('ring-2');
    expect(classes).not.toContain('bg-role-admin-soft');
    // Guards the exact-token reasoning above: the idle branch really
    // does carry a look-alike token, so substring matching would lie.
    expect(classes).toContain('hover:border-brand-cobalt');
  });

  it('defaults to inactive when `active` is omitted entirely', () => {
    // This is precisely the state a misspelled binding produced.
    const classes = mountChip().find('button').classes();

    expect(classes).toContain('border-slate-200');
    expect(classes).not.toContain('border-brand-cobalt');
  });

  it('lets `disabled` win over `active`', () => {
    const classes = mountChip({ active: true, disabled: true })
      .find('button')
      .classes();

    expect(classes).toContain('cursor-not-allowed');
    expect(classes).not.toContain('ring-2');
    expect(classes).not.toContain('bg-role-admin-soft');
  });

  it('does not declare an `isActive` prop, so the misspelling cannot work', () => {
    // Pins the root cause rather than a symptom: were someone to later
    // add an `isActive` alias, the ten call sites would silently become
    // legal again and this file would stop describing reality.
    const declared = Object.keys(AppFilterChip.props ?? {});

    expect(declared).toContain('active');
    expect(declared).not.toContain('isActive');
  });
});

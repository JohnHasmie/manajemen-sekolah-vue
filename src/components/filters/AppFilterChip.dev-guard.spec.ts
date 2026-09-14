/**
 * AppFilterChip — the dev-only misspelled-prop guard.
 *
 * The guard exists because `vue-tsc` as this repo is configured cannot
 * see an undeclared attribute on a component: there is no
 * `vueCompilerOptions`, so Volar's `checkUnknownProps` defaults off.
 * The baseline type-check passed with all ten `:is-active` misspellings
 * present.
 *
 * ── Anti-vacuity notes ──
 *
 * The silence half of this file is the important half. A guard that
 * fires on legitimate fall-through gets switched off, which is worse
 * than no guard. The allowlist is pinned against the real inventory of
 * what this repo actually passes through to the chip, which I took from
 * the compiler itself (a `checkUnknownProps` run reports exactly two
 * fall-through attrs on AppFilterChip: `title` x15 and `isActive` x10).
 * `title` is therefore load-bearing and has its own case below.
 *
 * `import.meta.env.DEV` is true under vitest, so the guard is live here.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import AppFilterChip from './AppFilterChip.vue';

let warn;

beforeEach(() => {
  warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
});
afterEach(() => warn.mockRestore());

function mountChip(attrs = {}) {
  return mount(AppFilterChip, {
    props: { label: 'KELAS', value: '7A' },
    attrs,
    global: { stubs: { NavIcon: true } },
  });
}

const messages = () => warn.mock.calls.map((c) => String(c[0]));

describe('AppFilterChip dev guard — fires on a misspelled prop', () => {
  it('warns on :is-active and names the prop that was meant', () => {
    mountChip({ 'is-active': true });

    expect(warn).toHaveBeenCalledTimes(1);
    const msg = messages()[0];
    expect(msg).toContain('is-active');
    expect(msg).toContain('Did you mean ":active"?');
  });

  it('warns on a wholly unknown prop without a bogus suggestion', () => {
    mountChip({ 'no-such-thing': 1 });

    expect(warn).toHaveBeenCalledTimes(1);
    expect(messages()[0]).not.toContain('Did you mean');
  });

  it('warns once per attribute, not once per render', async () => {
    const w = mountChip({ 'is-active': true });
    await w.setProps({ value: '8B' });
    await w.setProps({ value: '9C' });

    expect(warn).toHaveBeenCalledTimes(1);
  });
});

describe('AppFilterChip dev guard — silent on legitimate fall-through', () => {
  // `title` is the one real fall-through this repo uses (15 call sites).
  // If this case ever fails, the guard would have flooded those screens.
  it('is silent on :title', () => {
    mountChip({ title: 'Saring menurut kelas' });
    expect(warn).not.toHaveBeenCalled();
  });

  it.each([
    ['class', { class: 'ml-2' }],
    ['style', { style: 'margin:0' }],
    ['id', { id: 'chip-kelas' }],
    ['role', { role: 'button' }],
    ['tabindex', { tabindex: '0' }],
    ['data-*', { 'data-testid': 'chip' }],
    ['aria-*', { 'aria-label': 'Kelas', 'aria-expanded': 'false' }],
    ['event handlers', { onKeydown: () => {}, onMouseenter: () => {} }],
  ])('is silent on %s', (_label, attrs) => {
    mountChip(attrs);
    expect(warn).not.toHaveBeenCalled();
  });

  it('is silent when every declared prop is passed correctly', () => {
    mount(AppFilterChip, {
      props: {
        label: 'KELAS',
        value: '7A',
        iconName: 'users',
        tone: 'brand',
        disabled: false,
        active: true,
      },
      global: { stubs: { NavIcon: true } },
    });

    expect(warn).not.toHaveBeenCalled();
  });

  it('is silent on the full attribute set a real call site passes at once', () => {
    // Mirrors the busiest shape in the repo: a chip with a tooltip, a
    // test id and a keyboard handler, all legitimate.
    mountChip({
      title: 'Saring menurut kelas',
      'data-testid': 'chip-kelas',
      'aria-label': 'Kelas',
      class: 'shrink-0',
      onKeydown: () => {},
    });

    expect(warn).not.toHaveBeenCalled();
  });
});

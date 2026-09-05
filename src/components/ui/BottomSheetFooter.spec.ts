/**
 * Contract spec for BottomSheetFooter.
 *
 * The component was written for ONE shape — the Cancel/Save row of an
 * editable sheet — so it rendered its secondary Button unconditionally and
 * defaulted the label to the hardcoded literal 'Batal'. A read-only sheet
 * has nothing to cancel and therefore binds no `@secondary`, but it had no
 * way to say so: the button rendered anyway, took the 'Batal' default, and
 * swallowed every click as an unhandled emit.
 *
 * That is what a bimbel admin saw on the Pengumuman Kelompok detail dialog
 * (Slack 1788511561.654479): two buttons, "Batal" next to "Kembali", where
 * only "Kembali" did anything.
 *
 * These tests pin both halves of the contract — the DEFAULT two-button row
 * that twelve editable call sites still depend on, and the `hide-secondary`
 * row that read-only previews now use.
 */
import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import BottomSheetFooter from './BottomSheetFooter.vue';

function mountFooter(props: Record<string, unknown> = {}) {
  setActivePinia(createPinia());
  return mount(BottomSheetFooter, {
    props: { primaryLabel: 'Kembali', ...props },
  });
}

const CANCEL = '[data-testid="sheet-cancel"]';
const SUBMIT = '[data-testid="sheet-submit"]';

describe('BottomSheetFooter default (editable sheet)', () => {
  it('renders BOTH buttons when hide-secondary is not passed', () => {
    const w = mountFooter({ primaryLabel: 'Simpan' });

    expect(w.find(CANCEL).exists()).toBe(true);
    expect(w.find(SUBMIT).exists()).toBe(true);
    expect(w.find(SUBMIT).text()).toBe('Simpan');
  });

  it('keeps the two-column grid so neither button is full width', () => {
    const w = mountFooter({ primaryLabel: 'Simpan' });

    const row = w.find(SUBMIT).element.parentElement as HTMLElement;
    expect(row.className).toContain('grid-cols-2');
    expect(row.className).not.toContain('grid-cols-1');
  });

  it('still emits secondary when the cancel button is clicked', async () => {
    const w = mountFooter({ primaryLabel: 'Simpan' });

    await w.find(CANCEL).trigger('click');

    expect(w.emitted('secondary')).toHaveLength(1);
  });

  it('honours an explicit secondary-label', () => {
    const w = mountFooter({ primaryLabel: 'Simpan', secondaryLabel: 'Tutup' });

    expect(w.find(CANCEL).text()).toBe('Tutup');
  });
});

describe('BottomSheetFooter hide-secondary (read-only sheet)', () => {
  it('renders NO cancel button — this is the "Batal" Luay reported', () => {
    const w = mountFooter({ hideSecondary: true });

    expect(w.find(CANCEL).exists()).toBe(false);
    // Not merely relabelled or hidden by CSS: the node is gone entirely.
    expect(w.findAll('button')).toHaveLength(1);
  });

  it('never renders the hardcoded Indonesian "Batal" default', () => {
    // The default label bypasses i18n, so an en-locale reader used to get
    // "Batal" sitting next to an English primary. Suppressing the button
    // is what keeps that literal off a read-only footer.
    const w = mountFooter({ hideSecondary: true });

    expect(w.text()).not.toContain('Batal');
  });

  it('keeps the primary button, and it still works', async () => {
    const w = mountFooter({ hideSecondary: true });

    expect(w.find(SUBMIT).text()).toBe('Kembali');
    await w.find(SUBMIT).trigger('click');

    expect(w.emitted('primary')).toHaveLength(1);
  });

  it('drops the row to one column so the lone primary is not half width', () => {
    const w = mountFooter({ hideSecondary: true });

    const row = w.find(SUBMIT).element.parentElement as HTMLElement;
    expect(row.className).toContain('grid-cols-1');
    expect(row.className).not.toContain('grid-cols-2');
  });

  it('emits nothing on the secondary channel — there is no control for it', () => {
    const w = mountFooter({ hideSecondary: true });

    expect(w.emitted('secondary')).toBeUndefined();
  });
});

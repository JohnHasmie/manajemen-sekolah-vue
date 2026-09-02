/**
 * The contract the demo wizard's submit button depends on.
 *
 * `ConversationalWizard.submit()` calls `provision()` and, when it comes
 * back false, renders `wizard.error`. That only works because
 * `provision()` CATCHES its own failure and records the message rather
 * than rethrowing.
 *
 * Reported 2026-09-02: "diklik kirim permintaan demo tidak terjadi
 * apa-apa". The request was failing, `provision()` returned false, and
 * the component had no else-branch — so no toast, no error, no
 * navigation, while the real reason sat unread on the store.
 *
 * The component now reads that field, which makes these two properties
 * load-bearing: if `provision()` ever starts rethrowing, or stops
 * setting `error`, the button goes quiet again and the only visible
 * symptom is the one Luay reported. Hence a test rather than a comment.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import { DemoService } from '@/services/demo.service';

vi.mock('@/services/demo.service', () => ({
  DemoService: {
    provision: vi.fn(),
    saveWizardState: vi.fn().mockResolvedValue(undefined),
    loadWizardState: vi.fn().mockResolvedValue(null),
    resetWizardState: vi.fn().mockResolvedValue(undefined),
  },
}));

describe('demo wizard provision()', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('reports failure as false rather than throwing', async () => {
    // If this ever throws instead, the component's else-branch stops
    // running and the message falls back to generic copy.
    vi.mocked(DemoService.provision).mockRejectedValue(
      new Error('Terlalu banyak percobaan. Coba lagi 1 menit.'),
    );
    const store = useDemoWizardStore();

    await expect(store.provision()).resolves.toBe(false);
  });

  it('keeps the reason so the button can say WHY nothing happened', async () => {
    // The whole point: the user must see the throttle/network reason,
    // not a shrug. An empty `error` here is the reported bug.
    vi.mocked(DemoService.provision).mockRejectedValue(
      new Error('Terlalu banyak percobaan. Coba lagi 1 menit.'),
    );
    const store = useDemoWizardStore();

    await store.provision();

    expect(store.error).toBe('Terlalu banyak percobaan. Coba lagi 1 menit.');
  });

  it('clears a previous error on a fresh attempt', async () => {
    // Otherwise a retry that SUCCEEDS still shows the old failure text
    // the next time anything reads `error`.
    vi.mocked(DemoService.provision)
      .mockRejectedValueOnce(new Error('gagal'))
      .mockResolvedValueOnce({ school_id: 'x' } as never);
    const store = useDemoWizardStore();

    await store.provision();
    expect(store.error).toBe('gagal');

    await expect(store.provision()).resolves.toBe(true);
    expect(store.error).toBeNull();
  });
});

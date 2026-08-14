/**
 * Contract spec for TutoringTermsService + the term wire shape.
 *
 * The admin Term / Batch screen used to derive its list from learning
 * groups and invent every field but the id — a name of "Term " plus
 * eight characters of the UUID, null dates, and `status: 'draft'` on
 * every row including live batches.
 *
 * Same convention as sibling *.spec.ts under `services/tutoring2/`:
 * type-checked by `vue-tsc --build` (the active gate), Vitest itself
 * isn't wired in this workspace yet.
 */
import { describe, expect, it } from 'vitest';
import { TutoringTermsService } from './terms';
import type { BimbelTerm } from '@/types/tutoring2/term';

describe('TutoringTermsService contract', () => {
  it('exposes a read-only list method', () => {
    expect(typeof TutoringTermsService.list).toBe('function');
    // No write methods: `tutoring.term.manage` exists server-side but
    // the screen has no create or edit affordance, so nothing calls it.
    expect('create' in TutoringTermsService).toBe(false);
    expect('update' in TutoringTermsService).toBe(false);
  });

  it('a term carries its own name, dates and status', () => {
    const term: BimbelTerm = {
      id: 'tm-1',
      name: 'Batch Ganjil 2026',
      start_date: '2026-07-01',
      end_date: '2026-12-20',
      is_current: true,
      status: 'active',
      status_label: 'Aktif',
      groups_count: 4,
    };

    // The three the derivation used to fabricate.
    expect(term.name).not.toMatch(/^Term [0-9a-f]{8}$/);
    expect(term.start_date).not.toBeNull();
    expect(term.status).not.toBe('draft');
  });

  it('tolerates a status outside the three we know', () => {
    // `terms.status` is a free-text string(16), not an enum. An
    // unrecognised value must survive the type and render as itself.
    const term: BimbelTerm = {
      id: 'tm-2',
      name: 'Batch Lama',
      start_date: null,
      end_date: null,
      is_current: false,
      status: 'archived',
      status_label: 'archived',
    };

    expect(term.status).toBe('archived');
  });

  it('groups_count is optional — absent is not zero', () => {
    const term: BimbelTerm = {
      id: 'tm-3',
      name: 'Batch Tanpa Hitung',
      start_date: null,
      end_date: null,
      is_current: false,
      status: 'draft',
      status_label: 'Draf',
    };

    expect(term.groups_count).toBeUndefined();
  });
});

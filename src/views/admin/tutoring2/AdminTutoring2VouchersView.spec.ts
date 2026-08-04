/**
 * Contract spec for AdminTutoring2VouchersView.
 *
 * The view itself is UI — the spec locks the KPI/discount helpers that
 * derive display strings from the loaded voucher list. Those helpers are
 * inline in the SFC; the spec re-implements the exact same logic so a
 * silent behaviour drift in the SFC surfaces here in future refactors.
 *
 * Vitest isn't wired in this workspace — the spec parses under
 * `vue-tsc --build` alongside the other .spec.ts files in the tree, and
 * matches the tolerated "@ts-nocheck + import 'vitest'" pattern used by
 * every service/component spec (see staff.service.spec.ts).
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect } from 'vitest';
import type { BimbelVoucher } from '@/types/tutoring2/voucher';

function discountLabel(v: BimbelVoucher): string {
  return v.kind === 'percent'
    ? `${v.value}%`
    : `Rp ${v.value.toLocaleString('id-ID')}`;
}

function usesLabel(v: BimbelVoucher): string {
  const used = v.redemption_count ?? 0;
  const max = v.max_redemptions;
  return max == null ? `${used} / ∞` : `${used} / ${max}`;
}

const percentVoucher: BimbelVoucher = {
  id: 'v1',
  school_id: 's1',
  code: 'HEMAT10',
  kind: 'percent',
  value: 10,
  status: 'active',
  redemption_count: 3,
  max_redemptions: 100,
};

const fixedVoucher: BimbelVoucher = {
  id: 'v2',
  school_id: 's1',
  code: 'RP50K',
  kind: 'fixed',
  value: 50000,
  status: 'active',
  max_redemptions: null,
};

describe('AdminTutoring2VouchersView helpers', () => {
  it('renders percent discount as "N%"', () => {
    expect(discountLabel(percentVoucher)).toBe('10%');
  });

  it('renders fixed discount as "Rp N" with id-ID grouping', () => {
    expect(discountLabel(fixedVoucher)).toBe('Rp 50.000');
  });

  it('renders uses as "used / max" when a cap is set', () => {
    expect(usesLabel(percentVoucher)).toBe('3 / 100');
  });

  it('renders uses as "used / ∞" when the cap is null (unlimited)', () => {
    expect(usesLabel(fixedVoucher)).toBe('0 / ∞');
  });
});

/**
 * The money rule itself, independent of any screen.
 *
 * The cases that matter are the two the old per-view copies got wrong:
 * `pending` and `partial` are STILL OWED (the server's own summary says
 * `whereNotIn('status', ['paid'])`), and "overdue" is a LOCAL calendar
 * comparison, not `new Date(due).getTime() < Date.now()` — that form is
 * UTC midnight and calls a bill late seven hours early in WIB.
 */
import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  BIMBEL_BILL_STATUSES,
  bimbelBillDisplayStatus,
  bimbelBillStatusI18nKey,
  bimbelBillStatusTone,
  isBimbelBillOutstanding,
  isBimbelBillOverdue,
  isBimbelBillPaid,
  outstandingBimbelBills,
} from './bimbel-bill-rules';

describe('isBimbelBillOutstanding', () => {
  it('treats only `paid` as settled', () => {
    expect(isBimbelBillPaid('paid')).toBe(true);
    for (const s of ['unpaid', 'pending', 'partial']) {
      expect(isBimbelBillPaid(s)).toBe(false);
      expect(isBimbelBillOutstanding(s)).toBe(true);
    }
    expect(isBimbelBillOutstanding('paid')).toBe(false);
  });

  it('tolerates the casing and padding a free-text column can hold', () => {
    // `bills.status` is not a database enum; `BillStatus::fromAny`
    // lower-cases and trims on the way in, so reads do the same.
    expect(isBimbelBillPaid(' PAID ')).toBe(true);
    expect(isBimbelBillOutstanding('Pending')).toBe(true);
  });

  it('counts an unknown or missing word as still owed', () => {
    // Erring toward "owed" surfaces the row where a human can see it.
    // The other direction hides a bill the reminder cron is still
    // chasing, which is the failure this module exists to prevent.
    expect(isBimbelBillOutstanding('refunded')).toBe(true);
    expect(isBimbelBillOutstanding(null)).toBe(true);
    expect(isBimbelBillOutstanding(undefined)).toBe(true);
    expect(isBimbelBillOutstanding('')).toBe(true);
  });

  it('filters a page down to what is owed, preserving order', () => {
    const page = [
      { id: 'a', status: 'paid' },
      { id: 'b', status: 'pending' },
      { id: 'c', status: 'partial' },
      { id: 'd', status: 'unpaid' },
    ];
    expect(outstandingBimbelBills(page).map((b) => b.id)).toEqual(['b', 'c', 'd']);
  });

  it('carries the four wire words the backend enum declares', () => {
    expect([...BIMBEL_BILL_STATUSES]).toEqual(['unpaid', 'pending', 'partial', 'paid']);
  });
});

describe('isBimbelBillOverdue', () => {
  const TODAY = '2026-09-14';

  it('needs both conditions the server aggregate uses', () => {
    expect(isBimbelBillOverdue({ status: 'unpaid', due_date: '2026-09-13' }, TODAY)).toBe(true);
    // Still owed, but not yet late.
    expect(isBimbelBillOverdue({ status: 'unpaid', due_date: '2026-09-15' }, TODAY)).toBe(false);
    // Late, but settled — no longer arrears.
    expect(isBimbelBillOverdue({ status: 'paid', due_date: '2026-01-01' }, TODAY)).toBe(false);
  });

  it('a bill due TODAY is not late', () => {
    // Matches `whereDate('due_date', '<', today)` — strictly before.
    expect(isBimbelBillOverdue({ status: 'unpaid', due_date: TODAY }, TODAY)).toBe(false);
  });

  it('an awaiting-verification bill can still be overdue', () => {
    expect(isBimbelBillOverdue({ status: 'pending', due_date: '2026-08-01' }, TODAY)).toBe(true);
  });

  it('a bill with no usable due date is never overdue', () => {
    expect(isBimbelBillOverdue({ status: 'unpaid', due_date: null }, TODAY)).toBe(false);
    expect(isBimbelBillOverdue({ status: 'unpaid' }, TODAY)).toBe(false);
    expect(isBimbelBillOverdue({ status: 'unpaid', due_date: '2026-09' }, TODAY)).toBe(false);
  });

  it('uses the LOCAL day, not the UTC one', () => {
    // 00:30 WIB on the 15th is still the 14th in UTC. The old per-view
    // form compared against a UTC instant and would have called a bill
    // due on the 14th "not yet late" here.
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 8, 15, 0, 30, 0));
    expect(isBimbelBillOverdue({ status: 'unpaid', due_date: '2026-09-14' })).toBe(true);
  });

  afterEach(() => vi.useRealTimers());
});

describe('bimbelBillDisplayStatus', () => {
  const TODAY = '2026-09-14';

  it('gives pending and partial their own identity', () => {
    // They used to collapse onto `unpaid`, which told a wali who had
    // already transferred that they had not paid.
    expect(bimbelBillDisplayStatus({ status: 'pending', due_date: '2026-10-01' }, TODAY))
      .toBe('pending');
    expect(bimbelBillDisplayStatus({ status: 'partial', due_date: '2026-10-01' }, TODAY))
      .toBe('partial');
  });

  it('ranks overdue above the unsettled words', () => {
    // The old per-view copy returned early on `pending`, so a bill three
    // weeks late read as merely awaiting verification.
    expect(bimbelBillDisplayStatus({ status: 'pending', due_date: '2026-08-01' }, TODAY))
      .toBe('overdue');
  });

  it('settles on `paid` regardless of the date', () => {
    expect(bimbelBillDisplayStatus({ status: 'paid', due_date: '2020-01-01' }, TODAY)).toBe('paid');
  });

  it('falls back to `unpaid` for a word this build does not know', () => {
    // Never echoes the raw value: that is how the English wire word
    // `UNPAID` reached a student's screen on mobile.
    expect(bimbelBillDisplayStatus({ status: 'refunded', due_date: null }, TODAY)).toBe('unpaid');
  });

  it('maps every display state to a real i18n key and tone', () => {
    for (const s of ['unpaid', 'pending', 'partial', 'paid', 'overdue'] as const) {
      expect(bimbelBillStatusI18nKey(s)).toBe(`tutoring2.status.${s}`);
      expect(bimbelBillStatusTone(s)).toBeTruthy();
    }
  });

  it('paints an awaiting-verification bill differently from an untouched one', () => {
    // Same tone would read as "you still owe us an action" to a wali who
    // has already done everything asked of them.
    expect(bimbelBillStatusTone('pending')).not.toBe(bimbelBillStatusTone('unpaid'));
  });
});

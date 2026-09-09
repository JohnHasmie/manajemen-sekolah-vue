/**
 * The derived "Terlewat" state — a session whose time has passed while
 * its status is still `scheduled`, i.e. nobody marked it.
 *
 * ── What is actually at risk ──
 *
 * 1. **The wire must not move.** `Selesai` is the basis for calculating
 *    tutor honor, so it has to keep meaning "the class actually
 *    happened". Terlewat is a *reading* of `scheduled`, not a fifth
 *    status: it may not reach `SessionStatus`, the database, a request
 *    body, `BIMBEL_SESSION_STATUSES`, or a filter query. The last block
 *    below pins that.
 * 2. **Only `scheduled` may become it.** A past `cancelled` session is
 *    cancelled — the reason it did not happen is already recorded. A
 *    past `in_progress` session is the trace of a human starting the
 *    class, so it is not *unmarked*.
 * 3. **The comparison must be between INSTANTS, in local time.** The
 *    house bug this repo keeps re-learning is `toISOString().slice(0,10)`
 *    day arithmetic, which reads the UTC calendar day and so shifts by
 *    one for the first seven hours of every WIB day. The boundary block
 *    constructs the exact case where that form and the correct one
 *    DISAGREE, and asserts both verdicts.
 *
 * ── Anti-vacuity notes ──
 *
 * Every block pins `process.env.TZ = 'Asia/Jakarta'` and then asserts the
 * premise before the conclusion — `getTimezoneOffset() === -420`, and for
 * the boundary cases the WIB wall-clock hour of the fixture itself
 * (`getHours() === 21`). On a UTC CI runner the premise assertions fail
 * loudly rather than the whole file passing for the wrong reason: 21:00
 * WIB is 14:00 UTC, so a runner that ignored the TZ override would read
 * 14 and stop there.
 *
 * `now` is injected everywhere rather than faked globally, so no test
 * depends on the date it happens to be run on.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  bimbelSessionDisplayStatus,
  bimbelSessionIsMissed,
  bimbelSessionStatusLabel,
  bimbelSessionStatusTone,
  bimbelStatusLabel,
  type BimbelSessionStatusInput,
} from './bimbel-session-status';
import {
  BIMBEL_SESSION_STATUSES,
  type BimbelSessionStatus,
} from '@/services/tutoring-bimbel.service';
import { toLocalYmd } from './local-date';

/** The real `tutoring2.status.*` values, so labels are asserted verbatim. */
const MESSAGES: Record<string, string> = {
  'tutoring2.status.scheduled': 'Terjadwal',
  'tutoring2.status.missed': 'Terlewat',
  'tutoring2.status.inProgress': 'Berlangsung',
  'tutoring2.status.done': 'Selesai',
  'tutoring2.status.cancelled': 'Dibatalkan',
};

/**
 * Throws on an unknown key rather than echoing it. A helper that asked
 * for `tutoring2.status.missed` while the locale file had no such key
 * would otherwise "pass" by rendering the key path to the user.
 */
const t = (key: string): string => {
  const hit = MESSAGES[key];
  if (hit === undefined) throw new Error(`missing i18n key: ${key}`);
  return hit;
};

function session(over: Partial<BimbelSessionStatusInput> = {}) {
  return {
    status: 'scheduled',
    ends_at: '2026-09-09T10:00:00+07:00',
    status_label: 'Terjadwal',
    ...over,
  } as BimbelSessionStatusInput;
}

const REAL_TZ = process.env.TZ;

beforeAll(() => {
  // WIB (UTC+7) — every tenant on this platform is in it.
  process.env.TZ = 'Asia/Jakarta';
});
afterAll(() => {
  process.env.TZ = REAL_TZ;
});

describe('which statuses may become Terlewat', () => {
  // 12:00 WIB on 9 Sep; every fixture below ends at 10:00 WIB the same
  // day, i.e. two hours BEFORE this — comfortably past.
  const NOW = new Date('2026-09-09T12:00:00+07:00');

  it('pins the WIB premise these cases rest on', () => {
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(NOW.getHours()).toBe(12);
    expect(new Date('2026-09-09T10:00:00+07:00').getHours()).toBe(10);
  });

  it('reads a past unmarked session as Terlewat', () => {
    const s = session({ status: 'scheduled' });
    expect(bimbelSessionDisplayStatus(s, NOW)).toBe('missed');
    expect(bimbelSessionIsMissed(s, NOW)).toBe(true);
    expect(bimbelSessionStatusLabel(s, t, NOW)).toBe('Terlewat');
    expect(bimbelSessionStatusTone(s, NOW)).toBe('warning');
  });

  it('leaves a FUTURE scheduled session reading Terjadwal', () => {
    const s = session({ ends_at: '2026-09-09T14:00:00+07:00' });
    expect(bimbelSessionDisplayStatus(s, NOW)).toBe('scheduled');
    expect(bimbelSessionIsMissed(s, NOW)).toBe(false);
    expect(bimbelSessionStatusLabel(s, t, NOW)).toBe('Terjadwal');
    expect(bimbelSessionStatusTone(s, NOW)).toBe('neutral');
  });

  it('leaves a PAST CANCELLED session reading Dibatalkan', () => {
    // The reason it did not happen is already on the record. Calling it
    // "missed" would overwrite that with a vaguer, wronger claim.
    const s = session({ status: 'cancelled', status_label: 'Dibatalkan' });
    expect(bimbelSessionDisplayStatus(s, NOW)).toBe('cancelled');
    expect(bimbelSessionIsMissed(s, NOW)).toBe(false);
    expect(bimbelSessionStatusLabel(s, t, NOW)).toBe('Dibatalkan');
    expect(bimbelSessionStatusTone(s, NOW)).toBe('danger');
  });

  it('leaves a long-past IN_PROGRESS session reading Berlangsung', () => {
    // A deliberate product choice, not an oversight. `in_progress` is
    // the trace of somebody starting the class, so the session is not
    // "unmarked"; folding it in would erase the difference between
    // "nobody touched this" and "the tutor started it and forgot to
    // close it", which need different follow-ups.
    const s = session({
      status: 'in_progress',
      status_label: 'Berlangsung',
      ends_at: '2026-08-01T10:00:00+07:00', // five weeks before NOW
    });
    expect(bimbelSessionDisplayStatus(s, NOW)).toBe('in_progress');
    expect(bimbelSessionIsMissed(s, NOW)).toBe(false);
    expect(bimbelSessionStatusLabel(s, t, NOW)).toBe('Berlangsung');
    expect(bimbelSessionStatusTone(s, NOW)).toBe('info');
  });

  it('leaves a past DONE session reading Selesai', () => {
    const s = session({ status: 'done', status_label: 'Selesai' });
    expect(bimbelSessionDisplayStatus(s, NOW)).toBe('done');
    expect(bimbelSessionStatusLabel(s, t, NOW)).toBe('Selesai');
    expect(bimbelSessionStatusTone(s, NOW)).toBe('success');
  });

  it('does not guess when the wire sent no end time', () => {
    // "We were not told when this ends" is not evidence that it ended.
    for (const ends of [null, undefined, '', 'not-a-date']) {
      const s = session({ ends_at: ends as string | null });
      expect(bimbelSessionDisplayStatus(s, NOW)).toBe('scheduled');
    }
  });
});

describe('status_label precedence', () => {
  const NOW = new Date('2026-09-09T12:00:00+07:00');

  it('lets the derived Terlewat OVERRIDE the wire label', () => {
    // The server stamps `status_label` when it serializes the row, off
    // the same four values. It cannot know the end time has passed —
    // "passed" is relative to the reader's clock at the moment of
    // reading, and a row fetched at 20:59 is still on screen at 21:01.
    // Without this override the wire's "Terjadwal" wins and the whole
    // change is invisible on every screen.
    const s = session({ status: 'scheduled', status_label: 'Terjadwal' });
    expect(s.status_label).toBe('Terjadwal'); // the value being overridden
    expect(bimbelSessionStatusLabel(s, t, NOW)).toBe('Terlewat');
  });

  it('keeps wire-first precedence for every OTHER status', () => {
    const s = session({
      status: 'done',
      // Deliberately not one of this client's four labels: if the helper
      // ignored the wire, it would render "Selesai" and this would fail.
      status_label: 'Selesai (diverifikasi admin)',
    });
    expect(bimbelSessionStatusLabel(s, t, NOW)).toBe(
      'Selesai (diverifikasi admin)',
    );
  });

  it('falls back to the local label when the wire sent none', () => {
    const s = session({ status: 'done', status_label: null });
    expect(bimbelSessionStatusLabel(s, t, NOW)).toBe('Selesai');
  });
});

describe('the past/not-past boundary is in LOCAL time', () => {
  it('does not call a session ending 21:00 WIB missed at 15:00 WIB the same day', () => {
    // The reported shape of the bug, stated in wall-clock terms.
    const endsAt = '2026-09-09T21:00:00+07:00';
    const now = new Date('2026-09-09T15:00:00+07:00');

    // Premise first — on a UTC runner these read 14 and 08 and fail here
    // rather than letting the conclusion pass vacuously.
    expect(now.getTimezoneOffset()).toBe(-420);
    expect(new Date(endsAt).getHours()).toBe(21);
    expect(now.getHours()).toBe(15);

    expect(bimbelSessionDisplayStatus(session({ ends_at: endsAt }), now)).toBe(
      'scheduled',
    );
  });

  it('disagrees with UTC day arithmetic exactly where UTC day arithmetic is wrong', () => {
    // A session running 04:00–06:00 WIB on 10 Sep, read at 05:00 WIB —
    // it is HAPPENING. Both instants fall on 9 Sep in UTC, so the WIB
    // calendar day (the 10th) and the UTC calendar day (the 9th) differ,
    // which is precisely the window `toISOString().slice(0, 10)` gets
    // wrong.
    const endsAt = '2026-09-10T06:00:00+07:00';
    const now = new Date('2026-09-10T05:00:00+07:00');

    expect(now.getTimezoneOffset()).toBe(-420);
    expect(new Date(endsAt).getHours()).toBe(6);
    expect(now.getHours()).toBe(5);

    // The buggy form, spelled out and asserted so the disagreement is
    // demonstrated rather than claimed: it compares LOCAL today against
    // the end time's UTC day, and concludes the session is behind us.
    const utcDayOfEnd = new Date(endsAt).toISOString().slice(0, 10);
    expect(utcDayOfEnd).toBe('2026-09-09');
    expect(toLocalYmd(now)).toBe('2026-09-10');
    expect(toLocalYmd(now) > utcDayOfEnd).toBe(true); // "past" — wrong

    // The instant comparison, which is the one shipped.
    expect(new Date(endsAt).getTime()).toBeGreaterThan(now.getTime());
    expect(bimbelSessionDisplayStatus(session({ ends_at: endsAt }), now)).toBe(
      'scheduled',
    );
  });

  it('flips at the end time, not before it', () => {
    const endsAt = '2026-09-09T21:00:00+07:00';
    expect(new Date(endsAt).getHours()).toBe(21);

    // Exactly at ends_at the session has only just finished; nobody has
    // had a chance to mark it, and it is not yet "missed".
    expect(
      bimbelSessionDisplayStatus(session({ ends_at: endsAt }), new Date(endsAt)),
    ).toBe('scheduled');

    // One millisecond later it is.
    expect(
      bimbelSessionDisplayStatus(
        session({ ends_at: endsAt }),
        new Date(new Date(endsAt).getTime() + 1),
      ),
    ).toBe('missed');
  });
});

describe('the wire is untouched', () => {
  it('keeps BIMBEL_SESSION_STATUSES to the four real statuses', () => {
    // This array is the filter picker's source of truth AND drives the
    // `status` query parameter. A `missed` leaking in here would build a
    // filter that queries a value the API rejects.
    expect([...BIMBEL_SESSION_STATUSES].sort()).toEqual([
      'cancelled',
      'done',
      'in_progress',
      'scheduled',
    ]);
    expect(BIMBEL_SESSION_STATUSES as string[]).not.toContain('missed');
  });

  it('gives the filter picker a label for every wire status and no other', () => {
    // `bimbelStatusLabel` takes a bare status, so it is structurally
    // incapable of producing "Terlewat" — a picker cannot offer a value
    // the query does not accept.
    const labels = BIMBEL_SESSION_STATUSES.map((s: BimbelSessionStatus) =>
      bimbelStatusLabel(s, t),
    );
    expect(labels).toEqual([
      'Terjadwal',
      'Berlangsung',
      'Selesai',
      'Dibatalkan',
    ]);
    expect(labels).not.toContain('Terlewat');
  });

  it('never mutates the session it is handed', () => {
    // The display state is derived on read. Anything posted back must
    // still carry `scheduled`.
    const s = session({ status: 'scheduled' });
    const before = JSON.stringify(s);
    bimbelSessionStatusLabel(s, t, new Date('2026-09-09T12:00:00+07:00'));
    bimbelSessionStatusTone(s, new Date('2026-09-09T12:00:00+07:00'));
    expect(JSON.stringify(s)).toBe(before);
    expect(s.status).toBe('scheduled');
  });
});

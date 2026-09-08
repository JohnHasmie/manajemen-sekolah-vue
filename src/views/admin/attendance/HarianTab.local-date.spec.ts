/**
 * Kehadiran Siswa · Harian — the tab's default day must be the LOCAL
 * calendar day, and its prev/next stepper must land exactly one day away.
 *
 * The default was `new Date().toISOString().slice(0, 10)`, i.e. the UTC
 * day, which is the shortcut `lib/local-date.ts` exists to replace. In
 * WIB (UTC+7) that string is YESTERDAY until 07:00, and it is not a
 * cosmetic label: it goes straight into `GET /attendance/students/daily`
 * as `date`. An admin opening the page at 06:30 got yesterday's roster
 * — including a "belum absen" list for a day that had already closed,
 * behind a header reading today's name.
 *
 * ── Why the TZ pinning matters ──
 *
 * Every assertion below is timezone-sensitive by construction. On a
 * UTC CI runner the buggy form and the correct form agree, so a spec
 * that did not pin the zone would pass against the unfixed code and
 * prove nothing. Each block therefore forces Asia/Jakarta, asserts the
 * offset actually took (-420 minutes), and asserts what the OLD form
 * returns before asserting what the NEW one must return.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import HarianTab from './HarianTab.vue';
import { AttendanceDailyService } from '@/services/attendance-daily.service';
import { AttendanceQrService } from '@/services/attendance-qr.service';

vi.mock('@/services/attendance-daily.service', () => ({
  AttendanceDailyService: {
    getDailyRoster: vi.fn(),
    remindGuardians: vi.fn(),
  },
}));

vi.mock('@/services/attendance-qr.service', () => ({
  AttendanceQrService: {
    getCurrentGateQrToken: vi.fn(),
    rotateGateQrToken: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

vi.mock('@/stores/me', () => ({
  useMeStore: () => ({ can: () => true }),
}));

const EMPTY_ROSTER = {
  data: [],
  kpi: {
    present: 0,
    late: 0,
    excused: 0,
    sick: 0,
    absent: 0,
    unrecorded: 0,
    total: 0,
  },
  method_mix: { QR_GATE: 0, QR_CARD: 0, SELFIE: 0, MANUAL: 0 },
  recent_check_ins: [],
};

async function mountTab() {
  setActivePinia(createPinia());
  vi.mocked(AttendanceDailyService.getDailyRoster).mockResolvedValue(EMPTY_ROSTER);
  vi.mocked(AttendanceQrService.getCurrentGateQrToken).mockResolvedValue(null);

  const w = mount(HarianTab, {
    global: { stubs: { teleport: true, SegmentedControl: true, QrcodeVue: true } },
  });
  await flushPromises();
  return w;
}

/** The `date` of every roster request, oldest first. */
function requestedDates() {
  return vi.mocked(AttendanceDailyService.getDailyRoster).mock.calls.map((c) => c[0]?.date);
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Harian · default day is the LOCAL calendar day', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
  });

  it('asks for TODAY at 01:30 WIB, when UTC still says yesterday', async () => {
    // 2026-09-14T18:30Z === 15 Sep 2026, 01:30 WIB.
    vi.setSystemTime(new Date('2026-09-14T18:30:00Z'));

    // Premise guards — without these the spec is vacuous on a UTC runner.
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-14'); // the buggy form

    await mountTab();

    expect(requestedDates()).toEqual(['2026-09-15']); // the correct one
  });

  it('agrees with the UTC form once WIB is past 07:00', async () => {
    // 12:00 WIB — the two forms coincide here, which is exactly why the
    // bug survived: it is invisible for 17 hours of every day.
    vi.setSystemTime(new Date('2026-09-15T05:00:00Z'));
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-15');

    await mountTab();

    expect(requestedDates()).toEqual(['2026-09-15']);
  });

  it('rolls into the new month at 00:10 WIB on the 1st', async () => {
    // 2026-08-31T17:10Z === 1 Sep 2026, 00:10 WIB. The UTC form does not
    // just lose a day here, it reports the wrong MONTH.
    vi.setSystemTime(new Date('2026-08-31T17:10:00Z'));
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-08-31'); // the buggy form

    await mountTab();

    expect(requestedDates()).toEqual(['2026-09-01']);
  });
});

/**
 * The stepper is NOT the bug — it is left on `toISOString()` on purpose,
 * and this block is here so that stays a decision rather than an
 * oversight. `new Date('YYYY-MM-DD')` parses as UTC midnight and
 * `setDate` shifts the local day while holding the local wall clock, so
 * in a DST-free zone the instant moves exactly 24h and the value stays
 * on UTC midnight. Parse and serialize cancel out; breaking the pair by
 * converting only one half would introduce an off-by-one, not remove one.
 */
describe('Harian · prev/next stepper lands exactly one day away', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
  });

  it('steps back and forward across a month boundary without drift', async () => {
    vi.setSystemTime(new Date('2026-09-01T00:10:00+07:00'));
    const w = await mountTab();
    expect(requestedDates().at(-1)).toBe('2026-09-01');

    await w.get('button[aria-label="Sebelumnya"]').trigger('click');
    await flushPromises();
    expect(requestedDates().at(-1)).toBe('2026-08-31');

    await w.get('button[aria-label="Berikutnya"]').trigger('click');
    await flushPromises();
    expect(requestedDates().at(-1)).toBe('2026-09-01');
  });
});

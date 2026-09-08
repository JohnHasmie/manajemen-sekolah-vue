/**
 * Kehadiran Siswa · Per Mapel — the tab's default day must be the LOCAL
 * calendar day.
 *
 * Same defect as the Harian tab next door, same cause: the ref was
 * seeded with `new Date().toISOString().slice(0, 10)`, the UTC day. It
 * is sent as BOTH `date_start` and `date_end` of the summary request,
 * so before 07:00 WIB the tab listed yesterday's sessions and the
 * "Belum diinput guru" card named teachers for a day they had already
 * closed.
 *
 * The TZ is pinned to Asia/Jakarta and the OLD form's output is asserted
 * before the new one's: in UTC the two agree, so an unpinned spec would
 * pass against the unfixed code and prove nothing.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import PerMapelTab from './PerMapelTab.vue';
import { AttendanceService } from '@/services/attendance.service';

vi.mock('@/services/attendance.service', () => ({
  AttendanceService: { getAdminSummary: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

async function mountTab() {
  setActivePinia(createPinia());
  vi.mocked(AttendanceService.getAdminSummary).mockResolvedValue({ items: [] });

  const w = mount(PerMapelTab, {
    global: { stubs: { teleport: true, SegmentedControl: true } },
  });
  await flushPromises();
  return w;
}

/** `[date_start, date_end]` of every summary request, oldest first. */
function requestedWindows() {
  return vi
    .mocked(AttendanceService.getAdminSummary)
    .mock.calls.map((c) => [c[0]?.date_start, c[0]?.date_end]);
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Per Mapel · default day is the LOCAL calendar day', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
  });

  it('asks for TODAY at 06:30 WIB, when UTC still says yesterday', async () => {
    // 2026-09-14T23:30Z === 15 Sep 2026, 06:30 WIB — half an hour before
    // the UTC day catches up, and squarely inside the window when an
    // admin arrives at school.
    vi.setSystemTime(new Date('2026-09-14T23:30:00Z'));

    // Premise guards — without these the spec is vacuous on a UTC runner.
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-14'); // the buggy form

    await mountTab();

    expect(requestedWindows()).toEqual([['2026-09-15', '2026-09-15']]);
  });

  it('rolls into the new year at 00:05 WIB on 1 Jan', async () => {
    // 2026-12-31T17:05Z === 1 Jan 2027, 00:05 WIB. The UTC form is a
    // whole YEAR out here, which is what makes this shape worth a test
    // rather than a comment.
    vi.setSystemTime(new Date('2026-12-31T17:05:00Z'));
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-12-31'); // the buggy form

    await mountTab();

    expect(requestedWindows()).toEqual([['2027-01-01', '2027-01-01']]);
  });

  it('steps to the adjacent day without drift', async () => {
    vi.setSystemTime(new Date('2027-01-01T00:05:00+07:00'));
    const w = await mountTab();
    expect(requestedWindows().at(-1)).toEqual(['2027-01-01', '2027-01-01']);

    await w.get('button[aria-label="Sebelumnya"]').trigger('click');
    await flushPromises();
    expect(requestedWindows().at(-1)).toEqual(['2026-12-31', '2026-12-31']);

    await w.get('button[aria-label="Berikutnya"]').trigger('click');
    await flushPromises();
    expect(requestedWindows().at(-1)).toEqual(['2027-01-01', '2027-01-01']);
  });
});

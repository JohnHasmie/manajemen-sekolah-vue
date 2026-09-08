/**
 * Export filenames carry a LOCAL date stamp.
 *
 * Ten download sites across the app stamped their filename with
 * `new Date().toISOString().slice(0, 10)`. None of them drives a query,
 * so this was never the day-shifted-report bug — but an admin who
 * exports "Data Siswa" at 06:00 WIB should not receive a file named for
 * yesterday, and would have no way to tell from the name that the
 * contents are current. The repo already settled this convention
 * elsewhere (`AdminTutoring2AttendanceView.spec.ts` asserts the same
 * thing for the bimbel attendance export); this pins it for the shared
 * Manajemen Data service that four admin screens go through.
 *
 * TZ is pinned to Asia/Jakarta because the two forms are identical in
 * UTC — an unpinned spec would pass against the unfixed code.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { AdminDataExcelService } from './admin-data-excel.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: { get: vi.fn(), post: vi.fn() },
}));

/** Filenames handed to the anchor element, oldest first. */
let downloaded: string[] = [];

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  downloaded = [];

  // jsdom ships no object-URL implementation.
  globalThis.URL.createObjectURL = vi.fn(() => 'blob:stub');
  globalThis.URL.revokeObjectURL = vi.fn();

  const realCreate = document.createElement.bind(document);
  vi.spyOn(document, 'createElement').mockImplementation((tag: string) => {
    const el = realCreate(tag);
    if (tag === 'a') {
      el.click = () => downloaded.push(el.download);
    }
    return el;
  });
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe('AdminDataExcelService · export filename stamp', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
  });

  it('stamps the LOCAL day when UTC is still on yesterday', async () => {
    // 2026-09-14T22:00Z === 15 Sep 2026, 05:00 WIB.
    vi.setSystemTime(new Date('2026-09-14T22:00:00Z'));

    // Premise guards — without these the spec is vacuous on a UTC runner.
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-14'); // the buggy form

    vi.mocked(api.post).mockResolvedValue({ data: new Blob(['x']) });
    await AdminDataExcelService.exportExcel('student');

    expect(downloaded).toEqual(['siswa-2026-09-15.xlsx']);
  });

  it('agrees with the UTC form later in the day', async () => {
    vi.setSystemTime(new Date('2026-09-15T05:00:00Z')); // 12:00 WIB
    vi.mocked(api.post).mockResolvedValue({ data: new Blob(['x']) });
    await AdminDataExcelService.exportExcel('teacher');

    expect(downloaded).toEqual(['guru-2026-09-15.xlsx']);
  });
});

/**
 * Vitest spec for TutoringReportsService — pins the BE-28 wire
 * contract:
 *   - the three GET endpoints under `/tutoring-v2/admin/reports/*`
 *   - `?from=YYYY-MM-DD&to=YYYY-MM-DD` params forwarded verbatim
 *   - the `{ data, meta }` envelope unwrapped to `{ rows, meta }`
 *   - the PDF-URL builder produces `?_school_id=…&from=…&to=…` in the
 *     query and hits the `/pdf` suffix.
 *
 * Plus the tiny csvFrom helper — quoting rules matter (mis-quoted rows
 * silently corrupt Excel imports).
 *
 * Same convention as the other web-vue specs: Vitest API,
 * type-checked by `vue-tsc --build`. Vitest itself isn't wired yet —
 * vue-tsc is the active gate.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { csvFrom, TutoringReportsService } from './reports';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    defaults: { baseURL: 'http://api.test/api' },
  },
}));

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ schoolId: 'school-uuid-abc' }),
}));

describe('TutoringReportsService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('getActivityReport hits /tutoring-v2/admin/reports/activity with from/to', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            date: '2026-08-01',
            sessions_scheduled: 3,
            sessions_completed: 2,
            sessions_cancelled: 0,
            attendance_marked_count: 12,
          },
        ],
        meta: { from: '2026-08-01', to: '2026-08-31' },
      },
    });
    const res = await TutoringReportsService.getActivityReport({
      from: '2026-08-01',
      to: '2026-08-31',
    });
    expect((api.get as any).mock.calls[0][0]).toBe('/tutoring-v2/admin/reports/activity');
    expect((api.get as any).mock.calls[0][1].params).toEqual({
      from: '2026-08-01',
      to: '2026-08-31',
    });
    expect(res.rows).toHaveLength(1);
    expect(res.rows[0].sessions_scheduled).toBe(3);
    expect(res.meta).toEqual({ from: '2026-08-01', to: '2026-08-31' });
  });

  it('getAttendanceReport hits /tutoring-v2/admin/reports/attendance', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            enrollment_id: 'enr-1',
            student_name: 'Nadia',
            program_name: 'SBMPTN Saintek',
            sessions_planned: 8,
            hadir: 7,
            izin: 0,
            sakit: 1,
            alpa: 0,
            attendance_rate: 0.875,
          },
        ],
        meta: { from: '2026-08-01', to: '2026-08-31' },
      },
    });
    const res = await TutoringReportsService.getAttendanceReport({
      from: '2026-08-01',
      to: '2026-08-31',
    });
    expect((api.get as any).mock.calls[0][0]).toBe('/tutoring-v2/admin/reports/attendance');
    expect(res.rows[0].attendance_rate).toBeCloseTo(0.875);
  });

  it('getFinancialReport hits /tutoring-v2/admin/reports/financial', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            date: '2026-08-01',
            bills_created_count: 4,
            bills_created_amount: 6_000_000,
            bills_paid_amount: 4_500_000,
            bills_overdue_amount: 500_000,
            refunds_amount: 0,
          },
        ],
        meta: { from: '2026-08-01', to: '2026-08-31' },
      },
    });
    const res = await TutoringReportsService.getFinancialReport({
      from: '2026-08-01',
      to: '2026-08-31',
    });
    expect((api.get as any).mock.calls[0][0]).toBe('/tutoring-v2/admin/reports/financial');
    expect(res.rows[0].bills_created_amount).toBe(6_000_000);
    expect(res.rows[0].refunds_amount).toBe(0);
  });

  it('PDF-URL builders carry _school_id, from, to on the /pdf suffix', () => {
    const url = TutoringReportsService.buildActivityReportPdfUrl({
      from: '2026-08-01',
      to: '2026-08-31',
    });
    expect(url).toContain('/tutoring-v2/admin/reports/activity/pdf');
    expect(url).toContain('_school_id=school-uuid-abc');
    expect(url).toContain('from=2026-08-01');
    expect(url).toContain('to=2026-08-31');

    expect(
      TutoringReportsService.buildAttendanceReportPdfUrl({ from: '2026-08-01', to: '2026-08-31' }),
    ).toContain('/tutoring-v2/admin/reports/attendance/pdf');
    expect(
      TutoringReportsService.buildFinancialReportPdfUrl({ from: '2026-08-01', to: '2026-08-31' }),
    ).toContain('/tutoring-v2/admin/reports/financial/pdf');
  });
});

describe('csvFrom', () => {
  it('quotes fields containing commas, quotes, or newlines', () => {
    const csv = csvFrom(
      [
        { name: 'Nadia', note: 'no comma' },
        { name: 'Ali, Jr.', note: 'has, comma' },
        { name: 'Bob "the Builder"', note: 'has "quotes"' },
        { name: 'Zed', note: 'line1\nline2' },
      ],
      [
        { key: 'name', header: 'Name' },
        { key: 'note', header: 'Note' },
      ],
    );
    expect(csv.startsWith('Name,Note\r\n')).toBe(true);
    expect(csv).toContain('Nadia,no comma');
    expect(csv).toContain('"Ali, Jr.","has, comma"');
    expect(csv).toContain('"Bob ""the Builder""","has ""quotes"""');
    expect(csv).toContain('"line1\nline2"');
  });

  it('renders missing keys as empty strings and stable column order', () => {
    const csv = csvFrom(
      [{ a: 1 } as any, { a: 2, b: 3 } as any],
      [
        { key: 'a', header: 'A' },
        { key: 'b', header: 'B' },
      ],
    );
    expect(csv).toBe('A,B\r\n1,\r\n2,3');
  });
});

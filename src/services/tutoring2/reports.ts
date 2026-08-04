/**
 * TutoringReportsService — thin wrapper over BE-28 admin report
 * endpoints (`/api/tutoring-v2/admin/reports/*`).
 *
 * Two flavours per report:
 *
 *   1. JSON fetchers (`getActivityReport`, …) — return typed rows +
 *      `{from, to}` meta. The view renders the tables + KPI strip from
 *      these directly.
 *
 *   2. PDF-URL builders (`buildActivityReportPdfUrl`, …) — return the
 *      fully-qualified download URL including `?_school_id=…&from=…&to=…`
 *      so the view can drop it into `window.open()` or an `<a href>`
 *      without having to stream the blob through axios first. Auth is
 *      cookie-backed for the SPA (Laravel Sanctum) so the browser
 *      request carries the same session as the axios calls above.
 *
 * Plus a tiny `csvFrom(rows, columns)` writer used by all three views
 * for a client-side "Download CSV". We don't have a shared csv helper
 * in the repo (grep for `useCsvExport` / `csvFrom` — nothing), so this
 * lives here and can be lifted to `src/lib/` if a second consumer
 * appears.
 */
import { api } from '@/lib/http';
import { useAuthStore } from '@/stores/auth';
import type {
  ActivityReportRow,
  AttendanceReportRow,
  FinancialReportRow,
  ReportEnvelope,
  ReportRangeMeta,
  ReportRangeParams,
} from '@/types/tutoring2/report';

/** Result envelope surfaced to views — data + meta unwrapped. */
export interface ReportResult<T> {
  rows: T[];
  meta: ReportRangeMeta;
}

// ── Internals ──────────────────────────────────────────────────────────

/**
 * Build the fully-qualified URL for a GET endpoint under the main API
 * base. Reads the school id from the auth store so the URL is
 * self-contained (needed for `window.open` — headers aren't sent by an
 * anchor navigation; `_school_id` is the query-param fallback the
 * backend Controller::getSchoolId() honours).
 */
function buildAbsoluteUrl(path: string, params: Record<string, string | undefined>): string {
  const base = api.defaults.baseURL ?? '';
  const url = new URL(`${base.replace(/\/+$/, '')}${path}`, window.location.origin);
  const auth = useAuthStore();
  if (auth.schoolId) {
    url.searchParams.set('_school_id', auth.schoolId);
  }
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== '') url.searchParams.set(k, v);
  }
  return url.toString();
}

async function fetchReport<T>(
  path: string,
  range: ReportRangeParams,
): Promise<ReportResult<T>> {
  const r = await api.get<ReportEnvelope<T>>(path, {
    params: { from: range.from, to: range.to },
  });
  return { rows: r.data.data, meta: r.data.meta };
}

// ── CSV helper ─────────────────────────────────────────────────────────

/**
 * Serialise a row set to CSV and trigger a browser download. Kept tiny
 * on purpose — RFC 4180 essentials only:
 *   - quote fields containing `,`, `"`, `\n`, `\r`
 *   - escape `"` as `""`
 *   - CRLF line endings
 *
 * `columns` locks header order; only listed columns are emitted (rows
 * carrying extra fields are ignored, and missing fields render blank).
 */
export function csvFrom<T extends Record<string, unknown>>(
  rows: T[],
  columns: Array<{ key: keyof T; header: string }>,
): string {
  const escape = (v: unknown): string => {
    if (v == null) return '';
    const s = String(v);
    return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const head = columns.map((c) => escape(c.header)).join(',');
  const body = rows
    .map((r) => columns.map((c) => escape(r[c.key])).join(','))
    .join('\r\n');
  return `${head}\r\n${body}`;
}

/** Trigger a browser download for a text blob (CSV/TSV/etc.). */
export function downloadCsv(content: string, filename: string): void {
  // Prepending BOM so Excel opens UTF-8 content without mojibake.
  const blob = new Blob([`﻿${content}`], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  try {
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
  } finally {
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}

// ── Public API ─────────────────────────────────────────────────────────

export const TutoringReportsService = {
  // Activity ────────────────────────────────────────────────────────
  async getActivityReport(range: ReportRangeParams): Promise<ReportResult<ActivityReportRow>> {
    return fetchReport<ActivityReportRow>('/tutoring-v2/admin/reports/activity', range);
  },
  buildActivityReportPdfUrl(range: ReportRangeParams): string {
    return buildAbsoluteUrl('/tutoring-v2/admin/reports/activity/pdf', {
      from: range.from,
      to: range.to,
    });
  },

  // Attendance ──────────────────────────────────────────────────────
  async getAttendanceReport(range: ReportRangeParams): Promise<ReportResult<AttendanceReportRow>> {
    return fetchReport<AttendanceReportRow>('/tutoring-v2/admin/reports/attendance', range);
  },
  buildAttendanceReportPdfUrl(range: ReportRangeParams): string {
    return buildAbsoluteUrl('/tutoring-v2/admin/reports/attendance/pdf', {
      from: range.from,
      to: range.to,
    });
  },

  // Financial ───────────────────────────────────────────────────────
  async getFinancialReport(range: ReportRangeParams): Promise<ReportResult<FinancialReportRow>> {
    return fetchReport<FinancialReportRow>('/tutoring-v2/admin/reports/financial', range);
  },
  buildFinancialReportPdfUrl(range: ReportRangeParams): string {
    return buildAbsoluteUrl('/tutoring-v2/admin/reports/financial/pdf', {
      from: range.from,
      to: range.to,
    });
  },
};

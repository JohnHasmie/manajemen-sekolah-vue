/**
 * AdminDataExcelService — shared Excel helpers for admin Manajemen
 * Data pages (Student / Teacher / Kelas / Mapel).
 *
 * Each entity has the same 3-call surface on the backend:
 *   GET    /{entity}/template   — XLSX template download
 *   POST   /{entity}/export     — XLSX export of all rows
 *   POST   /{entity}/import     — multipart upload to bulk-create
 *
 * This service wraps the blob plumbing + filename generation so the
 * 4 views don't repeat the boilerplate.
 */
import { api } from '@/lib/http';

export type AdminEntity = 'student' | 'teacher' | 'class' | 'subject';

/** One actionable import row (conflict or failure) the admin should review. */
export interface ImportReviewRow {
  row: number;
  name: string;
  email: string;
  type: 'conflict' | 'failed';
  reason: string;
}

function humanError(e: unknown, fallback: string): string {
  const ax = e as any;
  if (ax?.response?.data) {
    const data = ax.response.data;
    if (typeof data === 'string') return data;
    if (data?.message) return String(data.message);
    if (data?.error) return String(data.error);
    if (data?.errors && typeof data.errors === 'object') {
      const first = Object.values(data.errors)[0];
      if (Array.isArray(first) && first.length > 0) return String(first[0]);
    }
  }
  if (e instanceof Error) return e.message;
  return fallback;
}

function triggerBlobDownload(blob: Blob, filename: string): void {
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

const LABELS: Record<AdminEntity, string> = {
  student: 'siswa',
  teacher: 'guru',
  class: 'kelas',
  subject: 'mata-pelajaran',
};

export const AdminDataExcelService = {
  async downloadTemplate(entity: AdminEntity): Promise<void> {
    try {
      const res = await api.get(`/${entity}/template`, {
        responseType: 'blob',
      });
      triggerBlobDownload(res.data as Blob, `template-${LABELS[entity]}.xlsx`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengunduh template.'));
    }
  },

  async exportExcel(entity: AdminEntity): Promise<void> {
    try {
      const res = await api.post(`/${entity}/export`, undefined, {
        responseType: 'blob',
      });
      const ts = new Date().toISOString().slice(0, 10);
      triggerBlobDownload(res.data as Blob, `${LABELS[entity]}-${ts}.xlsx`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengekspor data.'));
    }
  },

  async importExcel(
    entity: AdminEntity,
    file: File,
  ): Promise<{
    imported: number;
    failed: number;
    skipped: number;
    conflicts: number;
    message?: string;
    // Per-row detail for the rows that need admin attention (conflicts +
    // failures) — so the UI can name WHICH row and WHY. Empty for importers
    // that don't report it.
    review: ImportReviewRow[];
  }> {
    try {
      const fd = new FormData();
      fd.append('file', file);
      const res = await api.post(`/${entity}/import`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const body = res.data ?? {};
      // Backend shapes vary across importers. StudentsImport / ClassesImport
      // respond with { message, results: { success, failed, errors } };
      // TeachersImport adds { results: { created, restored, skipped,
      // conflicts, ... } } so "already exists" is no longer mislabelled as a
      // failure. We read top-level first, then `results.*`.
      //
      // `success` is the universal "rows that ended up present" count (for
      // teachers = created + restored), so it is preferred over `created`.
      // `skipped` (already there) and `conflicts` (email used elsewhere) are
      // NOT failures — they are surfaced separately and default to 0 for the
      // importers that don't report them.
      const results = (body.results ?? {}) as Record<string, unknown>;
      const num = (...vals: unknown[]): number => {
        for (const v of vals) if (v !== undefined && v !== null) return Number(v);
        return 0;
      };
      return {
        imported: num(
          body.imported,
          body.created,
          body.success,
          results.success,
          results.imported,
          results.created,
        ),
        failed: num(
          body.failed,
          body.errors_count,
          results.failed,
          results.errors_count,
        ),
        skipped: num(body.skipped, results.skipped),
        conflicts: num(body.conflicts, results.conflicts),
        message: body.message ?? undefined,
        review: Array.isArray(results.review)
          ? (results.review as ImportReviewRow[])
          : [],
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengimpor data.'));
    }
  },
};

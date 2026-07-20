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

/**
 * One processed import row — EVERY row the importer touched, not just the
 * problematic ones. Grouped by `status` in the shared result dialog so the
 * admin sees exactly what happened to each entry (added / already there /
 * needs review / failed) instead of just a summary count.
 */
export interface ImportDetailRow {
  row: number;
  label: string;
  sublabel: string | null;
  /**
   * `updated` (MR!516) — subject import now UPSERTS by (school, code):
   * a matching mapel is updated in place instead of a duplicate being
   * created, so the schedule slots that pointed at it stay linked. The
   * result dialog surfaces these in their own "Diperbarui" section so
   * the admin can see the re-import didn't orphan anything.
   */
  status: 'created' | 'updated' | 'restored' | 'skipped' | 'conflict' | 'failed';
  reason: string | null;
}

/**
 * Non-blocking per-row annotation attached to a row that DID import
 * (post-!453 subject import emits these when a Master lookup misses —
 * row goes in as an orphan but the admin should know to wire it up
 * later). Additive top-level `warnings[]` on the response body so
 * pre-!453 importers keep working (empty list = section skipped).
 */
export interface ImportWarningRow {
  row: number;
  label: string;
  sublabel: string | null;
  message: string;
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
    // Post-MR!516 subject import breaks `imported` into three buckets so
    // the UI can reassure the admin a re-import didn't orphan schedules:
    //   created  — brand-new mapel rows
    //   updated  — existing mapel upserted in place (schedules stay linked)
    //   restored — soft-deleted mapel re-hydrated
    // `imported` stays the grand total (created + updated + restored) for
    // back-compat with the other three importers that don't split it.
    created: number;
    updated: number;
    restored: number;
    failed: number;
    skipped: number;
    conflicts: number;
    message?: string;
    // Per-row detail for the rows that need admin attention (conflicts +
    // failures) — so the UI can name WHICH row and WHY. Empty for importers
    // that don't report it.
    review: ImportReviewRow[];
    // Per-row detail for EVERY processed row (added / already there / needs
    // review / failed) — the shared result dialog groups these by status.
    // Empty for importers that don't report it.
    details: ImportDetailRow[];
    // Non-blocking per-row notes for rows that DID import but flag a
    // follow-up (post-!453 subject import: unresolved Master name).
    // Empty for importers that don't emit warnings.
    warnings: ImportWarningRow[];
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
      const created = num(results.created, body.created);
      const updated = num(results.updated, body.updated);
      const restored = num(results.restored, body.restored);
      // When the importer splits its total into buckets (subjects,
      // post-MR!516) prefer their sum — `success`/`imported` may not
      // count `updated`. Otherwise fall back to the universal count.
      const splitTotal = created + updated + restored;
      return {
        imported:
          splitTotal > 0
            ? splitTotal
            : num(
                body.imported,
                body.created,
                body.success,
                results.success,
                results.imported,
                results.created,
              ),
        created,
        updated,
        restored,
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
        details: Array.isArray(results.details)
          ? (results.details as ImportDetailRow[])
          : [],
        warnings: Array.isArray(results.warnings)
          ? (results.warnings as ImportWarningRow[])
          : [],
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengimpor data.'));
    }
  },
};

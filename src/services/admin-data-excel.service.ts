/**
 * AdminDataExcelService — shared Excel helpers for admin Manajemen
 * Data pages (Siswa / Guru / Kelas / Mapel).
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
  ): Promise<{ imported: number; failed: number; message?: string }> {
    try {
      const fd = new FormData();
      fd.append('file', file);
      const res = await api.post(`/${entity}/import`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const body = res.data ?? {};
      // Backend shapes vary across importers. StudentsImport (and the
      // other Maatwebsite ToCollection importers) responds with
      //   { message, results: { success, failed, errors } }
      // while simpler endpoints respond at the top level
      //   { imported, failed }
      // We read both nests — top-level first, then `results.*` — so a
      // successful 1-student import no longer shows "0 berhasil"
      // (Luay 2026-06-16) because of a counter pulled from the wrong
      // depth.
      const results = (body.results ?? {}) as Record<string, unknown>;
      return {
        imported: Number(
          body.imported
          ?? body.created
          ?? body.success
          ?? results.imported
          ?? results.created
          ?? results.success
          ?? 0,
        ),
        failed: Number(
          body.failed
          ?? body.skipped
          ?? body.errors_count
          ?? results.failed
          ?? results.skipped
          ?? results.errors_count
          ?? 0,
        ),
        message: body.message ?? undefined,
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengimpor data.'));
    }
  },
};

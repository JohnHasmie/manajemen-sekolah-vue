/**
 * AcademicYearService — /academic-years* wrapper.
 * Mirrors `lib/features/settings/data/academic_service.dart`
 * (Flutter `ApiAcademicServices`).
 *
 * Only the read-side methods are surfaced here — the admin Kelola
 * Tahun Ajaran page wires up create/update/archive separately.
 */
import { api } from '@/lib/http';
import {
  academicYearFromJson,
  type AcademicYear,
  type AcademicYearSemester,
  type AcademicYearStatus,
} from '@/types/academic-year';

function humanError(e: unknown, fallback: string): string {
  const ax = e as any;
  if (ax?.response?.data) {
    const d = ax.response.data;
    if (typeof d === 'string') return d;
    if (d?.message) return String(d.message);
    if (d?.error) return String(d.error);
    if (d?.errors && typeof d.errors === 'object') {
      const first = Object.values(d.errors)[0];
      if (Array.isArray(first) && first.length > 0) return String(first[0]);
    }
  }
  if (e instanceof Error) return e.message;
  return fallback;
}

export interface AcademicYearKpiSummary {
  total: number;
  current_count: number;
  active_count: number;
  inactive_count: number;
  archived_count: number;
}

export interface AcademicYearPayload {
  year: string;
  semester?: AcademicYearSemester;
  current?: boolean;
  status?: AcademicYearStatus;
  start_date?: string | null;
  end_date?: string | null;
}

function unwrap(body: unknown): unknown[] {
  if (Array.isArray(body)) return body;
  if (body && typeof body === 'object') {
    const b = body as { data?: unknown };
    if (Array.isArray(b.data)) return b.data;
  }
  return [];
}

export const AcademicYearService = {
  /**
   * GET /academic-years — full list (active + inactive + archived).
   * Sorted ascending by `year` on the server in most cases; we
   * re-sort defensively after parsing.
   */
  async list(): Promise<AcademicYear[]> {
    try {
      const res = await api.get('/academic-years');
      const rows = unwrap(res.data);
      const items = rows.map((r) =>
        academicYearFromJson(r as Record<string, unknown>),
      );
      items.sort((a, b) => a.year.localeCompare(b.year));
      return items;
    } catch {
      return [];
    }
  },

  /**
   * GET /academic-year/active — backend's canonical "this is the
   * year we're in right now" record. Returns null on 204 / empty.
   */
  async getActive(): Promise<AcademicYear | null> {
    try {
      const res = await api.get('/academic-year/active');
      if (res.status === 204 || !res.data) return null;
      const body = res.data as { data?: Record<string, unknown> } | Record<string, unknown>;
      const raw =
        body && typeof body === 'object' && 'data' in body
          ? (body as { data?: Record<string, unknown> }).data
          : (body as Record<string, unknown>);
      if (!raw) return null;
      return academicYearFromJson(raw as Record<string, unknown>);
    } catch {
      return null;
    }
  },

  /**
   * GET /academic-years/kpi-summary — one-shot bucket counts powering
   * the Kelola Tahun Ajaran KPI strip (total / current / active /
   * inactive / archived).
   */
  async getKpiSummary(): Promise<AcademicYearKpiSummary> {
    try {
      const res = await api.get('/academic-years/kpi-summary');
      const body = res.data;
      const d = (body && typeof body === 'object' && 'data' in body
        ? (body as { data?: Record<string, unknown> }).data
        : body) as Record<string, unknown>;
      const num = (v: unknown) => {
        const n = Number(v);
        return Number.isFinite(n) ? n : 0;
      };
      return {
        total: num(d?.total),
        current_count: num(d?.current_count),
        active_count: num(d?.active_count),
        inactive_count: num(d?.inactive_count),
        archived_count: num(d?.archived_count),
      };
    } catch {
      return {
        total: 0,
        current_count: 0,
        active_count: 0,
        inactive_count: 0,
        archived_count: 0,
      };
    }
  },

  /** POST /academic-years — create. */
  async create(payload: AcademicYearPayload): Promise<AcademicYear> {
    try {
      const body: Record<string, unknown> = {
        year: payload.year,
        current: payload.current ?? false,
        status: payload.status ?? 'inactive',
      };
      if (payload.semester) body.semester = payload.semester;
      if (payload.start_date) body.start_date = payload.start_date;
      if (payload.end_date) body.end_date = payload.end_date;
      const res = await api.post('/academic-years', body);
      const raw = res.data?.data ?? res.data ?? {};
      return academicYearFromJson(raw as Record<string, unknown>);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal membuat tahun ajaran.'));
    }
  },

  /** PUT /academic-years/{id} — partial update. */
  async update(id: string, payload: Partial<AcademicYearPayload>): Promise<AcademicYear> {
    try {
      const body: Record<string, unknown> = {};
      if (payload.year !== undefined) body.year = payload.year;
      if (payload.semester !== undefined) body.semester = payload.semester;
      if (payload.current !== undefined) body.current = payload.current;
      if (payload.status !== undefined) body.status = payload.status;
      if (payload.start_date !== undefined) body.start_date = payload.start_date;
      if (payload.end_date !== undefined) body.end_date = payload.end_date;
      const res = await api.put(`/academic-years/${id}`, body);
      const raw = res.data?.data ?? res.data ?? {};
      return academicYearFromJson(raw as Record<string, unknown>);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui tahun ajaran.'));
    }
  },

  /** PUT /academic-years/{id}/status — flip active/inactive. */
  async updateStatus(id: string, status: AcademicYearStatus): Promise<void> {
    try {
      await api.put(`/academic-years/${id}/status`, { status });
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengubah status.'));
    }
  },

  /** PUT /academic-years/{id}/set-current — mark as canonical current. */
  async setCurrent(id: string): Promise<void> {
    try {
      await api.put(`/academic-years/${id}/set-current`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menetapkan tahun ajaran aktif.'));
    }
  },

  /** POST /academic-years/{id}/archive. */
  async archive(id: string): Promise<void> {
    try {
      await api.post(`/academic-years/${id}/archive`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengarsipkan tahun ajaran.'));
    }
  },

  /** POST /academic-years/{id}/unarchive. */
  async unarchive(id: string): Promise<void> {
    try {
      await api.post(`/academic-years/${id}/unarchive`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal membatalkan arsip.'));
    }
  },

  /** DELETE /academic-years/{id}. */
  async destroy(id: string): Promise<void> {
    try {
      await api.delete(`/academic-years/${id}`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus tahun ajaran.'));
    }
  },
};

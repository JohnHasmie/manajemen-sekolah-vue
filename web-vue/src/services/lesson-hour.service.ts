/**
 * LessonHourService — `/lesson-hour-settings/*` + `/lesson-hour/*`
 * CRUD wrapper for the day × hour matrix that drives the schedule
 * picker.
 *
 * Mirrors Flutter's `lib/features/schedule/data/lesson_hour_service.dart`.
 * The aliased `/lesson-hour` apiResource exposes the same handlers as
 * `/lesson-hour-settings`; we use `/lesson-hour-settings` because that
 * route also exposes `bulk-delete` + `copy`.
 */
import { api } from '@/lib/http';
import type {
  LessonHour,
  LessonHourCopyDayPayload,
  LessonHourPayload,
} from '@/types/schedule';

function asStr(v: unknown, fallback = ''): string {
  if (v === null || v === undefined) return fallback;
  return String(v);
}

function asNum(v: unknown, fallback = 0): number {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }
  return fallback;
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

function lessonHourFromJson(raw: any): LessonHour {
  const day =
    typeof raw.day === 'object' && raw.day !== null ? raw.day : null;
  return {
    id: asStr(raw.id),
    day_id: asStr(day?.id ?? raw.day_id),
    day_name: day?.name ?? raw.day_name ?? null,
    day_order:
      day?.order_number !== undefined ? asNum(day.order_number) : null,
    hour_number: asNum(raw.hour_number ?? raw.jam_ke ?? 0),
    start_time: String(raw.start_time ?? raw.jam_mulai ?? '').slice(0, 5),
    end_time: String(raw.end_time ?? raw.jam_selesai ?? '').slice(0, 5),
    room: raw.room ?? raw.ruangan ?? null,
  };
}

export interface LessonHourFilters {
  day_id?: string;
  academic_year_id?: string | number;
}

export const LessonHourService = {
  /** GET /lesson-hour-settings — list all rows for the active school. */
  async list(filters: LessonHourFilters = {}): Promise<LessonHour[]> {
    try {
      const params: Record<string, unknown> = {};
      if (filters.day_id) params.day_id = filters.day_id;
      if (filters.academic_year_id) params.academic_year_id = filters.academic_year_id;
      const res = await api.get('/lesson-hour-settings', { params });
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map(lessonHourFromJson);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat jam pelajaran.'));
    }
  },

  /** POST /lesson-hour-settings. */
  async create(payload: LessonHourPayload): Promise<LessonHour> {
    try {
      const res = await api.post('/lesson-hour-settings', payload);
      const body = res.data?.data ?? res.data;
      return lessonHourFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menambahkan jam pelajaran.'));
    }
  },

  /** PUT /lesson-hour-settings/{id}. */
  async update(id: string, payload: LessonHourPayload): Promise<LessonHour> {
    try {
      const res = await api.put(`/lesson-hour-settings/${id}`, payload);
      const body = res.data?.data ?? res.data;
      return lessonHourFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui jam pelajaran.'));
    }
  },

  /** DELETE /lesson-hour-settings/{id}. */
  async destroy(id: string): Promise<void> {
    try {
      await api.delete(`/lesson-hour-settings/${id}`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus jam pelajaran.'));
    }
  },

  /** POST /lesson-hour-settings/bulk-delete. */
  async bulkDestroy(ids: string[]): Promise<{ deleted_count: number }> {
    try {
      const res = await api.post('/lesson-hour-settings/bulk-delete', { ids });
      const body = res.data ?? {};
      return { deleted_count: asNum(body.deleted_count ?? body.count) };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus jam pelajaran massal.'));
    }
  },

  /** POST /lesson-hour-settings/copy — copy day's matrix to another day. */
  async copyDay(
    payload: LessonHourCopyDayPayload,
  ): Promise<{ copied_count: number }> {
    try {
      const res = await api.post('/lesson-hour-settings/copy', payload);
      const body = res.data ?? {};
      return { copied_count: asNum(body.copied_count ?? body.count) };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menyalin jam pelajaran.'));
    }
  },
};

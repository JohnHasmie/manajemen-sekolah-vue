/**
 * Client for the per-school holiday calendar (backend MR 3b).
 * Consumed by the Kalender step in the Attendance Config wizard AND
 * by the dedicated admin holiday-management page (MR 3c).
 */
import { api } from '@/lib/http';

export type AttendanceHolidayType = 'national' | 'school' | 'religious';

export interface AttendanceHoliday {
  id: string;
  date: string; // YYYY-MM-DD
  name: string;
  type: AttendanceHolidayType;
}

export interface AttendanceHolidayCreateInput {
  date: string;
  name: string;
  type?: AttendanceHolidayType;
}

export interface AttendanceHolidayListFilters {
  start_date?: string;
  end_date?: string;
}

const Endpoints = {
  base: '/attendance-holidays',
} as const;

export const AttendanceHolidaysService = {
  async list(
    filters: AttendanceHolidayListFilters = {},
  ): Promise<AttendanceHoliday[]> {
    const res = await api.get(Endpoints.base, { params: filters });
    return (res.data?.data ?? []) as AttendanceHoliday[];
  },

  /**
   * updateOrCreate semantics on the backend — POSTing a date that
   * already exists overwrites the name/type for that (school, date)
   * pair. Returns the persisted row (fresh id when new, existing
   * id on overwrite).
   */
  async createOrUpdate(
    payload: AttendanceHolidayCreateInput,
  ): Promise<AttendanceHoliday> {
    const res = await api.post(Endpoints.base, payload);
    return res.data?.data as AttendanceHoliday;
  },

  async destroy(id: string): Promise<void> {
    await api.delete(`${Endpoints.base}/${id}`);
  },
};

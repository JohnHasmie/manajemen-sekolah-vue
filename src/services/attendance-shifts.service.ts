/**
 * Client for per-school work shifts (backend MR 4b).
 *
 * The check-in flow reads shifts from `/teacher-attendance/config`'s
 * `shifts` field to avoid an extra round-trip during the check-in
 * moment. This service is for the admin's Shift wizard step / list.
 */
import { api } from '@/lib/http';

export interface AttendanceShift {
  id: string;
  name: string;
  start_time: string; // HH:MM
  end_time: string;   // HH:MM
  /**
   * Weekday numbers this shift is valid on. JS getDay()-compatible:
   * 0 = Sunday, 1 = Monday, …, 6 = Saturday.
   */
  days_of_week: number[];
}

export interface AttendanceShiftInput {
  name: string;
  start_time: string;
  end_time: string;
  days_of_week: number[];
}

const Endpoints = {
  base: '/attendance-shifts',
} as const;

export const AttendanceShiftsService = {
  async list(): Promise<AttendanceShift[]> {
    const res = await api.get(Endpoints.base);
    return (res.data?.data ?? []) as AttendanceShift[];
  },

  async create(payload: AttendanceShiftInput): Promise<AttendanceShift> {
    const res = await api.post(Endpoints.base, payload);
    return res.data?.data as AttendanceShift;
  },

  async update(
    id: string,
    payload: AttendanceShiftInput,
  ): Promise<AttendanceShift> {
    const res = await api.patch(`${Endpoints.base}/${id}`, payload);
    return res.data?.data as AttendanceShift;
  },

  async destroy(id: string): Promise<void> {
    await api.delete(`${Endpoints.base}/${id}`);
  },
};

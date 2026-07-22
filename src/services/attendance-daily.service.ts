/**
 * Client for the Kehadiran Siswa · Harian tab endpoints added in the
 * BE-A MR (see backend `App\Modules\Attendance\Actions\GetDailyStudentRosterAction`
 * and `RemindGuardiansOfAbsentStudentsAction`).
 *
 * Both endpoints live under `module:attendance_class` server-side and
 * are ability-checked in the controller (`attendance.student.view`
 * for the roster, `attendance.student.remind` for the WA blast).
 * Callers should still gate the UI on the same abilities via `useMe()`
 * so the buttons don't render for viewers who lack the permission.
 */

import { api } from '@/lib/http';
import type {
  DailyRosterParams,
  DailyRosterResponse,
  RemindGuardiansPayload,
  RemindGuardiansResponse,
} from '@/types/attendance-daily';

const ENDPOINT = {
  daily: '/attendance/students/daily',
  remindGuardians: '/attendance/students/remind-guardians',
} as const;

export const AttendanceDailyService = {
  /**
   * Roster + KPI + method-mix + recent-feed for one date. The response
   * is the single payload the Harian tab reads on load — one round-trip.
   */
  async getDailyRoster(params: DailyRosterParams = {}): Promise<DailyRosterResponse> {
    const cleaned: Record<string, string | number> = {};
    if (params.date) cleaned.date = params.date;
    if (params.class_id) cleaned.class_id = params.class_id;
    if (params.tingkat !== undefined && params.tingkat !== null && params.tingkat !== '') {
      cleaned.tingkat = params.tingkat;
    }
    if (params.status) cleaned.status = params.status;
    if (params.search) cleaned.search = params.search;

    const { data } = await api.get<{ success: true; data: DailyRosterResponse }>(
      ENDPOINT.daily,
      { params: cleaned },
    );
    return data.data;
  },

  /**
   * Fires the "Ingatkan wali" WA blast for the belum-absen list.
   * Server enforces the 1-batch-per-hour rate limit — a 429 comes back
   * as `{ status: 'rate_limited', retry_after }` so the caller can
   * render a friendly "coba lagi jam …" toast.
   */
  async remindGuardians(payload: RemindGuardiansPayload): Promise<RemindGuardiansResponse> {
    try {
      const { data } = await api.post<{ success: true; data: RemindGuardiansResponse }>(
        ENDPOINT.remindGuardians,
        payload,
      );
      return data.data;
    } catch (err: unknown) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const e = err as any;
      if (e?.response?.status === 429) {
        return {
          status: 'rate_limited',
          retry_after: e.response.data?.retry_after ?? null,
        };
      }
      throw err;
    }
  },
};

/**
 * Types for the Kehadiran Siswa · Harian tab dataset — mirrors the
 * response of `GET /api/attendance/students/daily` (see backend Action
 * `App\Modules\Attendance\Actions\GetDailyStudentRosterAction`).
 *
 * `check_in_method` is the raw wire value (`QR_GATE` / `QR_CARD` /
 * `SELFIE` / `null`); the FE renders a Method chip that also shows an
 * additional synthetic "MANUAL" bucket in `method_mix` (for rows written
 * by an admin without a self-check-in method).
 */

/** Wire status values — English canonical + a synthetic "not_recorded". */
export type DailyStatus =
  | 'present'
  | 'late'
  | 'excused'
  | 'sick'
  | 'absent'
  | 'not_recorded';

export type CheckInMethodWire = 'QR_GATE' | 'QR_CARD' | 'SELFIE' | null;

export interface DailyRosterRow {
  student_id: string;
  student_name: string;
  student_number: string;
  gender: string | null;
  class_id: string | null;
  class_name: string;
  status: DailyStatus;
  label: string; // Indonesian display label (Hadir/Sakit/…/Belum absen)
  check_in_time: string | null; // "HH:MM"
  check_in_method: CheckInMethodWire;
  late_minutes: number | null;
  note: string | null;
  self_check_in_at: string | null; // ISO8601
}

export interface DailyKpi {
  hadir: number;
  terlambat: number;
  izin: number;
  sakit: number;
  alfa: number;
  belum_absen: number;
  total: number;
}

export interface DailyMethodMix {
  QR_GATE: number;
  QR_CARD: number;
  SELFIE: number;
  MANUAL: number;
}

export interface DailyRecentCheckIn {
  time: string | null;
  student_id: string;
  student_name: string;
  class_name: string;
  method: string; // QR_GATE / QR_CARD / SELFIE / MANUAL
  status: string;
}

export interface DailyRosterResponse {
  date: string; // YYYY-MM-DD
  data: DailyRosterRow[];
  kpi: DailyKpi;
  method_mix: DailyMethodMix;
  recent_check_ins: DailyRecentCheckIn[];
}

export interface DailyRosterParams {
  date?: string;
  class_id?: string;
  tingkat?: number | string;
  status?: DailyStatus;
  search?: string;
}

export interface RemindGuardiansPayload {
  student_ids: string[];
  template?: string;
}

export interface RemindGuardiansResponse {
  status: 'ok' | 'rate_limited';
  batch_id?: string | null;
  queued?: number;
  skipped_no_phone?: number;
  first_send_at?: string;
  last_send_at?: string;
  interval_seconds?: number;
  retry_after?: number | null;
}

/** UI helpers — status tone mapping shared across all three tabs. */
export const STATUS_TONE: Record<DailyStatus, 'emerald' | 'amber' | 'sky' | 'red' | 'slate'> = {
  present: 'emerald',
  late: 'amber',
  excused: 'sky',
  sick: 'amber',
  absent: 'red',
  not_recorded: 'slate',
};

export const STATUS_LABEL: Record<DailyStatus, string> = {
  present: 'Hadir',
  late: 'Terlambat',
  excused: 'Izin',
  sick: 'Sakit',
  absent: 'Alfa',
  not_recorded: 'Belum absen',
};

export const METHOD_LABEL: Record<string, string> = {
  QR_GATE: 'QR Gerbang',
  QR_CARD: 'Kartu QR',
  SELFIE: 'Selfie',
  MANUAL: 'Manual admin',
};

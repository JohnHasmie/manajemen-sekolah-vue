/**
 * Employment status enum — canonical values for teacher kepegawaian.
 *
 * Must stay in sync with the backend `App\Enums\EmploymentStatus`.
 */
export const EmploymentStatus = {
  TETAP: 'tetap',
  TIDAK_TETAP: 'tidak_tetap',
  HONORER: 'honorer',
  KONTRAK: 'kontrak',
} as const;

export type EmploymentStatusValue =
  (typeof EmploymentStatus)[keyof typeof EmploymentStatus];

export interface EmploymentStatusOption {
  key: EmploymentStatusValue;
  label: string;
}

/** Ordered list of options for dropdowns and filter chips. */
export const EMPLOYMENT_STATUS_OPTIONS: EmploymentStatusOption[] = [
  { key: EmploymentStatus.TETAP, label: 'Tetap' },
  { key: EmploymentStatus.TIDAK_TETAP, label: 'Tidak Tetap' },
  { key: EmploymentStatus.HONORER, label: 'Honorer' },
  { key: EmploymentStatus.KONTRAK, label: 'Kontrak' },
];

/** Human-readable label for a given status value. */
export function employmentStatusLabel(
  value: string | null | undefined,
): string {
  if (!value) return '-';
  const found = EMPLOYMENT_STATUS_OPTIONS.find((o) => o.key === value);
  return found?.label ?? value;
}

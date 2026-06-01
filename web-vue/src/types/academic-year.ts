/**
 * AcademicYear types — mirror Flutter's academic_year_provider.dart
 * + ApiAcademicServices payload shape.
 *
 * Backend wire format (GET /academic-years item):
 *   {
 *     id: string,
 *     year: "2025/2026",
 *     semester: "ganjil" | "genap" | null,
 *     current: boolean | 0 | 1,
 *     status: "active" | "inactive" | "archived",
 *     start_date?: string,
 *     end_date?: string,
 *   }
 */

export type AcademicYearSemester = 'ganjil' | 'genap' | null;
export type AcademicYearStatus = 'active' | 'inactive' | 'archived';

export interface AcademicYear {
  id: string;
  /** e.g. "2025/2026". */
  year: string;
  semester: AcademicYearSemester;
  /** Backend's canonical "this is the current year" flag. */
  current: boolean;
  /** `inactive` / `archived` means the year is read-only for editing. */
  status: AcademicYearStatus;
  start_date?: string | null;
  end_date?: string | null;
}

/**
 * Normalise a raw response item (handles snake_case + boolean-as-int
 * + nested `data` wrappers).
 */
export function academicYearFromJson(raw: Record<string, unknown>): AcademicYear {
  const r = raw as Record<string, unknown>;
  const status = String(r.status ?? 'inactive') as AcademicYearStatus;
  const currentRaw = r.current;
  const current =
    currentRaw === true || currentRaw === 1 || currentRaw === '1' || currentRaw === 'true';
  const semRaw = (r.semester ?? null) as string | null;
  const semester = (
    semRaw && (semRaw === 'ganjil' || semRaw === 'genap') ? semRaw : null
  ) as AcademicYearSemester;
  return {
    id: String(r.id ?? ''),
    year: String(r.year ?? r.label ?? r.name ?? ''),
    semester,
    current,
    status,
    start_date: (r.start_date as string | undefined) ?? null,
    end_date: (r.end_date as string | undefined) ?? null,
  };
}

/** Human-readable semester label ("Sem. Ganjil" / "Sem. Genap"). */
export function semesterLabel(s: AcademicYearSemester): string | null {
  if (s === 'ganjil') return 'Sem. Ganjil';
  if (s === 'genap') return 'Sem. Genap';
  return null;
}

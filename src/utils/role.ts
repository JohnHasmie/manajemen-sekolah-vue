/**
 * Canonical English role keys — the target for the web client's internal role
 * strings.
 *
 * The backend is already canonical English (`App\Modules\Auth\Enums\Role` =
 * admin/teacher/student/parent). The Vue client historically uses the
 * Indonesian short-forms (`guru`/`wali`/`siswa`) as its INTERNAL `Role` union
 * (see `types/auth.ts`), produced by `normalizeRole` in the auth store. This
 * is the anchor for migrating the client to English too — the mirror of the
 * Flutter `canonicalRole` in `role_labels.dart`.
 *
 * [canonicalRole] returns a plain `string` (not the strict `Role` union) on
 * purpose: during the phased migration a call site compares
 * `canonicalRole(x) === ROLE_TEACHER`, which is robust whether `x` is still the
 * legacy `'guru'` or the migrated `'teacher'`, without forcing the `Role` type
 * to change first.
 */

export const ROLE_ADMIN = 'admin';
export const ROLE_TEACHER = 'teacher';
export const ROLE_PARENT = 'parent';
export const ROLE_STUDENT = 'student';
export const ROLE_STAFF = 'staff';

/**
 * Fold any legacy / wire spelling of a role to its canonical English key,
 * mirroring the backend `Role::fromAny` and the Flutter `canonicalRole`.
 * Accepts the Indonesian internal forms (`guru`, `wali`, `wali_murid`,
 * `orang_tua`, `siswa`), the English forms, and admin variants. Unknown input
 * (including the `wali_kelas` variant) is returned lowercased+trimmed rather
 * than throwing, so callers never crash on a novel role string.
 */
export function canonicalRole(role: string | null | undefined): string {
  const r = (role ?? '').toLowerCase().trim();
  switch (r) {
    case 'admin':
    case 'administrator':
      return ROLE_ADMIN;
    case 'guru':
    case 'teacher':
      return ROLE_TEACHER;
    case 'wali':
    case 'wali_murid':
    case 'walimurid':
    case 'orang_tua':
    case 'parent':
    case 'guardian':
      return ROLE_PARENT;
    case 'siswa':
    case 'student':
      return ROLE_STUDENT;
    case 'staff':
      return ROLE_STAFF;
    default:
      return r;
  }
}

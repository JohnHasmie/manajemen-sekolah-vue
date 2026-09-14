/**
 * bimbel-parent-children.ts — derive a wali's children from their
 * enrollment rows.
 *
 * ── Why enrollments, and why this is shared ──
 *
 * There is no `/tutoring-v2/parent/children` endpoint yet. A bimbel
 * guardian link goes via ENROLLMENT, not the legacy school-side guardian
 * columns, so the wali's children are the distinct `student_id` values
 * across `GET /tutoring-v2/enrollments` (the server scopes that index to
 * children the caller owns). `ParentTutoring2PickChildView` has derived
 * its list that way since it shipped.
 *
 * The "Ganti anak" link has to answer a question that DEPENDS on that
 * list: it may only appear when the wali actually has more than one
 * child, because a switcher that opens a one-item list is clutter, not
 * an affordance. The only way to be sure the destination list has more
 * than one row is to count it from the same source the destination
 * counts — so the dedupe lives here and both callers use it. A second
 * copy could disagree, and a disagreement means either a link that
 * leads nowhere or a wali with two children and no way to switch.
 *
 * Structural input type on purpose (same style as
 * `bimbel-session-label.ts`): the helper does not need the full
 * `BimbelEnrollment`, and not importing it keeps `lib/` off the service
 * layer.
 */

/** The fields of an enrollment row this derivation actually reads. */
export interface BimbelChildEnrollmentRow {
  student_id: string;
  student_name?: string | null;
  status?: string | null;
}

export interface BimbelChildRow {
  student_id: string;
  /**
   * Optional because `whenLoaded` omits `student_name` per row — see the
   * merge note below. Render it through `bimbelStudentLabel`, never
   * raw.
   */
  student_name?: string | null;
  active_count: number;
}

/** Enrollment statuses that count as "currently studying here". */
const ACTIVE_ENROLLMENT_STATUSES = new Set(['active', 'trial']);

/**
 * Collapse enrollment rows into one row per child, preserving first
 * appearance order.
 */
export function deriveBimbelChildren(
  items: readonly BimbelChildEnrollmentRow[],
): BimbelChildRow[] {
  const byStudent = new Map<string, BimbelChildRow>();

  for (const e of items) {
    const row = byStudent.get(e.student_id) ?? {
      student_id: e.student_id,
      active_count: 0,
    };

    /**
     * Outside the `??`, so it runs on the EXISTING row too. A child's
     * enrollments are not uniform: `whenLoaded` omits `student_name`
     * per row, so the first enrollment can be nameless while the second
     * carries the name. Copying the name only when the row is created
     * would leave every child with more than one programme showing an
     * id fragment whenever their first row happened to be the unnamed
     * one — a named sibling next to an unnamed one, on the same list.
     *
     * A name already taken is never overwritten (first non-blank wins,
     * matching TutorTutoring2StudentDetailView's `find`), and the trim
     * is what makes `"   "` count as still-unnamed rather than as an
     * answer.
     */
    if (!String(row.student_name ?? '').trim()) row.student_name = e.student_name;
    if (ACTIVE_ENROLLMENT_STATUSES.has(String(e.status ?? ''))) row.active_count += 1;

    byStudent.set(e.student_id, row);
  }

  return [...byStudent.values()];
}

/**
 * Type contracts for the greenfield bimbel terms / batches.
 *
 * Mirrors `App\Modules\Tutoring\Http\Controllers\TermController`:
 *
 *   GET /api/tutoring-v2/terms?status=&search=&per_page=
 *
 * The `terms` table has existed since BE-1; nothing served the rows
 * until now, so `AdminTutoring2TermView` derived a fake list from the
 * distinct `term_id` values on learning groups — inventing the name
 * ("Term " + eight characters of the UUID), the dates (null) and the
 * status ('draft' on every row, including live batches).
 *
 * `status` is a free-text `string(16)` column, not an enum, so the
 * union below is widened with `string`: an unrecognised value renders
 * as itself rather than being folded into one of the three we know.
 * `status_label` is the server's own wording — prefer it.
 */

export interface BimbelTerm {
  id: string;
  name: string;
  /** `YYYY-MM-DD`, or null — the column is nullable. */
  start_date: string | null;
  end_date: string | null;
  /** At most one per school (enforced by a unique partial index). */
  is_current: boolean;
  status: 'draft' | 'active' | 'closed' | string;
  status_label: string;
  /**
   * Learning groups in this term, excluding soft-deleted ones. Absent
   * when the endpoint did not compute it — absent means "not asked",
   * NOT "zero", so render it as "—" rather than as 0.
   */
  groups_count?: number;
  created_at?: string;
  updated_at?: string;
}

export interface TermListParams {
  page?: number;
  per_page?: number;
  status?: string;
  search?: string;
}

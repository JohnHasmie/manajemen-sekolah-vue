/**
 * absent-vs-zero — one helper for "the server did not send this number".
 *
 * A count that never arrived and a count that is genuinely zero are two
 * DIFFERENT facts, and `count ?? 0` silently collapses them into the
 * second one. That collapse has shipped fabricated numbers to prod more
 * than once on this codebase:
 *
 *   • "Rata-rata utilisasi" on Kelompok Belajar read 0% on every tenant
 *     — `GET /learning-groups` (index) never emits `seated_count`; only
 *     the single-group GET does, and Laravel's `when()` OMITS the key
 *     rather than sending null. Every row therefore contributed `?? 0`.
 *   • "Total presensi" on Presensi read 0 for the same reason
 *     (`attendances_count`), fixed earlier in AdminTutoring2AttendanceView.
 *
 * The honest rendering is an em-dash for ABSENT and the number itself
 * for PRESENT — including a present, real `0`. An empty group with
 * capacity 10 must read "0 / 10", never "— / 10": this helper exists to
 * fix `?? 0` WITHOUT conflating the two the other way round.
 *
 * The idiom this generalises already lived inline in
 * AdminTutoring2GroupsView's capacity cell (`x == null ? '—' : x`); it
 * is lifted here so the KPI strip above that table, and the sibling
 * screens reading the same fields, share one convention instead of
 * three ad-hoc ternaries.
 *
 * NOTE this is deliberately NOT `formatNumber()` from `@/lib/format`,
 * which returns '0' for null/undefined — the exact behaviour this
 * module exists to avoid.
 */

/** The single em-dash every "unknown" reading in the app renders. */
export const EM_DASH = '—';

/**
 * True when the server actually sent a number for this field.
 *
 * A type guard, so `isCounted(row.seated_count)` narrows the property
 * and downstream arithmetic needs no `!` and no cast. Loose enough to
 * cover both shapes the wire can take: an omitted key (`undefined`,
 * what `when()`/`whenLoaded()` produce) and an explicit `null`.
 */
export function isCounted(value: number | null | undefined): value is number {
  return typeof value === 'number';
}

/**
 * A count for display: the number when it was sent, "—" when it was not.
 *
 * `countOrDash(0)` is `'0'`. That is the whole point — do not "simplify"
 * this to a falsy check.
 */
export function countOrDash(value: number | null | undefined): string {
  return isCounted(value) ? String(value) : EM_DASH;
}

/**
 * Display label for the learning group a bimbel session belongs to.
 *
 * **The name has been on the wire all along.** `SessionResource`
 * denormalises `learning_group_name` onto every session, and
 * `SessionController` eager-loads the relation that produces it on both
 * `index` and `show`. The admin schedule table has read the real name
 * from that field since it shipped
 * (`AdminTutoring2ScheduleView.vue:279`). The tutor and student screens
 * simply never looked: they formatted `learning_group_id.slice(0, 8)`
 * unconditionally, with no `??` in the expression at all. So a tutor saw
 * "Kelompok 01a00e34" for the very session an admin saw as
 * "UTBK Pagi A".
 *
 * This is the web twin of mobile's `bimbelSessionTitle` (!1240). The
 * two must agree, so the fallback ladder is copied deliberately:
 *
 *   1. `learning_group_name`, when it is present AND non-blank.
 *   2. otherwise `"<prefix> <first 8 chars of the id>"`.
 *   3. otherwise an em-dash.
 *
 * **Why the id fallback is correct rather than lazy.** `whenLoaded`
 * OMITS the key when the relation was not loaded, and an optional
 * `string | null` field cannot tell "the server did not send it" apart
 * from "the group genuinely has no name". A null therefore means *we
 * were not told*, and an id fragment at least identifies the row; a
 * blank cell would not. What we must never do is render an empty string
 * or invent a placeholder name — that would be fabricated data.
 *
 * **Why step 3 exists.** When the id is missing too there is nothing
 * left to identify the group with, and `"Kelompok "` — a label ending in
 * a dangling space — tells the reader strictly less than the em-dash the
 * rest of these screens already use for "the wire did not say".
 *
 * DISPLAY ONLY. Never key, filter, or navigate on this string.
 */
export interface BimbelGroupLabelSource {
  learning_group_id?: string | null;
  learning_group_name?: string | null;
}

/**
 * @param source  Any payload row carrying the group id and/or its name.
 * @param prefix  Translated word placed before an id fragment, e.g.
 *                `t('tutoring2.common.group')`. Only used by step 2 —
 *                a real name is shown on its own, never prefixed.
 */
export function bimbelGroupLabel(
  source: BimbelGroupLabelSource | null | undefined,
  prefix = '',
): string {
  return labelFromNameOrId(
    source?.learning_group_name,
    source?.learning_group_id,
    prefix,
  );
}

/**
 * ── The ladder, generalised (!1244 follow-up) ───────────────────────
 *
 * !1244 fixed the tutor session screens and, in doing so, DELETED four
 * near-identical local `groupLabel()` functions that had already drifted
 * apart from one another. The sweep that followed found the same defect
 * on seven more screens — and there the missing name is not a group's
 * but a STUDENT's, a PROGRAM's, or a TUTOR's.
 *
 * Writing `studentLabel()`, `programLabel()` and `tutorLabel()` next to
 * this file would recreate exactly the divergence !1244 removed, three
 * times over. So the ladder itself moved down here into
 * `labelFromNameOrId`, and each entity gets a two-line adapter that only
 * says WHICH pair of fields it reads. There is one ladder in the app.
 *
 * The rungs are unchanged and deliberately identical for every entity:
 *
 *   1. the name, when present AND non-blank (trimmed before the test —
 *      a name of "   " is not a name, it is a whitespace-only string
 *      that would render as a blank cell);
 *   2. otherwise `"<prefix> <first 8 chars of the id>"`;
 *   3. otherwise an em-dash.
 *
 * Same reasoning as the group case for why rung 2 is right rather than
 * lazy: an optional `string | null` name cannot distinguish "the server
 * did not send it" from "this really has no name", so the id fragment
 * must survive as something the reader can quote back to support.
 *
 * DISPLAY ONLY. Never key, filter, or navigate on these strings.
 */
function labelFromNameOrId(
  name: string | null | undefined,
  id: string | null | undefined,
  prefix: string,
): string {
  const trimmedName = String(name ?? '').trim();
  if (trimmedName) return trimmedName;

  const trimmedId = String(id ?? '').trim();
  if (!trimmedId) return '—';

  return [prefix.trim(), trimmedId.slice(0, 8)].filter(Boolean).join(' ');
}

export interface BimbelStudentLabelSource {
  student_id?: string | null;
  student_name?: string | null;
  /**
   * Last-resort identifier. Submission rows are keyed by ENROLLMENT and
   * carry `student_id` only optionally, so without this rung a row that
   * has neither name nor student id would collapse to an em-dash even
   * though it does have an id the tutor can act on.
   */
  enrollment_id?: string | null;
}

/**
 * @param prefix Translated word placed before an id fragment, e.g.
 *               `t('tutoring2.common.studentId')`. Pass nothing where
 *               the surrounding column already says "Siswa" — a real
 *               name is never prefixed, so the prefix only ever labels
 *               the fragment.
 */
export function bimbelStudentLabel(
  source: BimbelStudentLabelSource | null | undefined,
  prefix = '',
): string {
  const studentId = String(source?.student_id ?? '').trim();
  return labelFromNameOrId(
    source?.student_name,
    studentId || source?.enrollment_id,
    prefix,
  );
}

export interface BimbelProgramLabelSource {
  program_id?: string | null;
  program_name?: string | null;
}

export function bimbelProgramLabel(
  source: BimbelProgramLabelSource | null | undefined,
  prefix = '',
): string {
  return labelFromNameOrId(source?.program_name, source?.program_id, prefix);
}

export interface BimbelTutorLabelSource {
  tutor_id?: string | null;
  tutor_name?: string | null;
}

export function bimbelTutorLabel(
  source: BimbelTutorLabelSource | null | undefined,
  prefix = '',
): string {
  return labelFromNameOrId(source?.tutor_name, source?.tutor_id, prefix);
}

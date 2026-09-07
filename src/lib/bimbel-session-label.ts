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
  const name = String(source?.learning_group_name ?? '').trim();
  if (name) return name;

  const id = String(source?.learning_group_id ?? '').trim();
  if (!id) return '—';

  return [prefix.trim(), id.slice(0, 8)].filter(Boolean).join(' ');
}

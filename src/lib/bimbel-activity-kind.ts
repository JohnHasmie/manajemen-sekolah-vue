/**
 * Display label for a bimbel activity's `kind`.
 *
 * The wire values are the three `App\Modules\Tutoring\Enums\ActivityKind`
 * cases (`tugas | kuis | materi_baca`) and the backend also denormalises
 * a `kind_label` onto every row. We deliberately do NOT render that
 * field: `ActivityKind::label()` returns Indonesian unconditionally, so
 * a tutor on the English locale would get "Materi Baca" next to
 * "Published". The three i18n keys below are the app's own translation
 * of the same enum and they follow the locale.
 *
 * It lives here rather than inside a view because the tutor now has TWO
 * screens rendering the same badge — the Aktivitas list and the detail
 * it opens. A second copy of this switch is exactly how four
 * `groupLabel()` functions drifted apart in this same feature (see
 * `bimbel-session-label.ts`), and a row disagreeing with the detail it
 * opens about what kind of activity it is would be the same defect.
 *
 * An unknown value falls through to the raw wire string rather than an
 * em-dash: a fourth kind added on the server should read as its own name
 * here, not disappear.
 *
 * DISPLAY ONLY. Never key, filter, or navigate on this string.
 */
import type { ActivityKind } from '@/types/tutoring2/activity';

type Translate = (key: string) => string;

export function activityKindLabel(
  kind: ActivityKind | string | null | undefined,
  t: Translate,
): string {
  switch (kind) {
    case 'tugas':
      return t('tutoring2.tutor.activities.kindTugas');
    case 'kuis':
      return t('tutoring2.tutor.activities.kindKuis');
    case 'materi_baca':
      return t('tutoring2.tutor.activities.kindMateriBaca');
    default:
      return String(kind ?? '—');
  }
}

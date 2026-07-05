/**
 * The canonical set of semantic tones for the shared `StatusBadge`
 * component. Every per-domain status map (report cards, lesson plans,
 * recommendations, …) maps its own statuses onto one of these, so the
 * pill palette is defined once in `components/ui/StatusBadge.vue`.
 */
export type StatusBadgeTone =
  | 'success'
  | 'warning'
  | 'danger'
  | 'info'
  | 'neutral';

/**
 * parent-tutoring2-targets.ts — the allow-list that ties the wali
 * child-picker to the per-child screen it was opened from.
 *
 * ── Why this lives outside the picker view ──
 *
 * The map started life inline in `ParentTutoring2PickChildView.vue`,
 * where it answered one question: "the wali just tapped a child — which
 * screen do I send them to?" `?target=` names the destination and is
 * resolved through this allow-list rather than pushed straight into
 * `router.push`, because `target` arrives from the URL and an unchecked
 * value would let a crafted link bounce a wali into any named route in
 * the app.
 *
 * `ParentSwitchChildLink` asks the MIRROR question: "the wali is on a
 * per-child screen and wants a different child — which `?target=` sends
 * them back HERE?" Two halves of one round trip. Kept inline, the
 * reverse lookup would have had to restate the pairs, and the day
 * someone added a seventh per-child screen to one copy the wali would
 * have been silently returned to Kehadiran instead of the page they
 * left. One table, derived both ways, cannot drift.
 *
 * Adding a per-child screen? Add it here and the "Ganti anak" link on
 * that screen round-trips for free.
 */

/** `?target=` key → route name. The allow-list, and the only one. */
export const PARENT_TUTORING2_TARGETS: Record<string, string> = {
  attendance: 'parent.tutoring2.attendance',
  vouchers: 'parent.tutoring2.vouchers',
  progress: 'parent.tutoring2.progress',
  activities: 'parent.tutoring2.activities',
  assessments: 'parent.tutoring2.assessments',
  sessions: 'parent.tutoring2.sessions',
  // The wali "Peringkat" menu item routes to the picker whenever no
  // child is active, and an absent key would have silently fallen
  // through to `attendance` — landing the wali on Kehadiran after they
  // clicked Peringkat.
  leaderboard: 'parent.tutoring2.leaderboard',
  // Added with the "Ganti anak" link. Rapor is a per-child screen like
  // the rest; without a key here its own switcher would have returned
  // the wali to Kehadiran for the newly chosen child.
  'report-card': 'parent.tutoring2.report-card',
};

/**
 * Where an unrecognised (or absent) `?target=` lands. Also the
 * historical destination, which keeps pre-`?target=` links working.
 */
export const PARENT_TUTORING2_DEFAULT_TARGET = 'attendance';

/**
 * Resolve a `?target=` query value to a route name.
 *
 * Anything unrecognised falls back to the default rather than throwing:
 * a wali who followed a stale link should land on a real screen, not an
 * error, and the fallback is what makes the value safe to trust
 * downstream.
 */
export function resolveParentTutoring2Target(target: unknown): string {
  const key = String(target ?? '');
  return (
    PARENT_TUTORING2_TARGETS[key] ??
    PARENT_TUTORING2_TARGETS[PARENT_TUTORING2_DEFAULT_TARGET]
  );
}

/**
 * The reverse: route name → its `?target=` key, or `null` when the
 * route is not a per-child destination.
 *
 * `null` is meaningful. It says "this screen is not in the allow-list",
 * and the caller must then send the wali to the picker WITHOUT a target
 * rather than inventing one — a fabricated key would resolve to the
 * default and quietly move them to a different screen than the one they
 * were reading.
 */
export function parentTutoring2TargetKey(routeName: string): string | null {
  for (const [key, name] of Object.entries(PARENT_TUTORING2_TARGETS)) {
    if (name === routeName) return key;
  }
  return null;
}

/**
 * Format a Date to `YYYY-MM-DD` using the browser's LOCAL calendar
 * components — not UTC.
 *
 * Why this exists: the historically-common `d.toISOString().slice(0, 10)`
 * shortcut formats the date IN UTC. For any user in a positive-offset
 * timezone (Indonesia = WIB / UTC+7), opening the app in the early
 * morning hours means UTC has not rolled over into the new day yet, so
 * `today.toISOString()` returns YESTERDAY'S date. Any code that uses
 * that string as `today` (attendance report window, calendar default,
 * bill payment_date default) then silently shifts by one day.
 *
 * Concrete incident: MTs Muhammadiyah Surakarta prod bug (2026-07-20) —
 * "7 Hari" filter on the Kehadiran Pegawai report loaded the window
 * `2026-07-13 → 2026-07-19` (Mon → Sun) instead of `2026-07-14 → 2026-07-20`
 * because the admin's browser resolved `today` off `toISOString()`
 * while WIB was between 00:00 and 06:59. Today's 12 check-ins were
 * live in the DB but invisible in the chart + Log Harian.
 *
 * Prefer this helper anywhere the string represents a CALENDAR DAY the
 * user is looking at (report window, filter default, calendar cell).
 * The UTC-slice form is fine when the string is a filename stamp or
 * anything else where "the exact day" is not user-facing.
 */
export function toLocalYmd(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

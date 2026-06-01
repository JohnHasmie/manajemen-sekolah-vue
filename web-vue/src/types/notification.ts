/**
 * Notification types — mirror the Flutter `Notification` model and the
 * Laravel response shape from `/api/notifications`.
 */

export type NotificationCategory =
  | 'announcement'
  | 'attendance'
  | 'grade'
  | 'lesson_plan'
  | 'billing'
  | 'system'
  | 'other';

export interface AppNotification {
  id: string;
  title: string;
  body: string;
  category: NotificationCategory;
  read_at: string | null;
  created_at: string;
  /** Optional in-app link, e.g. `/teacher/lesson-plans/42`. */
  href?: string | null;
  /** Free-form metadata from the server. */
  data?: Record<string, unknown>;
}

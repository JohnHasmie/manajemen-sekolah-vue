/**
 * Notification types — mirror the Flutter `Notification` model and the
 * Laravel response shape from `/api/notifications`.
 */

export type NotificationCategory =
  | 'announcement'
  | 'attendance'
  | 'grade'
  | 'class_activity'
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

/**
 * The audience role a deep-link should target. The same backend
 * notification `type` (e.g. `grade`, `attendance`) maps to a DIFFERENT
 * web route depending on who is reading it: a parent sees the parent
 * grade page, an admin sees the admin one. We resolve the active role at
 * mapping time and feed it into {@link notificationHref}.
 */
export type NotificationAudience = 'parent' | 'teacher' | 'admin' | null;

/**
 * Single source of truth: backend notification `type` → web
 * `NotificationCategory`. Used by BOTH the REST mapper (fromJson) and the
 * realtime mapper (echo.ts) so the list + bell + toast always agree.
 *
 * Backend `type` values (the persisted `notifications.type` column, which
 * is also what the realtime broadcast ships as `type`) seen in the Laravel
 * jobs:
 *   - `attendance`                          → SendAttendanceNotificationJob
 *   - `announcement`                        → SendAnnouncementNotificationJob
 *   - `announcement_event` / `_personal`    → DispatchAnnouncementRemindersJob
 *   - `grade`                               → SendGradeNotificationJob
 *   - `class_activity`                      → SendClassActivityNotificationJob
 *   - `finance`                             → SendFinanceNotificationJob
 *   - `kelas`                               → class-scoped announcement source
 *   - `system`                              → misc system rows
 * Plus class-activity sub-types that some older rows store directly in the
 * `type` column (`tugas`, `ujian`/`ulangan`, `materi`, `kegiatan`, …).
 *
 * Unknown / unmapped types fall back to `'other'` (shown as "LAIN").
 */
export function notificationCategoryFromType(
  type: string | null | undefined,
): NotificationCategory {
  const t = String(type ?? '')
    .toLowerCase()
    .trim();
  switch (t) {
    case 'attendance':
    case 'kehadiran':
    case 'presensi':
      return 'attendance';

    case 'announcement':
    case 'announcement_event':
    case 'announcement_event_personal':
    case 'unread_announcement':
    case 'pengumuman':
      return 'announcement';

    case 'grade':
    case 'nilai':
      return 'grade';

    case 'class_activity':
    case 'activity':
    case 'kegiatan':
    case 'tugas':
    case 'ujian':
    case 'ulangan':
    case 'materi':
    case 'lainnya':
      return 'class_activity';

    case 'lesson_plan':
    case 'rpp':
      return 'lesson_plan';

    case 'finance':
    case 'bill':
    case 'bill_generated':
    case 'overdue_bill':
    case 'due_soon':
    case 'payment':
    case 'payment_verified':
    case 'payment_rejected':
    case 'payment_confirmed':
    case 'payment_submitted':
    case 'payment_verification':
    case 'tagihan':
    case 'pembayaran':
      return 'billing';

    case 'system':
    case 'info':
    case 'reminder':
    case 'reminder_teaching':
    case 'reminder_teaching_personal':
    case 'school_access':
    case 'school_access_request':
    case 'login':
    case 'recommendation':
    case 'rekomendasi':
    case 'kelas':
      return 'system';

    default:
      return 'other';
  }
}

/** Pull a string id out of the free-form `data` payload, if present. */
function dataValue(
  data: Record<string, unknown> | null | undefined,
  ...keys: string[]
): string | null {
  if (!data) return null;
  for (const k of keys) {
    const v = data[k];
    if (typeof v === 'string' && v.length > 0) return v;
    if (typeof v === 'number') return String(v);
  }
  return null;
}

/**
 * Derive an in-app route (`href`) from the backend notification `type` +
 * its `data` payload, for the reader's active role. Returns `null` when
 * there's no usable target (e.g. the founder's bare test rows, or a type
 * we don't deep-link) — callers must treat `null` as "no navigation"
 * while STILL marking the row read on click.
 *
 * Routes come from `web-vue/src/router/index.ts`. Where a target detail
 * page needs an id the backend doesn't ship (e.g. attendance/grade rows
 * carry ids but the web views are filter-driven LIST pages, not `/:id`
 * detail routes), we link to the most sensible existing LIST page for
 * that role rather than invent a route.
 *
 * Shared by BOTH the REST mapper and the realtime mapper.
 */
export function notificationHref(
  type: string | null | undefined,
  data: Record<string, unknown> | null | undefined,
  audience: NotificationAudience = null,
): string | null {
  const category = notificationCategoryFromType(type);

  switch (category) {
    case 'attendance': {
      // No `/:id` attendance detail on the web; route to the role's
      // attendance overview. Parents are the usual recipients.
      if (audience === 'teacher') return '/teacher/attendance';
      if (audience === 'admin') return '/admin/student-attendance';
      return '/parent/attendance';
    }

    case 'grade': {
      // Grade rows go to parents (student->user_id). Web has no single
      // grade-detail route keyed by grade_id, so land on the grade page.
      if (audience === 'teacher') return '/teacher/grades';
      if (audience === 'admin') return '/admin/grades';
      return '/parent/grades';
    }

    case 'announcement': {
      if (audience === 'teacher') return '/teacher/announcements';
      if (audience === 'admin') return '/admin/announcements';
      return '/parent/announcements';
    }

    case 'class_activity': {
      if (audience === 'teacher') return '/teacher/class-activity';
      if (audience === 'admin') return '/admin/class-activity';
      return '/parent/class-activity';
    }

    case 'billing': {
      // `payment_submitted` notifies admins (needs verification) → admin
      // payments page. Everything else (bill_generated / payment_*) is a
      // parent-facing bill. When we know the bill id, deep-link straight
      // to the parent checkout for that bill.
      const subType = String(dataValue(data, 'type') ?? type ?? '').toLowerCase();
      if (audience === 'admin' || subType === 'payment_submitted') {
        return '/admin/finance/pembayaran';
      }
      const billId = dataValue(data, 'bill_id');
      if (billId) return `/parent/billing/checkout/${billId}`;
      return '/parent/billing';
    }

    case 'lesson_plan': {
      const planId = dataValue(data, 'lesson_plan_id', 'plan_id', 'id');
      if (audience === 'admin') {
        return planId ? `/admin/lesson-plans/${planId}` : '/admin/lesson-plans';
      }
      return planId
        ? `/teacher/lesson-plans/${planId}`
        : '/teacher/lesson-plans';
    }

    // `system` / `other` have no meaningful in-app target.
    default:
      return null;
  }
}

/**
 * The wire shape of one notification row from the REST API
 * (`NotificationResource`) — id/title/body/type/data/is_read/created_at.
 * Distinct from {@link AppNotification}, which is the normalised in-app
 * shape (category/read_at/href) the UI consumes.
 */
export interface NotificationJson {
  id: string;
  title?: string | null;
  body?: string | null;
  type?: string | null;
  data?: Record<string, unknown> | null;
  is_read?: boolean | null;
  read_at?: string | null;
  created_at?: string | null;
}

/**
 * Normalise a REST notification row into an {@link AppNotification}.
 *
 * The REST API does NOT send `category`, `read_at`, or `href` — it sends
 * `type`, `is_read`, `data`. Previously the service cast the raw row
 * straight to `AppNotification`, so `category` was `undefined` (→ "LAIN"),
 * `read_at` was `undefined` (→ every row looked unread), and `href` was
 * `undefined` (→ clicks never navigated). This mapper derives all three.
 *
 * @param json     the raw REST row
 * @param audience the reader's active role (for role-aware deep-links)
 */
export function notificationFromJson(
  json: NotificationJson,
  audience: NotificationAudience = null,
): AppNotification {
  const data = json.data ?? undefined;
  // Backend exposes `is_read` (boolean) but not a `read_at` timestamp.
  // The UI keys "read" off `read_at`, so synthesise one when read.
  const readAt =
    json.read_at ?? (json.is_read ? json.created_at ?? new Date().toISOString() : null);

  return {
    id: json.id,
    title: json.title ?? '',
    body: json.body ?? '',
    category: notificationCategoryFromType(json.type),
    read_at: readAt,
    created_at: json.created_at ?? new Date().toISOString(),
    href: notificationHref(json.type, data, audience),
    data,
  };
}

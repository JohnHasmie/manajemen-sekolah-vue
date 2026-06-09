/**
 * NotificationService — wraps the /notifications/* endpoints.
 *
 * Mirrors Flutter's `api_notification_service.dart`.
 */
import { api } from '@/lib/http';
import { useAuthStore } from '@/stores/auth';
import type { ApiPaginated, ApiSuccess, Pagination } from '@/types/api';
import {
  notificationFromJson,
  type AppNotification,
  type NotificationAudience,
  type NotificationJson,
} from '@/types/notification';

const Endpoints = {
  list: '/notifications',
  unreadCount: '/notifications/unread-count',
  // Single-row mark-read = DELETE /notifications/{id} (apiResource destroy);
  // there is no `/{id}/read` route. Matches the mobile app's markAsRead.
  markRead: (id: string) => `/notifications/${id}`,
  markAllRead: '/notifications/mark-all-read',
} as const;

/**
 * Map the logged-in user's active role onto the deep-link audience used
 * by `notificationHref`. Teacher + wali kelas share the teacher routes;
 * wali/orang tua are parents; admin/super-admin use the admin routes.
 * Shared so the REST mapper and the realtime mapper (echo.ts) resolve the
 * same target page for the same notification.
 */
export function activeNotificationAudience(): NotificationAudience {
  const auth = useAuthStore();
  const role = String(auth.activeRole ?? '').toLowerCase();
  switch (role) {
    case 'wali':
    case 'parent':
    case 'orang_tua':
      return 'parent';
    case 'guru':
    case 'teacher':
    case 'wali_kelas':
      return 'teacher';
    case 'admin':
    case 'administrator':
    case 'super_admin':
      return 'admin';
    default:
      return null;
  }
}

export const NotificationService = {
  async list(
    page = 1,
    perPage = 20,
  ): Promise<{ items: AppNotification[]; pagination?: Pagination }> {
    const res = await api.get<ApiPaginated<NotificationJson>>(Endpoints.list, {
      params: { page, per_page: perPage },
    });
    const audience = activeNotificationAudience();
    const items = (res.data.data ?? []).map((row) =>
      notificationFromJson(row, audience),
    );
    return { items, pagination: res.data.pagination };
  },

  async unreadCount(): Promise<number> {
    // The backend `getUnreadCount` returns a BARE `{ count: <int> }` body
    // (NOT the `{ success, data: {...} }` envelope) — same shape the mobile
    // app reads as `response.data['count']`. Reading `res.data.data.count`
    // therefore always yielded `undefined → 0`, so the bell badge showed 0
    // on mount regardless of real unread rows. Accept both shapes defensively.
    const res = await api.get<{ count?: number } | ApiSuccess<{ count: number }>>(
      Endpoints.unreadCount,
    );
    const body = res.data as {
      count?: number;
      data?: { count?: number };
    };
    return body.count ?? body.data?.count ?? 0;
  },

  async markRead(id: string): Promise<void> {
    // The API has NO `POST /notifications/{id}/read` route — that call 404'd,
    // which made the store revert its optimistic mark-read (dot reappeared,
    // count never dropped). The single-row "mark read" the backend actually
    // exposes is `DELETE /notifications/{id}` (apiResource destroy), which is
    // exactly what the mobile app uses (see notification_service.dart). The
    // list endpoint only returns unread rows, so removing the row server-side
    // is equivalent to marking it read.
    await api.delete(Endpoints.markRead(id));
  },

  async markAllRead(): Promise<void> {
    await api.post(Endpoints.markAllRead);
  },
};

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
  markRead: (id: string) => `/notifications/${id}/read`,
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
    const res = await api.get<ApiSuccess<{ count: number }>>(Endpoints.unreadCount);
    return res.data.data?.count ?? 0;
  },

  async markRead(id: string): Promise<void> {
    await api.post(Endpoints.markRead(id));
  },

  async markAllRead(): Promise<void> {
    await api.post(Endpoints.markAllRead);
  },
};

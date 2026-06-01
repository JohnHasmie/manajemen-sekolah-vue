/**
 * NotificationService — wraps the /notifications/* endpoints.
 *
 * Mirrors Flutter's `api_notification_service.dart`.
 */
import { api } from '@/lib/http';
import type { ApiPaginated, ApiSuccess, Pagination } from '@/types/api';
import type { AppNotification } from '@/types/notification';

const Endpoints = {
  list: '/notifications',
  unreadCount: '/notifications/unread-count',
  markRead: (id: string) => `/notifications/${id}/read`,
  markAllRead: '/notifications/mark-all-read',
} as const;

export const NotificationService = {
  async list(page = 1, perPage = 20): Promise<{ items: AppNotification[]; pagination?: Pagination }> {
    const res = await api.get<ApiPaginated<AppNotification>>(Endpoints.list, {
      params: { page, per_page: perPage },
    });
    return { items: res.data.data, pagination: res.data.pagination };
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

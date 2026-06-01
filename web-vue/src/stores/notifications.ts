/**
 * Notifications store — Pinia wrapper around NotificationService.
 *
 * State:
 *   - unreadCount: shown on the topbar bell badge
 *   - items: list cache used by NotificationListView
 *   - pagination: from the last list() response
 *   - isLoading / error
 *
 * Mirrors the Flutter NotificationProvider behaviour.
 */
import { defineStore } from 'pinia';
import { NotificationService } from '@/services/notification.service';
import type { Pagination } from '@/types/api';
import type { AppNotification } from '@/types/notification';

interface State {
  unreadCount: number;
  items: AppNotification[];
  pagination: Pagination | null;
  isLoading: boolean;
  error: string | null;
}

export const useNotificationsStore = defineStore('notifications', {
  state: (): State => ({
    unreadCount: 0,
    items: [],
    pagination: null,
    isLoading: false,
    error: null,
  }),

  actions: {
    async refreshUnreadCount() {
      try {
        this.unreadCount = await NotificationService.unreadCount();
      } catch {
        // Silently swallow — bell badge is best-effort.
      }
    },

    async fetch(page = 1) {
      this.isLoading = true;
      this.error = null;
      try {
        const res = await NotificationService.list(page);
        this.items = res.items;
        this.pagination = res.pagination ?? null;
      } catch (e) {
        this.error = (e as Error).message;
      } finally {
        this.isLoading = false;
      }
    },

    async markRead(id: string) {
      const item = this.items.find((i) => i.id === id);
      if (item && !item.read_at) {
        item.read_at = new Date().toISOString();
        if (this.unreadCount > 0) this.unreadCount -= 1;
      }
      try {
        await NotificationService.markRead(id);
      } catch {
        // Revert optimistic update on failure.
        if (item) {
          item.read_at = null;
          this.unreadCount += 1;
        }
      }
    },

    async markAllRead() {
      const previousCount = this.unreadCount;
      const now = new Date().toISOString();
      this.items.forEach((i) => {
        if (!i.read_at) i.read_at = now;
      });
      this.unreadCount = 0;
      try {
        await NotificationService.markAllRead();
      } catch {
        // Revert
        this.unreadCount = previousCount;
        // Best-effort: don't try to revert individual read_ats.
      }
    },
  },
});

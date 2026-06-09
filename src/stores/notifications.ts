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

    /**
     * Insert a freshly-arrived realtime notification at the top of the
     * list cache and bump the unread badge. Idempotent: a duplicate id
     * (e.g. a poll + push race) is ignored and reported via the return
     * value so the caller can skip showing a second toast.
     *
     * @returns true if the row was newly added, false if already known.
     */
    prepend(n: AppNotification): boolean {
      if (this.items.some((i) => i.id === n.id)) return false;
      // Always insert at the top of the cached list. The previous
      // `if (items.length > 0)` guard skipped the insert whenever the
      // cache was empty — but an empty cache is the COMMON case while the
      // user sits on the Notifikasi list with no rows yet, so realtime
      // arrivals bumped the bell badge (unreadCount) WITHOUT ever showing
      // in the list. That's the "badge says 3 unread but the list is
      // empty until I reload" bug. The dedup check above already prevents
      // a poll+push double-insert, and a later fetch() replaces `items`
      // wholesale with the authoritative server page, so unconditionally
      // unshifting is safe in every state (pre-fetch, loaded, or empty).
      this.items.unshift(n);
      if (!n.read_at) this.unreadCount += 1;
      return true;
    },

    async markRead(id: string) {
      const item = this.items.find((i) => i.id === id);
      const wasUnread = item ? !item.read_at : false;
      if (item && wasUnread) {
        item.read_at = new Date().toISOString();
        if (this.unreadCount > 0) this.unreadCount -= 1;
      }
      try {
        await NotificationService.markRead(id);
      } catch {
        // Revert optimistic update on failure.
        if (item && wasUnread) {
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

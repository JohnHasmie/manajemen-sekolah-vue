/**
 * echo.ts — Laravel Echo client wired to a self-hosted **Laravel Reverb**
 * server (Pusher-protocol compatible).
 *
 * Realtime is *purely additive* over the existing polling: when the backend
 * creates a Notification row it broadcasts `notification.created` on the
 * user's private channel `notifications.{user_id}`. The web app listens and
 * updates the bell badge + list live, with no page refresh.
 *
 * INERT-BY-DEFAULT: if `VITE_REVERB_APP_KEY` is empty (dev / builds without a
 * Reverb server) `init()` is a no-op, so nothing ever connects or errors.
 * Realtime only activates once prod sets the VITE_REVERB_* env vars AND a
 * Reverb server is running.
 *
 * Analogy for a Laravel dev: Echo is the JS half of broadcasting — the same
 * role `Broadcast::channel()` + `ShouldBroadcast` play on the server, but
 * living in the browser. `pusher-js` is the raw WebSocket transport; Echo is
 * the Laravel-flavoured wrapper that knows how to subscribe to a private
 * channel and authorise it against `/broadcasting/auth`.
 *
 * Contract (backend MR !106):
 *   - Private channel: `notifications.{user_id}`  (user UUID)
 *   - Event (broadcastAs): `notification.created`
 *     → with Echo, listen for the dot-prefixed name `.notification.created`
 *   - Auth endpoint: `POST {VITE_API_URL}/broadcasting/auth`
 *     (Sanctum bearer token, same one the http client already sends)
 *   - Payload (broadcastWith):
 *       { id, type, title, message, data, is_read, created_at }
 *     NB: `message` here == the model's `body` column (REST uses `body`).
 */
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

import { storage, StorageKeys } from './storage';
import router from '@/router';
import { useToast } from '@/composables/useToast';
import { useNotificationsStore } from '@/stores/notifications';
import { activeNotificationAudience } from '@/services/notification.service';
import {
  notificationCategoryFromType,
  notificationHref,
  type AppNotification,
} from '@/types/notification';

/**
 * Shape of the realtime payload the backend ships in `broadcastWith()`.
 * Deliberately mirrors `App\Events\NotificationCreated::broadcastWith()`.
 * `message` is the same value the REST API exposes as `body`.
 */
interface NotificationCreatedPayload {
  id: string;
  type: string;
  title: string;
  message: string;
  data: Record<string, unknown> | null;
  is_read: boolean;
  created_at: string;
}

// The base URL already ends in `/api` (see lib/http.ts), so the channel-auth
// endpoint is `${VITE_API_URL}/broadcasting/auth` — matching the backend's
// `withBroadcasting(prefix: 'api')` route POST /api/broadcasting/auth.
const API_BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:8001/api';

const REVERB_APP_KEY = import.meta.env.VITE_REVERB_APP_KEY ?? '';
const REVERB_HOST = import.meta.env.VITE_REVERB_HOST ?? '';
const REVERB_PORT = Number(import.meta.env.VITE_REVERB_PORT ?? '443');
const REVERB_SCHEME = import.meta.env.VITE_REVERB_SCHEME ?? 'https';
const FORCE_TLS = REVERB_SCHEME === 'https';

/** The live Echo instance — null whenever realtime is inert / torn down. */
let echo: Echo<'reverb'> | null = null;
/** The user id we currently hold a subscription for (guards re-init). */
let subscribedUserId: string | null = null;

/** Realtime is only possible once an app key is configured. */
export function isRealtimeEnabled(): boolean {
  return REVERB_APP_KEY.trim().length > 0;
}

/** Build the channel name from a user UUID (single source of truth). */
function channelName(userId: string): string {
  return `notifications.${userId}`;
}

/**
 * Map the realtime broadcast payload onto the store's `AppNotification`
 * shape. The realtime event uses `message`/`type`/`is_read`; the store
 * (and REST API) use `body`/`category`/`read_at`. We translate at this
 * boundary so the rest of the app never sees the wire shape.
 */
function toAppNotification(p: NotificationCreatedPayload): AppNotification {
  const data = p.data ?? undefined;
  // Use the SHARED type→category + href derivers so a realtime row and
  // the same row pulled later via REST land in the same category and
  // deep-link to the same page. Audience = the reader's active role.
  const audience = activeNotificationAudience();
  return {
    id: p.id,
    title: p.title,
    body: p.message,
    category: notificationCategoryFromType(p.type),
    read_at: p.is_read ? p.created_at : null,
    created_at: p.created_at,
    href: notificationHref(p.type, data, audience),
    data,
  };
}

/**
 * Navigate to a notification's target page (if any) and mark it read.
 * Shared by the realtime toast's click handler. Safe to call with a null
 * href — it still marks the row read (the founder's bare test rows have
 * no target, but the click must clear their unread state).
 */
function openNotification(n: AppNotification): void {
  const store = useNotificationsStore();
  void store.markRead(n.id);
  if (n.href) {
    void router.push(n.href).catch(() => {
      // Swallow redundant-navigation errors (already on the page).
    });
  }
}

/**
 * Lazily construct the Echo instance pointed at Reverb. Reuses the existing
 * Sanctum bearer token from storage so channel-auth succeeds exactly the way
 * REST calls do. Returns null if realtime is disabled.
 */
function createEcho(): Echo<'reverb'> | null {
  if (!isRealtimeEnabled()) return null;

  const token = storage.get<string>(StorageKeys.token);

  // pusher-js must be discoverable by Echo; v2 accepts it via the `Pusher`
  // option, but setting it on window too keeps older call paths happy.
  if (typeof window !== 'undefined') {
    (window as unknown as { Pusher: typeof Pusher }).Pusher = Pusher;
  }

  return new Echo<'reverb'>({
    broadcaster: 'reverb',
    Pusher,
    key: REVERB_APP_KEY,
    wsHost: REVERB_HOST,
    wsPort: REVERB_PORT,
    wssPort: REVERB_PORT,
    forceTLS: FORCE_TLS,
    enabledTransports: ['ws', 'wss'],
    // Channel authorisation — POST {api}/broadcasting/auth with the same
    // Sanctum bearer token the http client sends. The backend gate in
    // routes/channels.php checks (string)$user->id === (string)$userId.
    authEndpoint: `${API_BASE_URL}/broadcasting/auth`,
    auth: {
      headers: {
        Accept: 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    },
  });
}

/**
 * Subscribe to the logged-in user's private notification channel and wire
 * `notification.created` into the notifications store. Safe to call multiple
 * times — re-subscribing for the same user is a no-op; switching users tears
 * down the old subscription first.
 *
 * @param userId the authenticated user's UUID (e.g. `auth.user.id`)
 */
export function init(userId: string | null | undefined): void {
  if (!isRealtimeEnabled()) return; // inert until prod configures Reverb
  if (!userId) return; // not logged in yet

  // Already wired for this exact user — nothing to do.
  if (echo && subscribedUserId === userId) return;

  // Different user (or stale state) — start clean.
  if (echo) teardown();

  echo = createEcho();
  if (!echo) return;

  subscribedUserId = userId;

  const store = useNotificationsStore();
  const toast = useToast();

  echo
    .private(channelName(userId))
    .listen('.notification.created', (payload: NotificationCreatedPayload) => {
      try {
        const incoming = toAppNotification(payload);

        // Prepend to the list cache + bump the badge. Idempotent: a
        // duplicate id (poll + push race) returns false and we skip the
        // toast so the same arrival never double-notifies.
        const isNew = store.prepend(incoming);
        if (!isNew) return;

        // Don't pop a toast while the user is already staring at the
        // Notifikasi list — the new row appears there live, a toast on
        // top would be redundant. Everywhere else, show it.
        if (router.currentRoute.value.name === 'notifications') return;

        // Visible realtime trigger: a tappable toast with the title +
        // body. Clicking it deep-links to the notification's page (if
        // any) and marks it read.
        toast.show({
          tone: 'info',
          title: incoming.title,
          message: incoming.body,
          onClick: () => openNotification(incoming),
        });
      } catch {
        // Never let a malformed payload break the socket pipeline; the
        // existing polling will reconcile the count on the next tick.
      }
    });
}

/**
 * Leave the channel and disconnect the socket. Call on logout (and before
 * re-init for a different user). Idempotent.
 */
export function teardown(): void {
  if (!echo) {
    subscribedUserId = null;
    return;
  }
  try {
    if (subscribedUserId) {
      echo.leave(channelName(subscribedUserId));
    }
    echo.disconnect();
  } catch {
    // Best-effort cleanup; swallow so logout never throws.
  } finally {
    echo = null;
    subscribedUserId = null;
  }
}

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
import { useNotificationsStore } from '@/stores/notifications';
import type { AppNotification, NotificationCategory } from '@/types/notification';

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
  return {
    id: p.id,
    title: p.title,
    body: p.message,
    category: (p.type as NotificationCategory) ?? 'other',
    read_at: p.is_read ? p.created_at : null,
    created_at: p.created_at,
    data: p.data ?? undefined,
  };
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

  echo
    .private(channelName(userId))
    .listen('.notification.created', (payload: NotificationCreatedPayload) => {
      try {
        const incoming = toAppNotification(payload);

        // Prepend to the list cache *only if it's loaded* and we don't
        // already hold this id (defends against a poll + push race).
        const alreadyKnown = store.items.some((i) => i.id === incoming.id);
        if (!alreadyKnown) {
          if (store.items.length > 0) {
            store.items.unshift(incoming);
          }
          // Freshly-created rows are always unread → bump the badge.
          store.unreadCount += 1;
        }
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

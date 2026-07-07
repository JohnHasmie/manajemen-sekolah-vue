/**
 * Thin wrapper over Web Storage. SSR-safe (no-ops when window is undefined)
 * even though Vite/Vue 3 is CSR by default — keeps future SSR refactor easy.
 *
 * Mirrors Flutter's SharedPreferences usage in token_service.dart.
 *
 * Round-9 audit: the auth Sanctum PAT (StorageKeys.token) is routed to
 * `sessionStorage` instead of `localStorage`. Any successful XSS on the
 * SPA would otherwise walk off with a 30-day bearer (see backend Round-8
 * !331 for the TTL); sessionStorage bounds the theft window to the
 * current tab's lifetime.
 *
 * All other keys (user profile, school id, role, language, teacher
 * profile, parent active-child) stay in localStorage — they carry UI
 * cache, not auth material, and losing them on tab close would force
 * every user to reconfigure preferences every session.
 *
 * A one-time migration runs at module load: any residual legacy
 * `kamiledu.token` in localStorage is hoisted to sessionStorage and
 * then evicted, so already-logged-in users survive the upgrade.
 */

const isBrowser = typeof window !== 'undefined';

/**
 * Keys that carry auth material and must live in `sessionStorage`
 * instead of `localStorage`. Kept as a Set (not a bare string) so a
 * future auth-related key (refresh token, CSRF nonce) can join the
 * short-lived tier without touching the caller-facing API.
 */
const SESSION_STORAGE_KEYS = new Set<string>([
  'kamiledu.token',
]);

function backendFor(key: string): Storage | null {
  if (!isBrowser) return null;
  return SESSION_STORAGE_KEYS.has(key)
    ? window.sessionStorage
    : window.localStorage;
}

// One-time migration: if a legacy plaintext token still sits in
// localStorage from a prior build, hoist it into sessionStorage and
// evict the old copy so an XSS on any future page load can't scrape it.
// Runs at module load — before any store hydrates, before any http
// interceptor reads the token.
if (isBrowser) {
  for (const key of SESSION_STORAGE_KEYS) {
    const legacy = window.localStorage.getItem(key);
    if (legacy !== null) {
      if (window.sessionStorage.getItem(key) === null) {
        window.sessionStorage.setItem(key, legacy);
      }
      window.localStorage.removeItem(key);
    }
  }
}

export const storage = {
  get<T = string>(key: string): T | null {
    const backend = backendFor(key);
    if (!backend) return null;
    const raw = backend.getItem(key);
    if (raw === null) return null;
    try {
      return JSON.parse(raw) as T;
    } catch {
      return raw as unknown as T;
    }
  },

  set(key: string, value: unknown): void {
    const backend = backendFor(key);
    if (!backend) return;
    const payload = typeof value === 'string' ? value : JSON.stringify(value);
    backend.setItem(key, payload);
  },

  remove(key: string): void {
    const backend = backendFor(key);
    if (!backend) return;
    backend.removeItem(key);
  },

  clear(): void {
    if (!isBrowser) return;
    // Clear BOTH backends. `sessionStorage.clear()` only wipes the
    // current tab's copy, so a leftover token in another tab (rare but
    // possible if the user opened a duplicate tab pre-logout) would
    // survive a same-tab clear() — but that's the correct semantic:
    // logout on tab A shouldn't reach into tab B.
    window.localStorage.clear();
    window.sessionStorage.clear();
  },
};

export const StorageKeys = {
  token: 'kamiledu.token',
  user: 'kamiledu.user',
  schoolId: 'kamiledu.school_id',
  role: 'kamiledu.role',
  language: 'kamiledu.lang',
  // Teacher profile (id + homeroom classes) for the active school.
  // Persisted so a hard refresh can render the correct nav (wali-kelas
  // vs plain guru) on the FIRST paint instead of flickering while
  // hydrateSchoolsRoles() re-fetches it. Re-fetched + overwritten on
  // every login / school switch, so it never drifts for long.
  teacherProfile: 'kamiledu.teacher_profile',
  // Which child a multi-child parent is currently viewing. Persisted so
  // a hard refresh (or reopening the app tomorrow) doesn't yank the
  // parent back to child A after they'd been reading child B's rapor.
  // Cleared on logout, so user A's choice can't leak to user B.
  parentActiveChild: 'kamiledu.parent_active_child',
} as const;

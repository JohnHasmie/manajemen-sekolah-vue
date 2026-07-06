/**
 * Thin wrapper over localStorage. SSR-safe (no-ops when window is undefined)
 * even though Vite/Vue 3 is CSR by default — keeps future SSR refactor easy.
 *
 * Mirrors Flutter's SharedPreferences usage in token_service.dart.
 */

const isBrowser = typeof window !== 'undefined';

export const storage = {
  get<T = string>(key: string): T | null {
    if (!isBrowser) return null;
    const raw = window.localStorage.getItem(key);
    if (raw === null) return null;
    try {
      return JSON.parse(raw) as T;
    } catch {
      return raw as unknown as T;
    }
  },

  set(key: string, value: unknown): void {
    if (!isBrowser) return;
    const payload = typeof value === 'string' ? value : JSON.stringify(value);
    window.localStorage.setItem(key, payload);
  },

  remove(key: string): void {
    if (!isBrowser) return;
    window.localStorage.removeItem(key);
  },

  clear(): void {
    if (!isBrowser) return;
    window.localStorage.clear();
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

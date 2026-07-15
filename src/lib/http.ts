/**
 * HTTP client — axios instances for the main Laravel API and the AI API.
 *
 * Mirrors `lib/core/network/dio_client.dart` from the Flutter app:
 *   - Bearer token injected from auth store
 *   - X-School-ID header on every request
 *   - X-Active-Role header (when a role is selected) so the backend can
 *     scope abilities to the role the user is currently acting as
 *   - 30s timeout
 *   - 401 → clear auth + redirect to /login (matches Flutter's global
 *     error handler in `lib/core/network/error_interceptor.dart`)
 *   - Response envelope `{ success, data, message, errors }` unwrapped for
 *     callers via `extractData` helper
 */
import axios, {
  type AxiosInstance,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from 'axios';
import { storage, StorageKeys } from './storage';
import type { ApiError, ApiResponse } from '@/types/api';

/**
 * Request config augmented with a flag recording whether the request
 * was sent with a bearer token. Set by the request interceptor, read by
 * the response interceptor to scope session-expired handling to genuine
 * authenticated requests only.
 */
type AuthAwareRequestConfig = InternalAxiosRequestConfig & {
  __hadAuthToken?: boolean;
};

/**
 * URL prefixes that must NEVER receive an auto-injected
 * `academic_year_id` — either because they don't filter by year,
 * or because they're the academic-year endpoints themselves.
 */
const AY_INJECT_BLOCKLIST: readonly string[] = [
  '/academic-year', // /academic-year/active, /academic-years, etc.
  '/auth/',
  '/login',
  '/logout',
  '/notifications',
  '/school/',
];

function shouldInjectAcademicYear(url: string | undefined): boolean {
  if (!url) return false;
  const path = url.split('?')[0];
  return !AY_INJECT_BLOCKLIST.some((p) => path.startsWith(p));
}

const MAIN_BASE_URL =
  import.meta.env.VITE_API_URL ?? 'http://localhost:8001/api';
const AI_BASE_URL =
  import.meta.env.VITE_AI_API_URL ?? 'http://localhost:8000/api';

/**
 * Endpoints that look across the WHOLE registry rather than a single
 * tenant. Sending an X-Tenant-ID for these flags the request as
 * tenant-scoped and the backend's EnsureSchoolContext middleware 403s
 * any stale tenant id from a previous session — the wizard then can't
 * find any schools. The interceptor below skips the headers for these
 * paths so the registry search just works regardless of LS state.
 *
 * Match is on the URL we feed axios — both the relative form
 * (`/demo/schools/search`) and the absolute form land here.
 */
const TENANTLESS_PATTERNS: readonly RegExp[] = [
  /\/schools\/search(\?|$)/,
  /\/demo\/schools\/search(\?|$)/,
  /\/npsn-lookup(\?|$)/,
];
function isTenantless(url?: string): boolean {
  if (!url) return false;
  return TENANTLESS_PATTERNS.some((re) => re.test(url));
}

function buildClient(
  baseURL: string,
  // Whether to auto-inject the selected `academic_year_id` on year-scoped
  // requests. ONLY safe for the main (edu_core) API: the core uses UUID
  // academic-year ids, but the AI service (edu_ai) keys academic years by
  // INTEGER — sending the core UUID there fails its `nullable|integer`
  // rule with a 422 (e.g. POST /recommendations/generate). The AI service
  // resolves the current year itself when the field is absent, so the AI
  // client opts out entirely.
  injectAcademicYear = true,
): AxiosInstance {
  const client = axios.create({
    baseURL,
    timeout: 30_000,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
  });

  client.interceptors.request.use((config: InternalAxiosRequestConfig) => {
    const token = storage.get<string>(StorageKeys.token);
    const schoolId = storage.get<string>(StorageKeys.schoolId);
    const locale = storage.get<string>(StorageKeys.language) ?? 'id';
    // Read the ACTIVE role fresh on every request (not captured once at
    // module load) so a "pindah peran" switch takes effect on the very
    // next call — the auth store writes StorageKeys.role synchronously
    // in `selectRole` before it fires switchRole, so even that request
    // already carries the new role.
    const activeRole = storage.get<string>(StorageKeys.role);

    if (token) {
      config.headers.set('Authorization', `Bearer ${token}`);
    }
    // Record whether THIS request was made as an authenticated user.
    // The response interceptor uses this to distinguish a genuine
    // session-expiry (token was present → server rejected it) from a
    // 401 on a request that never carried a session at all (e.g. a
    // public endpoint hit on the login page before sign-in). Only the
    // former should clear state + show the "session expired" toast.
    (config as AuthAwareRequestConfig).__hadAuthToken = Boolean(token);
    if (schoolId && !isTenantless(config.url)) {
      // Send BOTH the new X-Tenant-ID (preferred by the backend's
      // EnsureSchoolContext since Phase 0) and the legacy X-School-ID
      // alias, same value — the `schools` table hosts both formal
      // schools and tutoring centers, so one id drives both. Forward-
      // compatible with no breaking change. Mirrors the Flutter Dio
      // AuthInterceptor.
      config.headers.set('X-School-ID', schoolId);
      config.headers.set('X-Tenant-ID', schoolId);
    }

    // Tell the backend which role the user is CURRENTLY acting as, so
    // its AbilityResolver can scope abilities to that one role instead
    // of unioning every active role the user holds at this school.
    //
    // Why: a user with parent+teacher+staff roles was getting teacher's
    // `academic.*` abilities while acting as *staff*, which wrongly lit
    // up Jadwal/Nilai/Rekap/RPP/Kegiatan/Riwayat-Presensi in the staff
    // sidebar.
    //
    // Scope note: this ONLY narrows abilities server-side. The user's
    // full roles + schools list is unaffected, so the role switcher
    // ("pindah peran") still sees every role.
    //
    // Omitted entirely when there's no active role (unauthenticated, or
    // the picker hasn't run yet) — the backend then falls back to the
    // legacy union behaviour. Never send an empty string.
    //
    // Sent as stored; the backend canonicalises aliases (guru→teacher,
    // wali→parent) itself.
    if (activeRole) {
      config.headers.set('X-Active-Role', activeRole);
    }
    // Tell the backend which locale to render server-side strings in
    // (priority-inbox labels/subtitles, validator messages, mail
    // bodies, etc.). The Laravel `SetLocaleFromHeader` middleware
    // reads this header and calls `App::setLocale()` accordingly.
    config.headers.set('Accept-Language', locale);

    // Auto-inject the selected academic year as a default param on
    // every request that targets a year-scoped endpoint. The caller
    // can still override by passing `academic_year_id` explicitly in
    // `config.params` / `config.data` — only undefined values get
    // back-filled. Pass `academic_year_id: null` to opt out for a
    // single call.
    if (injectAcademicYear && shouldInjectAcademicYear(config.url)) {
      // Lazy-read from localStorage to avoid pulling pinia in here.
      // The pinia store persists the picked id under the same key.
      let yearId: string | null = null;
      try {
        yearId = localStorage.getItem('kamiledu.academicYearId');
      } catch {
        yearId = null;
      }
      if (yearId) {
        const method = (config.method ?? 'get').toLowerCase();
        if (method === 'get' || method === 'delete') {
          const params = (config.params ?? {}) as Record<string, unknown>;
          if (
            !('academic_year_id' in params) ||
            params.academic_year_id === undefined
          ) {
            params.academic_year_id = yearId;
            config.params = params;
          } else if (params.academic_year_id === null) {
            // Caller explicitly opted out — drop the null so the
            // backend doesn't see it.
            delete params.academic_year_id;
            config.params = params;
          }
        } else {
          // POST / PUT / PATCH — inject into the body when the body
          // is a plain object and the field isn't already set. Skip
          // FormData / strings to stay safe.
          const data = config.data;
          if (
            data &&
            typeof data === 'object' &&
            !(data instanceof FormData) &&
            !Array.isArray(data) &&
            !('academic_year_id' in data)
          ) {
            (data as Record<string, unknown>).academic_year_id = yearId;
            config.data = data;
          }
        }
      }
    }
    return config;
  });

  client.interceptors.response.use(
    (response: AxiosResponse) => response,
    async (error) => {
      const status = error.response?.status;

      // 400 "No active school context" → treat GET requests as an
      // empty state instead of a hard error.
      //
      // Rationale: a fresh admin (or a super-admin briefly between
      // schools) legitimately has no active school selected for a
      // fraction of a second, and every list endpoint the shell
      // fires (kelas, guru, siswa, mapel, jadwal, stats,
      // filter-options, settings) responds 400. Rendering "Terjadi
      // kesalahan / Request failed with status code 400" for ALL of
      // them reads as a broken app rather than the truthful "you
      // haven't picked a school yet".
      //
      // Rewrite the error into a resolved 200 with an empty envelope
      // so the standard AsyncView empty-state fires everywhere. Only
      // GET is safe — mutations (POST/PUT/DELETE) still error because
      // they legitimately can't proceed without school context.
      const method = String(error.config?.method ?? '').toUpperCase();
      const errBody = error.response?.data;
      const isMissingContext =
        status === 400 &&
        typeof errBody?.error === 'string' &&
        errBody.error.toLowerCase().includes('no active school context');
      if (isMissingContext && method === 'GET') {
        // Log once so devs can trace unexpected empty states in
        // Sentry / server logs — the app SURFACE stays quiet.
        // eslint-disable-next-line no-console
        console.warn(
          '[http] No active school context on GET',
          error.config?.url,
          '→ rewriting to empty envelope',
        );
        return {
          ...error.response,
          status: 200,
          statusText: 'OK (empty context)',
          data: {
            success: true,
            data: [],
            pagination: {
              total_items: 0,
              total_pages: 0,
              current_page: 1,
              per_page: 0,
              has_next_page: false,
              has_prev_page: false,
            },
            _empty_context: true,
          },
        } as AxiosResponse;
      }

      // Only treat a 401 as a *session expiry* when the request was
      // actually made with a bearer token (a real session that the
      // server has now rejected). A 401 on a request that carried no
      // token is just an unauthenticated/public call being refused —
      // there was never a session to expire, so we must NOT clear
      // state, redirect, or show the "Session Anda telah berakhir" toast.
      //
      // Without this guard the public login page showed a spurious
      // session-expired toast: a 401 from any pre-auth call (or an
      // expired-token bounce that lands back here) redirected to
      // `/login?reason=...`, which LoginView surfaces as a red toast
      // even though the user had never signed in.
      const hadAuthToken = Boolean(
        (error.config as AuthAwareRequestConfig | undefined)?.__hadAuthToken,
      );

      // 402 Payment Required — the backend's EnsureSeatUnderHardCap
      // middleware refused a create/import because the tenant sits at
      // (or would exceed) paid_seats × 1.10. Route the payload into
      // the billing-ui store so the global modal in App.vue can prompt
      // the user to top up. We STILL reject the promise so the caller
      // can also react (spinner off, form re-enabled).
      if (status === 402 && error.response?.data?.error === 'seat_hard_cap_reached') {
        try {
          // Lazy-import to avoid a circular dep at module init.
          const { useBillingUiStore } = await import('@/stores/billing-ui');
          useBillingUiStore().reportHardCap(error.response.data);
        } catch {
          /* non-fatal — the caller still sees the reject */
        }
      }

      if (status === 401 && hadAuthToken) {
        // Token expired or invalidated. Clear state and bounce to /login.
        storage.remove(StorageKeys.token);
        storage.remove(StorageKeys.user);
        storage.remove(StorageKeys.schoolId);
        storage.remove(StorageKeys.role);

        // Do NOT yank the user off marketing / self-serve routes on a
        // background 401 — /subscribe, /register-demo, and /login are
        // meant to render in an unauthenticated state anyway, so a stale
        // token being rejected mid-flow (e.g. hydrateSchoolsRoles firing
        // a tenant-scoped call while the user is still at step='school'
        // on the multi-tenant Google-return path) should just clear the
        // token silently — not do a full-page navigation that pulls the
        // user off the page they intentionally landed on.
        const PUBLIC_PREFIXES = [
          '/login',
          '/subscribe',
          '/register-demo',
        ] as const;
        const pathname =
          typeof window !== 'undefined' ? window.location.pathname : '';
        const onPublicRoute = PUBLIC_PREFIXES.some(
          (p) => pathname === p || pathname.startsWith(p + '/'),
        );

        if (typeof window !== 'undefined' && !onPublicRoute) {
          window.location.assign(
            '/login?reason=Sesi+Anda+telah+berakhir.+Silakan+masuk+kembali.',
          );
        }
      }

      return Promise.reject(error);
    },
  );

  return client;
}

export const api = buildClient(MAIN_BASE_URL);
export const aiApi = buildClient(AI_BASE_URL, false);

/**
 * Unwraps the Laravel response envelope.
 *
 * On success: returns `data` directly (the meaningful payload).
 * On failure: throws an Error with a human-readable Indonesian message,
 *             matching Flutter's `error_utils.dart` behaviour.
 */
export function extractData<T>(response: AxiosResponse<ApiResponse<T>>): T {
  const body = response.data;
  if ('success' in body && body.success && 'data' in body) {
    return body.data;
  }
  if ('success' in body && body.success === false) {
    throw httpError(body);
  }
  // If the backend returned a non-envelope payload, pass it through.
  return body as unknown as T;
}

export function httpError(body: ApiError | unknown, fallback?: string): Error {
  if (body && typeof body === 'object' && 'message' in body) {
    return new Error(
      ((body as ApiError).message as string) ?? fallback ?? 'Terjadi kesalahan',
    );
  }
  return new Error(fallback ?? 'Terjadi kesalahan');
}

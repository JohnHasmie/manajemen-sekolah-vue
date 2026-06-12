/**
 * HTTP client — axios instances for the main Laravel API and the AI API.
 *
 * Mirrors `lib/core/network/dio_client.dart` from the Flutter app:
 *   - Bearer token injected from auth store
 *   - X-School-ID header on every request
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
    if (schoolId) {
      // Send BOTH the new X-Tenant-ID (preferred by the backend's
      // EnsureSchoolContext since Phase 0) and the legacy X-School-ID
      // alias, same value — the `schools` table hosts both formal
      // schools and tutoring centers, so one id drives both. Forward-
      // compatible with no breaking change. Mirrors the Flutter Dio
      // AuthInterceptor.
      config.headers.set('X-School-ID', schoolId);
      config.headers.set('X-Tenant-ID', schoolId);
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

      // Only treat a 401 as a *session expiry* when the request was
      // actually made with a bearer token (a real session that the
      // server has now rejected). A 401 on a request that carried no
      // token is just an unauthenticated/public call being refused —
      // there was never a session to expire, so we must NOT clear
      // state, redirect, or show the "Sesi Anda telah berakhir" toast.
      //
      // Without this guard the public login page showed a spurious
      // session-expired toast: a 401 from any pre-auth call (or an
      // expired-token bounce that lands back here) redirected to
      // `/login?reason=...`, which LoginView surfaces as a red toast
      // even though the user had never signed in.
      const hadAuthToken = Boolean(
        (error.config as AuthAwareRequestConfig | undefined)?.__hadAuthToken,
      );

      if (status === 401 && hadAuthToken) {
        // Token expired or invalidated. Clear state and bounce to /login.
        storage.remove(StorageKeys.token);
        storage.remove(StorageKeys.user);
        storage.remove(StorageKeys.schoolId);
        storage.remove(StorageKeys.role);

        if (
          typeof window !== 'undefined' &&
          window.location.pathname !== '/login'
        ) {
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

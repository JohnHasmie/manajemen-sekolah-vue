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

function buildClient(baseURL: string): AxiosInstance {
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

    if (token) {
      config.headers.set('Authorization', `Bearer ${token}`);
    }
    if (schoolId) {
      config.headers.set('X-School-ID', schoolId);
    }

    // Auto-inject the selected academic year as a default param on
    // every request that targets a year-scoped endpoint. The caller
    // can still override by passing `academic_year_id` explicitly in
    // `config.params` / `config.data` — only undefined values get
    // back-filled. Pass `academic_year_id: null` to opt out for a
    // single call.
    if (shouldInjectAcademicYear(config.url)) {
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

      if (status === 401) {
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
export const aiApi = buildClient(AI_BASE_URL);

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

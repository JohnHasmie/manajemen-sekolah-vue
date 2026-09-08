/**
 * Google Identity Services "redirect mode" — the return leg.
 *
 * GIS is initialised with `ux_mode: 'redirect'` (see
 * `composables/useGoogleSignIn.ts`), so the rendered button navigates the
 * WHOLE browser to Google and Google POSTs the credential to the backend's
 * `/auth/google-redirect`. That endpoint 302s us back to
 * `<frontend><state>#kg_token=<sanctum-pat>` on success, or
 * `<frontend><state>#kg_error=<code>` on failure — `<state>` being the path
 * the user started from, normally `/login`.
 *
 * ── Why this lives in its own module, consumed from `main.ts` ────────────
 *
 * The fragment carries a live 30-day Sanctum PAT. It must never survive
 * into anything that records URLs (LogRocket session replay, browser
 * history, a copy-pasted link).
 *
 * The handler used to sit in `App.vue`'s `onMounted`, which is too late by
 * two separate mechanisms:
 *
 *   1. `LogRocket.init()` runs at the top of `main.ts` and captures the
 *      page URL as it is at that moment — token included.
 *   2. `app.use(router)` kicks off vue-router's INITIAL navigation, which
 *      resolves the current location (hash and all) into `currentRoute` and
 *      then `history.replace(fullPath)` as part of finalising it. That
 *      replace runs AFTER `onMounted`, so the router faithfully re-pasted
 *      the `#kg_token=...` the handler had just stripped. The token was
 *      only "cleaned" until the next navigation overwrote the URL — and on
 *      the failure path there is no next navigation, which is exactly the
 *      stranded-on-/login-with-a-visible-token symptom users reported.
 *
 * Consuming the fragment at module scope in `main.ts` — before LogRocket
 * and before the router exists — means neither ever sees the token.
 * `App.vue` then reads the already-parsed outcome via `takeGoogleRedirect()`.
 */
import { storage, StorageKeys } from './storage';

/** Outcome of the boot-time fragment read. */
export type GoogleRedirectResult =
  | {
      kind: 'token';
      /** Backend flagged this account as eligible for the demo wizard. */
      canCreateDemo: boolean;
    }
  | { kind: 'error'; code: string; message: string }
  | { kind: 'none' };

const NONE: GoogleRedirectResult = { kind: 'none' };

/**
 * Storage keys that describe WHICH TENANT a session was last acting as.
 *
 * These live in `localStorage` while the token lives in `sessionStorage`
 * (see `storage.ts`), so they routinely outlive the session that wrote
 * them: close the tab and the token is gone but the tenant id remains.
 * `http.ts` then injects that leftover id as `X-Tenant-ID` on the very
 * first call of the NEXT session — including `/me`, which the backend's
 * `EnsureSchoolContext` does not bypass, so it answers 403 whenever the
 * newly signed-in account is not an active member of that tenant.
 *
 * `kamiledu.academicYearId` is written straight to `localStorage` by
 * `stores/academic-year.ts` rather than through `StorageKeys`, and
 * `http.ts` auto-injects it as a query param, so it belongs to the same
 * per-tenant scope and has to be dropped with the rest.
 */
const TENANT_SCOPE_KEYS: readonly string[] = Object.freeze([
  StorageKeys.user,
  StorageKeys.schoolId,
  StorageKeys.role,
  StorageKeys.teacherProfile,
  StorageKeys.parentActiveChild,
  'kamiledu.academicYearId',
]);

/**
 * Drop every cached "which tenant am I in" key, leaving the token alone.
 *
 * Used in two places, both on the Google return leg: before `/me` when the
 * remembered tenant turns out not to belong to the account that just
 * signed in, and after a failed hydration so the user's retry starts from
 * a clean slate instead of re-sending the same poisoned header.
 */
export function clearTenantScope(): void {
  for (const key of TENANT_SCOPE_KEYS) storage.remove(key);
}

/**
 * User-facing text for a `kg_error=<code>` fragment.
 *
 * The codes are emitted by `AuthController::googleRedirect`. An unknown
 * code still yields a real sentence — a new backend code must never
 * degrade into a blank toast.
 */
export function googleRedirectErrorMessage(code: string): string {
  switch (code) {
    case 'missing_credential':
    case 'malformed_token':
    case 'invalid_token':
      return 'Masuk dengan Google gagal: data dari Google tidak lengkap atau tidak valid. Silakan coba lagi.';
    case 'no_token':
      return 'Masuk dengan Google gagal: server tidak mengeluarkan sesi. Silakan coba lagi.';
    case 'login_rejected':
      return 'Akun Google Anda ditolak. Pastikan Anda memakai email yang terdaftar di KamilEdu, atau hubungi admin sekolah Anda.';
    default:
      return 'Masuk dengan Google gagal. Silakan coba lagi atau masuk dengan email dan kata sandi.';
  }
}

/** Outcome captured by `consumeGoogleRedirectFragment`, read once by App.vue. */
let pending: GoogleRedirectResult = NONE;

/**
 * Read + strip the `#kg_*` fragment and, on success, persist the token.
 *
 * MUST be called before `LogRocket.init()` and before `app.use(router)` —
 * see the module docblock for why. Idempotent in effect: a second call
 * finds no fragment and reports `none`, which also means a page reload
 * can't re-consume a token that is no longer in the URL.
 */
export function consumeGoogleRedirectFragment(): GoogleRedirectResult {
  pending = NONE;
  if (typeof window === 'undefined') return pending;

  const raw = window.location.hash;
  if (!raw || raw.length < 2) return pending;

  const params = new URLSearchParams(raw.slice(1));
  const token = params.get('kg_token');
  const err = params.get('kg_error');
  if (!token && !err) return pending;

  // Strip before anything else — including before we touch storage — so a
  // mid-flight exception can't leave the PAT sitting in the address bar.
  try {
    window.history.replaceState(
      null,
      '',
      window.location.pathname + window.location.search,
    );
  } catch {
    /* non-fatal: some embedded webviews refuse replaceState */
  }

  if (token) {
    try {
      storage.set(StorageKeys.token, token);
    } catch {
      // Storage full / private mode — we cannot authenticate at all.
      pending = {
        kind: 'error',
        code: 'storage_unavailable',
        message:
          'Browser Anda memblokir penyimpanan sesi, sehingga masuk dengan Google tidak bisa diselesaikan. Matikan mode penyamaran atau izinkan penyimpanan situs, lalu coba lagi.',
      };
      return pending;
    }
    pending = {
      kind: 'token',
      // Any non-empty value counts, matching the previous inline handler:
      // the backend emits `=1` today, but a future `=true` must not
      // silently stop routing demo-eligible accounts to the wizard.
      canCreateDemo: Boolean(params.get('kg_dapat_buat_demo')),
    };
    return pending;
  }

  const code = err ?? 'login_failed';
  pending = {
    kind: 'error',
    code,
    message: googleRedirectErrorMessage(code),
  };
  return pending;
}

/**
 * Hand the boot-time outcome to the single consumer (`App.vue`) and
 * forget it, so a remount can't replay a redirect that already happened.
 */
export function takeGoogleRedirect(): GoogleRedirectResult {
  const result = pending;
  pending = NONE;
  return result;
}

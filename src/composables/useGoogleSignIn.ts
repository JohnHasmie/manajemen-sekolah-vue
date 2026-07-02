/**
 * useGoogleSignIn — Google Identity Services (GIS) integration.
 *
 * Mirrors Flutter's google_sign_in flow that lands on `/auth/google-login`.
 * The web equivalent uses GIS's `id_token` flow:
 *   1. Lazy-load https://accounts.google.com/gsi/client
 *   2. Initialize ONCE with VITE_GOOGLE_CLIENT_ID
 *   3. Render a real Google button OR open the account chooser on demand
 *   4. On callback, decode the JWT for { email, name, picture } and POST
 *      it to /auth/google-login via the auth store
 *
 * Set VITE_GOOGLE_CLIENT_ID in `.env.local` to enable. With no client ID,
 * `isEnabled` is false and the LoginForm hides the button.
 *
 * ── Why a module-level singleton ──────────────────────────────────────
 * `google.accounts.id.initialize()` must be called EXACTLY ONCE per page.
 * This composable is used by BOTH `LoginForm` (rendered button) AND
 * `DemoCtaCard` (demo CTA). Previously each call site created its own
 * reactive state + its own `onMounted` → `initialize()`, so GIS logged
 * `initialize() is called multiple times` and the last config silently
 * won. We now hoist all GIS state + the init guard to module scope, so
 * every `useGoogleSignIn()` caller shares one initialized instance and
 * `initialize()` runs once regardless of how many components mount.
 *
 * ── Why we render a REAL, VISIBLE button (and dropped the proxy hack) ──
 * `google.accounts.id.prompt()` (One Tap) goes through FedCM, which the
 * browser disables on cooldown, in incognito, or after a prior dismissal
 * — it then rejects with NetworkError / AbortError and shows NO UI, so
 * the account chooser never appears.
 *
 * The previous fix tried to keep a custom-styled CTA button by rendering
 * a GIS button OFF-SCREEN and proxying a synthetic `.click()` to it. That
 * silently no-ops: GIS's rendered button only reacts to **trusted**,
 * user-initiated clicks (`event.isTrusted === true`). A programmatic
 * `HTMLElement.click()` produces an untrusted event, so GIS ignores it —
 * no popup, no console error (exactly the reported symptom).
 *
 * The robust, FedCM-independent path that still yields an `id_token`
 * (which the backend REQUIRES — see GoogleLoginRequest: `id_token` is
 * `required`) is to render a REAL, VISIBLE GIS button and let the user
 * click it directly. With `ux_mode: 'popup'` that trusted click opens
 * Google's account-chooser popup and returns an id_token to our shared
 * callback. Both the login form and the demo CTA render their own real
 * button. One Tap remains a best-effort progressive enhancement only.
 */
import { ref } from 'vue';
import { useAuthStore } from '@/stores/auth';

const GIS_SRC = 'https://accounts.google.com/gsi/client';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type GoogleAny = any;

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: GoogleAny) => void;
          renderButton: (parent: HTMLElement, options: GoogleAny) => void;
          prompt: (callback?: GoogleAny) => void;
        };
      };
    };
  }
}

/**
 * Detects embedded/in-app browsers (Threads, Instagram, Facebook, LINE,
 * WeChat, TikTok, Snapchat, Twitter, …) and any Android System WebView.
 *
 * Google Identity Services is unusable in these contexts on TWO counts:
 *   1. The GIS client script frequently fails to load at all (restricted
 *      webview network/CSP) → the old "GIS load failed" red text.
 *   2. Even when it loads, Google REFUSES OAuth from embedded webviews
 *      with `disallowed_useragent` ("this browser may not be secure").
 * So when this is true we never attempt GIS; instead the UI tells the
 * user to open the page in a real browser (Chrome/Safari) and keeps the
 * email + password path fully working. This is the reported bug: opening
 * the site from the Threads in-app browser broke Google login / demo.
 */
function detectInAppBrowser(): boolean {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent || '';
  // Named in-app browsers (Meta family incl. Threads' "Barcelona" codename).
  const named =
    /(FBAN|FBAV|FB_IAB|FBIOS|FBSS|Instagram|Barcelona|Threads|Line\/|MicroMessenger|TikTok|musical_ly|Bytedance|Snapchat|Twitter)/i;
  if (named.test(ua)) return true;
  // Android System WebView — Google OAuth is blocked in ANY Android
  // webview regardless of host app (`; wv)` is the WebView UA marker).
  if (/;\s*wv\)/.test(ua) || /\bwv\b/.test(ua)) return true;
  return false;
}

// ── Module-level singleton state ────────────────────────────────────────
// Shared across every `useGoogleSignIn()` caller so GIS is initialized
// exactly once and all components observe the same readiness/error.
const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;
const isEnabled = ref(Boolean(clientId));
const isReady = ref(false);
const error = ref<string | null>(null);
// True inside an embedded in-app browser where GIS can't work. Distinct
// from `isEnabled` (server has a client ID) and from a transient load
// error — lets the UI show "open in Chrome/Safari" instead of the
// misleading "Google not configured" / raw "GIS load failed".
const isInAppBrowser = ref(detectInAppBrowser());

let scriptPromise: Promise<void> | null = null;
let initPromise: Promise<void> | null = null;
let initialized = false;

function loadScript(): Promise<void> {
  if (typeof window === 'undefined') return Promise.resolve();
  if (window.google?.accounts?.id) return Promise.resolve();
  if (scriptPromise) return scriptPromise;

  scriptPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      `script[src="${GIS_SRC}"]`,
    );
    if (existing) {
      existing.addEventListener('load', () => resolve());
      existing.addEventListener('error', () => reject(new Error('GIS_LOAD_FAILED')));
      return;
    }

    const tag = document.createElement('script');
    tag.src = GIS_SRC;
    tag.async = true;
    tag.defer = true;
    tag.onload = () => resolve();
    tag.onerror = () => reject(new Error('GIS_LOAD_FAILED'));
    document.head.appendChild(tag);
  });

  return scriptPromise;
}

/** Decodes the JWT payload (no signature verification — server re-verifies). */
function decodeJwtPayload(token: string): Record<string, unknown> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return {};
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(json);
  } catch {
    return {};
  }
}

/**
 * Recover the calling-button's intent from the focused GIS iframe.
 *
 * Why this dance: GIS renders its button INSIDE a cross-origin iframe,
 * so click events on the actual button never bubble out — a listener on
 * the outer container is silent. But the iframe ELEMENT itself lives in
 * our DOM, and clicking inside it focuses the iframe (it becomes
 * `document.activeElement`). We can `closest()` upward from there to
 * find the nearest ancestor tagged by the mounting component, and act
 * on that intent. Components opt in by adding `data-google-intent="…"`
 * to the container they pass to `mountButton`.
 *
 * Side-effect-light by design: only writes the demo flag on a positive
 * match, so a plain login is never misrouted.
 */
function flagIntentFromFocusedGisButton(): void {
  try {
    const active = document.activeElement;
    if (!(active instanceof HTMLIFrameElement)) return;
    const ancestor = active.closest<HTMLElement>('[data-google-intent]');
    if (ancestor?.dataset.googleIntent === 'demo') {
      sessionStorage.setItem('demo_intent_v1', '1');
    }
  } catch {
    // sessionStorage can throw in private mode; non-fatal
  }
}

async function handleCredentialResponse(response: { credential?: string }) {
  if (!response?.credential) {
    error.value = 'Tidak ada kredensial dari Google.';
    return;
  }

  const payload = decodeJwtPayload(response.credential) as {
    email?: string;
    name?: string;
    picture?: string;
  };

  if (!payload.email) {
    error.value = 'Token Google tidak memuat email.';
    return;
  }

  // Recover demo intent from the just-clicked GIS button BEFORE handing
  // off to the auth store, so LoginView's post-auth watcher reads the
  // right flag and routes the user to /register-demo when appropriate.
  flagIntentFromFocusedGisButton();

  try {
    const auth = useAuthStore();
    await auth.googleLogin({
      email: payload.email,
      displayName: payload.name,
      photoUrl: payload.picture,
      idToken: response.credential,
    });
  } catch (e) {
    error.value = (e as Error).message;
  }
}

/**
 * Loads + initializes GIS exactly once. Subsequent calls await the same
 * in-flight/settled promise rather than re-initializing — this is the
 * single point that calls `google.accounts.id.initialize()`.
 */
function ensureInit(): Promise<void> {
  if (!isEnabled.value) return Promise.resolve();
  // Embedded in-app browser: never attempt GIS (it can't work — see
  // detectInAppBrowser). Surface a distinct sentinel so the UI shows the
  // "open in a real browser" notice rather than a technical/load error.
  if (isInAppBrowser.value) {
    error.value = 'IN_APP_BROWSER';
    return Promise.reject(new Error('IN_APP_BROWSER'));
  }
  if (initPromise) return initPromise;

  initPromise = (async () => {
    try {
      await loadScript();
      if (!window.google?.accounts?.id) {
        throw new Error('GIS not available after load');
      }
      if (!initialized) {
        // GIS "redirect mode" — see App.vue's kg_token/kg_error hash
        // handler for the return leg. Popup mode was silently failing
        // on some Chrome M120+ environments due to COOP enforcement on
        // the popup↔opener postMessage channel; redirect mode avoids
        // that channel entirely by navigating the whole browser to
        // Google and back.
        //
        // `state` carries the user's current path so the backend can
        // 302 them back to it after auth. Query string preserved too
        // so /subscribe?returnTo=... style flows keep their params.
        // The backend guards against open-redirect by only accepting
        // path-only `state` values.
        // login_uri resolution order — see the Google Cloud Console
        // "Authorized redirect URIs" list; every value we emit here must
        // be in it or Google returns `Error 400: redirect_uri_mismatch`.
        //
        //   1. `VITE_GOOGLE_LOGIN_URI` (preferred) — pin the exact URI in
        //      the FE build. Set this once per deployment target and it
        //      NEVER changes no matter how many times the backend is
        //      redeployed. The right knob to reach for when the team has
        //      a stable OAuth-callback subdomain (e.g. via nginx) that
        //      shouldn't move with backend container churn.
        //   2. Derive from `VITE_API_URL` — the historical behaviour, kept
        //      as a fallback so the smaller repos + local dev checkouts
        //      that never set the new var keep working. Downside: any
        //      time VITE_API_URL rotates (e.g. testing against a fresh
        //      ngrok tunnel) the URI changes too, which means re-adding
        //      it to GCP each time.
        //   3. Compile-time localhost default — last-resort dev fallback.
        //
        // If Google's error page reports a URI that doesn't match what
        // this code sends, DevTools console will show the effective
        // value (logged below) so you can compare against the GCP list.
        const explicitLoginUri = (
          import.meta.env.VITE_GOOGLE_LOGIN_URI as string | undefined
        )?.trim();
        const apiBase = ((import.meta.env.VITE_API_URL as string | undefined)
          ?? 'http://localhost:8001/api').replace(/\/+$/, '');
        const loginUri = explicitLoginUri && explicitLoginUri.length > 0
          ? explicitLoginUri
          : `${apiBase}/auth/google-redirect`;
        if (import.meta.env.DEV) {
          // eslint-disable-next-line no-console
          console.info('[GIS] login_uri =', loginUri, {
            source: explicitLoginUri ? 'VITE_GOOGLE_LOGIN_URI' : 'VITE_API_URL',
          });
        }
        window.google.accounts.id.initialize({
          client_id: clientId,
          // In redirect mode, `callback` only fires for the One Tap
          // prompt path (which still uses FedCM below). The rendered
          // button click goes through login_uri instead.
          callback: handleCredentialResponse,
          ux_mode: 'redirect',
          login_uri: loginUri,
          state: window.location.pathname + window.location.search,
          auto_select: false,
          // Enable FedCM for the One Tap prompt path (independent of
          // ux_mode). Chrome M120+ enforces COOP on the legacy
          // postMessage channel that One Tap otherwise uses; FedCM
          // uses navigator.credentials.get() and side-steps it.
          use_fedcm_for_prompt: true,
          // Safari ITP partitions third-party storage aggressively;
          // without this hint GIS can lose the session cookie between
          // pages, silently failing. No-op on other browsers.
          itp_support: true,
        });
        initialized = true;
      }
      isReady.value = true;
    } catch (e) {
      error.value = (e as Error).message;
      // NOTE: do NOT flip `isEnabled` to false here. A failed SCRIPT load
      // (network / restricted webview) is not the same as "the server has
      // no Google client ID" — conflating them made the demo card show the
      // misleading "Login Google belum dikonfigurasi di server ini" even
      // though it was configured. `isEnabled` stays true (client ID exists);
      // the UI keys off `error`/`isInAppBrowser` to show the right message.
      // Allow a future retry (e.g. transient network failure loading GIS).
      initPromise = null;
      throw e;
    }
  })();

  return initPromise;
}

export interface MountButtonOptions {
  /**
   * Pixel width of the rendered button. GIS caps this at 400 and ignores
   * `width: '100%'`-style values, so callers pass a concrete number
   * (usually the container's measured `clientWidth`).
   */
  width?: number;
  /** GIS button theme. Demo CTA uses a filled blue; login uses outline. */
  theme?: 'outline' | 'filled_blue' | 'filled_black';
  /** GIS label text key. */
  text?: 'signin_with' | 'signup_with' | 'continue_with' | 'signin';
}

export interface UseGoogleSignIn {
  isEnabled: typeof isEnabled;
  isReady: typeof isReady;
  error: typeof error;
  /** True in an embedded in-app browser (Threads/IG/FB/…) where GIS can't work. */
  isInAppBrowser: typeof isInAppBrowser;
  /**
   * Renders a REAL, VISIBLE Google-rendered button into `container`. The
   * user clicks it directly — that trusted click opens Google's
   * account-chooser popup and yields an id_token via the shared callback.
   * Used by BOTH the login form and the demo CTA (the only reliable path;
   * synthetic/proxied clicks on a GIS button are silently ignored).
   */
  mountButton: (container: HTMLElement, options?: MountButtonOptions) => Promise<void>;
  /** Best-effort One Tap (progressive enhancement only; may be a no-op). */
  promptOneTap: () => Promise<void>;
  /** Initializes GIS (idempotent). Safe to call from onMounted. */
  ensureReady: () => Promise<void>;
}

export function useGoogleSignIn(): UseGoogleSignIn {
  async function mountButton(container: HTMLElement, options?: MountButtonOptions) {
    try {
      await ensureInit();
    } catch {
      return; // error already surfaced via shared `error` ref
    }
    if (!isReady.value || !window.google?.accounts?.id) return;
    // Clear any previous render (e.g. when the container is re-mounted)
    // so GIS doesn't stack two buttons on top of each other.
    container.replaceChildren();
    window.google.accounts.id.renderButton(container, {
      type: 'standard',
      theme: options?.theme ?? 'outline',
      size: 'large',
      shape: 'rectangular',
      logo_alignment: 'left',
      text: options?.text ?? 'continue_with',
      width: options?.width ?? (container.clientWidth || 320),
    });
  }

  async function promptOneTap() {
    try {
      await ensureInit();
    } catch {
      return;
    }
    if (isReady.value) {
      // One Tap is best-effort: if FedCM is disabled it silently no-ops
      // here, but the rendered button (mountButton) still works.
      try {
        window.google?.accounts.id.prompt();
      } catch {
        // ignore — not the primary path
      }
    }
  }

  return {
    isEnabled,
    isReady,
    error,
    isInAppBrowser,
    mountButton,
    promptOneTap,
    ensureReady: ensureInit,
  };
}

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
 * ── Why we don't rely on One Tap / FedCM ──────────────────────────────
 * `google.accounts.id.prompt()` (One Tap) goes through FedCM, which the
 * browser disables on cooldown, in incognito, or after a prior dismissal
 * — it then rejects with NetworkError / AbortError and shows NO UI, so
 * the account chooser never appears. The reliable, FedCM-independent way
 * to open the chooser AND still receive an `id_token` (which the backend
 * REQUIRES — see GoogleLoginRequest: `id_token` is `required`) is to use
 * a real GIS-rendered button: rendering it offscreen and programmatically
 * clicking it opens the account-chooser popup with `ux_mode: 'popup'`.
 * One Tap remains a best-effort progressive enhancement only.
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

// ── Module-level singleton state ────────────────────────────────────────
// Shared across every `useGoogleSignIn()` caller so GIS is initialized
// exactly once and all components observe the same readiness/error.
const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;
const isEnabled = ref(Boolean(clientId));
const isReady = ref(false);
const error = ref<string | null>(null);

let scriptPromise: Promise<void> | null = null;
let initPromise: Promise<void> | null = null;
let initialized = false;

/**
 * Offscreen container holding a real GIS-rendered button. Clicking the
 * demo CTA proxies a click to this button's inner clickable node, which
 * opens the Google account chooser popup and yields an `id_token` via the
 * shared callback — without depending on FedCM/One Tap.
 */
let hiddenButtonHost: HTMLDivElement | null = null;
let hiddenButtonRendered = false;

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
      existing.addEventListener('error', () => reject(new Error('GIS load failed')));
      return;
    }

    const tag = document.createElement('script');
    tag.src = GIS_SRC;
    tag.async = true;
    tag.defer = true;
    tag.onload = () => resolve();
    tag.onerror = () => reject(new Error('GIS load failed'));
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
  if (initPromise) return initPromise;

  initPromise = (async () => {
    try {
      await loadScript();
      if (!window.google?.accounts?.id) {
        throw new Error('GIS not available after load');
      }
      if (!initialized) {
        window.google.accounts.id.initialize({
          client_id: clientId,
          callback: handleCredentialResponse,
          ux_mode: 'popup',
          auto_select: false,
          // Do NOT force FedCM-only; keep the legacy popup path available
          // so the rendered-button click reliably opens the chooser even
          // when FedCM is disabled by the browser/user.
          use_fedcm_for_prompt: false,
        });
        initialized = true;
      }
      isReady.value = true;
    } catch (e) {
      error.value = (e as Error).message;
      isEnabled.value = false;
      // Allow a future retry (e.g. transient network failure loading GIS).
      initPromise = null;
      throw e;
    }
  })();

  return initPromise;
}

/** Locates the same-origin clickable node inside a GIS-rendered button. */
function findClickable(host: HTMLElement): HTMLElement | null {
  return (
    host.querySelector<HTMLElement>('[role="button"]') ??
    host.querySelector<HTMLElement>('div[tabindex]') ??
    (host.firstElementChild as HTMLElement | null)
  );
}

/**
 * Synchronously dispatch a click to the pre-rendered hidden button, if it
 * is ready. Returns true if a click was dispatched. Kept synchronous so it
 * can run inside a user-gesture handler WITHOUT an intervening `await`,
 * which is what lets the browser allow the resulting popup.
 */
function tryClickHiddenButtonSync(): boolean {
  if (!hiddenButtonHost || !hiddenButtonRendered) return false;
  const clickable = findClickable(hiddenButtonHost);
  if (!clickable) return false;
  clickable.click();
  return true;
}

/**
 * Ensures the offscreen real Google button exists + is rendered so it can
 * be clicked programmatically to open the account chooser.
 */
async function ensureHiddenButton(): Promise<HTMLElement | null> {
  await ensureInit();
  if (!isReady.value || !window.google?.accounts?.id) return null;

  if (!hiddenButtonHost) {
    hiddenButtonHost = document.createElement('div');
    // Render off-screen with REAL dimensions + full opacity. GIS has
    // anti-abuse checks that ignore clicks on a button it considers
    // hidden (display:none / opacity:0 / zero-size), so we keep the
    // button genuinely rendered and just push it out of the viewport.
    hiddenButtonHost.setAttribute('aria-hidden', 'true');
    hiddenButtonHost.style.position = 'fixed';
    hiddenButtonHost.style.top = '0';
    hiddenButtonHost.style.left = '-10000px';
    hiddenButtonHost.style.width = '240px';
    hiddenButtonHost.style.height = '44px';
    hiddenButtonHost.style.zIndex = '-1';
    document.body.appendChild(hiddenButtonHost);
  }

  if (!hiddenButtonRendered) {
    window.google.accounts.id.renderButton(hiddenButtonHost, {
      type: 'standard',
      theme: 'outline',
      size: 'large',
      text: 'continue_with',
      width: 240,
    });
    hiddenButtonRendered = true;
  }

  return hiddenButtonHost;
}

export interface UseGoogleSignIn {
  isEnabled: typeof isEnabled;
  isReady: typeof isReady;
  error: typeof error;
  /** Renders a visible Google-rendered button into `container`. */
  mountButton: (container: HTMLElement) => Promise<void>;
  /**
   * Reliably opens the Google account chooser (popup) regardless of
   * FedCM/One Tap availability, and signs in via the id_token flow.
   * Returns `true` once the chooser was triggered, `false` if GIS is
   * unavailable. Used by the demo CTA.
   */
  openAccountChooser: () => Promise<boolean>;
  /** Best-effort One Tap (progressive enhancement only; may be a no-op). */
  promptOneTap: () => Promise<void>;
  /** Initializes GIS (idempotent). Safe to call from onMounted. */
  ensureReady: () => Promise<void>;
  /**
   * Pre-load GIS + render the hidden chooser button on mount so the demo
   * CTA's click can open the popup synchronously (avoids popup blocking).
   */
  prewarm: () => Promise<void>;
}

export function useGoogleSignIn(): UseGoogleSignIn {
  async function mountButton(container: HTMLElement) {
    try {
      await ensureInit();
    } catch {
      return; // error already surfaced via shared `error` ref
    }
    if (!isReady.value || !window.google?.accounts?.id) return;
    window.google.accounts.id.renderButton(container, {
      type: 'standard',
      theme: 'outline',
      size: 'large',
      shape: 'rectangular',
      logo_alignment: 'left',
      text: 'continue_with',
      width: container.clientWidth || 320,
    });
  }

  async function openAccountChooser(): Promise<boolean> {
    // Fast path: GIS was pre-warmed on mount, so the hidden button already
    // exists. Click it synchronously — staying inside the user gesture is
    // what keeps the browser from blocking the resulting popup.
    if (tryClickHiddenButtonSync()) return true;

    // Slow path: GIS not ready yet (first interaction before prewarm
    // finished, or prewarm was skipped). Load + render, then click. The
    // popup may require a second click if the browser blocked the first
    // because of the async gap — but the chooser reliably opens then.
    const host = await ensureHiddenButton();
    if (!host) return false;

    let clickable = findClickable(host);
    if (!clickable) {
      // GIS hasn't painted the button yet — give it a tick and retry once.
      await new Promise((r) => setTimeout(r, 200));
      clickable = findClickable(host);
      if (!clickable) return false;
    }
    clickable.click();
    return true;
  }

  /**
   * Pre-load GIS + render the hidden account-chooser button ahead of time
   * (call from onMounted). This lets the demo CTA's first click dispatch
   * synchronously, so the browser allows the account-chooser popup.
   */
  async function prewarm(): Promise<void> {
    if (!isEnabled.value) return;
    try {
      await ensureHiddenButton();
    } catch {
      // non-fatal — openAccountChooser will retry on click
    }
  }

  async function promptOneTap() {
    try {
      await ensureInit();
    } catch {
      return;
    }
    if (isReady.value) {
      // One Tap is best-effort: if FedCM is disabled it silently no-ops
      // here, but the rendered button / openAccountChooser still work.
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
    mountButton,
    openAccountChooser,
    promptOneTap,
    ensureReady: ensureInit,
    prewarm,
  };
}

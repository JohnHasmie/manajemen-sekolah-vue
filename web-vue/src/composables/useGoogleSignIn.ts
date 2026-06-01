/**
 * useGoogleSignIn — Google Identity Services (GIS) integration.
 *
 * Mirrors Flutter's google_sign_in flow that lands on `/auth/google-login`.
 * The web equivalent uses GIS's `id_token` flow:
 *   1. Lazy-load https://accounts.google.com/gsi/client
 *   2. Initialize with VITE_GOOGLE_CLIENT_ID
 *   3. Render a button OR call promptOneTap()
 *   4. On callback, decode the JWT for { email, name, picture } and POST
 *      it to /auth/google-login via the auth store
 *
 * Set VITE_GOOGLE_CLIENT_ID in `.env.local` to enable. With no client ID,
 * `isEnabled` is false and the LoginForm hides the button.
 */
import { onMounted, ref, type Ref } from 'vue';
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

let scriptPromise: Promise<void> | null = null;

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

export interface UseGoogleSignIn {
  isEnabled: Ref<boolean>;
  isReady: Ref<boolean>;
  error: Ref<string | null>;
  /** Renders the Google-rendered button into `containerRef`. */
  mountButton: (container: HTMLElement) => Promise<void>;
  /** Prompts the One Tap UI (no UI if user has already dismissed it). */
  promptOneTap: () => Promise<void>;
}

export function useGoogleSignIn(): UseGoogleSignIn {
  const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;
  const isEnabled = ref(Boolean(clientId));
  const isReady = ref(false);
  const error = ref<string | null>(null);
  const auth = useAuthStore();

  async function ensureInit() {
    if (!isEnabled.value) return;
    try {
      await loadScript();
      if (!window.google?.accounts?.id) {
        throw new Error('GIS not available after load');
      }
      window.google.accounts.id.initialize({
        client_id: clientId,
        callback: handleCredentialResponse,
        ux_mode: 'popup',
        auto_select: false,
      });
      isReady.value = true;
    } catch (e) {
      error.value = (e as Error).message;
      isEnabled.value = false;
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

  async function mountButton(container: HTMLElement) {
    await ensureInit();
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

  async function promptOneTap() {
    await ensureInit();
    if (isReady.value) window.google?.accounts.id.prompt();
  }

  onMounted(() => {
    if (isEnabled.value) void ensureInit();
  });

  return { isEnabled, isReady, error, mountButton, promptOneTap };
}

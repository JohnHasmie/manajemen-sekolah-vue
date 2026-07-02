<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useTutoringThemeStore } from '@/stores/tutoring-theme';
import { storage, StorageKeys } from '@/lib/storage';

const auth = useAuthStore();
const tutoringTheme = useTutoringThemeStore();
const router = useRouter();

/**
 * Parse Google Identity Services redirect-mode fragments.
 *
 * When the backend's /auth/google-redirect endpoint finishes handling
 * a GIS redirect, it 302s the browser back to us with either
 *   #kg_token=<sanctum-pat>  → success
 *   #kg_error=<code>          → failure
 *
 * We consume the fragment here, BEFORE the auth store's restore()
 * runs, so the newly-issued token is picked up by restore() as if
 * it had been sitting in local storage the whole time.
 *
 * The fragment is stripped from the URL immediately (via history
 * replace) so a copy-paste of the URL doesn't leak the token, and
 * a page reload doesn't re-consume the same token.
 */
function consumeGoogleRedirectFragment(): 'token_ok' | 'error' | 'none' {
  const raw = window.location.hash;
  if (!raw || raw.length < 2) return 'none';
  const params = new URLSearchParams(raw.slice(1));
  const token = params.get('kg_token');
  const err = params.get('kg_error');

  if (!token && !err) return 'none';

  // Strip the fragment before doing anything else so a mid-flight
  // exception can't leave the token visible in the URL bar.
  history.replaceState(
    null,
    '',
    window.location.pathname + window.location.search,
  );

  if (token) {
    try {
      storage.set(StorageKeys.token, token);
      return 'token_ok';
    } catch {
      // storage full / private mode — surface as error
      return 'error';
    }
  }

  // Any error branch: log for diagnostics but don't block boot.
  // eslint-disable-next-line no-console
  console.warn('[auth] Google redirect error:', err);
  return 'error';
}

// Rehydrate token / user from localStorage (persisted by Pinia plugin)
// and verify it's still valid on app boot. Mirrors Flutter's startup check
// in main.dart → TokenService.isLoggedIn().
//
// Also kick off the bimbel theme auto-tick so the tutor surface flips
// from dark → light at 06:00 and back at 18:30 (defaults) while the
// app is foregrounded. No-op for users who never touch a bimbel page;
// it's just a 60s setInterval that updates a Date ref.
onMounted(async () => {
  const status = consumeGoogleRedirectFragment();
  if (status === 'token_ok') {
    // Fresh token from Google redirect → NO cached user in storage
    // yet, so restore()'s `token && user` guard would silently no-op.
    // hydrateFromToken fetches /me + synthesizes the user row so the
    // /subscribe page (or wherever the redirect landed) can render
    // as authenticated on this same tick.
    const token = storage.get<string>(StorageKeys.token) ?? '';
    if (token) {
      try {
        await auth.hydrateFromToken(token);
        // Multi-tenant Google logins land here with step='school' —
        // the picker lives on /login and reads auth.step. Route there
        // so the user can pick which tenant they meant to open,
        // instead of silently landing on whichever tenant was cached
        // in local storage from a prior session (which for someone who
        // just activated a NEW subscription is the wrong dashboard).
        //
        // Exception: when the sessionStorage `demo_intent_v1` flag is
        // still set — meaning the user clicked "Buat Demo dengan
        // Google" and hasn't been dispatched to /register-demo yet —
        // send them straight to the demo wizard instead of forcing
        // them to pick a tenant they don't care about. LoginView's
        // onMounted handles the same case as a fallback, but a
        // direct route here avoids a flash of the picker.
        if (auth.step === 'school') {
          let demoIntent = false;
          try {
            demoIntent = sessionStorage.getItem('demo_intent_v1') === '1';
          } catch {
            /* private mode — fall through to picker */
          }
          if (demoIntent) {
            try { sessionStorage.removeItem('demo_intent_v1'); } catch { /* non-fatal */ }
            await router.replace('/register-demo');
          } else {
            await router.replace('/login');
          }
        }
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error('[auth] hydrateFromToken failed after Google redirect', err);
      }
    }
  } else {
    // Normal boot path — either no redirect happened, or a
    // #kg_error= arrived (already logged). restore() picks up any
    // pre-existing session from localStorage.
    auth.restore();
  }
  tutoringTheme.startAutoTick();
});
</script>

<template>
  <RouterView />
</template>

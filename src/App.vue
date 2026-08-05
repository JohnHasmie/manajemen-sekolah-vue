<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useTutoringThemeStore } from '@/stores/tutoring-theme';
import { storage, StorageKeys } from '@/lib/storage';
import SeatHardCapModal from '@/components/billing/SeatHardCapModal.vue';
import ConfirmHost from '@/components/ui/ConfirmHost.vue';

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

      // The backend now sends routing flags alongside the token so we
      // know BEFORE calling /me whether this user needs the demo wizard,
      // school picker, etc.  Persist them as the sessionStorage flags
      // that the existing onMounted routing logic already reads.
      if (params.get('kg_dapat_buat_demo')) {
        try { sessionStorage.setItem('demo_intent_v1', '1'); } catch { /* non-fatal */ }
      }

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
        // If Google brought us back to a self-serve marketing route
        // (/subscribe, /subscribe/new, /register-demo, …), just stay
        // put. Those pages handle their own multi-tenant flow — they
        // don't need the /login picker. This is the ground-truth
        // signal (we're literally on that URL right now) so it can't
        // desync from sessionStorage flags or GIS state races.
        const path = window.location.pathname;
        const staysOnPage =
          path === '/subscribe' ||
          path.startsWith('/subscribe/') ||
          path === '/register-demo' ||
          path.startsWith('/register-demo/');

        if (staysOnPage) {
          // Clear any lingering intent flags so a future visit to
          // /login (fresh session) doesn't misroute on them.
          try { sessionStorage.removeItem('demo_intent_v1'); } catch { /* non-fatal */ }
          try { sessionStorage.removeItem('subscribe_intent_v1'); } catch { /* non-fatal */ }
          // HARDENING: while user is at /subscribe/* or /register-demo/*, actively
          // collapse the tenant-picker state that hydrateFromToken set to 'school'.
          // The subscribe/register-demo pages don't need a picker — they onboard
          // a NEW tenant. Leaving step='school' is a race hazard: any code path
          // that reads `auth.step` (LoginView picker, ProfileMenu, etc.) or that
          // navigates the user away from /subscribe/* (e.g. an unrelated router
          // push) could then trigger the picker they never asked for. Clear the
          // pending schools list too so no picker UI has data to render even if
          // it briefly mounts.
          if (auth.step === 'school' || auth.step === 'role') {
            auth.step = 'done';
            auth.schools = [];
            auth.roles = [];
          }
        } else {
          let demoIntent = false;
          let subscribeIntent = false;
          try {
            demoIntent = sessionStorage.getItem('demo_intent_v1') === '1';
            subscribeIntent = sessionStorage.getItem('subscribe_intent_v1') === '1';
          } catch {
            /* private mode — fall through */
          }
          if (demoIntent) {
            try { sessionStorage.removeItem('demo_intent_v1'); } catch { /* non-fatal */ }
            await router.replace('/register-demo');
          } else if (subscribeIntent) {
            try { sessionStorage.removeItem('subscribe_intent_v1'); } catch { /* non-fatal */ }
            await router.replace('/subscribe');
          } else if (auth.step === 'school') {
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
  <SeatHardCapModal />
  <ConfirmHost />
</template>

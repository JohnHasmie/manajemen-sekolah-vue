<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useTutoringThemeStore } from '@/stores/tutoring-theme';
import { storage, StorageKeys } from '@/lib/storage';
import { takeGoogleRedirect } from '@/lib/google-redirect';
import SeatHardCapModal from '@/components/billing/SeatHardCapModal.vue';
import ConfirmHost from '@/components/ui/ConfirmHost.vue';

const auth = useAuthStore();
const tutoringTheme = useTutoringThemeStore();
const router = useRouter();

// Rehydrate token / user from localStorage (persisted by Pinia plugin)
// and verify it's still valid on app boot. Mirrors Flutter's startup check
// in main.dart → TokenService.isLoggedIn().
//
// The Google "redirect mode" fragment (`#kg_token=` / `#kg_error=`) was
// already read + stripped at module scope in main.ts — BEFORE LogRocket and
// before the router existed, so neither ever saw the PAT. Here we only act
// on the parsed outcome. See `lib/google-redirect.ts`.
//
// Also kick off the bimbel theme auto-tick so the tutor surface flips
// from dark → light at 06:00 and back at 18:30 (defaults) while the
// app is foregrounded. No-op for users who never touch a bimbel page;
// it's just a 60s setInterval that updates a Date ref.
onMounted(async () => {
  const redirect = takeGoogleRedirect();

  if (redirect.kind === 'error') {
    // Google (or the backend) refused the sign-in. This used to be a bare
    // console.warn, which left the user staring at an unchanged login form
    // with no idea anything had happened. Publish it to the store so
    // LoginView's `auth.error` watcher raises the toast.
    // eslint-disable-next-line no-console
    console.warn('[auth] Google redirect error:', redirect.code);
    auth.error = redirect.message;
    auth.restore();
    tutoringTheme.startAutoTick();
    return;
  }

  if (redirect.kind === 'token') {
    // Fresh token from Google redirect → NO cached user in storage
    // yet, so restore()'s `token && user` guard would silently no-op.
    // hydrateFromToken fetches /me + synthesizes the user row so the
    // /subscribe page (or wherever the redirect landed) can render
    // as authenticated on this same tick.
    const token = storage.get<string>(StorageKeys.token) ?? '';
    if (!token) {
      // The fragment carried a token but it did not survive the round-trip
      // through storage (blocked site data / private mode). Nothing left to
      // authenticate with — say so rather than leaving the user staring at
      // an unchanged login form.
      auth.error =
        'Sesi masuk Google tidak bisa disimpan di browser ini. Izinkan penyimpanan situs atau keluar dari mode penyamaran, lalu coba lagi.';
    } else {
      if (redirect.canCreateDemo) {
        // Backend flagged the account as demo-eligible. Persist as the
        // sessionStorage marker the routing logic below already reads.
        try {
          sessionStorage.setItem('demo_intent_v1', '1');
        } catch {
          /* non-fatal */
        }
      }
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
          } else if (auth.step === 'done' && path === '/login') {
            // Belt-and-braces for the success path. LoginView's own
            // `auth.step` watcher normally does this navigation, but it
            // only fires on a step CHANGE observed by a MOUNTED view —
            // and LoginView is lazily imported, so a slow chunk against a
            // fast /me leaves nobody watching. Without this branch that
            // race ends where the failure path used to: authenticated,
            // but parked on the login form forever. `router.replace` to
            // the same target is a no-op, so the normal ordering costs
            // nothing.
            //
            // Scoped to /login on purpose: `state` round-trips whatever
            // path the user started from, and a deep link that came back
            // authenticated should stay where it is, not be yanked to the
            // dashboard.
            await router.replace('/');
          }
        }
      } catch (err) {
        // Hydration failed (most often /me refusing the request). The
        // store has already torn the half-built session down, cleared the
        // stale tenant scope that usually caused it, and published a
        // user-facing message on `auth.error` — LoginView's watcher turns
        // that into a toast, and the login form is interactive again so
        // the user can retry Google immediately.
        //
        // The one thing the store can't do is guarantee we're on a screen
        // that RENDERS that form: a Google round-trip can return to
        // /subscribe or /register-demo, where a dead login attempt has
        // nothing to show. Send those cases to /login.
        // eslint-disable-next-line no-console
        console.error('[auth] hydrateFromToken failed after Google redirect', err);
        if (!auth.error) {
          auth.error =
            (err as Error)?.message ||
            'Masuk dengan Google gagal. Silakan coba lagi.';
        }
        if (window.location.pathname !== '/login') {
          await router.replace('/login');
        }
      }
    }
    tutoringTheme.startAutoTick();
    return;
  }

  // Normal boot path — no redirect happened. restore() picks up any
  // pre-existing session from storage.
  auth.restore();
  tutoringTheme.startAutoTick();
});
</script>

<template>
  <RouterView />
  <SeatHardCapModal />
  <ConfirmHost />
</template>

<script setup lang="ts">
import { onMounted } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useTutoringThemeStore } from '@/stores/tutoring-theme';
import { storage, StorageKeys } from '@/lib/storage';

const auth = useAuthStore();
const tutoringTheme = useTutoringThemeStore();

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
onMounted(() => {
  // MUST run before restore() so a freshly-arrived kg_token gets
  // written to storage in time for restore() to pick it up.
  consumeGoogleRedirectFragment();
  auth.restore();
  tutoringTheme.startAutoTick();
});
</script>

<template>
  <RouterView />
</template>

import { createApp, watch } from 'vue';
import { createPinia } from 'pinia';
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate';
import LogRocket from 'logrocket';

// Tabler icons webfont — powers every `<i class="ti ti-*">` used across
// the app (subscribe surface, admin views, etc.). Loaded once at boot
// so components can use icons without their own imports; without this
// the `ti` classes are inert and the app ships coloured squares where
// icons should be.
import '@tabler/icons-webfont/dist/tabler-icons.min.css';

import App from './App.vue';
import router from './router';
import { i18n } from './lib/i18n';
import { useAuthStore } from '@/stores/auth';
import { storage, StorageKeys } from '@/lib/storage';

// LogRocket session replay + monitoring. Initialised as early as possible
// so the full session is captured. Guarded to production builds only, so
// local `npm run dev` sessions aren't recorded (flip the guard if you want
// dev recording). 'gpgce7/kamil-edu' is the PUBLIC client-side app id, not a
// secret — safe to commit.
//
// ⚠️ PII: LogRocket records the DOM + network by default. Password inputs are
// masked automatically, but other sensitive fields (student names/NIS, grades,
// payment info, WhatsApp numbers) are NOT. Before relying on this in prod,
// configure DOM/network redaction — add `data-private` to sensitive elements
// or use input/request sanitizers. See https://docs.logrocket.com/reference/dom
if (import.meta.env.PROD) {
  LogRocket.init('gpgce7/kamil-edu');
}

// Poppins — regular + bold (matches Flutter pubspec).
import '@fontsource/poppins/400.css';
import '@fontsource/poppins/500.css';
import '@fontsource/poppins/600.css';
import '@fontsource/poppins/700.css';

import './style.css';

const app = createApp(App);
const pinia = createPinia();
pinia.use(piniaPluginPersistedstate);

app.use(pinia);
app.use(router);
app.use(i18n);

// LogRocket: tie sessions to the signed-in user (prod-only, mirroring init).
// A watcher — not a one-shot call — because `auth.restore()` runs on the
// first navigation, so this also catches an already-authenticated reload;
// `immediate` identifies right away if the user is already present, and it
// re-fires on an account switch.
if (import.meta.env.PROD) {
  const authStore = useAuthStore();
  watch(
    () => authStore.user,
    (u) => {
      if (u?.id) {
        LogRocket.identify(u.id, {
          name: u.name,
          email: u.email,
          role: String(u.role ?? ''),
        });
      }
    },
    { immediate: true },
  );
}

// Surface Vue component errors to LogRocket. (window.onerror + unhandled
// promise rejections are captured automatically by LogRocket.init.) Keep
// console logging too — Vue suppresses its own default once an errorHandler
// is set.
app.config.errorHandler = (err, _instance, info) => {
  console.error(err, info);
  if (import.meta.env.PROD && err instanceof Error) {
    LogRocket.captureException(err);
  }
};

// Auto-recover from stale dynamic-import chunks after a deploy. Vite fires
// `vite:preloadError` when a lazy chunk 404s because a new build purged the
// old hashed filename. Reload once to fetch the fresh index.html + chunks.
// Shares the `chunk-reload-at` guard with router.onError so the two can't
// loop or double-reload. (router.onError handles navigation imports; this
// handles module preloads.)
window.addEventListener('vite:preloadError', (event) => {
  const KEY = 'chunk-reload-at';
  const last = Number(sessionStorage.getItem(KEY) ?? '0');
  if (Date.now() - last < 10_000) return;
  sessionStorage.setItem(KEY, String(Date.now()));
  event.preventDefault();
  window.location.reload();
});

// Back/forward-cache (bfcache) guard for the login page.
//
// When the browser restores a page from bfcache on a "back" navigation, it
// does NOT re-run Vue Router's `beforeEach` — the whole document is served
// from the in-memory snapshot. So a user who logged in and then pressed
// browser-back would land on the STALE /login page sitting behind their live
// session, even though the router guard would otherwise redirect /login → /.
// (Reported by Luay: "ketika di-back malah bisa ke pilih email login lagi,
// harusnya mentok di dashboard karena masih login.")
//
// localStorage survives bfcache (it isn't part of the page snapshot), so on a
// bfcache restore we re-assert routing directly: if we're sitting on /login
// but a valid session is still stored, hard-redirect to the dashboard so the
// app + guard re-initialise on the authenticated route. `replace` keeps the
// dead /login entry out of history. Not authenticated → left alone (a genuine
// logged-out user stays on the login form).
//
// Scope: ONLY the plain post-login case. The self-serve subscribe /
// register-demo flows use Google in redirect mode, which does full-page
// navigations that can leave a bfcache'd /login document sitting BEHIND
// /subscribe/new (and friends). Pressing browser-back from /subscribe/new
// then restores that /login, and a blanket redirect would slam the user to
// the admin dashboard mid-signup instead of doing a normal history-back —
// exactly the "kembali dari /subscribe/new langsung ke dashboard admin" bug
// Luay reported. Those flows advertise themselves via the `subscribe_intent_v1`
// / `demo_intent_v1` sessionStorage flags (set on the Google round-trip, and
// they survive bfcache), so when either is present we step aside and let the
// browser's own back-navigation stand.
window.addEventListener('pageshow', (event) => {
  if (!(event as PageTransitionEvent).persisted) return;
  const onLoginPage = window.location.pathname === '/login';
  const hasSession = Boolean(
    storage.get(StorageKeys.token) && storage.get(StorageKeys.user),
  );
  // In an active self-serve subscribe / register-demo flow → don't clobber
  // back-navigation with a dashboard redirect.
  let inSelfServeFlow = false;
  try {
    inSelfServeFlow =
      sessionStorage.getItem('subscribe_intent_v1') === '1' ||
      sessionStorage.getItem('demo_intent_v1') === '1';
  } catch {
    // sessionStorage can throw in private mode — treat as "not in a flow"
    // so the original post-login guard still protects the common case.
  }
  if (onLoginPage && hasSession && !inSelfServeFlow) {
    window.location.replace('/');
  }
});

app.mount('#app');

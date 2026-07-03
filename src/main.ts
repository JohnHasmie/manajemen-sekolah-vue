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

app.mount('#app');

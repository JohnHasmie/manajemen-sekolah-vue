import { createApp } from 'vue';
import { createPinia } from 'pinia';
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate';

import App from './App.vue';
import router from './router';
import { i18n } from './lib/i18n';

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

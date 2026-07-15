/**
 * Recovery for failed lazy-chunk imports — the "blank page" guard.
 *
 * Every authenticated route renders inside a lazily-imported shell
 * (`AppShell`). Vue Router resolves that component with a dynamic `import()`.
 * If the download fails — a flaky network, a CDN edge hiccup, or an old
 * `index.html` pointing at chunks a new deploy purged — the import rejects,
 * Router aborts the navigation, and `<RouterView/>` renders NOTHING. Since
 * `App.vue` is only RouterView + two v-if hosts, the user gets a pure white
 * page with no message and no way out.
 *
 * The previous handler auto-reloaded once per 10s and, if another failure
 * landed inside that window, `return`ed — silently. That silence WAS the
 * blank page: recovery gave up without ever telling the user.
 *
 * This module makes that impossible:
 *   1. Bounded auto-recovery — up to MAX_RELOADS hard reloads, which fixes the
 *      common transient blip and the stale-deploy case (a hard navigation
 *      re-fetches index.html + the current chunk hashes).
 *   2. When the budget is spent we ALWAYS render a real error screen with a
 *      retry button. Never a blank page.
 *   3. A successful navigation clears the budget, so a later, unrelated
 *      incident starts fresh instead of hitting an exhausted counter.
 *
 * The error screen is built with raw DOM on purpose: by the time we need it,
 * Vue Router is wedged and the route component doesn't exist, so anything that
 * depends on rendering a route (or on a chunk we just failed to download)
 * could fail too. Inline styles are fine under our CSP (`style-src` allows
 * 'unsafe-inline'); inline <script>/onclick is NOT, so the button is wired
 * with addEventListener.
 */

const RELOAD_COUNT_KEY = 'chunk-reload-count';
const RELOAD_AT_KEY = 'chunk-reload-at';
const OVERLAY_ID = 'kamiledu-chunk-error';

/** Hard reloads we're willing to spend before showing the error screen. */
const MAX_RELOADS = 2;

/**
 * Failures older than this are treated as a NEW incident, so a user who hits
 * an unrelated blip an hour later still gets the full auto-recovery budget
 * instead of landing straight on the error screen.
 */
const INCIDENT_WINDOW_MS = 30_000;

/**
 * True for the "a lazy chunk didn't load" family of errors. Covers Chrome,
 * Firefox and Safari's differing messages, plus Vite's CSS preload variant.
 */
export function isChunkLoadError(err: unknown): boolean {
  const msg = String((err as Error | undefined)?.message ?? err ?? '');
  return (
    /Failed to fetch dynamically imported module/i.test(msg) ||
    /error loading dynamically imported module/i.test(msg) ||
    /Importing a module script failed/i.test(msg) ||
    /Unable to preload CSS/i.test(msg)
  );
}

function readCount(now: number): number {
  const last = Number(sessionStorage.getItem(RELOAD_AT_KEY) ?? '0');
  // Stale timestamp → previous incident is over; start the budget again.
  if (now - last > INCIDENT_WINDOW_MS) return 0;
  return Number(sessionStorage.getItem(RELOAD_COUNT_KEY) ?? '0');
}

/**
 * Called once a navigation completes. The chunks are clearly reachable again,
 * so release the budget for any future incident.
 */
export function markChunkRecoverySucceeded(): void {
  try {
    sessionStorage.removeItem(RELOAD_COUNT_KEY);
    sessionStorage.removeItem(RELOAD_AT_KEY);
  } catch {
    /* storage disabled — nothing to clear */
  }
}

/**
 * Entry point for both `router.onError` (navigation imports) and
 * `vite:preloadError` (module preloads). Reloads while budget remains,
 * otherwise shows the error screen. Never returns silently.
 *
 * @param targetPath where to land after the reload (defaults to current URL)
 */
export function recoverFromChunkError(targetPath?: string): void {
  const now = Date.now();

  let count: number;
  try {
    count = readCount(now);
  } catch {
    // Private mode / storage blocked: we can't track attempts, so don't risk
    // a reload loop — go straight to the actionable screen.
    showChunkErrorScreen();
    return;
  }

  if (count >= MAX_RELOADS) {
    showChunkErrorScreen();
    return;
  }

  try {
    sessionStorage.setItem(RELOAD_COUNT_KEY, String(count + 1));
    sessionStorage.setItem(RELOAD_AT_KEY, String(now));
  } catch {
    /* best effort */
  }

  // Hard navigation (not router.push): re-fetches index.html so a browser
  // running a purged build picks up the new chunk hashes.
  window.location.assign(
    targetPath ?? window.location.pathname + window.location.search,
  );
}

/** id/en without pulling in vue-i18n — this must work when the app is wedged. */
function copy() {
  const lang = (() => {
    try {
      return (
        localStorage.getItem('kamiledu.lang') ||
        localStorage.getItem('locale') ||
        'id'
      )
        .toLowerCase()
        .slice(0, 2);
    } catch {
      return 'id';
    }
  })();

  return lang === 'en'
    ? {
        title: 'Failed to load the page',
        body: 'Part of the app could not be downloaded — usually a brief connection drop. Your data is safe.',
        retry: 'Reload',
        hint: 'Still stuck? Check your connection, then reload again.',
      }
    : {
        title: 'Gagal memuat halaman',
        body: 'Sebagian aplikasi gagal diunduh — biasanya karena koneksi terputus sesaat. Data Anda aman.',
        retry: 'Muat ulang',
        hint: 'Masih gagal? Periksa koneksi Anda, lalu muat ulang lagi.',
      };
}

/**
 * Full-screen, dependency-free error state. Replaces the blank page.
 * Idempotent — a second failure won't stack overlays.
 */
export function showChunkErrorScreen(): void {
  if (typeof document === 'undefined') return;
  if (document.getElementById(OVERLAY_ID)) return;

  const t = copy();

  const overlay = document.createElement('div');
  overlay.id = OVERLAY_ID;
  overlay.setAttribute('role', 'alert');
  overlay.style.cssText = [
    'position:fixed',
    'inset:0',
    'z-index:2147483647',
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'padding:24px',
    'background:#f4f7fb',
    'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif',
  ].join(';');

  const card = document.createElement('div');
  card.style.cssText = [
    'max-width:380px',
    'width:100%',
    'background:#ffffff',
    'border:1px solid #e4e9f1',
    'border-radius:16px',
    'padding:28px 24px',
    'text-align:center',
    'box-shadow:0 12px 34px rgba(11,20,45,.12)',
  ].join(';');

  const icon = document.createElement('div');
  icon.setAttribute('aria-hidden', 'true');
  icon.style.cssText = [
    'width:52px',
    'height:52px',
    'margin:0 auto 16px',
    'border-radius:14px',
    'background:#fef3c7',
    'color:#b45309',
    'display:flex',
    'align-items:center',
    'justify-content:center',
  ].join(';');
  // Inline SVG — no external fetch, since the network is what just failed.
  icon.innerHTML =
    '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
    'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
    '<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z"/>' +
    '<line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>';

  const title = document.createElement('h1');
  title.textContent = t.title;
  title.style.cssText =
    'margin:0 0 8px;font-size:17px;font-weight:800;color:#0f1b30';

  const body = document.createElement('p');
  body.textContent = t.body;
  body.style.cssText =
    'margin:0 0 20px;font-size:13px;line-height:1.6;color:#5a6b86';

  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = t.retry;
  button.style.cssText = [
    'width:100%',
    'height:44px',
    'border:0',
    'border-radius:12px',
    'background:#143068',
    'color:#ffffff',
    'font-size:14px',
    'font-weight:700',
    'cursor:pointer',
  ].join(';');
  // addEventListener, not an inline onclick — CSP blocks inline handlers.
  button.addEventListener('click', () => {
    // Clear the budget so the manual retry gets a genuine fresh attempt
    // rather than bouncing straight back to this screen.
    markChunkRecoverySucceeded();
    window.location.reload();
  });

  const hint = document.createElement('p');
  hint.textContent = t.hint;
  hint.style.cssText = 'margin:14px 0 0;font-size:11.5px;color:#8695ac';

  card.append(icon, title, body, button, hint);
  overlay.append(card);
  document.body.append(overlay);
}

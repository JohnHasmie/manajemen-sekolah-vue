/**
 * @vitest-environment jsdom
 *
 * Vitest spec for the blank-page guard.
 *
 * The bug this replaces: recovery bailed out silently once a second chunk
 * failure landed inside its 10s window, leaving RouterView empty = a white
 * page. So the invariant under test is "we either reload or we SHOW
 * something — never nothing".
 *
 * jsdom is scoped to THIS file via the pragma above — the rest of the suite
 * stays on the default node environment.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  isChunkLoadError,
  markChunkRecoverySucceeded,
  recoverFromChunkError,
  showChunkErrorScreen,
} from './chunk-recovery';

const OVERLAY = '#kamiledu-chunk-error';

function stubLocation() {
  const assign = vi.fn();
  const reload = vi.fn();
  Object.defineProperty(window, 'location', {
    configurable: true,
    value: { assign, reload, pathname: '/super-admin', search: '' },
  });
  return { assign, reload };
}

describe('isChunkLoadError', () => {
  it('matches the browsers\' differing chunk-failure messages', () => {
    expect(isChunkLoadError(new Error('Failed to fetch dynamically imported module: /assets/AppShell-x.js'))).toBe(true);
    expect(isChunkLoadError(new Error('error loading dynamically imported module'))).toBe(true);
    expect(isChunkLoadError(new Error('Importing a module script failed.'))).toBe(true);
    expect(isChunkLoadError(new Error('Unable to preload CSS for /assets/x.css'))).toBe(true);
  });

  it('does not claim unrelated errors', () => {
    expect(isChunkLoadError(new Error('Request failed with status code 401'))).toBe(false);
    expect(isChunkLoadError(new TypeError('x is not a function'))).toBe(false);
    expect(isChunkLoadError(undefined)).toBe(false);
  });
});

describe('recoverFromChunkError', () => {
  beforeEach(() => {
    sessionStorage.clear();
    localStorage.clear();
    document.body.innerHTML = '';
  });
  afterEach(() => vi.restoreAllMocks());

  it('reloads to the intended path while budget remains', () => {
    const { assign } = stubLocation();
    recoverFromChunkError('/admin/trash');
    expect(assign).toHaveBeenCalledWith('/admin/trash');
    expect(document.querySelector(OVERLAY)).toBeNull();
  });

  it('spends at most 2 reloads, then shows the error screen instead of a blank page', () => {
    const { assign } = stubLocation();
    recoverFromChunkError('/a'); // 1st
    recoverFromChunkError('/a'); // 2nd
    expect(assign).toHaveBeenCalledTimes(2);

    recoverFromChunkError('/a'); // budget spent
    expect(assign).toHaveBeenCalledTimes(2); // no 3rd reload → no loop
    expect(document.querySelector(OVERLAY)).not.toBeNull(); // but SOMETHING is shown
  });

  it('REGRESSION: a rapid second failure must not end in silence (the old blank page)', () => {
    const { assign } = stubLocation();
    // Simulate the old guard's condition: a failure moments after the last try.
    sessionStorage.setItem('chunk-reload-count', '2');
    sessionStorage.setItem('chunk-reload-at', String(Date.now()));

    recoverFromChunkError('/a');

    expect(assign).not.toHaveBeenCalled();             // correctly no reload loop
    expect(document.querySelector(OVERLAY)).not.toBeNull(); // and NOT blank
    expect(document.body.innerText || document.body.textContent).toContain('Muat ulang');
  });

  it('a successful navigation releases the budget for a later incident', () => {
    const { assign } = stubLocation();
    recoverFromChunkError('/a');
    recoverFromChunkError('/a');
    expect(assign).toHaveBeenCalledTimes(2);

    markChunkRecoverySucceeded(); // router.afterEach

    recoverFromChunkError('/a'); // fresh incident gets a real retry again
    expect(assign).toHaveBeenCalledTimes(3);
    expect(document.querySelector(OVERLAY)).toBeNull();
  });

  it('treats a long-ago failure as a new incident (budget resets)', () => {
    const { assign } = stubLocation();
    sessionStorage.setItem('chunk-reload-count', '2');
    sessionStorage.setItem('chunk-reload-at', String(Date.now() - 60_000)); // >30s ago

    recoverFromChunkError('/a');
    expect(assign).toHaveBeenCalledTimes(1);
    expect(document.querySelector(OVERLAY)).toBeNull();
  });
});

describe('showChunkErrorScreen', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    localStorage.clear();
  });

  it('renders an actionable screen, not an empty page', () => {
    showChunkErrorScreen();
    const el = document.querySelector(OVERLAY);
    expect(el).not.toBeNull();
    expect(el.querySelector('button')).not.toBeNull();
    expect(el.getAttribute('role')).toBe('alert');
  });

  it('does not stack overlays on repeated failures', () => {
    showChunkErrorScreen();
    showChunkErrorScreen();
    expect(document.querySelectorAll(OVERLAY).length).toBe(1);
  });

  it('the retry button clears the budget and reloads', () => {
    const { reload } = stubLocation();
    sessionStorage.setItem('chunk-reload-count', '2');
    showChunkErrorScreen();
    document.querySelector(`${OVERLAY} button`).click();
    expect(reload).toHaveBeenCalled();
    expect(sessionStorage.getItem('chunk-reload-count')).toBeNull();
  });

  it('speaks English when the stored locale is en', () => {
    localStorage.setItem('kamiledu.lang', 'en');
    showChunkErrorScreen();
    expect(document.querySelector(OVERLAY).textContent).toContain('Reload');
  });
});

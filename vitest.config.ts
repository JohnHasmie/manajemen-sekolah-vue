import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vitest/config';

/**
 * Kept separate from `vite.config.ts` on purpose.
 *
 * The build config carries a `plugins: [vue()]` entry and a `server`
 * block that the test runner has no use for, and folding a `test` key
 * into it would mean every future build change has to be considered for
 * its effect on the suite as well. Nothing here mounts a component, so
 * the Vue plugin is genuinely not needed.
 *
 * Twelve `.spec.ts` files had been sitting in this repo importing
 * `vitest` — a dependency that was never installed — so not one of them
 * had ever run. This is what makes them executable.
 */
export default defineConfig({
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  test: {
    // jsdom rather than node: some specs reach for `localStorage` and
    // `document` (the lazy-chunk recovery helper, for one).
    environment: 'jsdom',
    include: ['src/**/*.{spec,test}.ts'],
    // Fail rather than silently pass when a glob matches nothing — the
    // whole point of this change is that missing tests stop being
    // invisible.
    passWithNoTests: false,
    reporters: ['default'],
  },
});

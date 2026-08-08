import { fileURLToPath, URL } from 'node:url';
import vue from '@vitejs/plugin-vue';
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
  plugins: [vue()],
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
    // VIEW specs mount `.vue` SFCs (unlike this repo's pattern of
    // pure-logic specs) and this config deliberately omits
    // `@vitejs/plugin-vue`, so they cannot run here. Migrating them to
    // logic-only specs — or adding a Vue-enabled sub-config — is still
    // an open follow-up.
    //
    // `src/services/tutoring2/**` was excluded alongside them and should
    // not have been: not one service spec imports a `.vue` file. The
    // over-broad glob kept 11 files / 64 passing tests out of CI. Keep
    // this list scoped to what genuinely cannot run — an exclusion that
    // silently disables working tests is worse than a failing one,
    // because nothing ever reports it.
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
    ],
    // Fail rather than silently pass when a glob matches nothing — the
    // whole point of this change is that missing tests stop being
    // invisible.
    passWithNoTests: false,
    reporters: ['default'],
  },
});

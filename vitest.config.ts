import { fileURLToPath, URL } from 'node:url';
import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vitest/config';

/**
 * Kept separate from `vite.config.ts` on purpose.
 *
 * The build config carries a `server` block that the test runner has no
 * use for, and folding a `test` key into it would mean every future
 * build change has to be considered for its effect on the suite as
 * well.
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
    // Pin the zone the suite reads dates in. Without this, every
    // rendered timestamp assertion is really an assertion about the
    // machine that ran it: a spec that expects "14.30" for a
    // `+07:00` instant passes on a WIB laptop and fails on a
    // UTC CI box — or, far worse, a component that formats via
    // `toISOString()` passes CI and ships the wrong time to every
    // user. Asia/Jakarta is where this product's readers are, so the
    // suite reads the clock the way they do.
    env: { TZ: 'Asia/Jakarta' },
    include: ['src/**/*.{spec,test}.ts'],
    // Keep this list scoped to what genuinely cannot run — an exclusion
    // that silently disables working tests is worse than a failing one,
    // because nothing ever reports it. `src/services/tutoring2/**` and
    // the view specs were both excluded here once and should not have
    // been: the over-broad glob kept 11 files / 64 passing tests out of
    // CI, and `plugins: [vue()]` above means mounting an SFC works.
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

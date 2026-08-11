import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Reads the fixture manifest E2ESeeder writes on the backend.
 *
 * Emails are generated per seed run, so they are NEVER hardcoded here — a
 * hardcoded list would go stale the first time anyone re-seeds and the
 * suite would fail with "invalid credentials" instead of anything that
 * points at the real cause.
 */

/** Manifest shape this reader understands. Bumped when the shape changes. */
const EXPECTED_VERSION = 2;

/** How old a manifest may get before we warn (ms). */
const STALE_AFTER_MS = 24 * 60 * 60 * 1000;

/**
 * The surfaces the suite covers. `key` is the SURFACE, which is not the
 * same as the role: `wali_kelas` is a `teacher` whose profile owns a
 * homeroom — the app collapses the role string and switches nav on
 * `homeroomClasses.length > 0` alone.
 */
export type FixtureKey =
  | 'parent_other'
  | 'admin'
  | 'teacher'
  | 'wali_kelas'
  | 'parent'
  | 'staff'
  | 'super_admin'
  | 'multi_role';

export const FIXTURE_KEYS: readonly FixtureKey[] = [
  'admin',
  'teacher',
  'wali_kelas',
  'parent',
  'staff',
  'super_admin',
  'multi_role',
] as const;

export interface E2EFixture {
  key: FixtureKey;
  role: string;
  email: string;
  name: string;
  user_id: string;
  teacher_id?: string;
  homeroom_class?: string;
  child_student_id?: string;
  child_class_id?: string;
  /** super_admin only: reaches every demo school, not just the fixture. */
  read_only?: boolean;
  /**
   * Do not drive this account through the browser.
   *
   * `multi_role` holds two roles and NO profile rows for either — no
   * `teachers` row, no student naming it as guardian. That is deliberate:
   * it exists solely to prove `X-Active-Role` narrows abilities, which is
   * decided by `role_id → roles → role_permissions` and needs no profile.
   * Walking it through the UI instead renders teacher pages for an account
   * with no teacher, which 404s and 403s in ways that look like product
   * bugs and are not.
   */
  api_only?: boolean;
  /** multi_role only: every role the account holds. */
  roles?: string[];
  warning?: string;
}

/** One authenticated GET whose controller carries no `authorize()`. */
export interface ProbeTarget {
  path: string;
  /** `SomeController@method` — what to open when a 2xx needs explaining. */
  action: string;
}

export interface E2EManifest {
  version: number;
  seeded_at: string;
  school: { id: string; name: string };
  password: string;
  fixtures: E2EFixture[];
  /**
   * Computed by the seeder, not transcribed here: every authenticated,
   * parameter-free `GET api/*` whose controller never calls
   * `$this->authorize()`. Optional because a manifest seeded before this
   * existed simply lacks it — the probe skips loudly rather than passing
   * on an empty list.
   */
  probe_targets?: ProbeTarget[];
  /**
   * The bimbel tenant, seeded alongside the school one.
   *
   * A SEPARATE tenant, not a mode: its roles hold `tutoring.*` abilities
   * a school's hold none of, so the bimbel surface is unreachable with a
   * school fixture. Optional because a manifest seeded before it exists
   * simply lacks it — specs that need it skip loudly.
   */
  bimbel?: {
    school: { id: string; name: string };
    fixtures: E2EFixture[];
    data: {
      programs: { id: string; name: string }[];
      groups: { id: string; name: string }[];
      sessions: { id: string }[];
      materials: { id: string }[];
      students: { id: string; name: string }[];
    };
  };
  data: {
    classes: { id: string; name: string }[];
    subjects: string[];
    students: { id: string; name: string; class_id: string }[];
  };
}

/**
 * Where the backend repo sits relative to this one. Both are checked out
 * side by side under ~/Projects; override when that is not true.
 */
const HERE = dirname(fileURLToPath(import.meta.url));

const BACKEND_REPO =
  process.env.E2E_BACKEND_PATH ??
  resolve(HERE, '../../../../backendmanajemensekolah_laravel');

const MANIFEST_PATH = resolve(BACKEND_REPO, 'storage/app/e2e/accounts.json');

const SEED_COMMAND =
  "  docker exec -e DB_CONNECTION=pgsql -e DB_DATABASE=edu_core kamiledu-core-api-app \\\n" +
  "    php artisan db:seed --class='Database\\Seeders\\E2ESeeder'";

let cached: E2EManifest | null = null;

export function loadManifest(): E2EManifest {
  if (cached) return cached;

  let raw: string;

  try {
    raw = readFileSync(MANIFEST_PATH, 'utf8');
  } catch (cause) {
    throw new Error(
      `Could not read the E2E manifest at ${MANIFEST_PATH}.\nSeed it first:\n${SEED_COMMAND}\n` +
        'Set E2E_BACKEND_PATH if the backend repo lives elsewhere.',
      { cause },
    );
  }

  const manifest = JSON.parse(raw) as E2EManifest;

  if (manifest.version !== EXPECTED_VERSION) {
    throw new Error(
      `E2E manifest is version ${manifest.version ?? '(none)'}, this suite expects ` +
        `${EXPECTED_VERSION}. Re-seed:\n${SEED_COMMAND}`,
    );
  }

  const age = Date.now() - Date.parse(manifest.seeded_at);

  if (Number.isFinite(age) && age > STALE_AFTER_MS) {
    // Not fatal: an old fixture is usually still fine. But when a run goes
    // strangely red, "seeded 6 days ago" is the first thing worth knowing.
    console.warn(
      `⚠ E2E fixture was seeded ${Math.round(age / 3_600_000)}h ago. ` +
        'Re-seed if results look inconsistent.',
    );
  }

  // Nothing type-checks this directory — `e2e/` is in no tsconfig include,
  // so `vue-tsc` never sees it. That is exactly how `multi_role` came to
  // sit in the manifest for weeks while `FixtureKey` did not list it and
  // `api_only` was declared by the seeder and honoured by nobody. A key
  // the suite does not know about must fail here, at load, or it silently
  // gets driven through whatever loop happens to iterate the list.
  const unknown = manifest.fixtures
    .map((f) => f.key)
    .filter((k) => !FIXTURE_KEYS.includes(k));

  if (unknown.length > 0) {
    throw new Error(
      `E2E manifest carries fixture(s) this suite does not know: ${unknown.join(', ')}.\n` +
        `Known: ${FIXTURE_KEYS.join(', ')}.\n` +
        'Add the key to FixtureKey/FIXTURE_KEYS and decide whether it is safe to ' +
        'drive through the browser (see uiFixtures) — do not just widen the type.',
    );
  }

  cached = manifest;

  return manifest;
}

/**
 * The fixtures a browser-driving loop may walk.
 *
 * Anything marked `api_only` is excluded: see the flag's note on
 * `E2EFixture`. The seeder has documented that contract since the account
 * was minted ("never used as a login fixture for the UI"); this is the
 * first thing that enforces it.
 */
export function uiFixtures(): E2EFixture[] {
  const usable = loadManifest().fixtures.filter((f) => !f.api_only);

  if (usable.length === 0) {
    throw new Error(
      'Every fixture in the manifest is marked api_only, so every UI walk would ' +
        'silently cover nothing. Re-seed:\n' +
        SEED_COMMAND,
    );
  }

  return usable;
}

/** Look a fixture up by surface, failing loudly when the seeder skipped it. */
export function fixture(key: FixtureKey): E2EFixture {
  const found = loadManifest().fixtures.find((f) => f.key === key);

  if (!found) {
    throw new Error(
      `No '${key}' fixture in the manifest. The seeder asserts every surface exists, ` +
        `so this means the manifest predates that check — re-seed:\n${SEED_COMMAND}`,
    );
  }

  return found;
}

/**
 * The bimbel tenant's fixtures, or `null` when the manifest predates it.
 *
 * Returns null rather than throwing so a spec can `test.skip` with a
 * message naming the re-seed, which is a coverage gap worth saying out
 * loud — not a failure.
 */
export function bimbel(): NonNullable<E2EManifest['bimbel']> | null {
  return loadManifest().bimbel ?? null;
}

/** A bimbel account by surface. Throws only once `bimbel()` is present. */
export function bimbelFixture(key: FixtureKey): E2EFixture {
  const block = bimbel();

  if (!block) {
    throw new Error(`no bimbel block in the manifest — re-seed:\n${SEED_COMMAND}`);
  }

  const found = block.fixtures.find((f) => f.key === key);

  if (!found) {
    throw new Error(
      `no '${key}' bimbel fixture. Seeded: ${block.fixtures.map((f) => f.key).join(', ')}.`,
    );
  }

  return found;
}

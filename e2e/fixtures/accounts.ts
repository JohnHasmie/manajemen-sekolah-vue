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
  | 'admin'
  | 'teacher'
  | 'wali_kelas'
  | 'parent'
  | 'staff'
  | 'super_admin';

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
  warning?: string;
}

export interface E2EManifest {
  version: number;
  seeded_at: string;
  school: { id: string; name: string };
  password: string;
  fixtures: E2EFixture[];
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

  cached = manifest;

  return manifest;
}

/** Look a fixture up by surface, failing loudly when the seeder skipped it. */
export function fixture(key: FixtureKey): E2EFixture {
  const found = loadManifest().fixtures.find((f) => f.key === key);

  if (!found) {
    throw new Error(
      `No '${key}' fixture in the manifest. The seeder asserts all six surfaces exist, ` +
        `so this means the manifest predates that check — re-seed:\n${SEED_COMMAND}`,
    );
  }

  return found;
}

# E2E suite (Playwright)

Local-only. The suite logs in as seeded fixture accounts and walks
authenticated pages, so it must never be pointed at a real tenant.

## Run it

1. **Local stack up** — core API on `:8001`.

2. **Seed the fixture tenant** (backend repo):

   ```
   docker exec -e DB_CONNECTION=pgsql -e DB_DATABASE=edu_core kamiledu-core-api-app \
     php artisan db:seed --class='Database\Seeders\E2ESeeder'
   ```

   `E2ESeeder` builds one school through the real provisioning pipeline,
   resets every account to one known password, and writes
   `storage/app/e2e/accounts.json`. It refuses to run outside
   `APP_ENV=local|testing` or against a non-local database host.

3. **Run**:

   ```
   npx playwright test
   ```

   The dev server starts automatically (`webServer` in the config) and an
   already-running one is reused.

## Environment

| Variable | Default | Purpose |
|---|---|---|
| `E2E_BASE_URL` | `http://localhost:5173` | web app |
| `E2E_API_URL` | `http://localhost:8001/api` | core API |
| `E2E_AI_URL` | `http://localhost:8000/api` | AI service |
| `E2E_BACKEND_PATH` | `../../backendmanajemensekolah_laravel` | where to read the manifest |
| `E2E_PASSWORD` | seeder default | must match what the seeder used |

## What Phase 1 covers

`nav-smoke.spec.ts` walks every nav item each role actually renders and
asserts the page came up. Nav items are read from the DOM, not from a
hardcoded list — a hardcoded list keeps passing after a menu is removed,
which tests history rather than the product.

**Fails the run** (the page is broken): bounced to `/login`, blank body,
a 5xx from the core API, an uncaught exception.

**Reported, does not fail**: console errors, 4xx, and 5xx from the AI
service. A page that renders correctly while logging a 404 for an
optional widget is not broken, and a suite that is red by default is a
suite everyone learns to ignore.

The AI service gets this treatment because a local stack routinely runs
without it wired up — with `EDU_CORE_URL` unset in the AI container its
entitlement lookup fails and **every** AI endpoint answers 503:

```
docker exec kamiledu-ai-api-app printenv EDU_CORE_URL
```

Empty output means the 503s in the report are your local stack, not the
web app.

## The six surfaces

The manifest keys fixtures by SURFACE, which is not the same as role:

| key | role | what makes it that surface |
|---|---|---|
| `admin` | admin | the school owner |
| `wali_kelas` | **teacher** | owns a homeroom class |
| `teacher` | **teacher** | owns **no** homeroom |
| `parent` | parent | guardian of a child in the `wali_kelas` homeroom |
| `staff` | staff | has a `staff` row; nav is entirely ability-driven |
| `super_admin` | super_admin | `read_only` — see below |

`wali_kelas` is not a stored role. `normalizeRole()` collapses it to
`teacher`, and the app switches to `WALI_KELAS_NAV` purely on
`homeroomClasses.length > 0`. So both a homeroom teacher **and** a plain
one are required, or that branch is never exercised and the suite walks
the same nav twice while reporting two passes.

There is deliberately no `student` surface on web.

**`super_admin` is fenced.** Its console reaches every demo school in the
database, not just the fixture. `applySession()` blocks `DELETE`/`POST`
to `**/api/admin/demo-schools/**` for any fixture marked `read_only`, so
no spec can delete another developer's tenant by accident.

## Fixture integrity

The seeder refuses to write a manifest it cannot vouch for. Before the
file is written it asserts, among others: every surface has an account;
the fixture password opens each one; each holds exactly **one** active
role (more and `LoginAction` switches to the role-picker response);
`role_id` is non-NULL except for super_admin; the two teacher fixtures
own 1 and 0 homerooms respectively; the parent has a child; and the
tenant clears content floors.

That check is the suite's false-positive control. A fixture that renders
empty pages passes a "did it load" assertion perfectly — removing that
ambiguity is the whole reason this seeder exists.

## Known gaps

Phase 1 asserts pages *render*. It does not exercise actions
(create/edit/delete), and it does not assert that a role **cannot** reach
what it should not. That negative authorization pass is the most
valuable thing to build next.

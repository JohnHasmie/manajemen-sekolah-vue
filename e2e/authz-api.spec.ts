import { expect, test } from '@playwright/test';
import { loadManifest, type FixtureKey } from './fixtures/accounts';
import { apiFor, statusOf } from './fixtures/api';
import { ADMIN_READ_PROBES, DENY_MATRIX, SCOPED_READS } from './fixtures/authz-matrix';
import { login } from './fixtures/auth';

/**
 * Phase 5 — authorization at the API, not at the router.
 *
 * The router guard is cosmetic. It has no 403 view, it fails open when
 * `/me` errors, and anyone can skip it entirely with curl. Real
 * enforcement lives in `$this->authorize()` inside the controllers — and
 * only 61 of 108 controllers carry one. A green Phase 4 says nothing
 * about any of that.
 *
 * These tests speak to the API directly, with the exact header set the
 * app's axios interceptor sends. Fidelity matters: a probe that omits
 * `X-School-ID` is rejected by EnsureSchoolContext, and then every
 * "expect 403" row passes for a reason that has nothing to do with
 * authorization.
 */

const manifest = loadManifest();

function has(key: FixtureKey): boolean {
  return manifest.fixtures.some((f) => f.key === key);
}

function fixtureFor(key: FixtureKey) {
  const found = manifest.fixtures.find((f) => f.key === key);
  if (!found) throw new Error(`fixture '${key}' missing from the manifest`);
  return found;
}

// ── Group A — curated matrix, hard failures ─────────────────────────

for (const row of DENY_MATRIX) {
  const verb = row.expect === 200 ? 'may' : 'may NOT';

  test(`${row.fixture} ${verb} ${row.method} ${row.path}`, async () => {
    const client = await apiFor(await login(fixtureFor(row.fixture)));

    try {
      const status = await statusOf(client, row.method, row.path, row.body);

      expect(status, row.because).toBe(row.expect);
    } finally {
      await client.dispose();
    }
  });
}

// ── Group B — broad probe, report only ──────────────────────────────

for (const key of ['parent', 'staff'] as FixtureKey[]) {
  test(`probe: what ${key} can read of the admin surface`, async () => {
    const client = await apiFor(await login(fixtureFor(key)));

    try {
      const reachable: string[] = [];
      const errors: string[] = [];

      for (const path of ADMIN_READ_PROBES) {
        const status = await statusOf(client, 'GET', path);

        if (status >= 200 && status < 300) reachable.push(`${status} ${path}`);
        // A 5xx is not an authorization answer at all — the endpoint
        // fell over. Worth seeing separately from "allowed".
        else if (status >= 500) errors.push(`${status} ${path}`);
      }

      console.log(`\n── ${key}: ${reachable.length}/${ADMIN_READ_PROBES.length} admin reads returned 2xx ──`);
      for (const r of reachable) console.log(`      ${r}`);

      if (errors.length) {
        console.log(`   ${errors.length} endpoints returned 5xx:`);
        for (const e of errors) console.log(`      ${e}`);
      }

      console.log(
        '   Report only. A 2xx here is a LEAD, not a verdict — several of these\n' +
          '   legitimately return an empty, correctly-scoped result (e.g. /bill/parent\n' +
          '   returns [] for a non-parent). Confirm the body actually carries other\n' +
          "   people's data before promoting a row into DENY_MATRIX.",
      );
    } finally {
      await client.dispose();
    }
  });
}

// ── Group C — X-Active-Role widening ────────────────────────────────

/**
 * The backend narrows abilities to the role named in `X-Active-Role`,
 * and falls back to the UNION of every role the user holds when the
 * header is absent. So a user who is both teacher and parent, acting as
 * parent, could reach teacher-only writes simply by dropping one header
 * — reachable from any client that forgets it.
 *
 * Needs a fixture holding two roles. The seeder does not mint one yet,
 * so this skips loudly rather than passing silently.
 */
test('omitting X-Active-Role does not widen abilities to the union of roles', async () => {
  test.skip(
    !has('multi_role'),
    'no multi_role fixture — E2ESeeder does not mint a two-role account yet, so ' +
      'the union-fallback cannot be exercised. This is a COVERAGE GAP, not a pass.',
  );

  const account = fixtureFor('multi_role');
  const session = await login(account);

  const asParent = await apiFor(session, { activeRole: 'parent' });
  const headerless = await apiFor(session, { activeRole: null });

  try {
    // `/rpp` is the right probe: teacher holds academic.lesson_plan.view,
    // parent does not, and the endpoint reaches the authorization layer
    // instead of failing validation first (which is why /report-cards
    // cannot be used — it 400s for everyone before authz runs).
    const scoped = await statusOf(asParent, 'GET', '/rpp');
    const widened = await statusOf(headerless, 'GET', '/rpp');

    expect(
      scoped,
      'CONTROL: acting as parent, a teacher-only read must be denied — otherwise the ' +
        'header is not narrowing at all and the widening check below proves nothing',
    ).toBe(403);

    expect(
      widened,
      'dropping X-Active-Role granted an ability the active role does not have. ' +
        'AbilityResolver falls back to the UNION of every role when the header is ' +
        'absent, so this is privilege widening reachable from any client that forgets it',
    ).toBe(403);
  } finally {
    await asParent.dispose();
    await headerless.dispose();
  }
});

// ── Group D — scoped reads: 200 for everyone, different rows each ────

/**
 * Reads whose protection is the PAYLOAD, not the status code.
 *
 * Every assertion here has a control that must hold first, because each
 * one has a way of passing for the wrong reason:
 *
 *  • the admin view must be non-empty — against an empty tenant "the
 *    parent sees fewer rows" is true and meaningless;
 *  • the narrowed caller must get 200 — a 403 would also produce zero
 *    rows, and would be a different (and wrong) fix silently accepted;
 *  • the narrowed set must be a strict SUBSET by id, not merely smaller.
 *    A count check passes an implementation scoped to the wrong class or
 *    the wrong teacher, as long as it returns fewer rows.
 */
for (const row of SCOPED_READS) {
  for (const key of row.narrowed) {
    test(`${key} sees only their slice of ${row.path}`, async () => {
      test.skip(!has(key) || !has(row.full), `fixture '${key}' or '${row.full}' missing`);

      const wide = await apiFor(await login(fixtureFor(row.full)));
      const narrow = await apiFor(await login(fixtureFor(key)));

      try {
        const idsOf = async (client: Awaited<ReturnType<typeof apiFor>>) => {
          const res = await client.ctx.fetch(`${client.base}${row.path}`);
          const body = (await res.json().catch(() => null)) as { data?: { id?: string }[] } | null;

          return {
            status: res.status(),
            ids: (body?.data ?? []).map((r) => r.id).filter(Boolean) as string[],
          };
        };

        const full = await idsOf(wide);
        const slice = await idsOf(narrow);

        expect(full.status, `CONTROL: ${row.full} must be able to read ${row.path}`).toBe(200);
        expect(
          full.ids.length,
          `CONTROL: ${row.full} sees no rows at ${row.path}, so every comparison below is vacuous. ` +
            'Re-seed the tenant rather than trusting this test.',
        ).toBeGreaterThan(0);

        expect(
          slice.status,
          `${key} must still be ALLOWED to read ${row.path} — the fix is scoping, not denial. ` +
            'A 403 here would zero the rows for the wrong reason and hide a regression.',
        ).toBe(200);

        const leaked = slice.ids.filter((id) => !full.ids.includes(id));
        expect(leaked, `${key} received rows outside ${row.full}'s view of ${row.path}`).toEqual([]);

        expect(
          slice.ids.length,
          `${key} received the SAME ${full.ids.length} rows as ${row.full} — the read is not ` +
            `scoped at all. ${row.because}`,
        ).toBeLessThan(full.ids.length);
      } finally {
        await wide.dispose();
        await narrow.dispose();
      }
    });
  }
}

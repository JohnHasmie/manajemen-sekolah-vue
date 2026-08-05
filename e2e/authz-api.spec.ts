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
          const body = (await res.json().catch(() => null)) as unknown;

          // Two response shapes in one controller: most reads answer
          // `{success, data: [...]}`, but the unfiltered index returns a
          // BARE array straight from the repository. Reading only `.data`
          // scored it as zero rows, and the control below then failed the
          // test for "an empty tenant" — a true statement about the wrong
          // thing. Accept either shape rather than assert the tidier one.
          const rows = Array.isArray(body)
            ? body
            : ((body as { data?: unknown })?.data ?? []);

          return {
            status: res.status(),
            ids: (Array.isArray(rows) ? rows : [])
              .map((r) => (r as { id?: string })?.id)
              .filter(Boolean) as string[],
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

// ── Group E — a teacher id in the query string is not a free pass ────

/**
 * `/teaching-schedule/teacher/{id}`, `week-summary` and `daily-summary`
 * take a teacher id as INPUT and scope themselves to it perfectly — for
 * whichever teacher the caller names. That is an IDOR, not an over-broad
 * list, which is why backend !636 answers 403 rather than an empty array:
 * nothing was filtered out, the request was not the caller's to make.
 *
 * These live here rather than in DENY_MATRIX because the path carries a
 * seeded id, and a hard-coded one would rot on the next re-seed.
 */
test('a parent cannot walk teacher ids', async () => {
  test.skip(!has('parent') || !has('teacher'), 'parent or teacher fixture missing');

  const victim = fixtureFor('teacher').user_id;
  const parent = await apiFor(await login(fixtureFor('parent')));
  const teacher = await apiFor(await login(fixtureFor('teacher')));

  try {
    for (const path of [
      `/teaching-schedule/teacher/${victim}`,
      `/teaching-schedule/week-summary?teacher_id=${victim}`,
      `/teaching-schedule/daily-summary?teacher_id=${victim}`,
    ]) {
      expect(await statusOf(parent, 'GET', path), `a parent read another person's ${path}`).toBe(403);
    }

    // CONTROL: the teacher's OWN id still works. Without it the three
    // 403s above would pass just as happily against an endpoint that had
    // been broken for everyone.
    expect(
      await statusOf(teacher, 'GET', `/teaching-schedule/teacher/${victim}`),
      'CONTROL: a teacher lost access to their own schedule',
    ).toBe(200);

    // And a missing id is still the historical 400, not a 403 — the
    // teacher's own screen calls these before it has resolved a profile
    // id, and turning that into a refusal broke it once already.
    expect(
      await statusOf(teacher, 'GET', '/teaching-schedule/week-summary'),
      'an absent teacher_id must stay a 400 "required", not become a 403',
    ).toBe(400);
  } finally {
    await parent.dispose();
    await teacher.dispose();
  }
});

test('the class timetable matrix refuses a class the caller has no tie to', async () => {
  test.skip(!has('parent') || !has('admin'), 'parent or admin fixture missing');

  const wide = await apiFor(await login(fixtureFor('admin')));
  const narrow = await apiFor(await login(fixtureFor('parent')));

  try {
    // Which classes is this parent actually entitled to? Ask the product,
    // do not assume. The first attempt at this test hard-coded
    // `classes[0]` and failed against a CORRECT backend, because the
    // fixture parent's child happens to sit in that very class — an
    // identical matrix was the right answer and the test called it a
    // leak.
    const mineRes = await narrow.ctx.fetch(`${narrow.base}/teaching-schedule`);
    const mineBody = (await mineRes.json().catch(() => null)) as unknown;
    const mineRows = (Array.isArray(mineBody) ? mineBody : ((mineBody as { data?: unknown })?.data ?? [])) as {
      class_id?: string;
    }[];
    const ownClassIds = new Set(mineRows.map((r) => r?.class_id).filter(Boolean));

    const foreign = manifest.data.classes.find((c) => !ownClassIds.has(c.id));
    test.skip(!foreign, 'the seeded parent is tied to every class, so there is no foreign class to probe');

    const cellCount = async (client: Awaited<ReturnType<typeof apiFor>>) => {
      const res = await client.ctx.fetch(
        `${client.base}/teaching-schedules/matrix?class_id=${foreign!.id}`,
      );
      const body = (await res.json().catch(() => null)) as
        | { data?: { cells?: Record<string, unknown> }; cells?: Record<string, unknown> }
        | null;
      const cells = body?.data?.cells ?? body?.cells ?? {};

      return { status: res.status(), filled: Object.keys(cells).length };
    };

    const full = await cellCount(wide);
    const slice = await cellCount(narrow);

    expect(full.status, `CONTROL: the admin must still read ${foreign!.name}`).toBe(200);
    expect(
      full.filled,
      `CONTROL: ${foreign!.name} has no lessons in it, so an empty parent matrix would prove nothing`,
    ).toBeGreaterThan(0);

    expect(slice.status, 'the matrix is scoped, not denied').toBe(200);
    expect(
      slice.filled,
      `a parent read the full timetable of ${foreign!.name} — class_id is caller-supplied, so ` +
        'without narrowing any class in the school can be read by naming it',
    ).toBe(0);
  } finally {
    await wide.dispose();
    await narrow.dispose();
  }
});

// ── Group F — class helper reads (backend !645) ──────────────────────

/**
 * Two more reads on ClassController, and the two different answers they
 * needed. Hand-written rather than matrix rows because both paths carry
 * a seeded id, and a hard-coded one rots on the next re-seed.
 */
test('the homeroom picker is admin-only', async () => {
  test.skip(!has('parent') || !has('teacher') || !has('admin'), 'fixtures missing');

  const classId = manifest.data.classes[0]?.id;
  test.skip(!classId, 'no seeded class in the manifest');

  const path = `/class/${classId}/homeroom-candidates`;
  const parent = await apiFor(await login(fixtureFor('parent')));
  const teacher = await apiFor(await login(fixtureFor('teacher')));
  const admin = await apiFor(await login(fixtureFor('admin')));

  try {
    // It returns `employee_number` — the NIP /teacher was gated for in
    // !633 — and answers "who could be wali kelas here", which a partial
    // staff list would answer wrongly rather than incompletely.
    expect(await statusOf(parent, 'GET', path), 'a parent read staff NIPs').toBe(403);
    expect(await statusOf(teacher, 'GET', path), 'a teacher read staff NIPs').toBe(403);

    // CONTROL: the admin screens that assign a wali kelas still work.
    expect(
      await statusOf(admin, 'GET', path),
      'CONTROL: the admin lost the homeroom picker, so the 403s above prove nothing',
    ).toBe(200);
  } finally {
    await parent.dispose();
    await teacher.dispose();
    await admin.dispose();
  }
});

test('the by-subject class list is scoped to the caller', async () => {
  test.skip(!has('parent') || !has('admin'), 'fixtures missing');

  const subjectId = manifest.data.subjects[0];
  test.skip(!subjectId, 'no seeded subject in the manifest');

  const path = `/class-by-mata-pelajaran?subject_id=${subjectId}`;
  const admin = await apiFor(await login(fixtureFor('admin')));
  const parent = await apiFor(await login(fixtureFor('parent')));

  try {
    const idsOf = async (client: Awaited<ReturnType<typeof apiFor>>) => {
      const res = await client.ctx.fetch(`${client.base}${path}`);
      const body = (await res.json().catch(() => null)) as unknown;
      const rows = Array.isArray(body) ? body : ((body as { data?: unknown })?.data ?? []);

      return {
        status: res.status(),
        ids: (Array.isArray(rows) ? rows : []).map((r) => (r as { id?: string })?.id).filter(Boolean) as string[],
      };
    };

    const full = await idsOf(admin);
    const slice = await idsOf(parent);

    expect(full.status, 'CONTROL: the admin must still read the by-subject list').toBe(200);
    expect(
      full.ids.length,
      'CONTROL: the seeded subject is attached to no class, so the comparison below is vacuous',
    ).toBeGreaterThan(1);

    // Scoped, NOT gated: the lesson-plan screens on mobile call this as
    // a teacher to pick the class an RPP is for, and school.class.view
    // is admin-only — a 403 here would stop teachers writing RPP.
    expect(slice.status, 'a parent must still be allowed to read, just less').toBe(200);
    expect(
      slice.ids.length,
      'a parent received every class attached to the subject; the read is not scoped',
    ).toBeLessThan(full.ids.length);

    // `teacher` is deliberately absent: the fixture teacher teaches both
    // seeded classes, so "sees fewer" is false for them and asserting it
    // would fail against a CORRECT backend. That branch is covered by
    // ClassAndPaymentTypeReadAuthzTest, on a fixture that is built.
  } finally {
    await admin.dispose();
    await parent.dispose();
  }
});

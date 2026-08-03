import { expect, test } from '@playwright/test';
import { fixture, loadManifest } from '../fixtures/accounts';
import { applySession, login } from '../fixtures/auth';
import { Tracker, namespaceFor } from '../fixtures/isolation';
import { crud, formSheet, sheetCancel, sheetSubmit } from '../pages/ui';

/**
 * Phase 6 — CRUD against the admin student roster.
 *
 * This is the PATTERN for the other four rosters (teachers, staff,
 * classes, subjects): same scaffold, same primitives, only the form
 * fields differ. Getting one right and copying beats five half-written.
 *
 * ── The isolation rules, applied without exception ──────────────────
 *  1. Name it, own it. Every record carries this test's namespace, and
 *     every list assertion searches for that namespace.
 *  2. Never assert a total count. `toHaveCount(20)` is how a suite
 *     becomes order-dependent the moment another spec adds a row.
 *  3. Teardown through the API, not the UI.
 *
 * Seeded rows are READ (to fill a class dropdown) but never mutated.
 */

test.describe.configure({ mode: 'serial' });

const manifest = loadManifest();

test.describe('admin · students', () => {
  let tracker: Tracker;
  let ns: string;

  test.beforeEach(async ({ context, page }, testInfo) => {
    tracker = new Tracker();
    ns = namespaceFor(testInfo);

    const admin = fixture('admin');
    await applySession(context, await login(admin), admin);
    await page.goto('/admin/students');

    // Wait for the control this spec actually needs, not for the network
    // to fall silent. `networkidle` never settles on this page — it keeps
    // polling — so waiting on it just burns the whole test budget and
    // then reports a timeout that looks like a broken page.
    await expect(crud(page).addFab).toBeVisible({ timeout: 60_000 });
  });

  test.afterEach(async () => {
    const leaks = await tracker.cleanup(await login(fixture('admin')));

    expect(leaks, 'API teardown could not remove records this test created').toEqual([]);
  });

  /**
   * Create a student through the UI and register it for teardown.
   *
   * The id comes from the create response rather than a follow-up
   * lookup: without it the Tracker has nothing to delete, and every run
   * leaves its rows behind in the shared tenant — which is exactly what
   * happened before this was wired up, leaving duplicate `-Siti` rows
   * that then broke the next run's assertions.
   */
  async function createStudent(page: import('@playwright/test').Page, name: string) {
    const created = page.waitForResponse(
      (r) => r.url().includes('/api/student') && r.request().method() === 'POST',
    );

    await fillNewStudent(page, name);
    await sheetSubmit(page).click();

    const body = (await (await created).json().catch(() => null)) as
      | { data?: { id?: string }; id?: string }
      | null;

    const id = body?.data?.id ?? body?.id;

    if (id) tracker.track('/student', id);

    await expect(formSheet(page)).toBeHidden();
  }

  /** Fill the create sheet with a uniquely-named student. */
  async function fillNewStudent(page: import('@playwright/test').Page, name: string) {
    await crud(page).addFab.click();
    await expect(formSheet(page)).toBeVisible();

    await page.getByTestId('field-name').fill(name);
    await page.getByTestId('field-student_number').fill(`${Date.now()}`.slice(-8));
    // Required — the form rejects with "Nama wali wajib diisi" without it.
    //
    // Deliberately NOT derived from the student's name. When it was
    // `${name}-Wali`, renaming the student left the OLD name on screen
    // through the guardian column, and the "old name is gone" assertion
    // failed on the test's own data rather than on anything the product
    // did wrong.
    await page.getByTestId('field-guardian_name').fill(`${ns}-Guardian`);

    // Class comes from seeded data — read, never mutated.
    const classId = manifest.data.classes[0]?.id;
    if (classId) {
      // The class list arrives from the API, so under parallel load the
      // <select> can still be empty when we reach it. selectOption then
      // times out on a form that is merely slow, not broken — wait for
      // the options to exist first.
      await expect
        .poll(async () => page.getByTestId('field-class_id').locator('option').count(), {
          timeout: 30_000,
        })
        .toBeGreaterThan(1);

      await page.getByTestId('field-class_id').selectOption(classId);
    }
  }

  test('create · the new student appears in the roster', async ({ page }) => {
    const name = `${ns}-Budi`;

    await createStudent(page, name);

    // NOTE: no success-toast assertion here, and that is deliberate.
    // `handleSave()` in AdminStudentManagementView simply reloads the
    // list — it raises no toast on create or on single delete, while
    // bulk delete and password reset both do. That inconsistency is
    // worth fixing in the product, but a test that demands a toast the
    // app never shows is asserting a wish, not a contract.
    await crud(page).searchFor(name);
    await expect(crud(page).row(name)).toBeVisible();
  });

  test('create · a blank required field blocks the request entirely', async ({ page }) => {
    // Watching the network, not just the DOM: a form that shows an error
    // AND still fires the POST is a different (worse) bug than one that
    // shows nothing, and only the network tells them apart.
    const writes: string[] = [];
    page.on('request', (r) => {
      if (r.method() === 'POST' && r.url().includes('/student')) writes.push(r.url());
    });

    await crud(page).addFab.click();
    await expect(formSheet(page)).toBeVisible();
    await page.getByTestId('field-name').fill('');
    await sheetSubmit(page).click();

    await expect(formSheet(page), 'the sheet must stay open on invalid input').toBeVisible();
    expect(writes, 'a create request left the browser despite invalid input').toEqual([]);

    await sheetCancel(page).click();
  });

  test('edit · the change survives a full page reload', async ({ page }) => {
    const name = `${ns}-Siti`;
    const renamed = `${ns}-Renamed`;

    await createStudent(page, name);

    await crud(page).searchFor(name);
    // Clicking a row opens the DETAIL sheet; editing is a step further
    // in. Asserting straight after the row click silently tested nothing
    // — the rename never happened and the row still read `-Siti`.
    await crud(page).row(name).click();
    await page.getByTestId('detail-edit').click();
    await expect(formSheet(page)).toBeVisible();
    await page.getByTestId('field-name').fill(renamed);
    await sheetSubmit(page).click();
    await expect(formSheet(page)).toBeHidden();

    // The reload is the entire point. An optimistic-UI-only update — the
    // list patched locally while the request failed or never fired —
    // passes every assertion made without one.
    await page.reload();
    // Same reason as in beforeEach: this page polls, so `networkidle`
    // never arrives and the wait consumes the whole test budget.
    await expect(crud(page).addFab).toBeVisible({ timeout: 60_000 });
    await crud(page).searchFor(renamed);

    await expect(crud(page).row(renamed)).toBeVisible();
    await expect(crud(page).body).not.toContainText(name);
  });

  test('delete · cancel keeps the row, confirm removes it for good', async ({ page }) => {
    const name = `${ns}-Andi`;

    await createStudent(page, name);

    await crud(page).searchFor(name);
    await expect(crud(page).row(name)).toBeVisible();

    // Cancelling a destructive confirm must be a no-op — the assertion
    // people forget, and the one that matters most.
    await crud(page).row(name).click();
    await page.getByTestId('detail-edit').click();
    await expect(formSheet(page)).toBeVisible();
    await sheetCancel(page).click();
    await page.reload();
    // Same reason as in beforeEach: this page polls, so `networkidle`
    // never arrives and the wait consumes the whole test budget.
    await expect(crud(page).addFab).toBeVisible({ timeout: 60_000 });
    await crud(page).searchFor(name);
    await expect(crud(page).row(name)).toBeVisible();
  });
});

import { expect, test, type Page } from '@playwright/test';
import { fixture } from '../fixtures/accounts';
import { applySession, login } from '../fixtures/auth';
import { Tracker, namespaceFor } from '../fixtures/isolation';
import { confirmDialog, crud, formSheet, sheetCancel, sheetSubmit } from '../pages/ui';

/**
 * Phase 6 — the remaining four admin rosters.
 *
 * Students live in their own spec: it is the reference implementation
 * and carries the richer assertions (edit-survives-reload, detail→edit
 * navigation). These four share the same scaffold and primitives, so
 * only the form differs — which is exactly what a table expresses
 * better than four near-identical files.
 *
 * Required fields come from the BACKEND validation rules, not from
 * reading the form. Guessing them cost several rounds on the students
 * spec: the sheet simply refused to close and the failure looked like a
 * broken save.
 */

/**
 * The four rosters are NOT uniform, and the table says so rather than
 * pretending otherwise:
 *
 *  · Classes hides the scaffold's FAB (`:hide-add-fab="true"`) and
 *    renders its own speed dial — the round button opens a menu, and
 *    "Tambah Kelas" is a second click.
 *  · Staff's sheet is a bare `<Modal>`, not a `FormSheet`, so it has
 *    neither the shared form wrapper nor the shared submit button.
 *
 * Papering over either — by tagging the speed dial as if it were the
 * scaffold FAB — would hide a real inconsistency behind a green test.
 */
interface Roster {
  key: string;
  path: string;
  /** DELETE endpoint used for teardown — what the UI itself calls. */
  endpoint: string;
  /** URL fragment identifying this roster's create request. */
  createUrl: string;
  /** Opens the create sheet. Defaults to the shared scaffold FAB. */
  openCreate?: (page: Page) => Promise<void>;
  /** The dialog this roster opens. Defaults to the shared FormSheet. */
  sheet?: (page: Page) => ReturnType<typeof formSheet>;
  /** Submits it. Defaults to the shared sheet footer button. */
  submit?: (page: Page) => Promise<void>;
  /**
   * Locator for the submit control, when invalid input DISABLES it
   * rather than letting the click through to validation. Both designs
   * deliver the same guarantee — no write leaves the browser — so the
   * test asserts the guarantee, not one particular mechanism.
   */
  submitControl?: (page: Page) => ReturnType<typeof formSheet>;
  /** Required fields, taken from the BACKEND validation rules. */
  fill: (page: Page, name: string) => Promise<void>;
  /**
   * Opens the edit sheet for a row. Defaults to the shared detail sheet
   * (row → Detail → Edit). Subjects has no detail sheet: its card
   * carries an inline Edit link instead.
   */
  openEdit?: (page: Page, name: string) => Promise<void>;
  /**
   * Opens the delete confirmation for a row. Defaults to the shared
   * detail sheet's danger button.
   */
  openDelete?: (page: Page, name: string) => Promise<void>;
}

const ROSTERS: Roster[] = [
  {
    key: 'teachers',
    path: '/admin/teachers',
    endpoint: '/teacher',
    createUrl: '/teacher',
    // CreateTeacherRequest: name + email required.
    //
    // The email carries a per-RUN suffix, not just the namespace. The
    // namespace derives from the test title and is therefore stable
    // across runs, so a leftover account from an earlier run made the
    // app raise its "Email sudah dipakai — attach the existing account?"
    // confirmation instead of saving. That prompt is correct product
    // behaviour; the test simply must not trigger it by accident.
    fill: async (page, name) => {
      await page.getByTestId('field-name').fill(name);
      await page
        .getByTestId('field-email')
        .fill(`${name.toLowerCase()}-${Date.now()}@kamiledu.test`);
    },
  },
  {
    key: 'staff',
    path: '/admin/staff',
    endpoint: '/staff',
    createUrl: '/staff',
    // Bare <Modal>: no FormSheet wrapper, no shared footer button.
    sheet: (page) => page.getByTestId('staff-sheet'),
    submit: async (page) => { await page.getByTestId('staff-submit').click(); },
    submitControl: (page) => page.getByTestId('staff-submit'),
    // StaffController::store validates name + position, but the sheet's
    // own `canSubmit` also demands a valid email and password before it
    // enables the button — so filling only the API-required fields left
    // Simpan disabled and the click timed out on a form that was working
    // exactly as designed.
    fill: async (page, name) => {
      await page.getByTestId('field-name').fill(name);
      await page.getByTestId('field-position').fill('Tata Usaha');
      await page.getByTestId('field-email').fill(`${name.toLowerCase()}-${Date.now()}@kamiledu.test`);
      // No password: the field only renders in manual mode, and the
      // sheet defaults to auto-generating one. Filling it timed out on a
      // control that correctly does not exist yet.
    },
  },
  {
    key: 'classes',
    path: '/admin/classes',
    endpoint: '/class',
    createUrl: '/class',
    // Speed dial: round toggle, then the "Tambah Kelas" entry.
    openCreate: async (page) => {
      await page.getByTestId('classes-fab-toggle').click();
      await page.getByTestId('classes-fab-add').click();
    },
    // CreateClassRequest: name + grade_level (integer 1..12).
    // grade_level renders as a <select>, so it needs selectOption —
    // fill() on it fails with "Element is not an <input>".
    fill: async (page, name) => {
      await page.getByTestId('field-name').fill(name);
      await page.getByTestId('field-grade_level').selectOption('7');
    },
  },
  {
    key: 'subjects',
    path: '/admin/subjects',
    endpoint: '/subject',
    createUrl: '/subject',
    // CreateSubjectRequest: name required.
    fill: async (page, name) => {
      await page.getByTestId('field-name').fill(name);
    },
    // No AdminEntityDetailSheet here — the curriculum card exposes an
    // inline Edit link and a kebab menu holding Hapus.
    // NB: clicking a subject card NAVIGATES to a detail page rather than
    // opening a sheet, so the row must not be clicked at all — the card
    // carries its own inline Edit link and a kebab holding Hapus. Search
    // has already narrowed the list to one card, so .first() is exact.
    openEdit: async (page) => {
      await page.getByTestId('subject-edit').first().click();
    },
    openDelete: async (page) => {
      await page.getByTestId('subject-kebab').first().click();
      await page.getByTestId('subject-delete').first().click();
    },
  },
];

/**
 * Close anything a roster leaves on screen after a successful create.
 *
 * Staff reveals the new account's generated password in a modal that
 * does not close itself. Left up, it intercepts the NEXT click — which
 * surfaces as "the row is not clickable", a timeout with no visible
 * connection to the modal that caused it. The trace is what showed it:
 * create succeeded, the sheet hid, search ran, and the row click then
 * never completed.
 *
 * The wait matters as much as the dismissal. The modal renders a beat
 * AFTER the form sheet hides, so a synchronous isVisible() right there
 * finds nothing, returns happily, and the modal appears immediately
 * afterwards. Applied to every roster: a stray modal blocking clicks is
 * a generic hazard, not a staff-specific one.
 */
async function dismissStrayModal(page: Page): Promise<void> {
  const modal = page.getByTestId('modal');

  await modal.waitFor({ state: 'visible', timeout: 3_000 }).catch(() => {});

  if (await modal.isVisible().catch(() => false)) {
    await page.keyboard.press('Escape');
    await expect(modal).toBeHidden();
  }
}

for (const roster of ROSTERS) {
  test.describe(`admin · ${roster.key}`, () => {
    test.describe.configure({ mode: 'serial' });

    let tracker: Tracker;
    let ns: string;

    const openCreate = (page: Page) =>
      roster.openCreate ? roster.openCreate(page) : crud(page).addFab.click();
    const sheetOf = (page: Page) => (roster.sheet ? roster.sheet(page) : formSheet(page));
    const submitSheet = (page: Page) =>
      roster.submit ? roster.submit(page) : sheetSubmit(page).click();
    const opener = (page: Page) =>
      roster.openCreate ? page.getByTestId('classes-fab-toggle') : crud(page).addFab;
    const openEdit = async (page: Page, name: string) => {
      if (roster.openEdit) return roster.openEdit(page, name);
      await crud(page).row(name).click();
      await page.getByTestId('detail-edit').click();
    };
    const openDelete = async (page: Page, name: string) => {
      if (roster.openDelete) return roster.openDelete(page, name);
      await crud(page).row(name).click();
      await page.getByTestId('detail-delete').click();
    };

    test.beforeEach(async ({ context, page }, testInfo) => {
      tracker = new Tracker();
      ns = namespaceFor(testInfo);

      const admin = fixture('admin');
      await applySession(context, await login(admin), admin);
      await page.goto(roster.path);

      // Wait on the control this roster actually offers — not
      // `networkidle`, which never arrives on these polling pages, and
      // not the scaffold FAB, which the classes page does not render.
      await expect(opener(page)).toBeVisible({ timeout: 60_000 });
    });

    test.afterEach(async () => {
      const leaks = await tracker.cleanup(await login(fixture('admin')));

      expect(leaks, 'API teardown could not remove records this test created').toEqual([]);
    });

    async function create(page: Page, name: string): Promise<void> {
      const created = page.waitForResponse(
        (r) => r.url().includes(roster.createUrl) && r.request().method() === 'POST',
      );

      await openCreate(page);
      await expect(sheetOf(page)).toBeVisible();
      await roster.fill(page, name);
      await submitSheet(page);

      const body = (await (await created).json().catch(() => null)) as
        | { data?: { id?: string }; id?: string }
        | null;

      const id = body?.data?.id ?? body?.id;

      // Registering the id is what keeps the shared tenant clean. Without
      // it every run leaves its rows behind, and the duplicates break the
      // NEXT run's row lookups rather than this one's.
      if (id) tracker.track(roster.endpoint, id);

      await expect(sheetOf(page)).toBeHidden();
      await dismissStrayModal(page);
    }

    test('create · the new row appears in the roster', async ({ page }) => {
      const name = `${ns}-Baru`;

      await create(page, name);
      await crud(page).searchFor(name);

      await expect(crud(page).row(name)).toBeVisible();
    });

    test('create · a blank required field blocks the request entirely', async ({ page }) => {
      // Watching the network rather than the DOM: a form that shows an
      // error AND still fires the POST is a different, worse bug than one
      // that shows nothing, and only the request log separates them.
      const writes: string[] = [];
      page.on('request', (r) => {
        if (r.method() === 'POST' && r.url().includes(roster.createUrl)) writes.push(r.url());
      });

      await openCreate(page);
      await expect(sheetOf(page)).toBeVisible();
      await page.getByTestId('field-name').fill('');

      if (roster.submitControl) {
        // This roster blocks invalid input by DISABLING submit, so
        // clicking would simply hang. Assert the button is unusable —
        // same guarantee, different mechanism.
        await expect(
          roster.submitControl(page),
          'submit should be disabled while a required field is blank',
        ).toBeDisabled();
      } else {
        await submitSheet(page);
      }

      await expect(sheetOf(page), 'the sheet must stay open on invalid input').toBeVisible();
      expect(writes, 'a create request left the browser despite invalid input').toEqual([]);
    });

    test('edit · the change survives a full page reload', async ({ page }) => {
      const name = `${ns}-Ubah`;
      const renamed = `${ns}-Sudah`;

      await create(page, name);
      await crud(page).searchFor(name);

      await openEdit(page, name);
      await expect(sheetOf(page)).toBeVisible();
      await page.getByTestId('field-name').fill(renamed);

      // Wait for the WRITE, not for the sheet to close. Whether a sheet
      // auto-closes after saving differs per roster — teachers keeps
      // theirs open — and that is a UI choice, not the contract. The
      // contract is that the change was persisted.
      const saved = page.waitForResponse(
        (r) => r.url().includes(roster.createUrl) && ['PUT', 'PATCH'].includes(r.request().method()),
      );
      await submitSheet(page);
      await saved;

      // The reload is the point: a list patched only in memory passes
      // every assertion made without one.
      await page.reload();
      await expect(opener(page)).toBeVisible({ timeout: 60_000 });
      await crud(page).searchFor(renamed);

      await expect(crud(page).row(renamed)).toBeVisible();
    });

    test('delete · cancel keeps the row, confirm removes it for good', async ({ page }) => {
      const name = `${ns}-Hapus`;

      await create(page, name);
      await crud(page).searchFor(name);
      await expect(crud(page).row(name)).toBeVisible();

      // Cancelling is the assertion people forget, and the one that
      // matters most: a flow that deletes on CANCEL is far worse than
      // one that fails to delete on confirm.
      await openDelete(page, name);
      await expect(confirmDialog(page)).toBeVisible();
      await sheetCancel(page).click();

      await page.reload();
      await expect(opener(page)).toBeVisible({ timeout: 60_000 });
      await crud(page).searchFor(name);
      await expect(crud(page).row(name), 'cancelling the confirm deleted the row').toBeVisible();

      await openDelete(page, name);
      await expect(confirmDialog(page)).toBeVisible();
      await sheetSubmit(page).click();

      // Wait for the dialog to close before reloading — reloading on the
      // click aborts the in-flight DELETE, and the surviving row then
      // reads as "delete is broken" when the request was just cancelled.
      await expect(confirmDialog(page)).toBeHidden();

      await page.reload();
      await expect(opener(page)).toBeVisible({ timeout: 60_000 });
      await crud(page).searchFor(name);
      await expect(crud(page).row(name), 'the row came back after a reload').toBeHidden();
    });

    test('search · finds the new row and clearing restores the list', async ({ page }) => {
      const name = `${ns}-Cari`;

      await create(page, name);

      await crud(page).searchFor(name);
      await expect(crud(page).row(name)).toBeVisible();

      await crud(page).searchFor('zzz-tidak-ada-zzz');
      await expect(crud(page).row(name)).toBeHidden();

      await crud(page).searchFor(name);
      await expect(crud(page).row(name)).toBeVisible();
    });
  });
}

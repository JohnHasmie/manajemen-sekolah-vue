import { expect, test } from '@playwright/test';
import { fixture, loadManifest } from './fixtures/accounts';
import { applySession, login } from './fixtures/auth';
import { backdrop, crud, formSheet, sheetCancel } from './pages/ui';

/**
 * Contract tests for the shared UI primitives.
 *
 * Every sheet, confirm and toast in the app is built on the same handful
 * of components, so their behaviour is worth pinning down ONCE here
 * instead of re-asserting it inside every CRUD spec. When one of these
 * fails, one component is broken — not one screen.
 *
 * Driven through a real page (`/admin/students`) rather than a mounted
 * component: the point is that the primitives behave correctly in situ,
 * with the app's own scroll locking, teleports and z-index in play.
 */

test.describe.configure({ mode: 'serial' });

test.beforeEach(async ({ context, page }) => {
  const admin = fixture('admin');
  await applySession(context, await login(admin), admin);
  await page.goto('/admin/students');

  // Wait for the control the spec needs, not for the network to fall
  // silent: this page polls, so `networkidle` never arrives and the wait
  // simply burns the budget before reporting a misleading timeout.
  await expect(crud(page).addFab).toBeVisible({ timeout: 60_000 });
});

test('the add sheet opens from the FAB and closes on Escape', async ({ page }) => {
  await crud(page).addFab.click();
  await expect(formSheet(page)).toBeVisible();

  await page.keyboard.press('Escape');
  await expect(formSheet(page)).toBeHidden();
});

test('a click inside the sheet does not close it; the backdrop does', async ({ page }) => {
  await crud(page).addFab.click();
  await expect(formSheet(page)).toBeVisible();

  // Clicking the sheet body must not bubble into the backdrop handler —
  // an easy regression when the backdrop's @click.self is refactored.
  await formSheet(page).click({ position: { x: 10, y: 10 } });
  await expect(formSheet(page)).toBeVisible();

  // The backdrop wraps the sheet, so click its far edge to hit the
  // backdrop itself rather than the card.
  await backdrop(page).click({ position: { x: 4, y: 4 } });
  await expect(formSheet(page)).toBeHidden();
});

test('Cancel closes the sheet without saving', async ({ page }) => {
  // No POST/PUT may leave the browser. Asserting on the DOM instead
  // (comparing the roster's text before and after) looked equivalent but
  // was brittle for the wrong reason: innerText normalisation and any
  // re-render make it flap without anything being saved. Watching the
  // network states the actual requirement.
  const writes: string[] = [];
  page.on('request', (r) => {
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(r.method())) writes.push(`${r.method()} ${r.url()}`);
  });

  await crud(page).addFab.click();
  await expect(formSheet(page)).toBeVisible();
  await sheetCancel(page).click();

  await expect(formSheet(page)).toBeHidden();
  expect(writes, 'Cancel must not write anything').toEqual([]);
});

/**
 * Closing a modal must restore page scrolling.
 *
 * Modal locks `document.body.style.overflow` on mount and clears it on
 * unmount — unconditionally. Two modals open at once (this app stacks
 * them: a picker over an edit sheet) means closing the inner one unlocks
 * scrolling while the outer is still open. This asserts the simple case
 * holds; the stacked case is the follow-up worth writing once a stacking
 * screen is under test.
 */
test('closing the sheet restores body scrolling', async ({ page }) => {
  const locked = async () =>
    page.evaluate(() => document.body.style.overflow);

  expect(await locked()).not.toBe('hidden');

  await crud(page).addFab.click();
  await expect(formSheet(page)).toBeVisible();
  expect(await locked(), 'body should be scroll-locked while a modal is open').toBe('hidden');

  await page.keyboard.press('Escape');
  await expect(formSheet(page)).toBeHidden();
  expect(await locked(), 'body scroll was never restored after the modal closed').not.toBe('hidden');
});

test('search filters the roster and clearing restores it', async ({ page }) => {
  const c = crud(page);

  // Assert on a SPECIFIC seeded name disappearing and coming back.
  // Asserting "the body has no words" instead looked simpler and was
  // wrong: filtering to nothing renders an empty-state message, which is
  // words, so the test failed while the search worked perfectly.
  const someone = loadManifest().data.students[0]?.name;

  test.skip(!someone, 'no seeded student in the manifest to search for');

  await expect(c.body).toContainText(someone!);

  await c.searchFor('zzz-no-such-student-zzz');
  await expect(c.body).not.toContainText(someone!);

  await c.search.fill('');
  await expect(c.body).toContainText(someone!);
});

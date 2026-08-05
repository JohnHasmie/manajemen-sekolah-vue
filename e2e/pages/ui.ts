import { expect, type Locator, type Page } from '@playwright/test';

/**
 * Handles for the shared UI primitives.
 *
 * Every dialog, sheet, confirm and toast in the app comes from a handful
 * of components in `src/components/ui`, so specs target these helpers
 * rather than re-deriving selectors per view. When the markup moves, one
 * file changes.
 *
 * Selectors are `data-testid`, deliberately. Text would couple assertions
 * to `src/locales/id.json` — the locale is switchable at runtime, so a
 * copy edit would turn the suite red with nothing broken. ARIA is
 * ambiguous here: `role="alert"` is on both the toast and
 * ConfirmationDialog's impact card, and `role="dialog"` is on Modal,
 * which is the base of FormSheet *and* ConfirmationDialog alike.
 */

export function modal(page: Page): Locator {
  return page.getByTestId('modal');
}

export function backdrop(page: Page): Locator {
  return page.getByTestId('modal-backdrop');
}

export function formSheet(page: Page): Locator {
  return page.getByTestId('form-sheet');
}

export function confirmDialog(page: Page): Locator {
  return page.getByTestId('confirm-dialog');
}

/** Cancel / submit — shared by every sheet and confirm dialog. */
export function sheetCancel(page: Page): Locator {
  return page.getByTestId('sheet-cancel');
}

export function sheetSubmit(page: Page): Locator {
  return page.getByTestId('sheet-submit');
}

export function toasts(page: Page): Locator {
  return page.getByTestId('toast');
}

/** The admin roster scaffold every CRUD page is built on. */
export function crud(page: Page) {
  return {
    search: page.getByTestId('crud-search'),
    clearFilters: page.getByTestId('crud-clear-filters'),
    body: page.getByTestId('crud-body'),
    bulkBar: page.getByTestId('crud-bulk-bar'),
    addFab: page.getByTestId('crud-add-fab'),

    async searchFor(term: string): Promise<void> {
      // Waits for the request the search actually fires, not for a fixed
      // slice of time.
      //
      // The previous comment here said the field is debounced. It is
      // not: AdminCrudScaffold emits on every change of its search ref
      // and each roster's `onSearch` calls `reload(1)` straight away.
      // The 600 ms was pure slop, and `teachers › search` failed about
      // one run in six when the box ran slower than that guess.
      //
      // `networkidle` genuinely is unusable on some of these pages, but
      // that is a separate fact and not a reason to guess at a delay.
      if (!term) {
        throw new Error(
          'searchFor() needs a non-empty term — it waits for the request carrying it. ' +
            'To clear the box, use the reset control instead.',
        );
      }

      // Registered BEFORE fill(): the request can be answered faster than
      // the next await resumes, and a listener attached afterwards would
      // wait for a response that has already come and gone.
      const settled = page.waitForResponse(
        (r) => r.request().method() === 'GET' && decodeURIComponent(r.url()).includes(`search=${term}`),
        { timeout: 20_000 },
      );

      await page.getByTestId('crud-search').fill(term);
      await settled;
    },

    /**
     * A roster row located by a name the CALLING TEST created. Never by
     * seeded data — a spec that asserts on rows it does not own becomes
     * order-dependent the moment another spec touches the same tenant.
     *
     * This resolves to the NAME ELEMENT inside the row, not to the
     * container. `crud-body.filter({ hasText })` looks like it selects a
     * row and does not: `filter` narrows the SAME element, so it returns
     * the whole container whenever the text appears anywhere inside it.
     * Clicking that clicks the container's centre — which landed on a row
     * by luck while the container hugged the list, and started landing on
     * empty space the moment it was widened to cover the empty state too.
     *
     * Clicking the name bubbles to whatever row handler owns it, so this
     * works without every view having to tag its own row markup.
     */
    row(ownName: string): Locator {
      return page.getByTestId('crud-body').getByText(ownName, { exact: false }).first();
    },
  };
}

/**
 * Assert exactly one toast appeared, with the expected tone.
 *
 * The count matters: 54 views still mount `Toast.vue` locally while
 * `ToastHost` is also live, so a single save can legitimately be expected
 * to raise one toast and actually raise two. Asserting "at least one"
 * would hide that.
 */
export async function expectToast(
  page: Page,
  tone: 'success' | 'error' | 'info',
  text?: RegExp,
): Promise<void> {
  // Toasts auto-dismiss after 4.5s, so this must be awaited IMMEDIATELY
  // after the action — anything slow in between (waiting for a sheet to
  // close, a list to refresh) can outlive the toast and turn a working
  // save into "element(s) not found".
  const toast = page.locator(`[data-testid="toast"][data-tone="${tone}"]`);

  await expect(toast.first()).toBeVisible();

  if (text) {
    await expect(toast.first()).toHaveText(text);
  }

  await expect(
    toast,
    'expected exactly one toast — two means a view mounts Toast.vue locally AND uses the host',
  ).toHaveCount(1);
}

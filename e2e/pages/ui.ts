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
      await page.getByTestId('crud-search').fill(term);
      // The field is debounced. `networkidle` is NOT usable here — these
      // pages poll, so it never arrives — so give the request time to go
      // out and let the caller's own assertion do the waiting.
      await page.waitForTimeout(600);
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

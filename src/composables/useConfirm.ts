/**
 * useConfirm — imperative confirmation dialog.
 *
 * Replaces native `window.confirm()` with the app's styled
 * ConfirmationDialog, so destructive actions get a consistent, on-brand,
 * localised dialog instead of the raw OS popup. Backed by a single
 * <ConfirmHost /> mounted once near the app root (App.vue).
 *
 * Usage:
 *   const { confirm } = useConfirm();
 *   if (!(await confirm({ message: t('...'), danger: true }))) return;
 *   // …proceed with the destructive action…
 */
import { reactive, readonly } from 'vue';

export interface ConfirmOptions {
  /** Dialog title. Falls back to a generic "Konfirmasi" in the host. */
  title?: string;
  /** Body text explaining what will happen. */
  message: string;
  /** Primary button label. Falls back to ConfirmationDialog's default. */
  confirmLabel?: string;
  /** Secondary button label. Falls back to "Batal". */
  cancelLabel?: string;
  /** Render the primary button in a destructive (red) style. */
  danger?: boolean;
  /**
   * Cascade consequences rendered as a warning card above the buttons.
   * Each string is one bullet — a single specific thing that will
   * happen when the action fires (e.g. "Rekap nilai + raport siswa
   * akan hilang"). Only shown on destructive actions where the
   * caller wants to warn the admin about downstream side effects.
   */
  impact?: string[];
}

interface ConfirmHostState extends ConfirmOptions {
  open: boolean;
}

// Module-level singleton — shared by every caller and the single host.
const state = reactive<ConfirmHostState>({
  open: false,
  title: undefined,
  message: '',
  confirmLabel: undefined,
  cancelLabel: undefined,
  danger: false,
  impact: undefined,
});

let resolver: ((value: boolean) => void) | null = null;

function settle(value: boolean): void {
  // Detach the resolver before invoking it so a re-entrant confirm() call
  // from inside the resolve handler can't double-settle this promise.
  const resolve = resolver;
  resolver = null;
  state.open = false;
  resolve?.(value);
}

/**
 * Open the confirm dialog. Resolves `true` when the user confirms,
 * `false` on cancel or dismiss.
 */
export function confirm(options: ConfirmOptions): Promise<boolean> {
  // If a previous dialog is somehow still pending, decline it first so its
  // caller isn't left awaiting forever.
  if (resolver) settle(false);
  state.title = options.title;
  state.message = options.message;
  state.confirmLabel = options.confirmLabel;
  state.cancelLabel = options.cancelLabel;
  state.danger = options.danger ?? false;
  state.impact = options.impact;
  state.open = true;
  return new Promise<boolean>((resolve) => {
    resolver = resolve;
  });
}

/** Host-only accessor. Do NOT use in feature code — call useConfirm(). */
export function useConfirmHost() {
  return {
    state: readonly(state),
    onConfirm: () => settle(true),
    onCancel: () => settle(false),
  };
}

export function useConfirm() {
  return { confirm };
}

/**
 * useToast — global app-level toast helper.
 *
 * Replaces the per-view `toast` ref pattern with a singleton so any
 * component (including ones outside the AppShell tree, like the
 * register-demo wizard) can fire success/error notifications without
 * mounting its own <Toast> instance. AppShell mounts a single
 * <ToastHost /> that subscribes to this composable.
 *
 * The web equivalent of Flutter's `SnackBarUtils.showSuccess /
 * showError`. Existing views that mount <Toast> manually keep
 * working — this is additive.
 */
import { ref } from 'vue';

export type ToastTone = 'success' | 'error' | 'info';

export interface ToastMessage {
  id: number;
  message: string;
  tone: ToastTone;
  durationMs: number;
  /** Optional bold heading rendered above `message` (e.g. notification title). */
  title?: string;
  /** Optional click handler — makes the whole toast tappable. */
  onClick?: () => void;
  /** Optional inline action button (e.g. "Batal" for undo). */
  action?: ToastAction;
}

/**
 * Inline action rendered as a button inside the toast body — separate
 * from `onClick` (which turns the whole toast into a tap surface). Use
 * this for undo affordances on destructive actions.
 */
export interface ToastAction {
  label: string;
  onAction: () => void;
}

/** Options for {@link useToast}.show — the richer, action-capable form. */
export interface ToastOptions {
  message: string;
  tone?: ToastTone;
  durationMs?: number;
  title?: string;
  onClick?: () => void;
  action?: ToastAction;
}

// Singleton state — shared across all callers within the SPA so the
// toast survives view transitions and only one queue exists.
const toasts = ref<ToastMessage[]>([]);
let counter = 0;

function enqueue(opts: ToastOptions): number {
  counter += 1;
  const id = counter;
  // Toasts with an action (typically undo) auto-dismiss slower so the
  // user actually has time to react — matches Material Design's undo
  // snackbar spec of 8 seconds.
  const defaultMs = opts.action ? 8000 : 4500;
  const durationMs = opts.durationMs ?? defaultMs;
  toasts.value = [
    ...toasts.value,
    {
      id,
      message: opts.message,
      tone: opts.tone ?? 'info',
      durationMs,
      title: opts.title,
      onClick: opts.onClick,
      action: opts.action,
    },
  ];
  // Auto-remove after duration. We keep the timer here so the host
  // component doesn't need its own bookkeeping.
  setTimeout(() => {
    toasts.value = toasts.value.filter((t) => t.id !== id);
  }, durationMs);
  return id;
}

function push(message: string, tone: ToastTone, durationMs?: number) {
  return enqueue({ message, tone, durationMs });
}

function dismiss(id: number) {
  toasts.value = toasts.value.filter((t) => t.id !== id);
}

export function useToast() {
  return {
    success: (msg: string, durationMs?: number) => push(msg, 'success', durationMs),
    error: (msg: string, durationMs?: number) => push(msg, 'error', durationMs),
    info: (msg: string, durationMs?: number) => push(msg, 'info', durationMs),
    /**
     * Rich toast with an optional title + click action. Used by the
     * realtime notification listener so an arriving notification is
     * visible and tappable (navigates to its href + marks it read).
     */
    show: (opts: ToastOptions) => enqueue(opts),
    /**
     * Undo-style toast — fires immediately after a destructive action
     * ("Aturan dihapus") and offers a "Batal" button that calls
     * `onUndo`. Auto-dismisses at 8s (matches Material Design's undo
     * snackbar) so the user has real time to react.
     */
    undoable: (
      message: string,
      onUndo: () => void,
      opts: { label?: string; tone?: ToastTone; durationMs?: number } = {},
    ) =>
      enqueue({
        message,
        tone: opts.tone ?? 'info',
        durationMs: opts.durationMs,
        action: { label: opts.label ?? 'Batal', onAction: onUndo },
      }),
    dismiss,
  };
}

/**
 * Internal accessor used by ToastHost to render the active queue.
 * Don't use this from app code — call useToast() instead.
 */
export function useToastQueue() {
  return { toasts, dismiss };
}

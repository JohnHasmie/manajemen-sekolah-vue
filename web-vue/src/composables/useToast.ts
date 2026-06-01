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
}

// Singleton state — shared across all callers within the SPA so the
// toast survives view transitions and only one queue exists.
const toasts = ref<ToastMessage[]>([]);
let counter = 0;

function push(message: string, tone: ToastTone, durationMs = 4500) {
  counter += 1;
  const id = counter;
  toasts.value = [...toasts.value, { id, message, tone, durationMs }];
  // Auto-remove after duration. We keep the timer here so the host
  // component doesn't need its own bookkeeping.
  setTimeout(() => {
    toasts.value = toasts.value.filter((t) => t.id !== id);
  }, durationMs);
  return id;
}

function dismiss(id: number) {
  toasts.value = toasts.value.filter((t) => t.id !== id);
}

export function useToast() {
  return {
    success: (msg: string, durationMs?: number) => push(msg, 'success', durationMs),
    error: (msg: string, durationMs?: number) => push(msg, 'error', durationMs),
    info: (msg: string, durationMs?: number) => push(msg, 'info', durationMs),
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

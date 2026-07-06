/**
 * errorHints.ts — classify a raw error string into a warm cause hint.
 *
 * The whole point of showing a hint below "Terjadi kesalahan" is telling
 * the user WHICH kind of thing went wrong, in words they can act on:
 * "cek internet Anda", "sesi habis, login ulang", etc. The classifier
 * pattern-matches common shapes (axios/native fetch messages, HTTP
 * status codes leaked into text) and returns a stable hint key that
 * ErrorState renders with a matching icon.
 *
 * When nothing matches we return `null` so the caller can render the
 * bare fallback ("Mohon coba lagi dalam beberapa saat.") — better a
 * quiet generic message than a confidently wrong one.
 */

export type ErrorHint =
  | 'network'
  | 'session'
  | 'permission'
  | 'notFound'
  | 'server'
  | 'timeout';

/**
 * Best-effort inference from a stringified error / API message.
 * Runs on the front-end for messages the http layer already surfaced;
 * mutations that need finer control can override by passing an
 * explicit `hint` to ErrorState.
 */
export function classifyError(input?: unknown): ErrorHint | null {
  if (input == null) return null;
  const s = String(input).toLowerCase();
  if (!s) return null;

  // Network — the browser couldn't reach the server at all. Axios
  // surfaces "Network Error", native fetch surfaces "Failed to fetch",
  // and Chrome-Android sometimes says "load failed".
  if (
    s.includes('network error') ||
    s.includes('failed to fetch') ||
    s.includes('load failed') ||
    s.includes('err_internet_disconnected') ||
    s.includes('err_network')
  ) {
    return 'network';
  }

  if (s.includes('timeout') || s.includes('timed out') || s.includes('econnaborted')) {
    return 'timeout';
  }

  // HTTP status leaks. Axios' default is "Request failed with status
  // code NNN" — match that verbatim and the raw " 4xx"/" 5xx" fragments.
  const m = s.match(/status code (\d{3})|\b([45]\d{2})\b/);
  if (m) {
    const code = Number(m[1] ?? m[2]);
    if (code === 401) return 'session';
    if (code === 403) return 'permission';
    if (code === 404) return 'notFound';
    if (code === 408 || code === 504) return 'timeout';
    if (code >= 500) return 'server';
  }

  return null;
}

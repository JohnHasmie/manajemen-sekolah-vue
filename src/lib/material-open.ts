/**
 * Opening and saving a bimbel material, in one place.
 *
 * ── Why this is a lib and not another copy in another view ──
 *
 * `TutorTutoring2MaterialDetailView.vue` worked this out properly: a
 * blocked popup must not be reported as a tab that opened, and a
 * cross-origin `fetch` that the bucket refuses must fall back to opening
 * rather than to nothing. The student LIST view did not get that
 * treatment — it calls `window.open(...)` and discards the result, so a
 * blocked popup there is silent.
 *
 * The wali screen is the one where silence costs the most: a wali who
 * presses Unduh and sees nothing has no tutor sitting next to them to
 * ask. So the logic is named and shared here instead of being typed a
 * third time.
 *
 * NOTE on `file_url`: it is short-lived. For an uploaded file the
 * backend signs the stored path per request with a 30-minute window; for
 * a pasted external link it comes back verbatim. Either way, render it
 * and act on it — never cache it, never store it.
 */

/**
 * Open a URL in a new tab, reporting whether one actually opened.
 *
 * `noopener` is not optional: the href is a foreign origin (the storage
 * bucket, or whatever host a tutor pasted), and without it that page
 * gets a handle on `window.opener`.
 *
 * The RETURN VALUE is the point. A blocked popup yields null, and a
 * caller that ignores it goes on to claim a tab opened — sending the
 * reader hunting for a tab that does not exist. "Nothing happened" is
 * worse news and better information.
 */
export function openMaterialInNewTab(url: string): boolean {
  if (typeof window === 'undefined') return false;
  return window.open(url, '_blank', 'noopener') != null;
}

/**
 * What actually became of a download attempt.
 *
 *  - `saved`   → the bytes were fetched and handed to the browser to save.
 *  - `opened`  → saving was refused, but the file opened in a new tab.
 *  - `blocked` → neither worked; the reader must be told so plainly.
 */
export type MaterialDownloadOutcome = 'saved' | 'opened' | 'blocked';

/**
 * Save the file if the browser will let us, open it if not, and never
 * quietly do nothing.
 *
 * The blob path needs CORS on the storage bucket, which nothing in this
 * stack configures today, and it cannot work at all for a third-party
 * host. So it is written to FAIL LOUDLY and fall back: `fetch` rejects
 * on a cross-origin read it may not make, and we open the URL instead.
 * That fallback is the whole point — in practice it is the path almost
 * every real download takes.
 */
export async function downloadMaterialFile(
  url: string,
  fileName?: string | null,
): Promise<MaterialDownloadOutcome> {
  let objectUrl: string | null = null;
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const blob = await res.blob();
    objectUrl = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = objectUrl;
    if (fileName) a.download = fileName;
    document.body.appendChild(a);
    a.click();
    a.remove();
    return 'saved';
  } catch {
    // Cross-origin refusal, an expired signature, or a host that will
    // not be read programmatically. Opening it still works — usually.
    return openMaterialInNewTab(url) ? 'opened' : 'blocked';
  } finally {
    // Revoked on a timeout rather than immediately: Safari cancels an
    // in-flight save when the object URL dies in the same tick.
    if (objectUrl) {
      const stale = objectUrl;
      setTimeout(() => URL.revokeObjectURL(stale), 10_000);
    }
  }
}

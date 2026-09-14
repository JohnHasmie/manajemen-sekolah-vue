/**
 * The `kind` vocabulary of `/tutoring-v2/materials`, in one place.
 *
 * It lived as a private `const MATERIAL_KINDS` inside the tutor Materi
 * LIST view. The detail screen needs the same list and the same label
 * lookup, and a second copy is how four `groupLabel()` functions in this
 * very feature drifted apart — so it moved here rather than being
 * retyped.
 *
 * The wire values are canonical uppercase. The backend does NOT enforce
 * them: `StoreMaterialRequest`/`UpdateMaterialRequest` validate `kind`
 * as `['string', 'max:16']` with no `in:` rule, so whatever a client
 * sends is what gets stored — see `unknownMaterialKind()` below for what
 * that has already cost us.
 */
import type { MaterialKind } from '@/types/tutoring2/material';

/**
 * Display order for a kind picker, and the exhaustiveness guard.
 *
 * `satisfies Record<MaterialKind, number>` is deliberately stronger than
 * the `MaterialKind[]` annotation the old list carried. An array
 * annotation only rejects a value that is NOT in the union; a kind ADDED
 * to `MaterialKind` and forgotten here still compiled. That is precisely
 * how LINK and IMAGE came to be missing from the Tipe chip. A Record has
 * to name every member, so the omission is now a type error.
 */
const KIND_ORDER = {
  PDF: 0,
  VIDEO: 1,
  DOC: 2,
  IMAGE: 3,
  LINK: 4,
} satisfies Record<MaterialKind, number>;

/** Every kind the API stores and its `kind` filter accepts. */
export const MATERIAL_KINDS: MaterialKind[] = (
  Object.keys(KIND_ORDER) as MaterialKind[]
).sort((a, b) => KIND_ORDER[a] - KIND_ORDER[b]);

/** The canonical kind for a raw wire value, or null if it is not one. */
export function normalizeMaterialKind(value: unknown): MaterialKind | null {
  const raw = String(value ?? '').trim().toUpperCase();
  return (MATERIAL_KINDS as string[]).includes(raw)
    ? (raw as MaterialKind)
    : null;
}

/**
 * A human label for a stored `kind`.
 *
 * Falls back to the RAW value rather than to `t()` for anything outside
 * the vocabulary, and that fallback is load-bearing today: the upload
 * form on this same surface declares its own local union
 * `'PDF' | 'VIDEO' | 'DOC' | 'IMG'` and writes `IMG` where the wire
 * value is `IMAGE`. Rows already carry it. Calling
 * `t('tutoring2.materialKind.IMG')` on one prints the key path on
 * screen; printing `IMG` at least tells the reader what is stored.
 */
export function materialKindLabel(
  value: unknown,
  t: (key: string) => string,
): string {
  const kind = normalizeMaterialKind(value);
  if (kind) return t(`tutoring2.materialKind.${kind}`);
  return String(value ?? '').trim().toUpperCase() || '—';
}

/**
 * Is this material an externally-hosted LINK rather than an uploaded file?
 *
 * `file_url` cannot answer it. `MaterialResource` signs a stored path
 * into an absolute `https://…` and passes an external link through
 * untouched, so BOTH arrive as absolute URLs and there is no prefix to
 * test.
 *
 * Two signals can answer it, and both are needed:
 *
 *  - `kind === 'LINK'`, which is what the API filter and the admin
 *    screens use, and
 *  - the NULL TRIPLE `file_name` / `file_size` / `file_mime`, because
 *    `POST /materials/upload` is the only thing that fills those three.
 *    A row that never went through it carries all three null.
 *
 * The triple is doing the real work. This app's upload form has no LINK
 * chip at all, so every link a tutor pastes is stored under whichever
 * file chip happened to be selected — `PDF` by default. Trusting `kind`
 * alone would present those rows as a downloadable PDF and offer an
 * "Unduh" that can never save anything.
 */
export function materialIsExternalLink(m: {
  kind: string;
  file_name: string | null;
  file_size: number | null;
  file_mime: string | null;
}): boolean {
  if (normalizeMaterialKind(m.kind) === 'LINK') return true;
  return m.file_name === null && m.file_size === null && m.file_mime === null;
}

/**
 * Tutoring2 · teaching materials — the wire shape of
 * `/tutoring-v2/materials`.
 *
 * `file_url` is what a browser should open, and its value is NOT stable:
 * for anything uploaded through the app the backend stores a storage
 * path and signs it per request, because the bucket rejects unsigned
 * reads. Externally-hosted links (a tutor pasting a Drive URL) come back
 * verbatim.
 *
 * The practical rule is the same either way: treat it as a short-lived
 * link. Render it, do not cache it, and never store it — re-read the
 * material to get a fresh one.
 */
export type MaterialKind = 'PDF' | 'VIDEO' | 'LINK' | 'DOC' | 'IMAGE';

export interface Material {
  id: string;
  learning_group_id: string | null;
  learning_group_name?: string | null;
  program_id: string | null;
  program_name?: string | null;
  title: string;
  description: string | null;
  file_url: string | null;
  file_name: string | null;
  file_size: number | null;
  file_mime: string | null;
  kind: MaterialKind | string;
  uploaded_by_user_id: string | null;
  uploaded_by_name?: string | null;
  /** Null while draft — students only see published materials. */
  published_at: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface MaterialListParams {
  learning_group_id?: string;
  program_id?: string;
  kind?: string;
  page?: number;
  per_page?: number;
}

/** What `POST /materials/upload` hands back for the create form to attach. */
export interface MaterialUploadResult {
  /** A storage PATH, not a URL. Send it straight back as `file_url`. */
  file_url: string;
  file_name: string;
  file_size: number;
  file_mime: string;
}

export interface MaterialCreatePayload {
  /** One of these two is required by the API. */
  learning_group_id?: string | null;
  program_id?: string | null;
  title: string;
  description?: string | null;
  /** An uploaded path, or an external absolute URL. */
  file_url: string;
  file_name?: string | null;
  file_size?: number | null;
  file_mime?: string | null;
  kind: string;
}

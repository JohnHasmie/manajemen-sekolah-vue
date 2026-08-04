/**
 * Group announcement DTO for the greenfield bimbel module (BE-22).
 *
 * Wire shape mirrors {@link GroupAnnouncementResource} on the backend:
 * a single `body` HTML string, and NO explicit `status` column — the
 * lifecycle is derived from `published_at` being null (draft) or a
 * timestamp (published). We surface `status` here as a computed enum
 * so the UI can chip / filter without repeating the null-check
 * everywhere.
 *
 * Endpoints under `/api/tutoring-v2/learning-groups/{groupId}/announcements`.
 */

/**
 * Lifecycle enum. `archived` is reserved for a future BE-22.1 that
 * introduces an `archived_at` column — for now the backend only knows
 * draft ↔ published. Keeping the enum shape open-ended so the FE
 * doesn't have to churn when it lands.
 */
export type GroupAnnouncementStatus = 'draft' | 'published' | 'archived';

export interface GroupAnnouncement {
  id: string;
  school_id: string;
  learning_group_id: string;
  author_user_id: string;
  /** Denormalised author name — only present when the BE eager-loads. */
  author_name?: string | null;
  title: string;
  /**
   * Rich-text HTML body (Quill-generated). Renamed to `body` on the
   * wire, mirrored to `body_html` in some upstream chatter — the field
   * on the resource is `body`.
   */
  body: string;
  /** ISO8601 timestamp or null when the row is still a draft. */
  published_at?: string | null;
  /** Convenience mirror of `published_at !== null`, emitted by the BE. */
  is_published?: boolean;
  created_at?: string;
  updated_at?: string;
}

/**
 * Derive the UI-facing status from `published_at`. Keeps every call
 * site consistent — do NOT reimplement the null-check inline.
 */
export function announcementStatus(a: GroupAnnouncement): GroupAnnouncementStatus {
  return a.published_at != null ? 'published' : 'draft';
}

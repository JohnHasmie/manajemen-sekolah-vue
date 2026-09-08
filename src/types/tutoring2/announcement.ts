/**
 * Bimbel announcement DTO for the greenfield module (BE-22, extended by
 * BE !856).
 *
 * Wire shape mirrors {@link GroupAnnouncementResource} on the backend:
 * a single `body` HTML string, and NO explicit `status` column — the
 * lifecycle is derived from `published_at` being null (draft) or a
 * timestamp (published). We surface `status` here as a computed enum
 * so the UI can chip / filter without repeating the null-check
 * everywhere.
 *
 * Two endpoint families carry this DTO:
 *
 *   · nested — `/api/tutoring-v2/learning-groups/{groupId}/announcements`,
 *     which by construction can only ever return group-addressed rows;
 *   · flat   — `/api/tutoring-v2/announcements`, the tenant-wide superset,
 *     which returns BOTH audiences.
 */

/**
 * Lifecycle enum. `archived` is reserved for a future BE-22.1 that
 * introduces an `archived_at` column — for now the backend only knows
 * draft ↔ published. Keeping the enum shape open-ended so the FE
 * doesn't have to churn when it lands.
 */
export type GroupAnnouncementStatus = 'draft' | 'published' | 'archived';

/**
 * WHO the announcement is addressed to. Mirrors the backend
 * `AnnouncementAudience` enum — the wire values stay English.
 *
 * `learning_group` is what every row that predates the column carries;
 * the backfill migration stamped them all. `tutor` is the tenant-wide
 * broadcast an admin composes from the flat endpoint.
 */
export type AnnouncementAudience = 'learning_group' | 'tutor';

export interface GroupAnnouncement {
  id: string;
  school_id: string;
  /**
   * NULLABLE, and the null is load-bearing rather than an accident of
   * typing: an `audience: 'tutor'` row hangs off no group at all, so
   * anything that pushes this into a URL segment or looks a name up by
   * it must handle null FIRST. A nested-endpoint response can never
   * contain a null here; a flat-endpoint response routinely can.
   */
  learning_group_id: string | null;
  /**
   * Optional because a cached/stale response from before BE !856 has
   * neither key. Treat a missing `audience` as `learning_group`, which
   * is what such a row necessarily was — see {@link announcementAudience}.
   */
  audience?: AnnouncementAudience;
  /**
   * Server-rendered Indonesian label for {@link audience} ("Kelompok
   * belajar" / "Semua tutor"). Rendered as-is rather than re-derived
   * client-side, so the two never drift when the backend gains a third
   * audience.
   */
  audience_label?: string | null;
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

/**
 * The row's audience, defaulting to `learning_group`.
 *
 * The default is not a guess. `audience` is absent only from a response
 * that predates BE !856, and every row that existed then was
 * group-addressed — the backfill migration stamped exactly that value.
 * Defaulting the other way would mislabel real group announcements as
 * tenant-wide broadcasts, which is the worse failure of the two.
 */
export function announcementAudience(a: GroupAnnouncement): AnnouncementAudience {
  return a.audience ?? 'learning_group';
}

/** Is this a tenant-wide broadcast (i.e. a row with no learning group)? */
export function isTutorAudience(a: GroupAnnouncement): boolean {
  return announcementAudience(a) === 'tutor';
}

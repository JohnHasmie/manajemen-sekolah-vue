/**
 * Announcement types — covers teacher / admin / parent read views,
 * admin compose form, and parent inbox.
 *
 * Mirrors the Flutter `Announcement` model + the admin compose
 * + filter shapes from `ApiAnnouncementService`.
 */

/**
 * Backend "category" enum — controls the colour badge on the card.
 * Some endpoints use Indonesian aliases (`umum` ↔ `pengumuman`).
 */
export type AnnouncementCategory =
  | 'pengumuman'
  | 'umum'
  | 'penting'
  | 'acara'
  | 'libur';

/** Priority pill — admin/teacher filter chip. */
export type AnnouncementPriority = 'penting' | 'biasa';

/**
 * Lifecycle status — drives the admin lifecycle section header.
 *
 *   draft       — saved but not yet published
 *   terjadwal   — published_at in the future
 *   terkirim    — already published (also serialised as `published`)
 *   kedaluwarsa — expires_at in the past
 *   archived    — soft-deleted / archived bucket
 */
export type AnnouncementStatus =
  | 'draft'
  | 'terjadwal'
  | 'terkirim'
  | 'kedaluwarsa'
  | 'archived';

/** Who the announcement targets. */
export type AnnouncementAudience = 'all' | 'role' | 'class' | 'student';

/**
 * Canonical announcement record returned by `/announcement` for
 * every role. Optional fields gracefully degrade when the backend
 * doesn't include them for a given viewer role.
 */
export interface Announcement {
  id: string;
  title: string;
  body: string;
  category: AnnouncementCategory;
  /** `penting | biasa`. Optional — falls back from category=penting. */
  priority?: AnnouncementPriority;
  status?: AnnouncementStatus;
  audience?: AnnouncementAudience;
  /** Target ids (class_id list when audience='class', etc.). */
  target_ids?: string[];
  /**
   * Friendly source label (e.g. "Sekolah" / "Wali Kelas Bu Sari").
   * Parent view especially relies on this.
   */
  source?: string | null;
  /** Audience label rendered as a pill ("→ Guru", "→ 9A"). */
  audience_label?: string | null;
  is_pinned?: boolean;
  scheduled_at?: string | null;
  published_at?: string | null;
  expires_at?: string | null;
  created_at: string;
  updated_at?: string | null;
  /** Per-viewer read state. Parent view shows the unread dot when false. */
  is_read?: boolean;
  read_at?: string | null;
  /** Admin/teacher metrics — visible on the card footer. */
  read_count?: number;
  total_recipients?: number;
}

/**
 * Legacy alias preserved so existing imports don't break.
 * New code should import `Announcement` instead.
 */
export type AdminAnnouncement = Announcement;

/** Capped `/announcement/filter-options` response. */
export interface AnnouncementFilterOptions {
  priority_options: { value: string; label: string }[];
  target_options: { value: string; label: string }[];
  status_options: { value: string; label: string }[];
}

/** Convert any raw backend row to a normalised Announcement. */
export function announcementFromJson(raw: Record<string, unknown>): Announcement {
  const r = raw ?? {};
  const rawCategory = String(r.category ?? r.kategori ?? 'pengumuman').toLowerCase();
  const category = (
    ['pengumuman', 'umum', 'penting', 'acara', 'libur'].includes(rawCategory)
      ? rawCategory
      : 'pengumuman'
  ) as AnnouncementCategory;

  const rawPriority = String(r.priority ?? r.prioritas ?? '').toLowerCase();
  const priority =
    rawPriority === 'penting' || rawPriority === 'biasa'
      ? (rawPriority as AnnouncementPriority)
      : category === 'penting'
        ? 'penting'
        : 'biasa';

  const rawStatus = String(r.status ?? '').toLowerCase();
  let status: AnnouncementStatus | undefined;
  if (['draft', 'terjadwal', 'terkirim', 'kedaluwarsa', 'archived'].includes(rawStatus)) {
    status = rawStatus as AnnouncementStatus;
  } else if (rawStatus === 'published') {
    status = 'terkirim';
  }

  const rawAudience = String(r.audience ?? r.target ?? '').toLowerCase();
  const audience =
    ['all', 'role', 'class', 'student'].includes(rawAudience)
      ? (rawAudience as AnnouncementAudience)
      : undefined;

  const isRead =
    r.is_read === true ||
    r.is_read === 1 ||
    r.is_read === '1' ||
    r.is_read === 'true' ||
    Boolean(r.read_at);

  return {
    id: String(r.id ?? ''),
    title: String(r.title ?? r.judul ?? ''),
    body: String(r.body ?? r.content ?? r.isi ?? ''),
    category,
    priority,
    status,
    audience,
    target_ids: Array.isArray(r.target_ids)
      ? (r.target_ids as unknown[]).map(String)
      : undefined,
    source: (r.source as string | null | undefined) ?? null,
    audience_label:
      (r.audience_label as string | null | undefined) ?? null,
    is_pinned: Boolean(r.is_pinned ?? r.pinned),
    scheduled_at: (r.scheduled_at as string | null | undefined) ?? null,
    published_at: (r.published_at as string | null | undefined) ?? null,
    expires_at: (r.expires_at as string | null | undefined) ?? null,
    created_at: String(r.created_at ?? r.tanggal ?? ''),
    updated_at: (r.updated_at as string | null | undefined) ?? null,
    is_read: isRead,
    read_at: (r.read_at as string | null | undefined) ?? null,
    read_count:
      typeof r.read_count === 'number'
        ? r.read_count
        : Number(r.read_count) || undefined,
    total_recipients:
      typeof r.total_recipients === 'number'
        ? r.total_recipients
        : Number(r.total_recipients) || undefined,
  };
}

/**
 * Bucket announcements into the four admin lifecycle sections used
 * by `AdminAnnouncementView`. Pure function so it can be tested
 * without Vue context.
 */
export function bucketByLifecycle(items: Announcement[]): {
  pinned: Announcement[];
  scheduled: Announcement[];
  published: Announcement[];
  draft: Announcement[];
} {
  const pinned: Announcement[] = [];
  const scheduled: Announcement[] = [];
  const published: Announcement[] = [];
  const draft: Announcement[] = [];
  const now = Date.now();
  for (const a of items) {
    if (a.is_pinned) {
      pinned.push(a);
      continue;
    }
    if (a.status === 'draft') {
      draft.push(a);
      continue;
    }
    const schedTs = a.scheduled_at ? Date.parse(a.scheduled_at) : NaN;
    if (a.status === 'terjadwal' || (!Number.isNaN(schedTs) && schedTs > now)) {
      scheduled.push(a);
      continue;
    }
    published.push(a);
  }
  return { pinned, scheduled, published, draft };
}

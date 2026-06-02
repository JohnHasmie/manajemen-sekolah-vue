/**
 * Announcement types — covers teacher / admin / parent read views,
 * admin compose form, and parent inbox.
 *
 * Mirrors the Flutter `Announcement` model + the admin compose
 * + filter shapes from `ApiAnnouncementService`.
 *
 * Backend canonical fields (post-rename):
 *  - `type`     ── category enum: info / event / general / announcement
 *  - `status`   ── lifecycle enum: draft / scheduled / published
 *  - `priority` ── low / normal / high / urgent
 *  - `role_target` ── all / parent / teacher / student / admin
 *
 * Vue still exposes `category` as a convenience alias on top of `type`
 * for legacy templates; new code should read/write `type` directly.
 */

/**
 * Backend "type" enum — controls the colour badge on the card.
 * Canonical values are lowercase English. Legacy Indonesian / mixed
 * inputs (`umum`, `pengumuman`, `acara`, `libur`, `penting`) are
 * normalised on read.
 */
export type AnnouncementCategory =
  | 'info'
  | 'event'
  | 'general'
  | 'announcement';

/** Priority pill — admin/teacher filter chip. */
export type AnnouncementPriority = 'low' | 'normal' | 'high' | 'urgent';

/**
 * Lifecycle status — drives the admin lifecycle section header.
 *
 *   draft       — saved but not yet published
 *   scheduled   — published_at in the future
 *   published   — already published
 *   expired     — expires_at in the past
 *   archived    — soft-deleted / archived bucket
 */
export type AnnouncementStatus =
  | 'draft'
  | 'scheduled'
  | 'published'
  | 'expired'
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
  /** Canonical column: `announcements.type`. */
  type: AnnouncementCategory;
  /** Back-compat alias for `type`. New code should read `type`. */
  category: AnnouncementCategory;
  /** low | normal | high | urgent. */
  priority?: AnnouncementPriority;
  status?: AnnouncementStatus;
  audience?: AnnouncementAudience;
  /** Target ids (class_id list when audience='class', etc.). */
  target_ids?: string[];
  /** Canonical column: `announcements.role_target`. */
  role_target?: string;
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

/** Normalise legacy / mixed `type`/`category` values to canonical English. */
export function normalizeAnnouncementType(raw: unknown): AnnouncementCategory {
  const v = String(raw ?? '').toLowerCase().trim();
  if (!v) return 'announcement';
  if (v === 'info') return 'info';
  if (v === 'event' || v === 'acara') return 'event';
  if (v === 'general' || v === 'umum') return 'general';
  if (v === 'announcement' || v === 'pengumuman') return 'announcement';
  // legacy `penting` was a category that doubled as priority; collapse to announcement.
  if (v === 'penting' || v === 'libur') return 'announcement';
  return 'announcement';
}

/** Normalise legacy / mixed `priority` values to canonical English. */
export function normalizeAnnouncementPriority(
  raw: unknown,
): AnnouncementPriority {
  const v = String(raw ?? '').toLowerCase().trim();
  if (!v) return 'normal';
  if (v === 'low' || v === 'biasa') return 'low';
  if (v === 'normal' || v === 'medium' || v === 'sedang') return 'normal';
  if (v === 'high' || v === 'penting' || v === 'important') return 'high';
  if (v === 'urgent' || v === 'mendesak') return 'urgent';
  return 'normal';
}

/** Normalise legacy / mixed `status` values to canonical English. */
export function normalizeAnnouncementStatus(
  raw: unknown,
): AnnouncementStatus | undefined {
  const v = String(raw ?? '').toLowerCase().trim();
  if (!v) return undefined;
  if (v === 'draft') return 'draft';
  if (v === 'scheduled' || v === 'terjadwal') return 'scheduled';
  if (v === 'published' || v === 'terkirim') return 'published';
  if (v === 'expired' || v === 'kedaluwarsa') return 'expired';
  if (v === 'archived') return 'archived';
  return undefined;
}

/** Normalise legacy `role_target` values: `wali` → `parent`, etc. */
export function normalizeRoleTarget(raw: unknown): string | undefined {
  const v = String(raw ?? '').toLowerCase().trim();
  if (!v) return undefined;
  if (v === 'wali') return 'parent';
  if (v === 'guru') return 'teacher';
  if (v === 'siswa') return 'student';
  return v;
}

/** Convert any raw backend row to a normalised Announcement. */
export function announcementFromJson(raw: Record<string, unknown>): Announcement {
  const r = raw ?? {};
  const type = normalizeAnnouncementType(r.type ?? r.category ?? r.kategori);
  const priority = normalizeAnnouncementPriority(r.priority ?? r.prioritas);
  const status = normalizeAnnouncementStatus(r.status);

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
    type,
    category: type,
    priority,
    status,
    audience,
    target_ids: Array.isArray(r.target_ids)
      ? (r.target_ids as unknown[]).map(String)
      : undefined,
    role_target: normalizeRoleTarget(r.role_target),
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
    if (a.status === 'scheduled' || (!Number.isNaN(schedTs) && schedTs > now)) {
      scheduled.push(a);
      continue;
    }
    published.push(a);
  }
  return { pinned, scheduled, published, draft };
}

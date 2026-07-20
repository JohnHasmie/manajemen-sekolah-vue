/**
 * Types for "Data Terhapus" — the school recycle bin. Mirrors the backend
 * TrashController payload (grouped soft-deleted rows + cascade impact).
 */

export type TrashType = 'teacher' | 'student' | 'subject' | 'schedule';

/**
 * A trashed schedule can depend on a subject / teacher / class that was ALSO
 * soft-deleted. Restoring the schedule then needs a per-dependency decision.
 */
export type ScheduleDependencyKind = 'subject' | 'teacher' | 'class';

/** An active (non-trashed) row the admin can repoint a dependency to. */
export interface DependencyCandidate {
  id: string;
  name: string;
}

/**
 * One trashed dependency of a schedule. `active_candidates` are same-kind rows
 * that are still live (repoint targets). `has_conflict` = restoring the trashed
 * row would collide with an active row of the same name.
 */
export interface ScheduleDependency {
  dependency: ScheduleDependencyKind;
  old_id: string;
  old_name: string;
  active_candidates: DependencyCandidate[];
  has_conflict: boolean;
}

/** GET /trash/schedule/{id}/dependencies. Empty `dependencies` → restore directly. */
export interface ScheduleDependenciesResult {
  schedule_id: string;
  bin_label: string;
  has_conflicts: boolean;
  dependencies: ScheduleDependency[];
}

/**
 * Per-dependency resolution sent on restore. Each value is one of
 * `restore` | `repoint:<activeId>` | `skip`. Keyed by dependency kind.
 */
export interface ScheduleResolution {
  subject?: string;
  teacher?: string;
  class?: string;
}

/** One conflict returned by a 409 on POST /trash/schedule/{id}/restore. */
export interface ScheduleConflict {
  dependency: ScheduleDependencyKind;
  old_name: string;
  active_candidates: DependencyCandidate[];
}

/** One schedule the bulk restore couldn't complete, with the reason. */
export interface BulkRestoreSkipped {
  id: string;
  reason: string;
  conflicts?: ScheduleConflict[];
  message?: string;
}

/** POST /trash/schedule/restore-bulk → never aborts the batch. */
export interface BulkRestoreResult {
  restored: number;
  skipped: BulkRestoreSkipped[];
}

/** One soft-deleted row awaiting restore or permanent delete. */
export interface TrashItem {
  id: string;
  type: TrashType;
  name: string;
  /** ISO 8601, when it was soft-deleted. */
  deleted_at: string | null;
  /** ISO 8601, when the auto-purge cron will force-delete it (deleted_at + retention). */
  purge_at: string | null;
}

/** A per-type bucket (Guru / Siswa / Mapel) with its live count. */
export interface TrashGroup {
  type: TrashType;
  label: string;
  /** True when restoring re-occupies a paid seat (guru/siswa). */
  quota: boolean;
  count: number;
  items: TrashItem[];
}

export interface TrashListResult {
  data: TrashGroup[];
  total: number;
  /** Days a row lingers before auto-purge — drives the "otomatis dibersihkan" copy. */
  retention_days: number;
}

/** One related-row line shown before a permanent delete. */
export interface TrashImpactRelation {
  label: string;
  count: number;
}

/** Cascade impact of permanently deleting one row. */
export interface TrashImpact {
  type: TrashType;
  label: string;
  name: string;
  related: TrashImpactRelation[];
}

/**
 * One line in the restore preview: a relation that will be re-linked when the
 * row is restored (e.g. "Jadwal" × 3). Mirrors the impact relations, but points
 * the other way — data that comes BACK rather than data that gets removed.
 */
export interface RestoreRelink {
  label: string;
  count: number;
}

/** An active (live) row that a restored subject could collide with or merge into. */
export interface RestoreConflictCandidate {
  id: string;
  name: string | null;
  grade: number | null;
}

/**
 * Present only when restoring a subject whose name already exists among the
 * active rows. The admin must resolve it (merge into an active row, or restore
 * under a new name).
 */
export interface RestoreConflict {
  name: string;
  grade: number | null;
  active: RestoreConflictCandidate[];
}

/**
 * GET /trash/{type}/{id}/restore-preview. Drives the restore-confirmation
 * dialog: what re-links, whether it re-takes a seat, and (subject only) any
 * name conflict that needs resolving before restore.
 */
export interface RestorePreview {
  type: string;
  name: string;
  relinks: RestoreRelink[];
  quota: {
    occupies_seat: boolean;
    label: string | null;
  };
  conflict: RestoreConflict | null;
}

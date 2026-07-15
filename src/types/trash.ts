/**
 * Types for "Data Terhapus" — the school recycle bin. Mirrors the backend
 * TrashController payload (grouped soft-deleted rows + cascade impact).
 */

export type TrashType = 'teacher' | 'student' | 'subject';

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

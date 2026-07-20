/**
 * TrashService — wraps /trash (TrashController). Backs the admin "Data Terhapus"
 * recycle-bin page: list soft-deleted rows grouped by type, preview the cascade
 * impact of a permanent delete, restore, or force-delete. School context is
 * injected by the http layer (X-Tenant-ID), same as StaffService. These
 * endpoints are not year-scoped, so no academic_year_id handling is needed.
 *
 * Schedules are a special case: a trashed schedule can point at a subject /
 * teacher / class that was ALSO deleted, so restoring one needs a per-dependency
 * resolution (restore | repoint | skip). The dedicated schedule endpoints below
 * drive that flow; the other three types keep using the plain `restore()`.
 */
import { api } from '@/lib/http';
import type {
  BulkRestoreResult,
  ScheduleConflict,
  ScheduleDependenciesResult,
  ScheduleResolution,
  TrashImpact,
  TrashListResult,
  TrashType,
} from '@/types/trash';

/**
 * Thrown when POST /trash/schedule/{id}/restore returns 409 — the chosen
 * resolution would restore a dependency whose name already exists among the
 * active rows. Carries the conflicting dependencies so the caller can re-open
 * the resolution dialog and force a repoint/skip instead.
 */
export class ScheduleConflictError extends Error {
  readonly conflicts: ScheduleConflict[];
  constructor(message: string, conflicts: ScheduleConflict[]) {
    super(message);
    this.name = 'ScheduleConflictError';
    this.conflicts = conflicts;
  }
}

export const TrashService = {
  async list(): Promise<TrashListResult> {
    const res = await api.get('/trash');
    const body = (res.data ?? {}) as Partial<TrashListResult>;
    return {
      data: body.data ?? [],
      total: body.total ?? 0,
      retention_days: body.retention_days ?? 30,
    };
  },

  async impact(type: TrashType, id: string): Promise<TrashImpact> {
    const res = await api.get(`/trash/${type}/${id}/impact`);
    return res.data as TrashImpact;
  },

  async restore(type: TrashType, id: string): Promise<void> {
    await api.post(`/trash/${type}/${id}/restore`);
  },

  async purge(type: TrashType, id: string): Promise<void> {
    await api.delete(`/trash/${type}/${id}`);
  },

  /**
   * Trashed subject/teacher/class a schedule depends on. Empty `dependencies`
   * → the schedule can be restored straight away with no dialog.
   */
  async scheduleDependencies(id: string): Promise<ScheduleDependenciesResult> {
    const res = await api.get(`/trash/schedule/${id}/dependencies`);
    return res.data as ScheduleDependenciesResult;
  },

  /**
   * Restore one schedule with a per-dependency resolution. Re-throws a
   * {@link ScheduleConflictError} on 409 so the caller can surface the conflict
   * and let the admin decide (repoint / skip).
   */
  async restoreSchedule(id: string, resolution: ScheduleResolution): Promise<void> {
    try {
      await api.post(`/trash/schedule/${id}/restore`, { resolution });
    } catch (e) {
      const ax = e as {
        response?: { status?: number; data?: { error?: string; conflicts?: ScheduleConflict[] } };
      };
      const data = ax?.response?.data;
      if (ax?.response?.status === 409 && Array.isArray(data?.conflicts)) {
        throw new ScheduleConflictError(data?.error ?? 'conflict', data!.conflicts!);
      }
      throw e;
    }
  },

  /**
   * Restore many rows of one type in a single call, applying the same
   * resolution to every id. Never aborts the batch — rows it can't restore come
   * back in `skipped[]`. Only `schedule` uses this today.
   */
  async restoreBulk(
    type: TrashType,
    ids: string[],
    resolution: ScheduleResolution,
  ): Promise<BulkRestoreResult> {
    const res = await api.post(`/trash/${type}/restore-bulk`, { ids, resolution });
    const body = (res.data ?? {}) as Partial<BulkRestoreResult>;
    return {
      restored: body.restored ?? 0,
      skipped: body.skipped ?? [],
    };
  },
};

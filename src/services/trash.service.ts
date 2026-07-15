/**
 * TrashService — wraps /trash (TrashController). Backs the admin "Data Terhapus"
 * recycle-bin page: list soft-deleted rows grouped by type, preview the cascade
 * impact of a permanent delete, restore, or force-delete. School context is
 * injected by the http layer (X-Tenant-ID), same as StaffService. These
 * endpoints are not year-scoped, so no academic_year_id handling is needed.
 */
import { api } from '@/lib/http';
import type { TrashImpact, TrashListResult, TrashType } from '@/types/trash';

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
};

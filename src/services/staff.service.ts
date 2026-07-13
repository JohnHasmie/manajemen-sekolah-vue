/**
 * StaffService — wraps /staff (StaffController). Backs the admin "Data Staf"
 * page: list/search + create-from-scratch + edit + delete. School context is
 * injected by the http layer (X-Tenant-ID), same as TeacherService.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  StaffCreatePayload,
  StaffCreateResult,
  StaffMember,
  StaffUpdatePayload,
} from '@/types/staff';

export interface StaffListParams {
  page?: number;
  per_page?: number;
  search?: string;
}

export interface StaffListResult {
  items: StaffMember[];
  pagination?: Pagination;
}

export const StaffService = {
  async list(params: StaffListParams = {}): Promise<StaffListResult> {
    const res = await api.get('/staff', {
      params: {
        page: params.page ?? 1,
        per_page: params.per_page ?? 20,
        ...(params.search ? { search: params.search } : {}),
      },
    });
    const body = (res.data ?? {}) as {
      data?: StaffMember[];
      meta?: {
        current_page?: number;
        last_page?: number;
        per_page?: number;
        total?: number;
      };
    };
    const meta = body.meta ?? {};
    const items = body.data ?? [];
    const pagination: Pagination | undefined =
      meta.current_page != null
        ? {
            total_items: meta.total ?? items.length,
            total_pages: meta.last_page ?? 1,
            current_page: meta.current_page,
            per_page: meta.per_page ?? params.per_page ?? 20,
            has_next_page: meta.current_page < (meta.last_page ?? 1),
          }
        : undefined;
    return { items, pagination };
  },

  async create(payload: StaffCreatePayload): Promise<StaffCreateResult> {
    const res = await api.post('/staff', payload);
    return res.data as StaffCreateResult;
  },

  async update(id: string, payload: StaffUpdatePayload): Promise<StaffMember> {
    const res = await api.put(`/staff/${id}`, payload);
    const body = res.data as { data?: StaffMember } | StaffMember;
    return ((body as { data?: StaffMember }).data ?? body) as StaffMember;
  },

  async remove(id: string): Promise<void> {
    await api.delete(`/staff/${id}`);
  },
};

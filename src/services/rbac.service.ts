/**
 * RbacService — thin wrapper over the RBAC endpoints added in backend
 * MRs !227 (Phase A foundation) and !228 (Phase B member endpoints).
 *
 * Same shape as Flutter's `RbacService` (lib/features/rbac/data/
 * rbac_service.dart): returns typed domain objects, never raw maps.
 *
 * The Laravel envelope `{ success, data }` is unwrapped here so the
 * caller (store / view) sees only the meaningful payload.
 */

import { api } from '@/lib/http';
import type {
  RbacAssignResult,
  RbacMemberPickerPage,
  RbacMemberSummary,
  RbacPermission,
  RbacRole,
  RbacRoleMember,
  RbacRoleType,
} from '@/types/rbac';

type Envelope<T> = { data?: T } & Partial<T>;

function unwrap<T>(payload: Envelope<T> | T | unknown): T {
  if (payload && typeof payload === 'object' && 'data' in (payload as any)) {
    return ((payload as any).data ?? payload) as T;
  }
  return payload as T;
}

export const RbacService = {
  /** GET /api/permissions */
  async fetchCatalog(): Promise<RbacPermission[]> {
    const res = await api.get('/permissions');
    return unwrap<RbacPermission[]>(res.data) ?? [];
  },

  /** GET /api/schools/{schoolId}/roles */
  async listRoles(schoolId: string): Promise<RbacRole[]> {
    const res = await api.get(`/schools/${schoolId}/roles`);
    return unwrap<RbacRole[]>(res.data) ?? [];
  },

  /** GET /api/schools/{schoolId}/roles/{roleId} */
  async showRole(schoolId: string, roleId: number): Promise<RbacRole> {
    const res = await api.get(`/schools/${schoolId}/roles/${roleId}`);
    return unwrap<RbacRole>(res.data);
  },

  /** POST /api/schools/{schoolId}/roles */
  async createRole(
    schoolId: string,
    payload: {
      key: string;
      label: string;
      role_type: RbacRoleType;
      permission_keys: string[];
    },
  ): Promise<RbacRole> {
    const res = await api.post(`/schools/${schoolId}/roles`, payload);
    return unwrap<RbacRole>(res.data);
  },

  /**
   * PUT /api/schools/{schoolId}/roles/{roleId}
   *
   * `label` is intentionally omitted for system roles — the backend
   * ignores it for those but sending it would be a lie about intent.
   */
  async updateRole(
    schoolId: string,
    roleId: number,
    payload: { label?: string; permission_keys: string[] },
  ): Promise<RbacRole> {
    const res = await api.put(
      `/schools/${schoolId}/roles/${roleId}`,
      payload,
    );
    return unwrap<RbacRole>(res.data);
  },

  /** DELETE /api/schools/{schoolId}/roles/{roleId} */
  async deleteRole(schoolId: string, roleId: number): Promise<void> {
    await api.delete(`/schools/${schoolId}/roles/${roleId}`);
  },

  /** GET /api/schools/{schoolId}/roles/{roleId}/members */
  async listMembers(
    schoolId: string,
    roleId: number,
  ): Promise<RbacRoleMember[]> {
    const res = await api.get(
      `/schools/${schoolId}/roles/${roleId}/members`,
    );
    return unwrap<RbacRoleMember[]>(res.data) ?? [];
  },

  /** POST /api/schools/{schoolId}/roles/{roleId}/members */
  async assignMembers(
    schoolId: string,
    roleId: number,
    userIds: string[],
  ): Promise<RbacAssignResult> {
    const res = await api.post(
      `/schools/${schoolId}/roles/${roleId}/members`,
      { user_ids: userIds },
    );
    return res.data as RbacAssignResult;
  },

  /** DELETE /api/schools/{schoolId}/roles/{roleId}/members/{userId} */
  async removeMember(
    schoolId: string,
    roleId: number,
    userId: string,
  ): Promise<void> {
    await api.delete(
      `/schools/${schoolId}/roles/${roleId}/members/${userId}`,
    );
  },

  /**
   * GET /api/schools/{schoolId}/members
   *
   * Backs the "Tambah anggota" picker. The endpoint nests pagination
   * under `meta`; flatten it here so callers get one consistent shape.
   */
  async searchMembers(
    schoolId: string,
    params: {
      search?: string;
      exclude_role_id?: number;
      page?: number;
      per_page?: number;
    } = {},
  ): Promise<RbacMemberPickerPage> {
    const res = await api.get(`/schools/${schoolId}/members`, {
      params: {
        search: params.search ?? '',
        page: params.page ?? 1,
        per_page: params.per_page ?? 20,
        ...(params.exclude_role_id !== undefined
          ? { exclude_role_id: params.exclude_role_id }
          : {}),
      },
    });
    const body = res.data ?? {};
    const meta = body.meta ?? {};
    return {
      data: (body.data ?? []) as RbacMemberSummary[],
      current_page: meta.current_page ?? 1,
      last_page: meta.last_page ?? 1,
      per_page: meta.per_page ?? 20,
      total: meta.total ?? 0,
    };
  },
};

export type RbacServiceType = typeof RbacService;

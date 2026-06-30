/**
 * Vitest spec for RbacService.
 *
 * The web-vue codebase doesn't yet have Vitest wired up — this file
 * follows the standard Vitest API (describe/it/expect/vi) so the team
 * can adopt it by adding:
 *
 *   npm i -D vitest @vue/test-utils jsdom
 *
 * and:
 *
 *   "test": "vitest run"
 *
 * to package.json scripts. Until then, this file is consumed only by
 * vue-tsc (type-check) as a documentation/contract artifact for the
 * RBAC service shape.
 *
 * Tests exercise the unwrap-envelope behaviour and the searchMembers
 * pagination flatten — both are subtle enough that a regression here
 * would silently break the admin UI.
 */
// @ts-nocheck — vitest types not installed yet
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { RbacService } from './rbac.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

describe('RbacService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('unwrap envelope', () => {
    it('extracts data from the standard { success, data } envelope', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: {
          success: true,
          data: [{ id: 1, key: 'finance.bill.view', label: 'View bills', module: 'finance' }],
        },
      });

      const result = await RbacService.fetchCatalog();

      expect(result).toHaveLength(1);
      expect(result[0].key).toBe('finance.bill.view');
    });

    it('passes raw arrays through when no envelope is present', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: [{ id: 1, key: 'a.b.c', label: 'X', module: 'a' }],
      });

      const result = await RbacService.fetchCatalog();
      expect(result).toHaveLength(1);
    });

    it('returns empty array when payload is null', async () => {
      (api.get as any).mockResolvedValueOnce({ data: null });
      const result = await RbacService.fetchCatalog();
      expect(result).toEqual([]);
    });
  });

  describe('searchMembers pagination flatten', () => {
    it('flattens the Laravel meta block into top-level pagination', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: {
          data: [
            { user_id: 'u1', name: 'A', email: 'a@x', roles: [], already_in_excluded_role: false },
          ],
          meta: { current_page: 2, last_page: 5, per_page: 20, total: 84 },
        },
      });

      const result = await RbacService.searchMembers('sch_1', {
        search: 'a',
        exclude_role_id: 7,
        page: 2,
      });

      expect(api.get).toHaveBeenCalledWith('/schools/sch_1/members', {
        params: {
          search: 'a',
          page: 2,
          per_page: 20,
          exclude_role_id: 7,
        },
      });
      expect(result.total).toBe(84);
      expect(result.current_page).toBe(2);
      expect(result.data).toHaveLength(1);
    });

    it('omits exclude_role_id from query when not provided', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: { data: [], meta: { current_page: 1, last_page: 1, per_page: 20, total: 0 } },
      });

      await RbacService.searchMembers('sch_1', {});

      const args = (api.get as any).mock.calls[0];
      expect(args[1].params).not.toHaveProperty('exclude_role_id');
    });

    it('defaults pagination to page 1 / per_page 20', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: { data: [], meta: {} },
      });

      await RbacService.searchMembers('sch_1');

      const args = (api.get as any).mock.calls[0];
      expect(args[1].params.page).toBe(1);
      expect(args[1].params.per_page).toBe(20);
    });
  });

  describe('updateRole', () => {
    it('forwards permission_keys + label to the server', async () => {
      (api.put as any).mockResolvedValueOnce({ data: { id: 4 } });
      await RbacService.updateRole('sch_1', 4, {
        label: 'New Label',
        permission_keys: ['a.b.c', 'd.e.f'],
      });
      expect(api.put).toHaveBeenCalledWith('/schools/sch_1/roles/4', {
        label: 'New Label',
        permission_keys: ['a.b.c', 'd.e.f'],
      });
    });
  });

  describe('assignMembers', () => {
    it('packs user IDs into a user_ids array', async () => {
      (api.post as any).mockResolvedValueOnce({
        data: { assigned: ['u1', 'u2'], already_member: [], not_in_school: [] },
      });
      const result = await RbacService.assignMembers('sch_1', 4, ['u1', 'u2']);
      expect(api.post).toHaveBeenCalledWith(
        '/schools/sch_1/roles/4/members',
        { user_ids: ['u1', 'u2'] },
      );
      expect(result.assigned).toEqual(['u1', 'u2']);
    });
  });
});

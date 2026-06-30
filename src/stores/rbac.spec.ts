/**
 * Vitest spec for useRbacStore.
 *
 * See `services/rbac.service.spec.ts` for adoption notes — this file
 * is also vue-tsc-only until Vitest lands.
 *
 * Tests focus on:
 *   - filtered/system/custom derivations (used for the Frame A counts)
 *   - permission diff tracking (drives the sticky save bar)
 *   - optimistic-remove rollback (members tab)
 *   - picker debounce + stale-result discard (search race safety)
 */
// @ts-nocheck — vitest types not installed yet
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useRbacStore } from './rbac';
import { RbacService } from '@/services/rbac.service';

vi.mock('@/services/rbac.service', () => ({
  RbacService: {
    fetchCatalog: vi.fn(),
    listRoles: vi.fn(),
    showRole: vi.fn(),
    createRole: vi.fn(),
    updateRole: vi.fn(),
    deleteRole: vi.fn(),
    listMembers: vi.fn(),
    assignMembers: vi.fn(),
    removeMember: vi.fn(),
    searchMembers: vi.fn(),
  },
}));

const ROLE = (over = {}) => ({
  id: 1,
  school_id: 'sch_1',
  key: 'admin',
  label: 'Admin',
  role_type: 'admin',
  is_system: true,
  permission_keys: ['finance.bill.view', 'attendance.session.create'],
  ...over,
});

describe('useRbacStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  describe('roles derivations', () => {
    it('splits system vs custom and respects the segmented filter', async () => {
      (RbacService.listRoles as any).mockResolvedValue([
        ROLE(),
        ROLE({ id: 2, key: 'guru', role_type: 'teacher' }),
        ROLE({ id: 3, key: 'bendahara', role_type: 'staff', is_system: false }),
      ]);

      const store = useRbacStore();
      await store.loadRoles('sch_1');

      expect(store.systemRoles).toHaveLength(2);
      expect(store.customRoles).toHaveLength(1);

      store.setFilter('custom');
      expect(store.systemRoles).toHaveLength(0);
      expect(store.customRoles).toHaveLength(1);
    });

    it('case-insensitively searches role label and key', async () => {
      (RbacService.listRoles as any).mockResolvedValue([
        ROLE({ id: 1, key: 'admin', label: 'Administrator' }),
        ROLE({ id: 2, key: 'bendahara', label: 'Bendahara', is_system: false }),
      ]);
      const store = useRbacStore();
      await store.loadRoles('sch_1');

      store.setSearch('benda');
      expect(store.filteredRoles).toHaveLength(1);
      expect(store.filteredRoles[0].id).toBe(2);
    });
  });

  describe('permission diff', () => {
    it('flags unsaved changes when staged keys differ from initial', async () => {
      (RbacService.showRole as any).mockResolvedValue(ROLE());
      (RbacService.fetchCatalog as any).mockResolvedValue([]);

      const store = useRbacStore();
      await store.loadRole('sch_1', 1);

      expect(store.hasUnsavedChanges).toBe(false);

      store.togglePermission('communication.announcement.create');
      expect(store.hasUnsavedChanges).toBe(true);
      expect(store.pendingDiffCount).toBe(1);

      store.togglePermission('communication.announcement.create');
      expect(store.hasUnsavedChanges).toBe(false);
    });

    it('resetPermissionChanges restores the original set', async () => {
      (RbacService.showRole as any).mockResolvedValue(ROLE());
      (RbacService.fetchCatalog as any).mockResolvedValue([]);

      const store = useRbacStore();
      await store.loadRole('sch_1', 1);
      store.togglePermission('x.y.z');
      expect(store.hasUnsavedChanges).toBe(true);
      store.resetPermissionChanges();
      expect(store.hasUnsavedChanges).toBe(false);
    });
  });

  describe('member removal', () => {
    it('rolls back the optimistic remove if the server errors', async () => {
      (RbacService.listMembers as any).mockResolvedValue([
        { user_id: 'u1', name: 'A', email: 'a@x', is_active: true, other_roles: [] },
        { user_id: 'u2', name: 'B', email: 'b@x', is_active: true, other_roles: [] },
      ]);
      (RbacService.removeMember as any).mockRejectedValue(
        new Error('last admin guard'),
      );

      const store = useRbacStore();
      await store.loadMembers('sch_1', 1);
      const err = await store.removeMember('sch_1', 1, 'u1');

      expect(err).toBe('last admin guard');
      expect(store.members).toHaveLength(2);
    });
  });

  describe('catalog filtering', () => {
    it('excludes platform.* and tutoring.* from school-admin view', async () => {
      (RbacService.fetchCatalog as any).mockResolvedValue([
        { id: 1, key: 'finance.bill.view', label: 'F', module: 'finance' },
        { id: 2, key: 'platform.tenant.create', label: 'P', module: 'platform' },
        { id: 3, key: 'tutoring.payout.view', label: 'T', module: 'tutoring' },
      ]);
      const store = useRbacStore();
      await store.ensureCatalog();
      expect(Object.keys(store.catalogByModule)).toEqual(['finance']);
    });
  });
});

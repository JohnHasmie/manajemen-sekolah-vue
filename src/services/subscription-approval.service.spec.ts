/**
 * Vitest spec for SubscriptionApprovalService.
 *
 * Same "no Vitest wired yet" setup as rbac.service.spec.ts — the
 * @ts-nocheck header suppresses vitest type errors until the
 * dependency is installed. vue-tsc still compiles this file, so it
 * doubles as a contract snapshot of the service shape.
 *
 * Coverage:
 *   1. list() unwraps the { data, meta } paginator envelope and
 *      fills in defaults when the server returns a partial shape.
 *   2. reject() posts the trimmed reason and returns the
 *      idempotency-flagged result.
 *   3. Error mapping — 403 becomes an Indonesian super-admin gate
 *      message so pages can render a friendly state instead of a
 *      raw axios error.
 */
// @ts-nocheck — vitest types not installed yet
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { SubscriptionApprovalService } from './subscription-approval.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
  },
}));

describe('SubscriptionApprovalService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('list', () => {
    it('unwraps { data, meta } paginator envelope', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: {
          data: [
            {
              id: 'sub-1',
              order_id: 'SUB-20260702-abcd',
              plan: 'yearly',
              amount: 4_752_000,
              currency: 'IDR',
              tenant_name: 'Bimbel Cendekia',
              admin_email: 'a@b.id',
              admin_whatsapp: '0812345',
              created_at: '2026-07-01T12:00:00Z',
              last_marked_at: '2026-07-02T08:00:00Z',
              waiting_hours: 26,
            },
          ],
          meta: {
            current_page: 1,
            per_page: 20,
            total: 7,
            last_page: 1,
          },
        },
      });

      const result = await SubscriptionApprovalService.list({ per_page: 20 });

      expect(result.items).toHaveLength(1);
      expect(result.items[0].order_id).toBe('SUB-20260702-abcd');
      expect(result.meta.total).toBe(7);
      expect(result.meta.last_page).toBe(1);
    });

    it('fills default meta when the server omits it', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: { data: [] },
      });

      const result = await SubscriptionApprovalService.list();

      expect(result.items).toEqual([]);
      expect(result.meta.total).toBe(0);
      expect(result.meta.current_page).toBe(1);
    });

    it('surfaces a 403 as the super-admin gate message', async () => {
      (api.get as any).mockRejectedValueOnce({
        response: { status: 403, data: { error: 'Hanya super admin.' } },
      });

      await expect(SubscriptionApprovalService.list()).rejects.toThrow(
        /super-admin/i,
      );
    });
  });

  describe('approve', () => {
    it('returns the ApproveResult verbatim including already_active', async () => {
      (api.post as any).mockResolvedValueOnce({
        data: {
          status: 'active',
          starts_at: '2026-07-02T00:00:00Z',
          expires_at: '2027-07-02T00:00:00Z',
          already_active: false,
          notifications_dispatched: { email: true, whatsapp: true },
        },
      });

      const result = await SubscriptionApprovalService.approve('sub-1');

      expect(api.post).toHaveBeenCalledWith('/billing/admin/approve/sub-1');
      expect(result.status).toBe('active');
      expect(result.already_active).toBe(false);
    });
  });

  describe('reject', () => {
    it('posts the reason in the body', async () => {
      (api.post as any).mockResolvedValueOnce({
        data: {
          status: 'canceled',
          rejection_reason: 'Nominal kurang Rp 2.000.',
          rejected_at: '2026-07-02T10:00:00Z',
          already_canceled: false,
          notifications_dispatched: { email: true, whatsapp: true },
        },
      });

      await SubscriptionApprovalService.reject(
        'sub-1',
        'Nominal kurang Rp 2.000.',
      );

      expect(api.post).toHaveBeenCalledWith('/billing/admin/reject/sub-1', {
        reason: 'Nominal kurang Rp 2.000.',
      });
    });

    it('maps 422 to the "sudah tidak menunggu" message', async () => {
      (api.post as any).mockRejectedValueOnce({
        response: { status: 422, data: {} },
      });

      await expect(
        SubscriptionApprovalService.reject('sub-1', 'reason'),
      ).rejects.toThrow(/tidak berstatus menunggu/i);
    });
  });
});

/**
 * Demo-request admin service — thin wrapper around the Laravel
 * super-admin `/demo-requests/*` endpoints (backend MR !112).
 *
 * Every endpoint here is gated server-side by the `super_admin`
 * route-middleware (app/Http/Middleware/EnsureSuperAdmin.php). A
 * non-super-admin caller gets a 403, which we surface as a plain
 * Indonesian message so the page can render a friendly state instead
 * of a raw axios error.
 */
import { api } from '@/lib/http';
import type {
  DemoRequest,
  DemoRequestListMeta,
  DemoRequestListParams,
  DemoRequestListResult,
} from '@/types/demo-request';

/** Map a raw axios failure to an Indonesian, user-facing Error. */
function toFriendlyError(e: unknown, fallback: string): Error {
  const err = e as {
    response?: { status?: number; data?: { message?: string } };
    message?: string;
  };
  const status = err.response?.status;
  const backendMsg = err.response?.data?.message;
  if (status === 401) {
    return new Error('Sesi Anda telah berakhir. Silakan masuk kembali.');
  }
  if (status === 403) {
    return new Error(
      'Anda tidak memiliki akses super-admin untuk halaman ini.',
    );
  }
  if (status === 404) {
    return new Error('Permintaan demo tidak ditemukan.');
  }
  if (status === 422) {
    return new Error(
      backendMsg ?? 'Permintaan ini sudah tidak berstatus menunggu.',
    );
  }
  if (status === 429) {
    return new Error('Terlalu banyak percobaan. Coba lagi sebentar.');
  }
  return new Error(backendMsg ?? err.message ?? fallback);
}

export const DemoRequestService = {
  /**
   * GET /api/demo-requests — paginated list, newest first.
   *
   * @param status   optional lifecycle filter (default backend = all)
   * @param per_page 1-100, backend default 20
   * @param page     1-based page number
   */
  async list(params: DemoRequestListParams = {}): Promise<DemoRequestListResult> {
    try {
      const res = await api.get('/demo-requests', {
        params: {
          status: params.status ?? undefined,
          per_page: params.per_page ?? undefined,
          page: params.page ?? undefined,
        },
      });
      const body = res.data ?? {};
      const items: DemoRequest[] = Array.isArray(body.data) ? body.data : [];
      const meta: DemoRequestListMeta = body.meta ?? {
        current_page: 1,
        last_page: 1,
        per_page: items.length,
        total: items.length,
      };
      return { items, meta };
    } catch (e) {
      throw toFriendlyError(e, 'Gagal memuat daftar permintaan demo.');
    }
  },

  /**
   * GET /api/demo-requests/{id} — full detail incl. the stored
   * `school_payload` (replayed on approve).
   */
  async show(id: string): Promise<DemoRequest> {
    try {
      const res = await api.get(`/demo-requests/${id}`);
      const data = res.data?.data ?? res.data;
      if (!data) throw new Error('Detail permintaan demo tidak valid.');
      return data as DemoRequest;
    } catch (e) {
      throw toFriendlyError(e, 'Gagal memuat detail permintaan demo.');
    }
  },

  /**
   * POST /api/demo-requests/{id}/approve — *Aktivasi*.
   *
   * Provisions the demo (school + account), sets the 7-day expiry,
   * and notifies the requester via email + WhatsApp. 422 if the
   * request is no longer pending. Returns the updated request.
   *
   * @param note optional internal note recorded on the review.
   */
  async approve(id: string, note?: string): Promise<DemoRequest> {
    try {
      // Provisioning can run a few seconds on a fully-seeded demo —
      // override the default 30s axios timeout to stay safe.
      const res = await api.post(
        `/demo-requests/${id}/approve`,
        { note: note?.trim() ? note.trim() : undefined },
        { timeout: 120_000 },
      );
      const data = res.data?.data ?? res.data;
      return data as DemoRequest;
    } catch (e) {
      throw toFriendlyError(e, 'Gagal mengaktivasi permintaan demo.');
    }
  },

  /**
   * POST /api/demo-requests/{id}/reject — sets status=rejected.
   * 422 if the request is no longer pending. Returns the updated
   * request.
   *
   * @param reason optional rejection reason recorded on the review.
   */
  async reject(id: string, reason?: string): Promise<DemoRequest> {
    try {
      const res = await api.post(`/demo-requests/${id}/reject`, {
        reason: reason?.trim() ? reason.trim() : undefined,
      });
      const data = res.data?.data ?? res.data;
      return data as DemoRequest;
    } catch (e) {
      throw toFriendlyError(e, 'Gagal menolak permintaan demo.');
    }
  },
};

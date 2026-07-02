/**
 * SuperAdminTenantService — GET /super-admin/tenants
 *
 * Powers the /super-admin/schools page's Aktif / Demo / Semua tabs.
 * Gated server-side by the `super_admin` middleware; failure modes
 * (401/403/404/429) are translated into friendly Indonesian strings
 * so the page renders a legible error state instead of a raw axios
 * exception.
 */
import { api } from '@/lib/http';
import type {
  PlatformTenant,
  PlatformTenantListParams,
  PlatformTenantListResult,
  PlatformTenantMeta,
} from '@/types/super-admin-tenant';

function toFriendlyError(e: unknown, fallback: string): Error {
  const err = e as {
    response?: { status?: number; data?: { error?: string; message?: string } };
    message?: string;
  };
  const status = err.response?.status;
  const backendMsg = err.response?.data?.error ?? err.response?.data?.message;
  if (status === 401) {
    return new Error('Sesi Anda telah berakhir. Silakan masuk kembali.');
  }
  if (status === 403) {
    return new Error('Halaman ini hanya untuk super-admin KamilEdu.');
  }
  if (status === 429) {
    return new Error('Terlalu banyak percobaan. Coba lagi sebentar.');
  }
  return new Error(backendMsg ?? err.message ?? fallback);
}

export const SuperAdminTenantService = {
  async list(
    params: PlatformTenantListParams = {},
  ): Promise<PlatformTenantListResult> {
    try {
      const res = await api.get('/super-admin/tenants', {
        params: {
          scope: params.scope ?? undefined,
          search: params.search?.trim() ? params.search.trim() : undefined,
          per_page: params.per_page ?? undefined,
          page: params.page ?? undefined,
        },
      });
      const body = res.data ?? {};
      const items: PlatformTenant[] = Array.isArray(body.data) ? body.data : [];
      const meta: PlatformTenantMeta = body.meta ?? {
        current_page: 1,
        last_page: 1,
        per_page: items.length,
        total: items.length,
      };
      return { items, meta };
    } catch (e) {
      throw toFriendlyError(e, 'Gagal memuat daftar tenant platform.');
    }
  },
};

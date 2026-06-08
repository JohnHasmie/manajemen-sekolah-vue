/**
 * Demo-account admin service — thin wrapper around the Laravel
 * super-admin demo-account + incomplete-registration endpoints.
 *
 * Every endpoint here is gated server-side by the `super_admin`
 * route-middleware (app/Http/Middleware/EnsureSuperAdmin.php). The
 * DELETE endpoint ADDITIONALLY re-asserts schools.is_demo=true inside
 * DeleteDemoSchoolAccountsAction — a real (non-demo) school can never
 * be wiped from here, and the backend answers a non-demo target with a
 * 422 that we surface as a friendly Indonesian message.
 */
import { api } from '@/lib/http';
import type {
  DemoAccountCounts,
  DemoAccountDeleteMode,
  DemoAccountDeleteResult,
  IncompleteRegistration,
  IncompleteRegistrationListMeta,
  IncompleteRegistrationListParams,
  IncompleteRegistrationListResult,
} from '@/types/demo-account';

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
    return new Error('Data tidak ditemukan.');
  }
  if (status === 422) {
    // The demo-only guard rejection lands here — keep the backend's
    // exact message (e.g. "hanya diizinkan untuk sekolah demo").
    return new Error(backendMsg ?? 'Permintaan tidak dapat diproses.');
  }
  if (status === 429) {
    return new Error('Terlalu banyak percobaan. Coba lagi sebentar.');
  }
  return new Error(backendMsg ?? err.message ?? fallback);
}

export const DemoAccountService = {
  /**
   * GET /api/demo-schools/{schoolId}/accounts — account counts grouped
   * by role for a demo school, so the UI can show "how many will be
   * deleted" before the user confirms.
   */
  async counts(schoolId: string): Promise<DemoAccountCounts> {
    try {
      const res = await api.get(`/demo-schools/${schoolId}/accounts`);
      const data = res.data?.data ?? res.data;
      if (!data) throw new Error('Ringkasan akun demo tidak valid.');
      return data as DemoAccountCounts;
    } catch (e) {
      throw toFriendlyError(e, 'Gagal memuat ringkasan akun demo.');
    }
  },

  /**
   * DELETE /api/demo-schools/{schoolId}/accounts — delete demo-school
   * accounts by scope. IRREVERSIBLE.
   *
   * @param mode all | guru | admin | wali
   */
  async deleteAccounts(
    schoolId: string,
    mode: DemoAccountDeleteMode,
  ): Promise<DemoAccountDeleteResult> {
    try {
      const res = await api.delete(`/demo-schools/${schoolId}/accounts`, {
        params: { mode },
      });
      const data = res.data?.data ?? res.data;
      return data as DemoAccountDeleteResult;
    } catch (e) {
      throw toFriendlyError(e, 'Gagal menghapus akun demo.');
    }
  },

  /**
   * GET /api/demo-incomplete-registrations — abandoned demo wizards
   * (started but never finished/submitted), newest active first.
   */
  async listIncomplete(
    params: IncompleteRegistrationListParams = {},
  ): Promise<IncompleteRegistrationListResult> {
    try {
      const res = await api.get('/demo-incomplete-registrations', {
        params: {
          per_page: params.per_page ?? undefined,
          page: params.page ?? undefined,
        },
      });
      const body = res.data ?? {};
      const items: IncompleteRegistration[] = Array.isArray(body.data)
        ? body.data
        : [];
      const meta: IncompleteRegistrationListMeta = body.meta ?? {
        current_page: 1,
        last_page: 1,
        per_page: items.length,
        total: items.length,
      };
      return { items, meta };
    } catch (e) {
      throw toFriendlyError(e, 'Gagal memuat daftar registrasi belum selesai.');
    }
  },
};

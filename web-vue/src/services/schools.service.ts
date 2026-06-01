/**
 * SchoolService — read the active school's settings.
 *
 * Mirrors Flutter's `settings_service.dart > getSchoolSettings()`. The
 * backend resolves "active school" from the `X-School-ID` header (set
 * by our axios interceptor), so we don't pass the id explicitly.
 *
 * Used by the auth store as a fallback when the login response /
 * `/auth/schools` doesn't include the school's display name — so the
 * topbar SchoolPill and Profile page can always show a real label.
 */
import { api } from '@/lib/http';
import type { School } from '@/types/auth';

export const SchoolService = {
  /** GET /school/settings — { school_name, address, jenjang, … }. */
  async getActiveSchool(): Promise<School | null> {
    try {
      const res = await api.get('/school/settings');
      const body = res.data?.data ?? res.data ?? null;
      if (!body || typeof body !== 'object') return null;
      const id =
        body.id ??
        body.school_id ??
        body.uuid ??
        body.data?.id ??
        null;
      const name =
        body.school_name ??
        body.name ??
        body.nama_sekolah ??
        body.nama ??
        null;
      if (!id && !name) return null;
      return {
        id: String(id ?? ''),
        name: String(name ?? 'Sekolah Aktif'),
        address: body.address ?? body.alamat ?? undefined,
        city: body.city ?? body.kota ?? undefined,
        academic_year: body.academic_year ?? body.tahun_ajaran ?? undefined,
        level: body.jenjang ?? body.level ?? undefined,
        logo_url: body.logo_url ?? body.logo ?? undefined,
      };
    } catch {
      return null;
    }
  },
};

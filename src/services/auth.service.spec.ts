/**
 * Vitest spec for AuthService.listSchools() normalization.
 *
 * Locks the contract that `tenant_type` survives normalization of the
 * GET /user/schools rows.
 *
 * Why this is worth a test: `useTenant` resolves the active tenant kind
 * by checking `tenant_type` on the persisted user, then on the rows of
 * this list — and when every authoritative source comes up empty it
 * falls back to sniffing the school NAME for "bimbel" / "tutoring".
 * normalizeSchool() used to rebuild each row field-by-field and simply
 * omitted `tenant_type`, which made that lossy name heuristic the only
 * remaining signal. A bimbel whose name doesn't happen to contain the
 * word — the live tenants "Konimex" and "Cahaya", 2026-08-04 — resolved
 * to SCHOOL and rendered the school sidebar (Siswa / Kelas / Mata
 * Pelajaran) instead of the bimbel one, while the mobile app (which
 * reads the field directly) showed the correct menu.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { AuthService } from './auth.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    delete: vi.fn(),
  },
}));

describe('AuthService.listSchools() normalization', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('carries tenant_type through for a bimbel whose name lacks "bimbel"', async () => {
    // Shape mirrors the real GET /user/schools row: the name arrives as
    // `school_name`, and tenant_type is a sibling field.
    (api.get as any).mockResolvedValueOnce({
      data: [
        {
          id: '019fcc09-1d1d-71e6-a1e5-c73f0542f8b1',
          school_id: '019fcc09-1d1d-71e6-a1e5-c73f0542f8b1',
          school_name: 'Konimex',
          tenant_type: 'TUTORING_CENTER',
        },
      ],
    });

    const schools = await AuthService.listSchools();

    expect(schools).toHaveLength(1);
    expect(schools[0].tenant_type).toBe('TUTORING_CENTER');
    // The rest of the normalization still holds.
    expect(schools[0].name).toBe('Konimex');
    expect(schools[0].id).toBe('019fcc09-1d1d-71e6-a1e5-c73f0542f8b1');
  });

  it('leaves tenant_type undefined when the backend omits it', async () => {
    // Older payloads have no tenant_type; useTenant treats that as
    // SCHOOL. Assert we pass through the absence rather than inventing
    // a value.
    (api.get as any).mockResolvedValueOnce({
      data: [{ id: 's1', school_name: 'SMP Negeri 1' }],
    });

    const schools = await AuthService.listSchools();

    expect(schools[0].tenant_type).toBeUndefined();
    expect(schools[0].name).toBe('SMP Negeri 1');
  });
});

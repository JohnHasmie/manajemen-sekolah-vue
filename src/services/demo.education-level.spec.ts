/**
 * The demo wizard reached 100% and then died on
 * "The selected school.education level is invalid." (Slack 2026-09-07).
 *
 * Cause: the wizard's jenjang chips send MI / MTs / MA / TK / PAUD, but
 * the backend folded those into the English tiers and its `Rule::in`
 * only accepts KINDERGARTEN / ELEMENTARY / JUNIOR_HIGH / SENIOR_HIGH /
 * VOCATIONAL_HIGH / Pesantren / PKBM. Five of the ten chips were an
 * unconditional 422 — the submit could not succeed no matter what else
 * the user typed.
 *
 * These lock BOTH halves: that the fold happens on the way out, and
 * that a 422 no longer shows the raw Laravel string.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { DemoService } from './demo.service';
import { toEducationLevelPayload } from '@/lib/labels';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: { get: vi.fn(), post: vi.fn(), put: vi.fn(), delete: vi.fn() },
}));

/** Exactly `EducationLevel::payloadValues()` on the backend. */
const SERVER_ACCEPTS = [
  'KINDERGARTEN',
  'ELEMENTARY',
  'JUNIOR_HIGH',
  'SENIOR_HIGH',
  'VOCATIONAL_HIGH',
  'Pesantren',
  'PKBM',
];

/** Every chip the wizard actually offers (questions.ts). */
const WIZARD_CHIPS = [
  'ELEMENTARY',
  'MI',
  'JUNIOR_HIGH',
  'MTs',
  'SENIOR_HIGH',
  'MA',
  'VOCATIONAL_HIGH',
  'TK',
  'PAUD',
  'Pesantren',
];

const payloadWith = (level: string) => ({
  tenant_kind: 'school',
  school: { name: 'SD Contoh', education_level: level, city: 'Bandung', npsn: '' },
  identity: { full_name: 'A', email: 'a@b.c', phone: '08' },
});

describe('education_level wire fold', () => {
  beforeEach(() => vi.clearAllMocks());

  it('every chip the wizard offers folds to a value the server accepts', () => {
    for (const chip of WIZARD_CHIPS) {
      const folded = toEducationLevelPayload(chip);
      expect(SERVER_ACCEPTS, `chip "${chip}" folded to ${folded}`).toContain(folded);
    }
  });

  it('the five that used to 422 map to their folded tier', () => {
    expect(toEducationLevelPayload('MI')).toBe('ELEMENTARY');
    expect(toEducationLevelPayload('MTs')).toBe('JUNIOR_HIGH');
    expect(toEducationLevelPayload('MA')).toBe('SENIOR_HIGH');
    expect(toEducationLevelPayload('TK')).toBe('KINDERGARTEN');
    expect(toEducationLevelPayload('PAUD')).toBe('KINDERGARTEN');
  });

  it('the ones that already worked are left alone', () => {
    expect(toEducationLevelPayload('ELEMENTARY')).toBe('ELEMENTARY');
    expect(toEducationLevelPayload('JUNIOR_HIGH')).toBe('JUNIOR_HIGH');
    expect(toEducationLevelPayload('SENIOR_HIGH')).toBe('SENIOR_HIGH');
    expect(toEducationLevelPayload('VOCATIONAL_HIGH')).toBe('VOCATIONAL_HIGH');
    expect(toEducationLevelPayload('Pesantren')).toBe('Pesantren');
  });

  it('an unrecognised level is NOT rewritten to something the user did not pick', () => {
    expect(toEducationLevelPayload('Akademi Luar Angkasa')).toBeNull();
    expect(toEducationLevelPayload('')).toBeNull();
    expect(toEducationLevelPayload(null)).toBeNull();
  });

  it('provision() actually sends the folded value, not the chip value', async () => {
    (api.post as any).mockResolvedValue({
      data: { data: { demo_request_id: 'r1', status: 'pending', submitted_at: 'x' } },
    });
    await DemoService.provision(payloadWith('TK'));
    const [, sent] = (api.post as any).mock.calls[0];
    expect(sent.school.education_level).toBe('KINDERGARTEN');
  });

  it('provision() leaves an already-canonical value untouched', async () => {
    (api.post as any).mockResolvedValue({
      data: { data: { demo_request_id: 'r1', status: 'pending', submitted_at: 'x' } },
    });
    await DemoService.provision(payloadWith('SENIOR_HIGH'));
    const [, sent] = (api.post as any).mock.calls[0];
    expect(sent.school.education_level).toBe('SENIOR_HIGH');
  });
});

describe('422 no longer leaks the raw Laravel string', () => {
  beforeEach(() => vi.clearAllMocks());

  const reject422 = (errors: unknown, message: string) => {
    (api.post as any).mockRejectedValue({
      response: { status: 422, data: { message, errors } },
    });
  };

  it('names the field in Indonesian instead of echoing the dotted path', async () => {
    // The exact payload from the report.
    reject422(
      { 'school.education_level': ['The selected school.education level is invalid.'] },
      'The selected school.education level is invalid.',
    );
    await expect(DemoService.provision(payloadWith('TK'))).rejects.toThrow(
      /Jenjang sekolah tidak diterima server/,
    );
  });

  it('never shows an internal field path for an unknown field either', async () => {
    reject422({ 'school.some_new_column': ['nope'] }, 'The selected school.some new column is invalid.');
    await expect(DemoService.provision(payloadWith('SENIOR_HIGH'))).rejects.toThrow(
      'Data belum lengkap. Cek kembali setiap langkah.',
    );
  });

  it('falls back cleanly when the server sends no errors map', async () => {
    reject422(undefined, 'The selected school.education level is invalid.');
    await expect(DemoService.provision(payloadWith('SENIOR_HIGH'))).rejects.toThrow(
      'Data belum lengkap. Cek kembali setiap langkah.',
    );
  });
});

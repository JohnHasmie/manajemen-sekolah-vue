import { describe, expect, it } from 'vitest';

import { SEKOLAH_ONLY_MODULE_KEYS, isModuleHiddenFor } from './moduleTokens';

/**
 * `SEKOLAH_ONLY_MODULE_KEYS` is a client-side mirror of the server's
 * `ModuleCatalog::SCOPE_SCHOOL` set. A mirror that drifts is worse than
 * no mirror: on 2026-08-13 it claimed six modules were sekolah-only that
 * the backend happily sells to bimbel, so the picker hid SIX of the nine
 * modules a bimbel tenant can buy. Luay noticed the missing one by name
 * — "kenapa di rakit paket tidak ada absensi tutor" (`attendance_staff`).
 *
 * These pin the list against what production actually returns for
 * `?tenant_type=bimbel`, so the next drift fails here instead of in a
 * customer's signup screen.
 */

/** Verified against prod `GET /billing/public/modules/catalog?tenant_type=bimbel`. */
const BIMBEL_SELLABLE = [
  'attendance_gate',
  'attendance_staff',
  'finance',
  'communication',
  'tutoring',
  'ai_recommendation',
  'ai_material_quiz',
  'ai_rpp',
  'teacher_gamification',
] as const;

/** Verified against prod `?tenant_type=sekolah` — present there, absent for bimbel. */
const SEKOLAH_ONLY_IN_PROD = [
  'attendance_class',
  'grades',
  'report_cards',
  'class_activity',
  'schedule',
  'lms',
] as const;

describe('SEKOLAH_ONLY_MODULE_KEYS', () => {
  it('never lists a module the backend sells to bimbel', () => {
    const wrong = BIMBEL_SELLABLE.filter((k) => SEKOLAH_ONLY_MODULE_KEYS.includes(k));

    expect(wrong).toEqual([]);
  });

  it('covers every module the backend withholds from bimbel', () => {
    const missing = SEKOLAH_ONLY_IN_PROD.filter((k) => !SEKOLAH_ONLY_MODULE_KEYS.includes(k));

    expect(missing).toEqual([]);
  });
});

describe('isModuleHiddenFor', () => {
  it.each(BIMBEL_SELLABLE)('shows %s to a bimbel tenant', (key) => {
    expect(isModuleHiddenFor(key, undefined, 'bimbel')).toBe(false);
  });

  it.each(SEKOLAH_ONLY_IN_PROD)('hides %s from a bimbel tenant', (key) => {
    expect(isModuleHiddenFor(key, undefined, 'bimbel')).toBe(true);
  });

  it('keeps bimbel-native groups away from a sekolah tenant', () => {
    // Group-based rule, not key-based: this is the fail-closed half and
    // it stays, because an unscoped catalog can still reach the
    // authenticated Kelola Modul list.
    expect(isModuleHiddenFor('tutoring', 'Operasional Bimbel', 'sekolah')).toBe(true);
    expect(isModuleHiddenFor('tutoring', 'Operasional Bimbel', 'bimbel')).toBe(false);
    expect(isModuleHiddenFor('tutoring', 'Operasional Bimbel', null)).toBe(true);
  });
});

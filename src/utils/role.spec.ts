/**
 * Vitest spec for [canonicalRole] — the anchor for the web role-key migration
 * (guru→teacher, wali→parent, siswa→student). Every legacy/wire spelling must
 * fold to the same canonical English key so call sites can compare against
 * ROLE_TEACHER etc. regardless of the current internal spelling.
 *
 * Type-checks under vue-tsc (the active gate) and runs under Vitest.
 */
import { describe, expect, it } from 'vitest';
import {
  canonicalRole,
  ROLE_ADMIN,
  ROLE_PARENT,
  ROLE_STAFF,
  ROLE_STUDENT,
  ROLE_TEACHER,
} from './role';

describe('canonicalRole', () => {
  it('folds admin aliases', () => {
    for (const r of ['admin', 'Administrator', ' ADMIN ']) {
      expect(canonicalRole(r)).toBe(ROLE_ADMIN);
    }
  });

  it('folds teacher aliases', () => {
    for (const r of ['guru', 'teacher', 'Guru', 'TEACHER']) {
      expect(canonicalRole(r)).toBe(ROLE_TEACHER);
    }
  });

  it('folds parent aliases', () => {
    for (const r of [
      'wali',
      'wali_murid',
      'walimurid',
      'orang_tua',
      'parent',
      'guardian',
    ]) {
      expect(canonicalRole(r)).toBe(ROLE_PARENT);
    }
  });

  it('folds student aliases', () => {
    for (const r of ['siswa', 'student', 'Siswa']) {
      expect(canonicalRole(r)).toBe(ROLE_STUDENT);
    }
  });

  it('folds staff', () => {
    expect(canonicalRole('staff')).toBe(ROLE_STAFF);
  });

  it('returns lowercased/trimmed for unknown + nullish, never throws', () => {
    expect(canonicalRole('wali_kelas')).toBe('wali_kelas');
    expect(canonicalRole('  SuperAdmin ')).toBe('superadmin');
    expect(canonicalRole(null)).toBe('');
    expect(canonicalRole(undefined)).toBe('');
  });

  it('constants are the English wire values', () => {
    expect(ROLE_ADMIN).toBe('admin');
    expect(ROLE_TEACHER).toBe('teacher');
    expect(ROLE_PARENT).toBe('parent');
    expect(ROLE_STUDENT).toBe('student');
    expect(ROLE_STAFF).toBe('staff');
  });
});

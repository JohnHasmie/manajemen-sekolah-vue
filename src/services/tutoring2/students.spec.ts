/**
 * Vitest spec for TutoringStudentsService — pins the endpoint DTOs
 * and CRUD method shape so the sheet component (WEB-11) and any
 * future WEB-12+ consumer can trust the contract.
 *
 * Same convention as the other web-vue specs: Vitest API,
 * type-checked by `vue-tsc --build`. Vitest itself isn't wired yet —
 * vue-tsc is the active gate.
 */
import { describe, expect, it } from 'vitest';
import { TutoringStudentsService } from './students';
import type {
  BimbelStudent,
  BimbelStudentCreatePayload,
  BimbelStudentUpdatePayload,
  BimbelStudentCreateResponse,
} from '@/types/tutoring2/student';

describe('TutoringStudentsService contract', () => {
  it('exposes all 5 CRUD methods (BE-18 endpoint spine)', () => {
    expect(typeof TutoringStudentsService.list).toBe('function');
    expect(typeof TutoringStudentsService.get).toBe('function');
    expect(typeof TutoringStudentsService.create).toBe('function');
    expect(typeof TutoringStudentsService.update).toBe('function');
    expect(typeof TutoringStudentsService.deactivate).toBe('function');
  });

  it('list() returns items + pagination envelope', async () => {
    // Compile-time proof that the return type includes `items`
    // (array of BimbelStudent) and an optional `pagination` — if the
    // service ever drops the envelope, this stops type-checking.
    type ListReturn = Awaited<ReturnType<typeof TutoringStudentsService.list>>;
    const _sample: ListReturn = { items: [], pagination: undefined };
    expect(_sample.items).toEqual([]);
  });

  it('create payload requires name/gender/guardian, allows optional wali fields', () => {
    // Minimum viable payload — anything smaller breaks the BE 422.
    const _payload: BimbelStudentCreatePayload = {
      name: 'Nadia Putri',
      gender: 'female',
      guardian_name: 'Ibu Sari',
      guardian_email: 'sari@example.com',
    };
    expect(_payload.name).toBe('Nadia Putri');

    // Full payload — verifies every optional key is on the type.
    const _full: BimbelStudentCreatePayload = {
      name: 'Bagas',
      student_number: 'B-001',
      nisn: '0031234567',
      gender: 'male',
      place_of_birth: 'Solo',
      date_of_birth: '2010-04-12',
      address: 'Jl. Slamet Riyadi',
      phone_number: '08123456789',
      guardian_name: 'Pak Aris',
      guardian_email: 'aris@example.com',
      guardian_phone: '08111222333',
      student_status: 'aktif',
    };
    expect(_full.gender).toBe('male');
  });

  it('update payload is a partial (no field required)', () => {
    // The BE uses `sometimes` — an empty PUT is legal.
    const _empty: BimbelStudentUpdatePayload = {};
    expect(_empty).toBeTruthy();

    // Common single-field write — e.g. resetting the wali phone.
    const _one: BimbelStudentUpdatePayload = { guardian_phone: null };
    expect(_one.guardian_phone).toBeNull();
  });

  it('create response carries data + guardian_temp_password', () => {
    // Compile-time proof of the envelope shape — the sheet reads
    // `guardian_temp_password` to one-time-show the temp password.
    const _res: BimbelStudentCreateResponse = {
      data: {
        id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
        school_id: '019f8090-51c4-703d-ad74-6b95f8421445',
        name: 'Nadia Putri',
      } as BimbelStudent,
      guardian_temp_password: 'K@mil-abc123',
    };
    expect(_res.guardian_temp_password).toBe('K@mil-abc123');

    // Null branch — wali already existed OR Opsi B activation is on.
    const _reused: BimbelStudentCreateResponse = {
      data: { id: 'x', school_id: 'y', name: 'Z' } as BimbelStudent,
      guardian_temp_password: null,
    };
    expect(_reused.guardian_temp_password).toBeNull();
  });

  it('BimbelStudent surfaces the two subselect counts as numbers', () => {
    // The BE resource returns these as ints (cast) — the FE list card
    // renders them as chips, so a string would break the toLocaleString
    // call. Compile-time guard against regression.
    const _row: BimbelStudent = {
      id: 'a',
      school_id: 'b',
      name: 'Nadia',
      active_enrollment_count: 3,
      active_bill_count: 1,
    };
    expect(_row.active_enrollment_count).toBe(3);
  });
});

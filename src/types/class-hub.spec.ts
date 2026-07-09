/**
 * Vitest spec for the Kelas hub parsers — pins the JSON contract of
 * GET /classes/mine and GET /classes/{id}/feed.
 *
 * Like the other web-vue specs, this follows the Vitest API; the suite is
 * runnable once Vitest is wired (`npm i -D vitest` + a `test` script). It also
 * type-checks under `vue-tsc`, which is the active gate today.
 */
import { describe, expect, it } from 'vitest';
import {
  classCardFromJson,
  classFeedItemFromJson,
  isWaliKelas,
} from './class-hub';

describe('classCardFromJson', () => {
  it('parses a wali-kelas card with counts', () => {
    const c = classCardFromJson({
      id: 'abc',
      name: 'Kelas 7A',
      grade_level: 7,
      student_count: 24,
      is_homeroom: true,
      is_teaching: true,
      role_in_class: 'wali_kelas',
      homeroom_teacher: { id: 't1', name: 'Bu Sari' },
      active_tugas: 3,
      needs_grading: 5,
    });
    expect(c.id).toBe('abc');
    expect(c.studentCount).toBe(24);
    expect(c.isHomeroom).toBe(true);
    expect(c.roleInClass).toBe('wali_kelas');
    expect(isWaliKelas(c)).toBe(true);
    expect(c.homeroomTeacherName).toBe('Bu Sari');
    expect(c.activeTugas).toBe(3);
  });

  it('guru mapel is not wali kelas; tolerates string/missing numbers', () => {
    const c = classCardFromJson({
      id: 1,
      name: '8B',
      is_teaching: true,
      role_in_class: 'guru_mapel',
      student_count: '30',
      grade_level: null,
    });
    expect(c.id).toBe('1');
    expect(isWaliKelas(c)).toBe(false);
    expect(c.studentCount).toBe(30);
    expect(c.gradeLevel).toBeNull();
    expect(c.needsGrading).toBe(0);
  });
});

describe('classFeedItemFromJson', () => {
  it('parses each known type and falls back to unknown', () => {
    const cases: Record<string, string> = {
      tugas: 'tugas',
      ujian: 'ujian',
      materi: 'materi',
      pengumuman: 'pengumuman',
      nilai: 'nilai',
      'something-else': 'unknown',
    };
    for (const [raw, expected] of Object.entries(cases)) {
      const item = classFeedItemFromJson({ type: raw, id: 'i', title: 'T' });
      expect(item.type).toBe(expected);
    }
  });

  it('parses occurred_at, subtitle, meta, is_read; null-safe', () => {
    const item = classFeedItemFromJson({
      type: 'tugas',
      id: 'a1',
      title: 'Latihan Bab 3',
      subtitle: 'Matematika',
      occurred_at: '2026-07-08T10:15:00+07:00',
      meta: { due_date: '2026-07-10T23:59:00+07:00' },
      is_read: true,
    });
    expect(item.title).toBe('Latihan Bab 3');
    expect(item.subtitle).toBe('Matematika');
    expect(item.occurredAt).toBe('2026-07-08T10:15:00+07:00');
    expect(item.meta.due_date).toBeTruthy();
    expect(item.isRead).toBe(true);

    const bare = classFeedItemFromJson({ type: 'pengumuman', id: 'a2', title: 'Kabar' });
    expect(bare.occurredAt).toBeNull();
    expect(bare.isRead).toBe(false);
    expect(bare.subtitle).toBeNull();
  });
});

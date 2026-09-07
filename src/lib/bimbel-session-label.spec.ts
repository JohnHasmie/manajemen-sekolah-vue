/**
 * Contract spec for `bimbelGroupLabel`.
 *
 * The whole point of the helper is the FALLBACK LADDER, so each rung is
 * pinned separately. The rungs are not interchangeable:
 *
 *   - a blank/whitespace name must NOT win, or the row renders empty;
 *   - a missing name must fall to the id, not to a blank or an invented
 *     placeholder — `whenLoaded` omits the key when the relation was not
 *     eager-loaded, so "no name" means "not sent", not "unnamed";
 *   - a missing id on top of that must give the em-dash, not the
 *     dangling `"Kelompok "` the naive `prefix + slice` produced.
 */
import { describe, expect, it } from 'vitest';
import {
  bimbelGroupLabel,
  bimbelProgramLabel,
  bimbelStudentLabel,
  bimbelTutorLabel,
} from './bimbel-session-label';

describe('bimbelGroupLabel', () => {
  it('shows the name when the row carries one', () => {
    expect(
      bimbelGroupLabel(
        { learning_group_id: '01a00e34-dead-beef', learning_group_name: 'UTBK Pagi A' },
        'Kelompok',
      ),
    ).toBe('UTBK Pagi A');
  });

  it('never prefixes a real name', () => {
    const out = bimbelGroupLabel(
      { learning_group_id: 'gr-1', learning_group_name: 'UTBK Pagi A' },
      'Kelompok',
    );
    expect(out).not.toContain('Kelompok');
  });

  it('falls back to a short id when the name was not sent', () => {
    expect(
      bimbelGroupLabel({ learning_group_id: '01a00e34-dead-beef' }, 'Kelompok'),
    ).toBe('Kelompok 01a00e34');
  });

  it('falls back to a short id when the name is null', () => {
    expect(
      bimbelGroupLabel(
        { learning_group_id: '01a00e34-dead-beef', learning_group_name: null },
        'Kelompok',
      ),
    ).toBe('Kelompok 01a00e34');
  });

  it('treats a blank name as no name rather than rendering nothing', () => {
    expect(
      bimbelGroupLabel(
        { learning_group_id: '01a00e34-dead-beef', learning_group_name: '   ' },
        'Kelompok',
      ),
    ).toBe('Kelompok 01a00e34');
  });

  it('gives an em-dash when neither name nor id is available', () => {
    expect(bimbelGroupLabel({ learning_group_id: '', learning_group_name: null }, 'Kelompok')).toBe('—');
    expect(bimbelGroupLabel({}, 'Kelompok')).toBe('—');
    expect(bimbelGroupLabel(null, 'Kelompok')).toBe('—');
  });

  it('never emits a dangling prefix or an empty string', () => {
    for (const row of [{}, { learning_group_id: null }, { learning_group_name: '' }]) {
      const out = bimbelGroupLabel(row, 'Kelompok');
      expect(out).not.toBe('');
      expect(out).not.toBe('Kelompok ');
      expect(out.trim()).toBe(out);
    }
  });

  it('omits the prefix entirely when none was passed', () => {
    expect(bimbelGroupLabel({ learning_group_id: '01a00e34-dead' })).toBe('01a00e34');
  });
});

/**
 * The three entity adapters added by the !1244 follow-up sweep. They
 * exist so seven more screens could stop rendering uuids WITHOUT four
 * more local copies of the ladder appearing — so what these specs
 * really pin is that all four adapters behave identically. Each rung is
 * asserted per entity rather than "spot-checked on one of them",
 * because a per-entity copy silently drifting is the exact failure
 * !1244 was cleaning up.
 */
describe('bimbelStudentLabel', () => {
  it('shows the name when the row carries one', () => {
    expect(
      bimbelStudentLabel(
        { student_id: '01a00e34-dead-beef', student_name: 'Aisyah Nur' },
        'ID siswa',
      ),
    ).toBe('Aisyah Nur');
  });

  it('does not let a whitespace-only name win over the id', () => {
    expect(
      bimbelStudentLabel({ student_id: '01a00e34-dead', student_name: '   ' }, 'ID siswa'),
    ).toBe('ID siswa 01a00e34');
  });

  it('falls back to a TRUNCATED id, never the full uuid', () => {
    const out = bimbelStudentLabel({ student_id: '01a00e34-dead-beef-cafe' }, 'ID siswa');
    expect(out).toBe('ID siswa 01a00e34');
    expect(out).not.toContain('dead-beef');
  });

  it('uses enrollment_id as the last identifier when there is no student_id', () => {
    // Submission rows are keyed by enrollment; `student_id` is optional
    // on the wire. Without this rung such a row would collapse to an
    // em-dash even though the tutor can still act on it.
    expect(bimbelStudentLabel({ enrollment_id: '77771111-dead' })).toBe('77771111');
    // A blank student_id must not shadow it either.
    expect(bimbelStudentLabel({ student_id: '  ', enrollment_id: '77771111-dead' })).toBe(
      '77771111',
    );
  });

  it('gives an em-dash when nothing identifies the student', () => {
    expect(bimbelStudentLabel({}, 'ID siswa')).toBe('—');
    expect(bimbelStudentLabel(null, 'ID siswa')).toBe('—');
    expect(bimbelStudentLabel({ student_id: '', student_name: null }, 'ID siswa')).toBe('—');
  });
});

describe('bimbelProgramLabel', () => {
  it('shows the name when the row carries one', () => {
    expect(
      bimbelProgramLabel({ program_id: '9f0a1122-dead', program_name: 'Intensif UTBK' }, 'Program'),
    ).toBe('Intensif UTBK');
  });

  it('falls back to a truncated id, then an em-dash', () => {
    expect(bimbelProgramLabel({ program_id: '9f0a1122-dead-beef' }, 'Program')).toBe(
      'Program 9f0a1122',
    );
    expect(bimbelProgramLabel({ program_name: '  ' }, 'Program')).toBe('—');
  });
});

describe('bimbelTutorLabel', () => {
  it('shows the name when the row carries one', () => {
    expect(
      bimbelTutorLabel({ tutor_id: 'ab120000-dead', tutor_name: 'Pak Rudi' }, 'Tutor'),
    ).toBe('Pak Rudi');
  });

  it('falls back to a truncated id, then an em-dash', () => {
    // The bug this replaced rendered `session.tutor_id ?? '—'` — a FULL
    // 36-character uuid, not even truncated.
    const out = bimbelTutorLabel({ tutor_id: 'ab120000-dead-beef-cafe' }, 'Tutor');
    expect(out).toBe('Tutor ab120000');
    expect(out).not.toContain('dead-beef');
    expect(bimbelTutorLabel({ tutor_id: null, tutor_name: null }, 'Tutor')).toBe('—');
  });
});

/**
 * The reason the ladder was centralised. If someone later "optimises"
 * one adapter — drops the trim, or forgets the em-dash — this fails
 * even though that adapter's own describe block might still pass.
 */
describe('all four adapters share one ladder', () => {
  const cases: Array<[string, (name: unknown, id: unknown) => string]> = [
    ['group', (n, i) => bimbelGroupLabel({ learning_group_name: n as string, learning_group_id: i as string }, 'P')],
    ['student', (n, i) => bimbelStudentLabel({ student_name: n as string, student_id: i as string }, 'P')],
    ['program', (n, i) => bimbelProgramLabel({ program_name: n as string, program_id: i as string }, 'P')],
    ['tutor', (n, i) => bimbelTutorLabel({ tutor_name: n as string, tutor_id: i as string }, 'P')],
  ];

  it.each(cases)('%s: name wins, blank name does not, id truncates, nothing gives em-dash', (_n, label) => {
    expect(label('Nama Asli', 'aaaabbbb-cccc')).toBe('Nama Asli');
    expect(label('   ', 'aaaabbbb-cccc')).toBe('P aaaabbbb');
    expect(label(null, 'aaaabbbb-cccc')).toBe('P aaaabbbb');
    expect(label(null, null)).toBe('—');
  });
});

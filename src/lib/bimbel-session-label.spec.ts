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
import { bimbelGroupLabel } from './bimbel-session-label';

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

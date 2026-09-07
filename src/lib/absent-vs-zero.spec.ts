/**
 * Unit spec for the absent-vs-zero helper.
 *
 * The whole helper exists to keep TWO facts apart that `?? 0` merged:
 * "the server sent no number" and "the number is zero". Both directions
 * are pinned here, because fixing the first by breaking the second
 * (rendering a real 0 as "—") would be the same class of lie.
 */
import { describe, expect, it } from 'vitest';
import { countOrDash, EM_DASH, isCounted } from './absent-vs-zero';

describe('isCounted', () => {
  it('is false for an omitted key (what Laravel `when()` produces)', () => {
    const row: { seated_count?: number } = {};
    expect(isCounted(row.seated_count)).toBe(false);
  });

  it('is false for an explicit null', () => {
    expect(isCounted(null)).toBe(false);
  });

  it('is TRUE for a real zero', () => {
    expect(isCounted(0)).toBe(true);
  });

  it('is true for a positive count', () => {
    expect(isCounted(8)).toBe(true);
  });
});

describe('countOrDash', () => {
  it('renders an em-dash when the field was never sent', () => {
    expect(countOrDash(undefined)).toBe(EM_DASH);
    expect(countOrDash(null)).toBe(EM_DASH);
  });

  it('renders a genuine zero as "0", NOT as an em-dash', () => {
    // The invariant. An empty group with capacity 10 must read "0 / 10".
    expect(countOrDash(0)).toBe('0');
    expect(countOrDash(0)).not.toBe(EM_DASH);
  });

  it('renders a positive count verbatim', () => {
    expect(countOrDash(8)).toBe('8');
  });
});

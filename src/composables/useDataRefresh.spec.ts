/**
 * Pins `useDataRefresh`'s EMPTY DETECTION, because every view that binds
 * `:state="state"` straight into `<AsyncView>` silently depends on it.
 *
 * The rule is narrow and easy to trip over: only `null`, `undefined`, or
 * an empty ARRAY count as empty. A loader that returns an object — say
 * `{ rows: [], summary }` because it also has to carry aggregate counts —
 * resolves to `status: 'content'` no matter how little is in it, and the
 * view renders its content branch over nothing instead of the "belum ada
 * data" empty state.
 *
 * That is not hypothetical: both parent bimbel views hit it. The
 * Activities view acquired the bug the moment its payload grew from an
 * array into an object, and the Progress view had shipped with it. The
 * fix in both is to return `null` when there is genuinely nothing, which
 * only works while the behaviour below holds — hence this spec.
 */
import { describe, expect, it, vi } from 'vitest';
import { useDataRefresh } from './useDataRefresh';

/** Run the loader without a component instance (no onMounted, no watchers). */
async function loadOnce<T>(value: T, isEmpty?: (d: T) => boolean) {
  const { state, reload } = useDataRefresh<T>(async () => value, {
    immediate: false,
    watchAcademicYear: false,
    watchLocale: false,
    isEmpty,
  });
  await reload();
  return state.value.status;
}

describe('useDataRefresh empty detection', () => {
  it('treats null and undefined as empty', async () => {
    expect(await loadOnce(null)).toBe('empty');
    expect(await loadOnce(undefined)).toBe('empty');
  });

  it('treats an empty array as empty, a populated one as content', async () => {
    expect(await loadOnce([])).toBe('empty');
    expect(await loadOnce([{ id: 'a' }])).toBe('content');
  });

  it('does NOT look inside an object — this is the trap', async () => {
    // The shape both parent bimbel views return. Zero rows, yet 'content'.
    // A loader carrying aggregates alongside its rows MUST return null
    // when the rows are empty; it cannot rely on the composable noticing.
    expect(await loadOnce({ rows: [], summary: { total: 0 } })).toBe('content');
    expect(await loadOnce({ points: [] })).toBe('content');
  });

  it('reports a thrown loader as error, not as empty', async () => {
    const { state, reload } = useDataRefresh(
      async () => {
        throw new Error('boom');
      },
      { immediate: false, watchAcademicYear: false, watchLocale: false },
    );
    await reload();
    expect(state.value.status).toBe('error');
  });

  describe('the isEmpty escape hatch', () => {
    it('lets an object-shaped payload declare itself empty', () => {
      // The whole point: a loader that carries aggregates alongside its
      // rows can now say what empty means, instead of having to discard
      // the aggregates by returning null.
      return expect(
        loadOnce({ rows: [], summary: { total: 0 } }, (d) => d.rows.length === 0),
      ).resolves.toBe('empty');
    });

    it('still reports content when the predicate says so', async () => {
      expect(
        await loadOnce({ rows: [{ id: 'a' }], summary: { total: 1 } }, (d) => d.rows.length === 0),
      ).toBe('content');
    });

    it('never hands the predicate a null payload', async () => {
      // A custom predicate describes an empty PAYLOAD; it should not have
      // to defend against not being given one at all.
      const predicate = vi.fn(() => false);
      expect(await loadOnce(null, predicate)).toBe('empty');
      expect(predicate).not.toHaveBeenCalled();
    });
  });
});

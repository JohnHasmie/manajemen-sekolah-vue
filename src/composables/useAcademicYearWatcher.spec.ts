/**
 * `selectedYearId` is a computed off `selectedYear`, so it starts as
 * NULL — not undefined. On a hard refresh the store hydrates AFTER the
 * page mounts, and the old `prev === undefined` guard never caught that
 * null → id transition: every one of the ~55 pages using this composable
 * ran its loader twice and visibly flashed content → blank → content.
 *
 * Skipping it is only safe when the refetch would be identical work,
 * which is why `isCurrent` gates the skip.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { effectScope, nextTick, ref } from 'vue';

const selectedYearId = ref<string | null>(null);
const isCurrent = ref(true);

vi.mock('@/stores/academic-year', () => ({
  useAcademicYearStore: () => ({
    get selectedYearId() {
      return selectedYearId.value;
    },
    get isCurrent() {
      return isCurrent.value;
    },
  }),
}));

import { useAcademicYearWatcher } from './useAcademicYearWatcher';

/**
 * Run the composable inside an effect scope rather than a mounted
 * component — the watcher is all we are exercising, and this keeps the
 * spec free of a @vue/test-utils dependency the project does not carry.
 */
function mountWithWatcher(loader: () => void) {
  const scope = effectScope();
  scope.run(() => useAcademicYearWatcher(loader));
  return scope;
}

describe('useAcademicYearWatcher', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    selectedYearId.value = null;
    isCurrent.value = true;
  });

  it('does not fire when the store hydrates to the CURRENT year', async () => {
    // The double-load bug. The page's own onMounted already fetched with
    // no year param, which the backend resolves to the current year, so
    // this refetch would be byte-identical work plus a blank flash.
    const loader = vi.fn();
    mountWithWatcher(loader);

    selectedYearId.value = 'year-current';
    await nextTick();

    expect(loader).not.toHaveBeenCalled();
  });

  it('DOES fire when the store hydrates to a non-current (persisted) year', async () => {
    // Here skipping would be wrong: the first load fetched the current
    // year while the user had previously picked an older one.
    const loader = vi.fn();
    isCurrent.value = false;
    mountWithWatcher(loader);

    selectedYearId.value = 'year-2024';
    await nextTick();

    expect(loader).toHaveBeenCalledTimes(1);
  });

  it('fires when the user switches between two real years', async () => {
    const loader = vi.fn();
    selectedYearId.value = 'year-a';
    mountWithWatcher(loader);

    selectedYearId.value = 'year-b';
    await nextTick();

    expect(loader).toHaveBeenCalledTimes(1);
  });

  it('ignores a no-op re-set of the same id', async () => {
    const loader = vi.fn();
    selectedYearId.value = 'year-a';
    mountWithWatcher(loader);

    selectedYearId.value = 'year-a';
    await nextTick();

    expect(loader).not.toHaveBeenCalled();
  });
});

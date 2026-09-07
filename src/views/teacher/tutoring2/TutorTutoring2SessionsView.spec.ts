/**
 * Contract spec for the tutor's session list — the screen a bimbel tutor
 * reported as "keluar id kelompok" (the group's UUID where its name
 * belongs).
 *
 * Three things are pinned, and each one fails against the old template:
 *
 *   1. the row shows `learning_group_name`, which was already on the very
 *      row being rendered — the old expression was
 *      `{{ t(...) }} {{ s.learning_group_id.slice(0, 8) }}` with no `??`
 *      in it, so the UUID won even when the name was right there;
 *   2. the id fragment survives as the FALLBACK, because a missing name
 *      means "the server did not send it", not "this group is unnamed" —
 *      blanking the row would be a worse answer than a short id;
 *   3. searching by the group NAME finds the row. The haystack was built
 *      from `learning_group_id`, so a tutor typing the name they can see
 *      in the very same row matched nothing. This one is not cosmetic.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SessionsView from './TutorTutoring2SessionsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listSessions: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

function makeSession(overrides: Record<string, unknown> = {}) {
  return {
    id: 'ses-1',
    learning_group_id: '01a00e34-dead-beef',
    learning_group_name: 'UTBK Pagi A',
    starts_at: '2026-08-17T08:00:00+07:00',
    ends_at: '2026-08-17T10:00:00+07:00',
    room: 'R1',
    status: 'scheduled',
    status_label: 'Terjadwal',
    ...overrides,
  };
}

/**
 * The search box is stubbed rather than driven through the real
 * <PageFilterToolbar>, so the assertion is about the HAYSTACK and not
 * about the toolbar's markup.
 */
const SearchStub = {
  props: ['search', 'searchPlaceholder'],
  emits: ['update:search'],
  template:
    '<div><input data-testid="search" :value="search" ' +
    '@input="$emit(\'update:search\', $event.target.value)" /><slot name="chips" /></div>',
};

async function mountView(items: unknown[]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({
    items,
  } as never);

  const w = mount(SessionsView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: { tutoring2: { common: { group: 'Kelompok' } } } },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        AppFilterChip: true,
        PageFilterToolbar: SearchStub,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async">' +
            "<slot v-if=\"state?.status === 'content' || state?.status === 'empty'\" />" +
            '</div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Text of the rendered session rows only — day headers excluded. */
function rowText(w: Awaited<ReturnType<typeof mountView>>) {
  return w.findAll('[data-testid="async"] li').map((li) => li.text());
}

describe('TutorTutoring2SessionsView — group label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders the group NAME the row already carries', async () => {
    const w = await mountView([makeSession()]);

    expect(rowText(w)[0]).toContain('UTBK Pagi A');
    // The id must not leak into the row now that a name is available,
    // and neither must the "Kelompok" prefix that only introduces one.
    expect(rowText(w)[0]).not.toContain('01a00e34');
    expect(rowText(w)[0]).not.toContain('Kelompok');
  });

  it('falls back to a short id when the name was not sent', async () => {
    const w = await mountView([makeSession({ learning_group_name: null })]);

    expect(rowText(w)[0]).toContain('Kelompok 01a00e34');
  });
});

describe('TutorTutoring2SessionsView — search', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
  });
  afterEach(() => vi.useRealTimers());

  async function search(w: Awaited<ReturnType<typeof mountView>>, q: string) {
    await w.get('[data-testid="search"]').setValue(q);
    vi.advanceTimersByTime(400); // clear the 300 ms debounce
    await flushPromises();
  }

  it('finds a row by its group NAME, not only by its id', async () => {
    const w = await mountView([
      makeSession(),
      makeSession({
        id: 'ses-2',
        learning_group_id: '99bbccdd-0000-1111',
        learning_group_name: 'SMP Sore B',
        room: 'R2',
      }),
    ]);
    expect(rowText(w)).toHaveLength(2);

    await search(w, 'utbk');

    const rows = rowText(w);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toContain('UTBK Pagi A');
  });

  it('still finds a row by a pasted id fragment', async () => {
    const w = await mountView([
      makeSession(),
      makeSession({
        id: 'ses-2',
        learning_group_id: '99bbccdd-0000-1111',
        learning_group_name: 'SMP Sore B',
      }),
    ]);

    await search(w, '99bbccdd');

    const rows = rowText(w);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toContain('SMP Sore B');
  });
});

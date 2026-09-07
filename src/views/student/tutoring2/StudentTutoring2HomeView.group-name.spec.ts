/**
 * The student dashboard's "Sesi hari ini" rows — the first thing a
 * student sees after logging in — printed the group's UUID fragment
 * unconditionally while the name sat on the same row.
 *
 * Pinned for the reason the tutor dashboard's twin spec spells out:
 * the fix is one line, and an untested one-line fix is exactly the
 * shape a later refactor silently undoes.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import HomeView from './StudentTutoring2HomeView.vue';
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

async function mountView(items: unknown[]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({ items } as never);

  const w = mount(HomeView, {
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
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async">' +
            "<slot v-if=\"state?.status === 'content'\" :data=\"state.data\" />" +
            '</div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

function rowText(w: Awaited<ReturnType<typeof mountView>>) {
  return w.findAll('[data-testid="async"] li').map((li) => li.text());
}

describe('StudentTutoring2HomeView — group label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders the group NAME the row already carries', async () => {
    const w = await mountView([makeSession()]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('UTBK Pagi A');
    expect(rowText(w)[0]).not.toContain('01a00e34');
    expect(rowText(w)[0]).not.toContain('Kelompok');
  });

  it('falls back to a short id when the name was not sent', async () => {
    const w = await mountView([makeSession({ learning_group_name: null })]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Kelompok 01a00e34');
    expect(rowText(w)[0]).not.toContain('dead-beef');
  });

  it('gives an em-dash when neither name nor id was sent', async () => {
    const w = await mountView([
      makeSession({ learning_group_name: null, learning_group_id: '' }),
    ]);

    expect(rowText(w)[0]).toContain('—');
    // Never the dangling "Kelompok " a naive prefix+slice would leave.
    expect(rowText(w)[0]).not.toContain('Kelompok');
  });
});

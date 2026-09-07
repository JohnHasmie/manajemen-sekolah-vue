/**
 * A student's own Jadwal must name the group they are sitting in.
 *
 * Same defect !1244 fixed for tutors, on the student's copy of the
 * screen: the row printed `learning_group_id.slice(0, 8)`
 * UNCONDITIONALLY — there was no `??` in the expression, so the real
 * name sitting on the very same row could never win. A student saw
 * "Kelompok 01a00e34" for the session an admin saw as "UTBK Pagi A".
 *
 * Both rungs are pinned, not just the happy one. A missing name means
 * "the server did not eager-load the relation", not "this group has no
 * name", so the id fragment must SURVIVE as the fallback rather than
 * blank the row — a blank row would tell the student strictly less.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ScheduleView from './StudentTutoring2ScheduleView.vue';
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

/** Tomorrow, so the view's "upcoming" cutoff can never filter it away. */
function soon(): string {
  return new Date(Date.now() + 24 * 3600 * 1000).toISOString();
}

function makeSession(overrides: Record<string, unknown> = {}) {
  return {
    id: 'ses-1',
    learning_group_id: '01a00e34-dead-beef',
    learning_group_name: 'UTBK Pagi A',
    starts_at: soon(),
    ends_at: soon(),
    room: 'R1',
    status: 'scheduled',
    status_label: 'Terjadwal',
    ...overrides,
  };
}

async function mountView(items: unknown[]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({ items } as never);

  const w = mount(ScheduleView, {
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

describe('StudentTutoring2ScheduleView — group label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders the group NAME the row already carries', async () => {
    const w = await mountView([makeSession()]);

    // Guard against a vacuous pass: with an empty list the two
    // not.toContain assertions below would hold trivially.
    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('UTBK Pagi A');
    expect(rowText(w)[0]).not.toContain('01a00e34');
    expect(rowText(w)[0]).not.toContain('Kelompok');
  });

  it('falls back to a short id when the name was not sent', async () => {
    const w = await mountView([makeSession({ learning_group_name: null })]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Kelompok 01a00e34');
    // Truncated, never the whole uuid.
    expect(rowText(w)[0]).not.toContain('dead-beef');
  });

  it('does not let a whitespace-only name blank the row', async () => {
    const w = await mountView([makeSession({ learning_group_name: '   ' })]);

    expect(rowText(w)[0]).toContain('Kelompok 01a00e34');
  });
});

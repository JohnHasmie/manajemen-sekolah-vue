/**
 * The tutor DASHBOARD's "Sesi hari ini" rows must show the group's NAME,
 * not its UUID — the fourth call site of `bimbelGroupLabel`, and the one
 * a tutor sees first after logging in.
 *
 * WHY THIS FILE EXISTS AT ALL. The three other sites (sessions list, its
 * search haystack, session detail) were each pinned when they were
 * fixed; this one was not. Reverting only line ~111 of
 * `TutorTutoring2HomeView.vue` back to
 * `{{ t('tutoring2.common.group') }} {{ s.learning_group_id.slice(0, 8) }}`
 * left the entire suite green at 833/833 — the fix was real but
 * unguarded, which is the exact state a later refactor silently undoes.
 *
 * That matters more than one line. The point of the shared helper is
 * that the NEXT screen imports it instead of copy-pasting a fifth
 * divergent variant; an untested call site is where that divergence
 * starts, because nothing tells the person who broke it that they did.
 *
 * Own file rather than a general `TutorTutoring2HomeView.spec.ts`: this
 * screen has no base spec, and a file named for the whole view would
 * claim to pin its KPI strip and empty state too. Named for the concern,
 * mirroring `TutorTutoring2SessionDetailView.group-name.spec.ts`.
 *
 * Both rungs of the ladder are pinned, for the same reason as the
 * sibling specs: a missing name means "the server did not send it" (the
 * relation was not eager-loaded), not "this group is unnamed", so the id
 * fragment must SURVIVE as the fallback rather than blank the row.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import HomeView from './TutorTutoring2HomeView.vue';
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
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({
    items,
  } as never);

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
        // The default slot is scoped: this screen renders `data`, not a
        // local computed, so the stub must forward it or the list is
        // empty and every assertion below passes vacuously.
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

/** Text of the rendered "Sesi hari ini" rows. */
function rowText(w: Awaited<ReturnType<typeof mountView>>) {
  return w.findAll('[data-testid="async"] li').map((li) => li.text());
}

describe('TutorTutoring2HomeView — group label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders the group NAME the row already carries', async () => {
    const w = await mountView([makeSession()]);

    // Guard against a vacuous pass: if the slot rendered nothing, the
    // "not.toContain" assertions below would hold for an empty list.
    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('UTBK Pagi A');
    // Neither the UUID nor the "Kelompok" prefix that only introduces
    // one may survive once a real name is available.
    expect(rowText(w)[0]).not.toContain('01a00e34');
    expect(rowText(w)[0]).not.toContain('Kelompok');
  });

  it('falls back to a short id when the name was not sent', async () => {
    const w = await mountView([makeSession({ learning_group_name: null })]);

    expect(rowText(w)[0]).toContain('Kelompok 01a00e34');
  });
});

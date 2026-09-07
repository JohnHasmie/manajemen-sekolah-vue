/**
 * The "Kelompok" row on the tutor's session detail must show the group's
 * NAME, not its UUID.
 *
 * Own file rather than an addition to
 * `TutorTutoring2SessionDetailView.spec.ts` (reschedule wire format) or
 * `.gate.spec.ts` (ability gating): those two mount the screen with the
 * `tutoring.session.manage` grant present/withheld because that is what
 * they are about. The label is visible to every tutor regardless of any
 * grant, so mixing it in would tie a read-only assertion to a write
 * permission it does not depend on.
 *
 * The list row and this detail row read the same helper on purpose — a
 * tutor tapping "UTBK Pagi A" in the list must not land on a page that
 * calls it `Kelompok 01a00e34`.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SessionDetail from './TutorTutoring2SessionDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listSessions: vi.fn(),
    rescheduleSession: vi.fn(),
    completeSession: vi.fn(),
  },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'ses-1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));
vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: () => true, canAny: () => true }),
}));

function makeSession(overrides: Record<string, unknown> = {}) {
  return {
    id: 'ses-1',
    learning_group_id: '01a00e34-dead-beef',
    learning_group_name: 'UTBK Pagi A',
    starts_at: '2026-07-18T09:00:00+07:00',
    ends_at: '2026-07-18T10:30:00+07:00',
    room: 'R1',
    status: 'scheduled',
    ...overrides,
  };
}

async function mountView(session: Record<string, unknown>) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({
    items: [session],
  } as never);

  const w = mount(SessionDetail, {
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
        StatusBadge: true,
        AsyncView: {
          props: ['state'],
          template:
            "<div><slot v-if=\"state?.status === 'content'\" :data=\"state.data\" /></div>",
        },
        Modal: { template: '<div><slot /></div>' },
        BottomSheetFooter: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Text of the definition list row whose term is "Kelompok". */
function groupRowText(w: Awaited<ReturnType<typeof mountView>>) {
  const row = w
    .findAll('dl > div')
    .find((d) => d.find('dt').exists() && d.get('dt').text() === 'Kelompok');
  expect(row, 'no "Kelompok" row rendered').toBeTruthy();
  return row!.get('dd').text();
}

describe('TutorTutoring2SessionDetailView — group label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows the group NAME the payload already carries', async () => {
    const w = await mountView(makeSession());

    expect(groupRowText(w)).toBe('UTBK Pagi A');
  });

  it('falls back to a short id when the name was not sent', async () => {
    const w = await mountView(makeSession({ learning_group_name: null }));

    expect(groupRowText(w)).toBe('Kelompok 01a00e34');
  });
});

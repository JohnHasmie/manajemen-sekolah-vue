/**
 * The student's session detail carried TWO of these defects at once,
 * three lines apart, which is why they are pinned in one file:
 *
 *   - the Kelompok row printed `learning_group_id.slice(0, 8)`
 *     unconditionally (the same bug as the tutor screens, !1244);
 *   - the Tutor row printed `session.tutor_id ?? '—'` — a FULL
 *     36-character uuid, not even truncated — while `tutor_name` sat on
 *     the very same session object.
 *
 * The tutor row is the worse of the two for a reason worth recording:
 * `?? '—'` LOOKS like a considered fallback, so it reads as finished
 * code. It only ever guarded against the field being absent; it never
 * asked whether a better field was available.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import DetailView from './StudentTutoring2SessionDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listSessions: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: { id: 'ses-1' }, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

const FULL_TUTOR_ID = 'ab120000-dead-beef-cafe-000000000001';

function makeSession(overrides: Record<string, unknown> = {}) {
  return {
    id: 'ses-1',
    learning_group_id: '01a00e34-dead-beef',
    learning_group_name: 'UTBK Pagi A',
    tutor_id: FULL_TUTOR_ID,
    tutor_name: 'Pak Rudi',
    starts_at: '2026-08-17T08:00:00+07:00',
    ends_at: '2026-08-17T10:00:00+07:00',
    room: 'R1',
    status: 'scheduled',
    status_label: 'Terjadwal',
    ...overrides,
  };
}

async function mountView(overrides: Record<string, unknown> = {}) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({
    items: [makeSession(overrides)],
  } as never);

  const w = mount(DetailView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: {
            id: { tutoring2: { common: { group: 'Kelompok', tutor: 'Tutor' } } },
          },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: true,
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

/** Every value cell of the detail list. */
function cells(w: Awaited<ReturnType<typeof mountView>>) {
  return w.findAll('[data-testid="async"] dd').map((dd) => dd.text());
}

describe('StudentTutoring2SessionDetailView — group + tutor labels', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders both NAMES the session already carries', async () => {
    const w = await mountView();
    const text = cells(w).join(' | ');

    // Non-vacuity: the detail list must actually have rendered.
    expect(cells(w).length).toBeGreaterThan(2);
    expect(text).toContain('UTBK Pagi A');
    expect(text).toContain('Pak Rudi');
    expect(text).not.toContain('01a00e34');
    expect(text).not.toContain(FULL_TUTOR_ID);
    expect(text).not.toContain('ab120000');
  });

  it('falls back to TRUNCATED ids when the names were not sent', async () => {
    const w = await mountView({ learning_group_name: null, tutor_name: null });
    const text = cells(w).join(' | ');

    expect(text).toContain('Kelompok 01a00e34');
    expect(text).toContain('Tutor ab120000');
    // The old code leaked the whole uuid here. It must never come back.
    expect(text).not.toContain(FULL_TUTOR_ID);
    expect(text).not.toContain('dead-beef');
  });

  it('gives an em-dash when neither a name nor an id was sent', async () => {
    const w = await mountView({
      learning_group_name: null,
      learning_group_id: '',
      tutor_name: null,
      tutor_id: null,
    });
    const text = cells(w).join(' | ');

    expect(text).toContain('—');
    expect(text).not.toContain('Kelompok ab');
    expect(text).not.toContain('Tutor ab');
  });
});

/**
 * Vitest spec for AdminTutoring2TutorDetailView — locks the wire
 * contract the view depends on (Tutor + DeactivateTutorConflict) and
 * verifies the component exports cleanly.
 *
 * The contract block below is type-level: it breaks the build when a
 * downstream shape changes.
 *
 * The second block DOES mount the view. It was added with the
 * absent-vs-zero fix: the "Kelompok aktif" tab printed
 * `{{ g.seated_count ?? 0 }} / {{ g.capacity }}`, and since
 * `GET /learning-groups` (index) never emits `seated_count`, every group
 * this tutor teaches read "0 / 12" — a confident, wrong number on a
 * screen with no coverage at all.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2TutorDetailView from './AdminTutoring2TutorDetailView.vue';
import type { DeactivateTutorConflict, Tutor } from '@/types/tutoring2/tutor';

describe('AdminTutoring2TutorDetailView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2TutorDetailView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('Tutor carries every field the detail view renders', () => {
    // If a field is dropped from Tutor, the view template will break —
    // this test fails at type-check time to catch that early.
    const _t: Tutor = {
      id: 't1',
      user_id: 'u1',
      name: 'Ust. Ali',
      email: 'ali@sekolah.id',
      employee_number: 'K-2026-01',
      is_active: true,
      active_group_count: 2,
    };
    expect(_t.name).toBeTruthy();
    // active_group_count is what the confirm-dialog callout reads.
    expect(_t.active_group_count).toBeGreaterThanOrEqual(0);
  });

  it('DeactivateTutorConflict has the two fields the toast reads', () => {
    // Both `message` (verbatim string) and `active_group_count` (int)
    // are surfaced by the danger footer's 409 branch.
    const _c: DeactivateTutorConflict = {
      message: 'Tutor masih mengajar kelompok belajar aktif — pindahkan tutor kelompok tersebut sebelum menonaktifkan.',
      active_group_count: 3,
    };
    expect(_c.active_group_count).toBe(3);
    expect(_c.message).toContain('kelompok');
  });
});

// ─── Seat counts: ABSENT is not ZERO ─────────────────────────────────
import { beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listGroups: vi.fn(),
    listSessions: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { get: vi.fn(), deactivate: vi.fn(), update: vi.fn() },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'tu-1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: () => true }),
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {
    /* noop in tests */
  },
}));

const TUTOR = {
  id: 'tu-1',
  user_id: 'us-1',
  name: 'Pak Rahmat',
  email: 'rahmat@bimbel.id',
  employee_number: 'K-01',
  is_active: true,
  active_group_count: 1,
};

function makeActiveGroup(overrides: Record<string, unknown> = {}) {
  return {
    id: 'gr-1',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    term_id: 'tm-1',
    term_name: 'Gelombang 1',
    tutor_id: 'tu-1',
    name: 'UTBK Pagi A',
    kind: 'group',
    capacity: 12,
    status: 'active',
    status_label: 'Aktif',
    // No `seated_count`: the groups LIST never carries one.
    ...overrides,
  };
}

async function mountTutorDetail(groups: Record<string, unknown>[]) {
  setActivePinia(createPinia());
  (TutoringTutorsService.get as any).mockResolvedValue(TUTOR);
  (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: groups });
  (TutoringBimbelService.listSessions as any).mockResolvedValue({ items: [] });

  const w = mount(AdminTutoring2TutorDetailView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          fallbackLocale: 'id',
          missingWarn: false,
          fallbackWarn: false,
          messages: { id: {} },
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        EmptyState: true,
        InitialsAvatar: true,
        Modal: true,
        Toast: true,
        Button: true,
        AsyncView: {
          props: ['state'],
          // Only render once the bundle resolved — the real AsyncView
          // shows its loading branch until then.
          template:
            '<div data-testid="async"><slot v-if="state?.data" :data="state.data" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

function groupsText(w: ReturnType<typeof mount>): string {
  return w.find('[data-testid="async"]').text().replace(/\s+/g, ' ');
}

describe('AdminTutoring2TutorDetailView — active groups, seats absent vs zero', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders "— / 12" when the list carried no seat count', async () => {
    const w = await mountTutorDetail([makeActiveGroup()]);

    expect(groupsText(w)).toContain('— / 12');
    expect(groupsText(w)).not.toContain('0 / 12');
  });

  it('THE INVARIANT: a group reporting zero seated still reads "0 / 12"', async () => {
    const w = await mountTutorDetail([makeActiveGroup({ seated_count: 0 })]);

    expect(groupsText(w)).toContain('0 / 12');
    expect(groupsText(w)).not.toContain('— / 12');
  });

  it('renders a reported positive count verbatim', async () => {
    const w = await mountTutorDetail([makeActiveGroup({ seated_count: 7 })]);

    expect(groupsText(w)).toContain('7 / 12');
  });
});

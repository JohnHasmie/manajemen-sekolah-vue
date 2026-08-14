/**
 * One leaderboard view, two subjects.
 *
 * The siswa result screen shipped a "Lihat peringkat" button wired to a
 * `notAvailable` toast. It was removed in !1163 because nothing was
 * behind it — the backend endpoints existed and admin, wali and tutor
 * all had views, but the student did not. This view is that
 * destination, reached by making the wali's view role-neutral rather
 * than copying 443 lines into a twin that would drift.
 *
 * The load-bearing difference is HOW THE SUBJECT IS RESOLVED:
 *
 *   wali  → `:studentId` from the route
 *   siswa → whatever their own enrollments carry, because the backend
 *           narrows `/enrollments` to them via `enrollment.view_own`
 *
 * Sending a `student_id` on the siswa path would be a 403, not a
 * filter — a student asking for a student id, even their own, is asking
 * the admin-shaped question. That is what the first test pins.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import LeaderboardView from './Tutoring2LeaderboardView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';

const routeParams: { studentId?: string } = {};

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: routeParams }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listEnrollments: vi.fn() },
}));
vi.mock('@/services/tutoring2/leaderboard', () => ({
  TutoringLeaderboardService: { getGroup: vi.fn(), getProgram: vi.fn() },
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

const ENROLLMENTS = [
  {
    id: 'enr-1',
    student_id: 'stu-1',
    learning_group_id: 'grp-1',
    learning_group_name: 'Kelompok A',
    program_id: 'prog-1',
    program_name: 'Matematika',
    status: 'active',
  },
];

/** Names deliberately avoid the badge words ("Anak" / "Saya") — a
 *  fixture called "Anak Lain" makes the negative badge assertions match
 *  a NAME and pass for the wrong reason. */
const ROWS = [
  { rank: 1, student_id: 'stu-9', student_name: 'Siti Rahma', average: 90, assessments_taken: 4 },
  { rank: 2, student_id: 'stu-1', student_name: 'Budi', average: 82, assessments_taken: 4 },
];

async function mountView() {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listEnrollments).mockResolvedValue({
    items: ENROLLMENTS,
  } as never);
  // `getGroup`/`getProgram`, returning `{ items }` — the first draft of
  // this mock guessed `group()`/`{ rows }`, which made the loader throw
  // and every row assertion fail against an error state rather than
  // against the view.
  vi.mocked(TutoringLeaderboardService.getGroup).mockResolvedValue({
    items: ROWS,
  } as never);
  vi.mocked(TutoringLeaderboardService.getProgram).mockResolvedValue({
    items: ROWS,
  } as never);

  const w = mount(LeaderboardView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: {
            id: {
              tutoring2: {
                leaderboard: {
                  title: 'Peringkat anak',
                  titleSelf: 'Peringkat saya',
                  childBadge: 'Anak',
                  selfBadge: 'Saya',
                  childLabel: 'Anak Anda · {name}',
                  selfLabel: 'Peringkat Anda',
                },
              },
            },
          },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: {
          props: ['role', 'kicker', 'title', 'meta'],
          template: '<div data-testid="hdr">{{ title }}</div>',
        },
        KpiStripCards: true,
        PageFilterToolbar: true,
        AppFilterChip: true,
        NavIcon: true,
        AsyncView: {
          props: ['state'],
          template: `<div><slot v-if="state?.status === 'content'" :data="state.data" /></div>`,
        },
      },
    },
  });
  // Three ticks: scope options resolve, the watcher picks the first
  // group, then the board itself loads.
  await flushPromises();
  await flushPromises();
  await flushPromises();
  return w;
}

describe('Tutoring2LeaderboardView', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    delete routeParams.studentId;
  });

  describe('as a siswa (no route param)', () => {
    it('asks for enrollments WITHOUT a student_id', async () => {
      await mountView();

      // The backend scopes this to the caller. Passing an id here is the
      // admin-shaped request and comes back 403.
      const arg = vi.mocked(TutoringBimbelService.listEnrollments).mock
        .calls[0][0] as Record<string, unknown>;
      expect(arg).not.toHaveProperty('student_id');
    });

    it('resolves the subject from their own enrollments', async () => {
      const w = await mountView();

      // `.text()`, not `.html()`: rendered markup carries the source
      // comments, one of which says "Anak saya" — asserting on html()
      // matched that comment and failed for a reason with nothing to do
      // with the view.
      //
      // stu-1 is the only student on those rows, so the highlighted row
      // is theirs — with no id passed in from anywhere.
      expect(w.text()).toContain('Saya');
      expect(w.text()).not.toContain('Anak');
    });

    it('titles the page for the person reading it', async () => {
      const w = await mountView();
      expect(w.get('[data-testid="hdr"]').text()).toBe('Peringkat saya');
    });
  });

  describe('as a wali (route param)', () => {
    beforeEach(() => {
      routeParams.studentId = 'stu-1';
    });

    it('filters enrollments to the named child', async () => {
      await mountView();

      const arg = vi.mocked(TutoringBimbelService.listEnrollments).mock
        .calls[0][0] as Record<string, unknown>;
      expect(arg.student_id).toBe('stu-1');
    });

    it('keeps the child-facing copy', async () => {
      const w = await mountView();

      expect(w.get('[data-testid="hdr"]').text()).toBe('Peringkat anak');
      expect(w.text()).toContain('Anak');
      expect(w.text()).not.toContain('Saya');
    });
  });
});

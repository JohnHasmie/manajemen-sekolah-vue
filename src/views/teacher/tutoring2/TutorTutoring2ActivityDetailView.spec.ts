/**
 * The tutor activity detail screen.
 *
 * ── The mock honours the id it is handed ──
 *
 * `ActivitiesService.get` is implemented here as a real lookup keyed by
 * id: the known id resolves, anything else rejects with the message
 * axios produces for a 404. A `mockResolvedValue` that ignores its
 * argument would let "requests the activity by id" pass for a screen
 * that asked for the wrong one — or for none at all — and would make
 * the out-of-scope case untestable, because every id would succeed.
 *
 * ── The locale file is the real one ──
 *
 * Read off `src/locales/id.json` rather than an inline subtree, so a key
 * this view renders but never shipped fails here instead of silently
 * echoing its own path back through `t()`.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ActivityDetailView from './TutorTutoring2ActivityDetailView.vue';
import { ActivitiesService } from '@/services/tutoring2/activities';

const { push, routeState } = vi.hoisted(() => ({
  push: vi.fn(),
  routeState: { id: 'act-77' },
}));

vi.mock('@/services/tutoring2/activities', () => ({
  ActivitiesService: {
    get: vi.fn(),
    listByGroup: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    publish: vi.fn(),
    delete: vi.fn(),
  },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
  useRoute: () => ({ params: { id: routeState.id }, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

const ACTIVITY = {
  id: 'act-77',
  learning_group_id: 'g-1',
  learning_group_name: 'UTBK Pagi A',
  program_id: 'p-9',
  program_name: 'Intensif UTBK',
  kind: 'tugas',
  kind_label: 'Tugas',
  title: 'PR Aljabar Bab 3',
  description: '<p>Kerjakan soal <strong>1-10</strong>.</p>',
  due_at: '2026-09-20T16:59:00+07:00',
  max_points: 80,
  created_by_user_id: 'u-1',
  published_at: '2026-09-14T08:30:00+07:00',
  submissions_count: 6,
};

/** Axios' own message for a 404 — what the http layer actually re-rejects. */
const NOT_FOUND = 'Request failed with status code 404';

const ID = JSON.parse(
  readFileSync(join(process.cwd(), 'src', 'locales', 'id.json'), 'utf8'),
);
const L = ID.tutoring2;

const stubs = {
  BrandPageHeader: true,
  NavIcon: true,
  StatusBadge: {
    props: ['label', 'tone', 'uppercase'],
    template: '<span class="badge" :data-tone="tone">{{ label }}</span>',
  },
  Button: { template: '<button v-bind="$attrs"><slot /></button>' },
  AsyncView: {
    props: ['state'],
    // Surfaces the BRANCH as an attribute. A missing activity must land
    // on `error` — not on `empty`, and not on a blank page.
    template:
      '<div data-testid="async" :data-status="state?.status" :data-error="state?.error ?? \'\'">' +
      "<slot v-if=\"state?.status === 'content'\" />" +
      '</div>',
  },
};

/**
 * @param id       what the route says — the only thing the request may
 *                 be built from.
 * @param override fields patched onto the stored activity, so the draft
 *                 / empty-description cases exercise the SAME loader.
 */
async function mountDetail(id = 'act-77', override = {}) {
  setActivePinia(createPinia());
  routeState.id = id;
  vi.mocked(ActivitiesService.get).mockImplementation(async (requested) => {
    if (requested !== ACTIVITY.id) throw new Error(NOT_FOUND);
    return { ...ACTIVITY, ...override };
  });
  const w = mount(ActivityDetailView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: ID },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs,
    },
  });
  await flushPromises();
  await flushPromises();
  return w;
}

const txt = (w, id) => w.find(`[data-testid="${id}"]`).text();
const status = (w) => w.find('[data-testid="async"]').attributes('data-status');

beforeEach(() => {
  vi.clearAllMocks();
  routeState.id = 'act-77';
});

describe('TutorTutoring2ActivityDetailView — loads by id', () => {
  it('asks the server for the id in the route, not for a page of the list', async () => {
    await mountDetail('act-77');
    expect(ActivitiesService.get).toHaveBeenCalledTimes(1);
    expect(ActivitiesService.get).toHaveBeenCalledWith('act-77');
    expect(ActivitiesService.listByGroup).not.toHaveBeenCalled();
  });

  it('follows the route id rather than a hard-coded one', async () => {
    // The mock rejects anything but `act-77`, so this doubles as proof
    // that the request really carries whatever the route says.
    await mountDetail('act-999');
    expect(ActivitiesService.get).toHaveBeenCalledWith('act-999');
  });
});

describe('TutorTutoring2ActivityDetailView — renders the activity', () => {
  it('lands on the content branch', async () => {
    const w = await mountDetail();
    expect(status(w)).toBe('content');
  });

  it('shows the title', async () => {
    const w = await mountDetail();
    expect(txt(w, 'activity-detail-title')).toBe('PR Aljabar Bab 3');
  });

  it.each([
    ['activity-detail-group', 'UTBK Pagi A'],
    ['activity-detail-program', 'Intensif UTBK'],
    ['activity-detail-max-points', '80'],
    ['activity-detail-submissions', '6 pengumpulan'],
  ])('%s reads "%s"', async (testid, expected) => {
    const w = await mountDetail();
    expect(txt(w, testid)).toBe(expected);
  });

  it('renders the group NAME, never the raw id', async () => {
    const w = await mountDetail();
    expect(txt(w, 'activity-detail-group')).not.toContain('g-1');
  });

  it('badges the kind from the app locale, not the backend Indonesian-only label', async () => {
    const w = await mountDetail('act-77', { kind: 'materi_baca', kind_label: 'Materi Baca' });
    expect(w.findAll('.badge').map((b) => b.text())).toContain(
      L.tutor.activities.kindMateriBaca,
    );
  });

  it('renders the description — the one field the list row never shows', async () => {
    const w = await mountDetail();
    const body = w.find('[data-testid="activity-detail-description"]');
    expect(body.exists()).toBe(true);
    expect(body.text()).toContain('Kerjakan soal');
    // Sanitised, not escaped: the <strong> survives as real markup.
    expect(body.html()).toContain('<strong>1-10</strong>');
  });

  it('strips script out of a stored description instead of trusting it', async () => {
    const w = await mountDetail('act-77', {
      description: '<p>Halo</p><script>alert(1)</script><img src=x onerror="alert(2)">',
    });
    const html = w.find('[data-testid="activity-detail-description"]').html();
    expect(html).toContain('Halo');
    expect(html).not.toContain('<script');
    expect(html).not.toContain('onerror');
  });

  it('says so plainly when there are no instructions', async () => {
    const w = await mountDetail('act-77', { description: null });
    expect(w.find('[data-testid="activity-detail-description"]').exists()).toBe(false);
    expect(txt(w, 'activity-detail-description-empty')).toBe(
      L.tutor.activityDetail.noDescription,
    );
  });

  it('labels a draft as not yet published rather than printing an empty cell', async () => {
    const w = await mountDetail('act-77', { published_at: null });
    expect(txt(w, 'activity-detail-published')).toBe(
      L.tutor.activityDetail.notPublishedYet,
    );
    expect(w.findAll('.badge').map((b) => b.text())).toContain(L.status.draft);
  });

  it('prints an em-dash for an open-ended due date instead of "Invalid Date"', async () => {
    const w = await mountDetail('act-77', { due_at: null });
    expect(txt(w, 'activity-detail-due')).toBe('—');
  });
});

describe('TutorTutoring2ActivityDetailView — a missing id', () => {
  it('renders the ERROR branch, not empty and not a blank screen', async () => {
    const w = await mountDetail('deleted-or-not-mine');
    expect(status(w)).toBe('error');
    expect(w.find('[data-testid="async"]').attributes('data-error')).toBe(NOT_FOUND);
  });

  it('renders no detail card at all for a 404', async () => {
    const w = await mountDetail('deleted-or-not-mine');
    expect(w.find('[data-testid="activity-detail-card"]').exists()).toBe(false);
    expect(w.find('[data-testid="activity-detail-title"]').exists()).toBe(false);
  });
});

describe('TutorTutoring2ActivityDetailView — a read surface, and only that', () => {
  /**
   * `update`, `publish` and `delete` all authorize on
   * `tutoring.activity.manage`, a key `show` does NOT require. Rather
   * than duplicating the list's `canManage` gate, its publish dialog and
   * its delete confirm — the second copy being the one that drifts —
   * this screen offers no write control at all and leaves those one tap
   * away on the row it was opened from.
   *
   * So the guard is structural: press every control on the page and
   * assert nothing manage-gated ever fires. Add a "Terbitkan" button
   * here without a gate and this goes red.
   */
  it('fires no manage-gated call no matter which control is pressed', async () => {
    const w = await mountDetail();
    const buttons = w.findAll('button');
    // Guard against a vacuous pass: a page with no buttons would sail
    // through the three assertions below.
    expect(buttons.length).toBeGreaterThan(0);
    for (const b of buttons) await b.trigger('click');
    expect(ActivitiesService.update).not.toHaveBeenCalled();
    expect(ActivitiesService.publish).not.toHaveBeenCalled();
    expect(ActivitiesService.delete).not.toHaveBeenCalled();
  });

  it('sends the grader to THIS activity, using the query key the grader reads', async () => {
    const w = await mountDetail();
    await w.find('[data-testid="activity-open-submissions"]').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'teacher.tutoring2.submissions',
      query: { activity_id: 'act-77' },
    });
  });

  it('offers a way back to the list', async () => {
    const w = await mountDetail();
    await w.find('[data-testid="activity-back-to-list"]').trigger('click');
    expect(push).toHaveBeenCalledWith({ name: 'teacher.tutoring2.activities' });
  });
});

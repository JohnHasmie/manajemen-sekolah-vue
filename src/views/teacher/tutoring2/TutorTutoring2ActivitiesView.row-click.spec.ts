/**
 * "website role : teacher pada halaman kegiatan ketika di klik list
 * kegiatannya seharusnya memunculkan detail kegiatan tersebut."
 *
 * The row was inert: the `<li>` carried no `@click`, no `role`, no
 * `tabindex`. The four buttons under the text block were the only live
 * targets in it, so tapping the title, the badges or the due date did
 * nothing at all.
 *
 * ── Why the router mock records instead of shrugging ──
 *
 * `TutorTutoring2ActivitiesView.filters.spec.ts` mocks `useRouter` as
 * `() => ({ push: vi.fn() })` — a FRESH spy on every call, so nothing it
 * receives can ever be asserted. A navigation test written that way
 * passes whether the handler pushes the right id, the wrong id, or a
 * literal `undefined`. The spy here is hoisted and shared, and every
 * assertion below reads the argument it was actually given.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ActivitiesView from './TutorTutoring2ActivitiesView.vue';
import { ActivitiesService } from '@/services/tutoring2/activities';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

const { push, meState } = vi.hoisted(() => ({
  push: vi.fn(),
  // Mutable so a single hoisted module mock can serve both ability
  // cases. `vi.doMock` inside the mount helper would be too late — the
  // component under test is imported at the top of this file and would
  // keep the first factory it saw.
  meState: { canManage: true },
}));

vi.mock('@/services/tutoring2/activities', () => ({
  ActivitiesService: {
    listByGroup: vi.fn(),
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    publish: vi.fn(),
    delete: vi.fn(),
  },
}));
vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => ({
  ...(await importOriginal()),
  TutoringBimbelService: { listGroups: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/stores/me', () => ({
  useMeStore: () => ({ can: () => meState.canManage }),
}));

const GROUPS = [{ id: 'g-1', name: 'UTBK Pagi A' }];

const ROWS = [
  {
    id: 'act-1',
    learning_group_id: 'g-1',
    kind: 'tugas',
    title: 'PR Aljabar',
    published_at: null,
    submissions_count: 0,
  },
  {
    id: 'act-2',
    learning_group_id: 'g-1',
    kind: 'kuis',
    title: 'Kuis Trigonometri',
    published_at: '2026-09-01T03:00:00+07:00',
    submissions_count: 4,
  },
  {
    id: 'act-3',
    learning_group_id: 'g-1',
    kind: 'materi_baca',
    title: 'Bacaan Limit',
    published_at: null,
    submissions_count: 0,
  },
];

const messages = {
  id: {
    tutoring2: {
      common: { all: 'Semua', group: 'Kelompok', kind: 'Jenis' },
      status: { published: 'Terbit', draft: 'Draft' },
      tutor: {
        activities: {
          dueLabel: 'Batas',
          submissionsCount: '{n} pengumpulan',
          openDetailAria: 'Buka detail kegiatan {title}',
          kindTugas: 'Tugas',
          kindKuis: 'Kuis',
          kindMateriBaca: 'Materi baca',
        },
      },
    },
  },
};

async function mountView({ canManage = true } = {}) {
  setActivePinia(createPinia());
  meState.canManage = canManage;
  vi.mocked(TutoringBimbelService.listGroups).mockResolvedValue({ items: GROUPS });
  vi.mocked(ActivitiesService.listByGroup).mockResolvedValue({ items: ROWS });
  const w = mount(ActivitiesView, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        NavIcon: true,
        AppRichTextEditor: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        PageFilterToolbar: {
          props: ['search', 'searchPlaceholder'],
          template: '<div><slot name="chips" /></div>',
        },
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
  await flushPromises();
  return w;
}

const rows = (w) => w.findAll('[data-testid="activity-row"]');

beforeEach(() => {
  vi.clearAllMocks();
  meState.canManage = true;
});

describe('TutorTutoring2ActivitiesView — clicking a row opens its detail', () => {
  it('renders one clickable row per activity', async () => {
    const w = await mountView();
    // Guard against a vacuous pass: if the list rendered nothing, every
    // "did not navigate" assertion below would be trivially true.
    expect(rows(w)).toHaveLength(ROWS.length);
  });

  it.each(ROWS)('clicking "$title" pushes the detail route with id $id', async (row) => {
    const w = await mountView();
    const target = rows(w)[ROWS.indexOf(row)];
    await target.trigger('click');

    expect(push).toHaveBeenCalledTimes(1);
    expect(push).toHaveBeenCalledWith({
      name: 'teacher.tutoring2.activity-detail',
      params: { id: row.id },
    });
  });

  it('never sends the submissions target when the row body is clicked', async () => {
    // The row used to have exactly one reachable navigation — the
    // "Nilai" button, which goes to the GRADER, not to a detail. A fix
    // that simply re-pointed the row at that same screen would look
    // green on "something happened" and still not answer the report.
    const w = await mountView();
    await rows(w)[0].trigger('click');
    expect(push.mock.calls[0][0].name).not.toBe('teacher.tutoring2.submissions');
  });

  it('is a real button, so keyboard users reach it too', async () => {
    const w = await mountView();
    const el = rows(w)[0];
    expect(el.element.tagName).toBe('BUTTON');
    expect(el.attributes('type')).toBe('button');
    expect(el.attributes('aria-label')).toBe('Buka detail kegiatan PR Aljabar');
  });

  it('does not carry `inline-flex`, which would hijack the filter-chip selector', async () => {
    // TutorTutoring2ActivitiesView.filters.spec.ts picks the two chips
    // with `w.findAll('button.inline-flex')[0]` / `[1]`. A row carrying
    // that class silently enters the NodeList and shifts every index,
    // breaking nine assertions in a file this change never touched.
    const w = await mountView();
    expect(w.findAll('button.inline-flex')).toHaveLength(2);
    for (const r of rows(w)) {
      expect(r.classes()).not.toContain('inline-flex');
    }
  });

  it('stays reachable for a tutor who may read but not manage activities', async () => {
    // The detail is a READ surface: `ActivityController::show`
    // authorizes on `tutoring.activity.view`, which is not the key the
    // publish/edit/delete buttons need. Hiding the row from a read-only
    // tutor would hide the only thing they can actually do here.
    const w = await mountView({ canManage: false });
    expect(rows(w)).toHaveLength(ROWS.length);
    await rows(w)[1].trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'teacher.tutoring2.activity-detail',
      params: { id: 'act-2' },
    });
  });
});

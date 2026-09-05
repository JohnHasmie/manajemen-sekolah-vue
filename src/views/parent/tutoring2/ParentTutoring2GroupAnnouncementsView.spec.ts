/**
 * Contract spec for ParentTutoring2GroupAnnouncementsView — preview footer.
 *
 * Wali-side twin of the admin/tutor announcement screens. A bimbel admin
 * reported a stray "Batal" on the announcement detail dialog (Slack
 * 1788511561.654479); all three screens carried the identical footer, and
 * this one had no spec at all.
 *
 * The dialog is READ-ONLY — for a wali the whole screen is — so the call
 * site binds no `@secondary`. BottomSheetFooter rendered its cancel button
 * regardless, took the hardcoded 'Batal' default, and swallowed the click
 * as an unhandled emit: a visible, enabled control that did nothing.
 *
 * `BottomSheetFooter` is deliberately NOT stubbed here; stubbing it on the
 * two sibling screens is precisely why the dead button was never seen.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2GroupAnnouncementsView from './ParentTutoring2GroupAnnouncementsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringAnnouncementsService } from '@/services/tutoring2/announcements';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listEnrollments: vi.fn() },
}));

vi.mock('@/services/tutoring2/announcements', () => ({
  TutoringAnnouncementsService: { list: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

const ENROLLMENTS = [
  { id: 'en-1', learning_group_id: 'gr-1', learning_group_name: 'UTBK Pagi A' },
];

const ANNOUNCEMENT = {
  id: 'an-1',
  learning_group_id: 'gr-1',
  title: 'Libur Maulid',
  body: '<p>Kelas diliburkan Senin.</p>',
  author_name: 'Admin Satu',
  published_at: '2026-08-11T09:00:00+07:00',
  created_at: '2026-08-10T09:00:00+07:00',
};

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { back: 'Kembali', cancel: 'Batal' },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(ParentTutoring2GroupAnnouncementsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        NavIcon: true,
        // BottomSheetFooter is deliberately NOT stubbed.
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
        },
        Modal: { template: '<div data-testid="modal"><slot /></div>' },
      },
    },
  });
  await flushPromises();
  return w;
}

const CANCEL = '[data-testid="sheet-cancel"]';
const SUBMIT = '[data-testid="sheet-submit"]';

/** A wali opens the detail dialog by tapping the announcement row itself. */
function announcementRow(w) {
  return w.findAll('[data-testid="async"] li')[0];
}

describe('ParentTutoring2GroupAnnouncementsView preview footer', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listEnrollments as any).mockResolvedValue({ items: ENROLLMENTS });
    (TutoringAnnouncementsService.list as any).mockResolvedValue({ items: [ANNOUNCEMENT] });
  });

  it('renders one announcement row for the wali feed', async () => {
    const w = await mountView();

    expect(announcementRow(w).text()).toContain('Libur Maulid');
  });

  it('the detail dialog ends in ONE button, and it is "Kembali"', async () => {
    const w = await mountView();

    await announcementRow(w).trigger('click');

    const modal = w.find('[data-testid="modal"]');
    expect(modal.exists()).toBe(true);
    expect(modal.find(SUBMIT).text()).toBe('Kembali');
    expect(modal.find(CANCEL).exists()).toBe(false);
  });

  it('renders no "Batal" anywhere in the detail dialog', async () => {
    const w = await mountView();

    await announcementRow(w).trigger('click');

    expect(w.find('[data-testid="modal"]').text()).not.toContain('Batal');
  });

  it('"Kembali" still closes the dialog', async () => {
    const w = await mountView();

    await announcementRow(w).trigger('click');
    expect(w.find('[data-testid="modal"]').exists()).toBe(true);

    await w.find(`[data-testid="modal"] ${SUBMIT}`).trigger('click');

    expect(w.find('[data-testid="modal"]').exists()).toBe(false);
  });
});

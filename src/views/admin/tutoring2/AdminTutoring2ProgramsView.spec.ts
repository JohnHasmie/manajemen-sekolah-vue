/**
 * Vitest contract spec for AdminTutoring2ProgramsView.
 *
 * Pins the floating "+ Program baru" CTA, which shipped with NO `@click`
 * and no handler — a fully styled button carrying a real i18n label that
 * could not do anything. Prod reported it as "tombol diklik tidak
 * terjadi apa-apa".
 *
 * The fix is NOT a handler, because there is nothing to handle:
 * web-vue has never had a program create surface.
 * `TutoringBimbelService.createProgram` exists and wraps the live
 * `POST /tutoring-v2/programs`, but it has zero call sites anywhere in
 * the app (and had zero in the retired legacy stack too). So the button
 * states that it is unavailable instead of swallowing the click.
 *
 * These tests fail against the old template — an enabled button with no
 * handler passes neither the `disabled` assertion nor the "carries a
 * reason" one — and they will fail again the day someone builds the
 * create sheet without deleting the disabled state, which is exactly
 * when this spec should be rewritten to assert the sheet opens.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2ProgramsView from './AdminTutoring2ProgramsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listPrograms: vi.fn(),
    createProgram: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

const PROGRAMS = [
  {
    id: 'pr-1',
    name: 'Intensif UTBK',
    grade_level: 'SMA',
    status: 'active',
    packages_count: 3,
    min_price: 500000,
  },
];

const CTA_REASON =
  'Membuat program belum tersedia di web. Hubungi tim KamilEdu untuk menambah program.';

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', status: 'Status', gradeLevel: 'Jenjang' },
          admin: {
            programs: {
              newCta: 'Program baru',
              newCtaUnavailable: CTA_REASON,
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2ProgramsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: true,
        AppFilterChip: true,
        AsyncView: {
          props: ['state'],
          template: '<div><slot :data="state?.data ?? []" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

const ctaOf = (w) => w.find('[data-testid="programs-new-cta"]');

describe('AdminTutoring2ProgramsView "+ Program baru" CTA', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({
      items: PROGRAMS,
      pagination: undefined,
    });
  });

  it('is disabled rather than silently inert', async () => {
    const w = await mountView();
    const cta = ctaOf(w);

    expect(cta.exists()).toBe(true);
    // The regression: it rendered enabled and did nothing when clicked.
    expect(cta.attributes('disabled')).toBeDefined();
  });

  it('carries the reason it cannot be used', async () => {
    const w = await mountView();
    const cta = ctaOf(w);

    // Pointer users get it from the tooltip …
    expect(cta.attributes('title')).toBe(CTA_REASON);
    // … and screen-reader users, who never see a tooltip, get it from
    // the element `aria-describedby` points at.
    const describedBy = cta.attributes('aria-describedby');
    expect(describedBy).toBeTruthy();
    expect(w.find(`#${describedBy}`).text()).toBe(CTA_REASON);
  });

  it('never POSTs a program, because no create surface exists yet', async () => {
    const w = await mountView();

    await ctaOf(w).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.createProgram).not.toHaveBeenCalled();
    // And no dialog appeared either — this must not quietly grow an
    // invented create form; building one is a product decision.
    expect(w.find('[data-testid="form-sheet"]').exists()).toBe(false);
  });
});

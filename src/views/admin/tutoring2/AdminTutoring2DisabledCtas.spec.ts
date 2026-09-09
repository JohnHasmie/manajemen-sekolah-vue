/**
 * Vitest contract spec for the bimbel admin CTAs that have NO create
 * surface behind them.
 *
 * "+ Buat tagihan" (billing) GRADUATED out of this file: it now opens
 * <AdminTutoring2BillCreateSheet> and is gated on
 * `tutoring.bill.create`, so its case moved to a wiring spec of its own
 * — AdminTutoring2BillingView.create-cta.spec.ts — exactly as the
 * closing note below prescribes. Three remain.
 *
 * All of them shipped fully styled, with correct i18n labels, and with
 * no `@click` — they looked exactly like the two CTAs wired in the same
 * MR, and prod reported them as "tombol diklik tidak terjadi apa-apa".
 *
 * They are NOT wired, because there is nothing admin-shaped to wire
 * them to (each view's docblock records the specific reason). What is
 * locked here is the honesty, exactly as !1211 locked it for
 * "+ Program baru":
 *
 *   1. disabled           — the control refuses visibly rather than
 *                           swallowing the click.
 *   2. reason on hover    — `title`, for a pointer.
 *   3. reason for a11y    — an `aria-describedby` line, because a screen
 *                           reader never sees a tooltip.
 *   4. label kept         — it still says what it WOULD do, so the
 *                           feature stays discoverable.
 *
 * Empty-state copy is covered too: three of these screens told admins to
 * "Klik +" to do the thing the + could not do. A disabled button plus
 * instructions to press it is the same lie in two places.
 *
 * When any of these grows a real create surface, its case here should be
 * moved to a wiring spec of its own — a failure in this file means
 * someone enabled a button without giving it a destination, or gave it
 * one without updating this spec.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2EnrollmentsView from './AdminTutoring2EnrollmentsView.vue';
import AdminTutoring2AssessmentsView from './AdminTutoring2AssessmentsView.vue';
import AdminTutoring2TermView from './AdminTutoring2TermView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTermsService } from '@/services/tutoring2/terms';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listEnrollments: vi.fn(),
    listPrograms: vi.fn(),
    listAssessments: vi.fn(),
    // Deliberately present-but-unused: these are the create methods the
    // buttons would call if a surface existed. If a future change wires
    // one, the assertions below start failing and force this file to be
    // revisited rather than quietly bypassed.
    createEnrollment: vi.fn(),
    createAssessment: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/terms', () => ({
  TutoringTermsService: { list: vi.fn() },
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
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

const REASONS = {
  enrollments: 'Mendaftarkan siswa belum tersedia.',
  assessments: 'Membuat penilaian belum tersedia.',
  term: 'Membuat term belum tersedia.',
};

const LABELS = {
  enrollments: 'Daftarkan siswa',
  assessments: 'Buat try-out',
  term: 'Term baru',
};

/** Empty-state copy must not instruct pressing a button that cannot work. */
const EMPTY_DESCS = {
  enrollments: 'Belum ada pendaftaran. Wali mendaftarkan anaknya lewat aplikasi.',
  assessments: 'Belum ada penilaian. Tutor membuatnya.',
  // Term's AsyncView used to carry a HARDCODED Indonesian literal here
  // ("Klik + untuk membuat term baru — …") with a `TODO i18n key`
  // comment beside it, so the string never appeared in any locale file
  // and no copy sweep could see it. It reads from the key now.
  term: 'Belum ada term. Hubungi tim KamilEdu untuk menambah term.',
};

function makeI18n() {
  const section = (name: string) => ({
    newCta: LABELS[name],
    newCtaUnavailable: REASONS[name],
    emptyDesc: EMPTY_DESCS[name],
    emptyTitle: 'Kosong',
  });
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', program: 'Program', status: 'Status', term: 'Term' },
          admin: {
            enrollments: section('enrollments'),
            assessments: section('assessments'),
            term: section('term'),
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView(component) {
  setActivePinia(createPinia());
  const w = mount(component, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        FilterFacetPickerModal: true,
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
        AppFilterChip: {
          props: ['label', 'value', 'iconName', 'active', 'disabled'],
          emits: ['click'],
          template:
            '<button data-testid="chip" :disabled="disabled" @click="$emit(\'click\')">{{ value }}</button>',
        },
        AsyncView: {
          props: ['state', 'emptyDescription'],
          template:
            '<div data-testid="async" :data-empty-desc="emptyDescription"><slot :data="state?.data ?? []" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

const CASES = [
  { name: 'enrollments', component: AdminTutoring2EnrollmentsView, testid: 'enrollments-new-cta' },
  { name: 'assessments', component: AdminTutoring2AssessmentsView, testid: 'assessments-new-cta' },
  { name: 'term', component: AdminTutoring2TermView, testid: 'term-new-cta' },
];

describe('bimbel admin CTAs with no create surface', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listEnrollments as any).mockResolvedValue({ items: [], pagination: undefined });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: [] });
    (TutoringBimbelService.listAssessments as any).mockResolvedValue({ items: [], pagination: undefined });
    (TutoringTermsService.list as any).mockResolvedValue({ items: [], pagination: undefined });
  });

  describe.each(CASES)('$name', ({ name, component, testid }) => {
    const sel = `[data-testid="${testid}"]`;

    it('renders the CTA, still labelled with what it would do', async () => {
      const w = await mountView(component);

      const cta = w.find(sel);
      expect(cta.exists()).toBe(true);
      expect(cta.text()).toContain(LABELS[name]);
    });

    it('is disabled rather than silently swallowing the click', async () => {
      const w = await mountView(component);

      expect(w.find(sel).attributes('disabled')).toBeDefined();
    });

    it('carries the reason for a pointer, via title', async () => {
      const w = await mountView(component);

      expect(w.find(sel).attributes('title')).toBe(REASONS[name]);
    });

    it('carries the reason for a screen reader, via aria-describedby', async () => {
      const w = await mountView(component);

      const reasonId = w.find(sel).attributes('aria-describedby');
      expect(reasonId).toBe(`${testid}-reason`);

      const reason = w.find(`#${reasonId}`);
      expect(reason.exists()).toBe(true);
      expect(reason.text()).toBe(REASONS[name]);
      // sr-only, not visually duplicated next to the button.
      expect(reason.classes()).toContain('sr-only');
    });

    it('passes its empty-state description through to AsyncView', async () => {
      const w = await mountView(component);

      expect(w.find('[data-testid="async"]').attributes('data-empty-desc')).toBe(
        EMPTY_DESCS[name],
      );
    });
  });
});

/**
 * The copy assertions above run against this file's own fixture, so they
 * prove the wiring but not the shipped words. These read the REAL locale
 * files instead.
 *
 * `emptyDesc` on all three of these screens used to read "Klik + untuk
 * …" — instructions to press a button that could not work, the same
 * defect !1211 found on `programs.emptyDesc`. Term's copy was already
 * honest and is included to keep it that way.
 */
describe('shipped empty-state copy for the disabled CTAs', () => {
  const SECTIONS = ['enrollments', 'assessments', 'term'];

  it.each(['id', 'en'])('%s.json does not tell admins to press a dead CTA', async (locale) => {
    const messages = (await import(`@/locales/${locale}.json`)).default;
    const admin = messages.tutoring2.admin;

    for (const section of SECTIONS) {
      const desc = admin[section].emptyDesc as string;
      expect(desc, `${locale}: ${section}.emptyDesc`).not.toMatch(/klik \+|click \+|tekan \+/i);
    }
  });

  it.each(['id', 'en'])('%s.json states a reason for every disabled CTA', async (locale) => {
    const messages = (await import(`@/locales/${locale}.json`)).default;
    const admin = messages.tutoring2.admin;

    for (const section of SECTIONS) {
      const reason = admin[section].newCtaUnavailable as string | undefined;
      expect(reason, `${locale}: ${section}.newCtaUnavailable`).toBeTruthy();
      expect(reason!.length, `${locale}: ${section}.newCtaUnavailable`).toBeGreaterThan(10);
    }
  });

  it('keeps the schedule CTA copy intact — that one IS wired', async () => {
    const messages = (await import('@/locales/id.json')).default;
    const schedule = messages.tutoring2.admin.schedule;

    // "Klik + untuk membuat sesi baru." is TRUE now, so it stays; and
    // the schedule CTA must NOT have acquired an unavailable reason.
    expect(schedule.emptyDesc).toMatch(/klik \+/i);
    expect(schedule.newCtaUnavailable).toBeUndefined();
  });
});

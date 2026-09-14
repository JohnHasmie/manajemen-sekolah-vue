/**
 * Contract spec for the Jenis + Status chips on the tutor's "Penilaian"
 * screen. Both were blind cycles inlined in the template: press once,
 * land on the next value, with nothing ever listing the options. The
 * chips also printed the RAW WIRE TOKEN ("tryout", "published") because
 * the old `:value` was the ref itself.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AssessmentsView from './TutorTutoring2AssessmentsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => ({
  ...(await importOriginal()),
  TutoringBimbelService: { listAssessments: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

function makeAssessment(o = {}) {
  return {
    id: 'as-1',
    program_id: 'pr-1',
    title: 'Tryout 1',
    kind: 'tryout',
    max_score: 100,
    published_at: '2026-08-30T00:00:00+07:00',
    ...o,
  };
}

const messages = {
  id: {
    tutoring2: {
      common: {
        all: 'Semua',
        kind: 'Jenis',
        status: 'Status',
        kindTryout: 'Try-out',
        kindLatihan: 'Latihan',
        kindKuis: 'Kuis',
      },
      status: { published: 'Terbit', draft: 'Draft' },
    },
  },
};

async function mountView(rows = [makeAssessment()]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listAssessments).mockResolvedValue({ items: rows });
  const w = mount(AssessmentsView, {
    global: {
      plugins: [createI18n({ legacy: false, locale: 'id', messages, missingWarn: false, fallbackWarn: false })],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        RouterLink: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        PageFilterToolbar: {
          props: ['search', 'searchPlaceholder'],
          template: '<div><slot name="chips" /></div>',
        },
        Modal: { template: '<div class="modal"><slot /></div>' },
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
  return w;
}

const chips = (w) => w.findAll('button.inline-flex');
const optionRows = (w) => w.findAll('.modal button');
const rowLabels = (w) => optionRows(w).map((b) => b.text());
const lastParams = () => {
  const calls = vi.mocked(TutoringBimbelService.listAssessments).mock.calls;
  return calls[calls.length - 1]?.[0] ?? {};
};

beforeEach(() => vi.clearAllMocks());

describe('TutorTutoring2AssessmentsView — Jenis filter', () => {
  it('opens a picker listing every kind, LABELLED', async () => {
    const w = await mountView();
    expect(optionRows(w)).toHaveLength(0);
    await chips(w)[0].trigger('click');
    expect(rowLabels(w)).toEqual(['Semua', 'Try-out', 'Latihan', 'Kuis']);
  });

  it.each([
    ['Try-out', 'tryout'],
    ['Latihan', 'latihan'],
    ['Kuis', 'kuis'],
  ])('selecting %s asks the server for %s', async (label, wire) => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === label).trigger('click');
    await flushPromises();
    expect(lastParams().kind).toBe(wire);
    // the chip reads the LABEL, not the wire token the old one printed
    expect(chips(w)[0].text()).toContain(label);
    expect(chips(w)[0].text()).not.toContain(wire);
  });

  it('"Semua" drops the kind parameter', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Kuis').trigger('click');
    await flushPromises();
    expect(lastParams().kind).toBe('kuis');
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Semua').trigger('click');
    await flushPromises();
    expect(lastParams().kind).toBeUndefined();
  });
});

describe('TutorTutoring2AssessmentsView — Status filter', () => {
  it('opens a picker listing both publication states', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    expect(rowLabels(w)).toEqual(['Semua', 'Terbit', 'Draft']);
  });

  it.each([
    ['Terbit', true],
    ['Draft', false],
  ])('selecting %s sends published=%s', async (label, flag) => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === label).trigger('click');
    await flushPromises();
    expect(lastParams().published).toBe(flag);
    expect(chips(w)[1].text()).toContain(label);
  });

  it('"Semua" drops the published parameter entirely', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Draft').trigger('click');
    await flushPromises();
    expect(lastParams().published).toBe(false);
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Semua').trigger('click');
    await flushPromises();
    expect(lastParams().published).toBeUndefined();
  });
});

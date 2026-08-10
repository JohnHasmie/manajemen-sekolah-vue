/**
 * The assessment runner must not pretend to collect answers.
 *
 * This screen used to serve ten fabricated questions and, on
 * "Kumpulkan", navigate to the results page having sent nothing. There
 * is no question or attempt endpoint in the v2 route group, so a
 * student's exam answers were discarded by construction.
 *
 * These tests pin the honest state. They are deliberately written as
 * NEGATIVES — no question UI, no submit — because the failure mode being
 * guarded is a plausible-looking runner reappearing ahead of the backend
 * that could store its answers.
 */
import { describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import TakeAssessment from './StudentTutoring2TakeAssessmentView.vue';

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'assess-0123456789' } }),
  useRouter: () => ({ push, back: vi.fn() }),
}));

function mountView() {
  setActivePinia(createPinia());
  return mount(TakeAssessment, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: {
            id: {
              tutoring2: {
                student: {
                  takeAssessment: {
                    unavailableTitle: 'Ujian online belum tersedia',
                    unavailableBody: 'Asesmen dikerjakan tertulis.',
                    reference: 'Referensi asesmen: {id}',
                    backToList: 'Kembali',
                  },
                },
              },
            },
          },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
}

describe('StudentTutoring2TakeAssessmentView', () => {
  it('explains that online assessments are unavailable', () => {
    const w = mountView();
    expect(w.text()).toContain('Ujian online belum tersedia');
  });

  it('renders NO question or answer controls', () => {
    // The fabricated runner used option buttons and a progress bar. If a
    // future change reintroduces inputs here, it has to reintroduce a
    // backend that can store what they collect.
    const w = mountView();
    expect(w.findAll('input')).toHaveLength(0);
    expect(w.findAll('textarea')).toHaveLength(0);
    expect(w.findAll('[type="radio"]')).toHaveLength(0);
  });

  it('offers only a way back — never a submit', () => {
    const w = mountView();
    const labels = w.findAll('button').map((b) => b.text().toLowerCase());
    expect(labels).toHaveLength(1);
    expect(labels[0]).toContain('kembali');
    expect(labels.join(' ')).not.toMatch(/kumpulkan|submit|kirim/);
  });

  it('shows a truncated reference rather than the bare id', () => {
    // Enough for a student to quote to their tutor, without pasting a
    // full uuid into a support chat.
    const w = mountView();
    expect(w.text()).toContain('assess-0');
    expect(w.text()).not.toContain('assess-0123456789');
  });
});

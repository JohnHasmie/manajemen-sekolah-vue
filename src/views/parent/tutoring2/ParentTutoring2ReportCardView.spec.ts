/**
 * The report card must not invent a report card.
 *
 * This screen rendered a complete, official-looking rapor: a different
 * institution ("Bimbel Cendekia"), a programme the child is not in, a
 * hardcoded term, three marks that do not exist, and a "published"
 * badge asserting the whole thing was official.
 *
 * A parent could read those grades and act on them.
 *
 * Written as NEGATIVES, because the regression is a plausible-looking
 * rapor reappearing before the backend that could attest to one.
 */
import { describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ReportCard from './ParentTutoring2ReportCardView.vue';

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { studentId: 'st-1' } }),
  useRouter: () => ({ push, back: vi.fn() }),
}));

function mountView() {
  setActivePinia(createPinia());
  return mount(ReportCard, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: { tutoring2: { parent: { reportCard: {
            title: 'Rapor',
            unavailableTitle: 'Rapor belum tersedia',
            unavailableBody: 'Belum diterbitkan lewat aplikasi.',
            seeProgress: 'Lihat perkembangan nilai',
          } } } } },
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

describe('ParentTutoring2ReportCardView', () => {
  it('says the rapor is not available instead of inventing one', () => {
    const w = mountView();
    expect(w.text()).toContain('Rapor belum tersedia');
  });

  it('shows no marks, no predikat, and no other institution', () => {
    const html = mountView().html();
    for (const invented of ['Matematika', 'Fisika', 'Kimia', 'B+', 'Bimbel Cendekia', 'SBMPTN']) {
      expect(html).not.toContain(invented);
    }
  });

  it('never claims the rapor is published', () => {
    // The old screen carried a success-toned "published" badge, which is
    // the part that made invented marks look attested.
    expect(mountView().html().toLowerCase()).not.toContain('published');
  });

  it('points the parent at the marks that DO exist', () => {
    const w = mountView();
    w.find('button').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'parent.tutoring2.progress',
      params: { studentId: 'st-1' },
    });
  });
});

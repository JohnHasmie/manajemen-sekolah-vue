/**
 * Pins the picker's `?target=` routing, including the part that matters
 * for safety: `target` arrives from the URL, so it is resolved through an
 * allow-list rather than handed to router.push directly.
 *
 * Without that check a crafted link — /parent/tutoring2/children?target=…
 * — could bounce a wali into any named route in the app on what looks to
 * them like an ordinary "choose your child" tap.
 *
 * The view hard-coded `parent.tutoring2.attendance` before this, which is
 * why a param-free "Voucher" menu entry had nowhere to point during the
 * CLEAN-2 teardown.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2PickChildView from './ParentTutoring2PickChildView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

const push = vi.fn();
let query: Record<string, string> = {};

vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
  useRoute: () => ({ query }),
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listEnrollments: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

async function mountPicker(target?: string) {
  query = target === undefined ? {} : { target };
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listEnrollments).mockResolvedValue({
    items: [{ id: 'en-1', student_id: 'st-1', status: 'active' }],
  } as never);

  const w = mount(ParentTutoring2PickChildView, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages: { id: {} }, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: {
        BrandPageHeader: true,
        AsyncView: {
          props: ['state'],
          template: '<div><slot v-if="state?.status === \'content\'" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('ParentTutoring2PickChildView target routing', () => {
  beforeEach(() => {
    push.mockClear();
  });

  it('defaults to attendance when no target is given', async () => {
    const w = await mountPicker();
    await w.find('button, [role="button"], li').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'parent.tutoring2.attendance',
      params: { studentId: 'st-1' },
    });
  });

  it('honours a known target — this is what unblocked the Voucher nav entry', async () => {
    const w = await mountPicker('vouchers');
    await w.find('button, [role="button"], li').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'parent.tutoring2.vouchers',
      params: { studentId: 'st-1' },
    });
  });

  it('refuses an unknown target instead of routing to it', async () => {
    // A route name straight off the query string is attacker-controlled.
    const w = await mountPicker('admin.tutoring2.payouts.summary');
    await w.find('button, [role="button"], li').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'parent.tutoring2.attendance',
      params: { studentId: 'st-1' },
    });
  });
});

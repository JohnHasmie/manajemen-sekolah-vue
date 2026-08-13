/**
 * Reschedule must actually reschedule.
 *
 * The button existed for as long as the screen did, next to two siblings
 * that worked, and its whole body was:
 *
 *     function rescheduleAction() {
 *       toast.info(t('tutoring2.common.notAvailable'));
 *     }
 *
 * `POST /tutoring-v2/sessions/{id}/reschedule` shipped with BE-4 and had
 * no caller.
 *
 * The load-bearing assertion here is the WIRE FORMAT. `datetime-local`
 * yields a local wall-clock string with no zone; converting it to an ISO
 * instant on the way out would shift every session by the UTC offset —
 * a tutor moving a class to 16:00 WIB would file it at 23:00, and the
 * bug would look like a backend fault.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SessionDetail from './TutorTutoring2SessionDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

const toastError = vi.fn();
const toastSuccess = vi.fn();

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listSessions: vi.fn(),
    rescheduleSession: vi.fn(),
    completeSession: vi.fn(),
  },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'ses-1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: toastSuccess, error: toastError, info: vi.fn() }),
}));

const SESSION = {
  id: 'ses-1',
  learning_group_id: 'grp-1',
  // +07:00 on purpose: the local-time assertion is meaningless if the
  // fixture is already UTC.
  starts_at: '2026-07-18T09:00:00+07:00',
  ends_at: '2026-07-18T10:30:00+07:00',
  room: 'R1',
  status: 'scheduled',
};

async function mountView() {
  setActivePinia(createPinia());
  // The view destructures `{ items }` — returning a bare array makes
  // `items.find` throw inside the loader and the screen renders its
  // error branch with no buttons at all.
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({
    items: [SESSION],
  } as never);

  const w = mount(SessionDetail, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages: { id: {} }, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        AsyncView: {
          props: ['state'],
          template: `<div><slot v-if="state?.status === 'content'" :data="state.data" /></div>`,
        },
        Modal: { template: '<div data-testid="modal"><slot /></div>' },
        BottomSheetFooter: {
          props: ['primaryLabel', 'secondaryLabel', 'primaryDisabled', 'primaryLoading'],
          template:
            '<div><button data-testid="save" :disabled="primaryDisabled" @click="$emit(\'primary\')">save</button>' +
            '<button data-testid="cancel" @click="$emit(\'secondary\')">cancel</button></div>',
        },
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** The Reschedule button is the second in the action row. */
async function openDialog(w: Awaited<ReturnType<typeof mountView>>) {
  const buttons = w.findAll('button');
  await buttons[1].trigger('click');
  await flushPromises();
}

describe('TutorTutoring2SessionDetailView — reschedule', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(TutoringBimbelService.rescheduleSession).mockResolvedValue(
      SESSION as never,
    );
  });

  it('opens a dialog prefilled from the session', async () => {
    const w = await mountView();
    await openDialog(w);

    expect(w.find('[data-testid="modal"]').exists()).toBe(true);

    // Prefilled so nudging a class by half an hour is two edits, not
    // four — and in LOCAL time, which is what the tutor reads.
    const inputs = w.findAll('input[type="datetime-local"]');
    expect(inputs).toHaveLength(2);
    expect((inputs[0].element as HTMLInputElement).value).toBe('2026-07-18T09:00');
    expect((inputs[1].element as HTMLInputElement).value).toBe('2026-07-18T10:30');
  });

  it('sends LOCAL wall-clock time, never a UTC instant', async () => {
    const w = await mountView();
    await openDialog(w);

    const inputs = w.findAll('input[type="datetime-local"]');
    await inputs[0].setValue('2026-07-18T16:00');
    await inputs[1].setValue('2026-07-18T17:30');
    await w.get('[data-testid="save"]').trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.rescheduleSession).toHaveBeenCalledWith('ses-1', {
      starts_at: '2026-07-18 16:00',
      ends_at: '2026-07-18 17:30',
      room: 'R1',
    });

    // An ISO instant here would file a 16:00 WIB class at 09:00 UTC and
    // the screen would show it moved to the wrong hour.
    const payload = vi.mocked(TutoringBimbelService.rescheduleSession).mock
      .calls[0][1] as { starts_at: string };
    expect(payload.starts_at).not.toContain('Z');
    expect(payload.starts_at).not.toContain('T');
  });

  it('surfaces the backend message rather than re-checking the rules', async () => {
    // The backend refuses `ends_at` before `starts_at` and refuses a
    // cancelled session. Duplicating those checks client-side is how the
    // two drift; the 422 text is shown verbatim instead.
    vi.mocked(TutoringBimbelService.rescheduleSession).mockRejectedValue(
      new Error('ends_at harus setelah starts_at'),
    );

    const w = await mountView();
    await openDialog(w);
    await w.get('[data-testid="save"]').trigger('click');
    await flushPromises();

    expect(toastError).toHaveBeenCalledWith('ends_at harus setelah starts_at');
  });

  it('re-reads the session after a successful move', async () => {
    const w = await mountView();
    await openDialog(w);
    await w.get('[data-testid="save"]').trigger('click');
    await flushPromises();

    // Twice: the initial load, then the refresh. Patching the row
    // locally would show the new time even if the server had stored
    // something else.
    expect(TutoringBimbelService.listSessions).toHaveBeenCalledTimes(2);
    expect(toastSuccess).toHaveBeenCalled();
  });

  it('cancelling closes without calling the API', async () => {
    const w = await mountView();
    await openDialog(w);
    await w.get('[data-testid="cancel"]').trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.rescheduleSession).not.toHaveBeenCalled();
    expect(w.find('[data-testid="modal"]').exists()).toBe(false);
  });
});

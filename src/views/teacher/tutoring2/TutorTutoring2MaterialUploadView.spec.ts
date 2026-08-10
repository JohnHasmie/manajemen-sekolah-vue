/**
 * The material upload form.
 *
 * This screen used to be, in full:
 *
 *     toast.success(t('...savedStub'));
 *     router.push({ name: 'teacher.tutoring2.materials' });
 *
 * It imported no service. A tutor filled it in, picked a file, was told
 * it saved, and was returned to a list it was not on — the work silently
 * discarded, with a success message on top. These tests exist so that
 * cannot come back quietly: the first one fails if `submit()` stops
 * calling the API at all.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import TutorTutoring2MaterialUploadView from './TutorTutoring2MaterialUploadView.vue';
import { MaterialsService } from '@/services/tutoring2/materials';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

const push = vi.fn();

vi.mock('@/services/tutoring2/materials', () => ({
  MaterialsService: { uploadFile: vi.fn(), create: vi.fn(), list: vi.fn(), destroy: vi.fn() },
}));
vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listGroups: vi.fn() },
}));
vi.mock('vue-router', () => ({ useRouter: () => ({ push, back: vi.fn() }) }));
vi.mock('@/composables/useAcademicYearWatcher', () => ({ useAcademicYearWatcher: () => {} }));
vi.mock('@/composables/useLocaleWatcher', () => ({ useLocaleWatcher: () => {} }));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

async function mountForm() {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listGroups).mockResolvedValue({
    items: [{ id: 'grp-1', name: 'Kelompok A' }],
  } as never);

  const w = mount(TutorTutoring2MaterialUploadView, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages: { id: {} }, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: {
        BrandPageHeader: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Fill the minimum the API requires, then submit. */
async function fillAndSubmit(
  w: Awaited<ReturnType<typeof mountForm>>,
  opts: { file?: File; url?: string } = {},
) {
  await w.findAll('input[type="text"]')[0].setValue('Materi Bab 1');
  await w.find('select').setValue('grp-1');

  if (opts.file) {
    const input = w.find('input[type="file"]');
    Object.defineProperty(input.element, 'files', { value: [opts.file], configurable: true });
    await input.trigger('change');
  }
  if (opts.url) {
    await w.find('input[type="url"]').setValue(opts.url);
  }

  // The submit control is the LAST button — the file field renders one
  // too, so "first enabled button" picks the picker instead.
  const buttons = w.findAll('button');
  await buttons[buttons.length - 1].trigger('click');
  await flushPromises();
}

describe('TutorTutoring2MaterialUploadView', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    push.mockClear();
  });

  it('uploads the file then creates the material — it does not just toast', async () => {
    vi.mocked(MaterialsService.uploadFile).mockResolvedValue({
      file_url: 'bimbel/materials/sc-1/abc.pdf',
      file_name: 'bab-1.pdf',
      file_size: 1024,
      file_mime: 'application/pdf',
    });
    vi.mocked(MaterialsService.create).mockResolvedValue({ id: 'mat-1' } as never);

    const w = await mountForm();
    await fillAndSubmit(w, { file: new File(['x'], 'bab-1.pdf', { type: 'application/pdf' }) });

    expect(MaterialsService.uploadFile).toHaveBeenCalledTimes(1);
    const payload = vi.mocked(MaterialsService.create).mock.calls[0][0];
    // The path from the upload is passed straight through, and the group
    // is a real id rather than the free text this field used to hold.
    expect(payload.file_url).toBe('bimbel/materials/sc-1/abc.pdf');
    expect(payload.learning_group_id).toBe('grp-1');
    expect(payload.title).toBe('Materi Bab 1');
    expect(push).toHaveBeenCalled();
  });

  it('accepts an external link with no upload', async () => {
    vi.mocked(MaterialsService.create).mockResolvedValue({ id: 'mat-2' } as never);

    const w = await mountForm();
    await fillAndSubmit(w, { url: 'https://drive.example.com/x' });

    expect(MaterialsService.uploadFile).not.toHaveBeenCalled();
    expect(vi.mocked(MaterialsService.create).mock.calls[0][0].file_url)
      .toBe('https://drive.example.com/x');
  });

  it('cannot submit without a group or a file', async () => {
    const w = await mountForm();
    await w.findAll('input[type="text"]')[0].setValue('Judul saja');

    // Submit is still reachable in the DOM; what must not happen is a
    // request. A title alone would 422 — the API requires a group and a
    // file_url.
    const buttons = w.findAll('button');
    await buttons[buttons.length - 1].trigger('click');
    await flushPromises();

    expect(MaterialsService.create).not.toHaveBeenCalled();
  });

  it('a failed save keeps the tutor on the form with an error', async () => {
    vi.mocked(MaterialsService.uploadFile).mockResolvedValue({
      file_url: 'p', file_name: 'f', file_size: 1, file_mime: 'application/pdf',
    });
    vi.mocked(MaterialsService.create).mockRejectedValue(new Error('422 judul terlalu pendek'));

    const w = await mountForm();
    await fillAndSubmit(w, { file: new File(['x'], 'a.pdf', { type: 'application/pdf' }) });

    // Navigating away on failure is exactly how the work got lost before.
    expect(push).not.toHaveBeenCalled();
    expect(w.text()).toContain('422 judul terlalu pendek');
  });
});

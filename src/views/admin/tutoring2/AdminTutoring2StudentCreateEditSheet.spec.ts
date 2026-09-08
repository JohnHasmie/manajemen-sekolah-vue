/**
 * Vitest spec for AdminTutoring2StudentCreateEditSheet — pins the
 * prop / emit contract and the payload shape the sheet emits on
 * `saved`. Same convention as the other web-vue specs: Vitest API,
 * type-checked by `vue-tsc --build`. Vitest isn't wired yet — vue-tsc
 * is the active gate.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { DefineComponent } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2StudentCreateEditSheet from './AdminTutoring2StudentCreateEditSheet.vue';
import FormField from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type { BimbelStudent } from '@/types/tutoring2/student';

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: {
    list: vi.fn(),
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    deactivate: vi.fn(),
  },
}));

// Module-level spies, not a fresh vi.fn() per useToast() call — a
// factory that mints a new mock each time leaves the component holding
// a spy the test can never reach, and every toast assertion goes
// vacuous.
const toastError = vi.fn();
const toastSuccess = vi.fn();

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: toastSuccess, error: toastError, info: vi.fn() }),
}));

describe('AdminTutoring2StudentCreateEditSheet contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2StudentCreateEditSheet as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('emits `saved` with a BimbelStudent + `close` (no payload)', () => {
    // Compile-time proof the emit signatures haven't drifted. The
    // parent list view reloads on `saved` and un-mounts the sheet on
    // `close`.
    type SavedHandler = (student: BimbelStudent) => void;
    type CloseHandler = () => void;
    const _s: SavedHandler = () => {};
    const _c: CloseHandler = () => {};
    expect(typeof _s).toBe('function');
    expect(typeof _c).toBe('function');
  });

  it('accepts `student` prop for edit mode; undefined → create', () => {
    // Both `undefined` and a full BimbelStudent must satisfy the prop
    // type — the parent flips between create and edit by passing the
    // row (or null) without unmounting.
    const _createProp: { student?: BimbelStudent | null } = { student: undefined };
    const _editProp: { student?: BimbelStudent | null } = {
      student: {
        id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
        school_id: '019f8090-51c4-703d-ad74-6b95f8421445',
        name: 'Nadia Putri',
        gender: 'female',
        guardian_name: 'Ibu Sari',
        guardian_email: 'sari@example.com',
      },
    };
    expect(_createProp.student).toBeUndefined();
    expect(_editProp.student?.id).toBeTruthy();
  });
});

/**
 * The "Tanggal lahir" field — until now the one control in this sheet
 * that supplied its own `<input type="date">` through FormField's
 * default slot, carrying a hand-pasted copy of FormField's control
 * classes. `type="date"` did not exist on FormField when the sheet was
 * written (!1267 added it); now that it does, the slot buys nothing.
 *
 * Two things come free with the swap and are asserted below as the
 * RED-BEFORE cases:
 *
 *   1. `field="date_of_birth"` gives the control the same E2E handle
 *      every other converted field has. This sheet had none at all.
 *
 *   2. `:error="errors.date_of_birth"` closes a real hole. The 422
 *      mapper writes `errors[field]` for whatever Laravel returns, and
 *      FIELD_TAB already lists `date_of_birth: 'identity'` so the sheet
 *      would JUMP to the Identitas tab on a date error — and then show
 *      nothing, because the slot-based field rendered no error line.
 *      The admin got a tab switch and a generic toast, with no red text
 *      anywhere near the field at fault.
 *
 * The remaining two — the disabled binding and the payload shape — are
 * REGRESSION guards. Read their redness carefully: they do go red
 * against the old markup, but only because they reach for the testid
 * that (1) introduces. The BEHAVIOUR they assert was already correct
 * before the change — the old slot input bound `:disabled="isSaving"`
 * and `nz()` already mapped '' to `null`. They pin that nothing moved;
 * they are not evidence that anything was broken.
 */
describe('AdminTutoring2StudentCreateEditSheet date of birth', () => {
  const STUDENT: BimbelStudent = {
    id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
    school_id: '019f8090-51c4-703d-ad74-6b95f8421445',
    name: 'Nadia Putri',
    gender: 'female',
    date_of_birth: '2011-03-09',
    guardian_name: 'Ibu Sari',
    guardian_email: 'sari@example.com',
  } as BimbelStudent;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  /** Edit mode: `name` + `guardian_name` arrive prefilled, so
   *  `validate()` passes without the test having to drive every
   *  control on both tabs. */
  function mountSheet(student: BimbelStudent | null = STUDENT) {
    const pinia = createPinia();
    setActivePinia(pinia);
    return mount(AdminTutoring2StudentCreateEditSheet, {
      props: { student },
      global: {
        plugins: [
          createI18n({
            legacy: false,
            locale: 'id',
            fallbackLocale: 'id',
            messages: { id: {} },
            missingWarn: false,
            fallbackWarn: false,
          }),
          pinia,
        ],
        // Modal teleports to <body>; stub it so the fields stay inside
        // the wrapper. FormField and FormSheet stay REAL — a stubbed
        // FormField would render its own input whatever `type` said,
        // and these assertions would be about the stub.
        stubs: { Modal: { template: '<div><slot /></div>' } },
      },
    });
  }

  function dobField(w: ReturnType<typeof mountSheet>) {
    return w.findAllComponents(FormField).find(
      (c) => c.props('field') === 'date_of_birth',
    );
  }

  it('gives the date control an E2E handle and renders it as a native date input', () => {
    const w = mountSheet();
    const input = w.get('[data-testid="field-date_of_birth"]');
    expect(input.element.tagName).toBe('INPUT');
    expect(input.attributes('type')).toBe('date');
    // The default slot is empty now — the input is FormField's own.
    expect(dobField(w)!.findAll('input')).toHaveLength(1);
  });

  it('shows a server 422 on date_of_birth under the field itself', async () => {
    const MESSAGE = 'Tanggal lahir tidak valid.';
    (TutoringStudentsService.update as unknown as { mockRejectedValue: (v: unknown) => void })
      .mockRejectedValue({
        message: 'Request failed with status code 422',
        response: {
          status: 422,
          data: { message: 'Data tidak valid.', errors: { date_of_birth: [MESSAGE] } },
        },
      });

    const w = mountSheet();
    w.findComponent(FormSheet).vm.$emit('save');
    await flushPromises();

    // The mapper ran at all…
    expect(TutoringStudentsService.update).toHaveBeenCalledTimes(1);
    // …and the message is next to the control, not only in a toast.
    // Paired with the toast assertion so "nothing rendered" cannot
    // masquerade as a correctly-placed error.
    expect(toastError).toHaveBeenCalled();
    expect(dobField(w)!.props('error')).toBe(MESSAGE);
    expect(dobField(w)!.text()).toContain(MESSAGE);
  });

  it('forwards the saving state to the control', async () => {
    // Regression guard — the old slot input bound `:disabled="isSaving"`
    // too. `isSaving` is internal, so the only honest way to observe it
    // is to hold the request open.
    let release: (v: unknown) => void = () => {};
    (TutoringStudentsService.update as unknown as { mockReturnValue: (v: unknown) => void })
      .mockReturnValue(new Promise((res) => { release = res; }));

    const w = mountSheet();
    expect(
      w.get('[data-testid="field-date_of_birth"]').attributes('disabled'),
    ).toBeUndefined();

    w.findComponent(FormSheet).vm.$emit('save');
    await w.vm.$nextTick();
    expect(
      w.get('[data-testid="field-date_of_birth"]').attributes('disabled'),
    ).toBeDefined();

    release(STUDENT);
    await flushPromises();
  });

  it('still sends a typed date through, and an empty one as null', async () => {
    // Regression guard on the PAYLOAD — the thing that must not move.
    // A date input reports a cleared field as '', and `nz()` turns that
    // into `null`, which is what the nullable BE rule expects.
    (TutoringStudentsService.update as unknown as { mockResolvedValue: (v: unknown) => void })
      .mockResolvedValue(STUDENT);

    const w = mountSheet();
    await w.get('[data-testid="field-date_of_birth"]').setValue('2010-05-04');
    w.findComponent(FormSheet).vm.$emit('save');
    await flushPromises();

    const calls = (TutoringStudentsService.update as unknown as { mock: { calls: unknown[][] } })
      .mock.calls;
    expect((calls[0][1] as Record<string, unknown>).date_of_birth).toBe('2010-05-04');

    await w.get('[data-testid="field-date_of_birth"]').setValue('');
    w.findComponent(FormSheet).vm.$emit('save');
    await flushPromises();

    const second = calls[1][1] as Record<string, unknown>;
    expect(second.date_of_birth).toBeNull();
    expect(second.date_of_birth).not.toBe('');
  });
});

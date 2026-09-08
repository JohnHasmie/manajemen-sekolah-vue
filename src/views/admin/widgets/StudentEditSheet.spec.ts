/**
 * Vitest spec for StudentEditSheet — specifically its "Tanggal lahir"
 * field, which until now supplied its own `<input type="date">`
 * through FormField's default slot with a hand-pasted copy of
 * FormField's control classes.
 *
 * That predated `type="date"` existing on FormField at all (!1267
 * added it). With the prop in place the slot buys nothing and costs a
 * second copy of the chrome, so the field is now
 * `<FormField type="date" field="date_of_birth">`.
 *
 * ── WHICH OF THESE WOULD HAVE GONE RED BEFORE THE CHANGE ──
 *
 * Only the first: before, no FormField in this sheet carried
 * `field="date_of_birth"` or `type="date"` — the date input was the
 * caller's, not the component's — so looking the component up by those
 * props found nothing.
 *
 * The rest are REGRESSION GUARDS and would have passed against the old
 * markup too, because the old markup was already correct: it already
 * rendered a `type="date"` input, already carried the testid, already
 * forwarded `disabled`, and the payload builder already mapped an
 * empty string to `null`. They are here to pin exactly those four
 * things across the swap, not to prove the swap happened. Saying so
 * matters — a green run on them is evidence of nothing changing, which
 * is the entire point of the MR, but it is not evidence the conversion
 * landed.
 */
import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import StudentEditSheet from './StudentEditSheet.vue';
import FormField from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import type { Classroom } from '@/types/entities';

const CLASSES = [
  { id: 'cl-1', name: '7A' },
  { id: 'cl-2', name: '7B' },
] as unknown as Classroom[];

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: {} },
    missingWarn: false,
    fallbackWarn: false,
  });
}

function mountSheet(props: Record<string, unknown> = {}) {
  // FormSheet's footer Buttons read a Pinia store (theme), so the
  // sheet cannot mount without one.
  const pinia = createPinia();
  setActivePinia(pinia);
  return mount(StudentEditSheet, {
    props: {
      classes: CLASSES,
      primaryColor: '#0ea5e9',
      isSaving: false,
      ...props,
    },
    global: {
      plugins: [makeI18n(), pinia],
      stubs: {
        // Modal teleports to <body>; stubbing it keeps the fields
        // inside the wrapper so `find()` reaches them. FormField and
        // FormSheet stay REAL — a stubbed FormField would render its
        // own input whatever `type` said, and the assertions below
        // would then be about the stub, not the component.
        Modal: { template: '<div><slot /></div>' },
      },
    },
  });
}

/** The FormField instance that owns a given wire key, if any. */
function fieldComponent(w: ReturnType<typeof mountSheet>, key: string) {
  return w
    .findAllComponents(FormField)
    .find((c) => c.props('field') === key);
}

describe('StudentEditSheet date of birth', () => {
  it('renders the date control through FormField, not through its slot', () => {
    // THE RED-BEFORE ONE. Previously the sheet passed neither `field`
    // nor `type` here — it wrapped a hand-rolled input — so this
    // lookup returned undefined.
    const w = mountSheet();
    const dob = fieldComponent(w, 'date_of_birth');
    expect(dob).toBeDefined();
    expect(dob!.props('type')).toBe('date');
    // And the default slot really is empty now: the only <input>
    // inside that field is the one FormField itself renders.
    expect(dob!.findAll('input')).toHaveLength(1);
  });

  it('keeps the data-testid E2E handle on a native date input', () => {
    // Regression guard — true of the old markup as well.
    const w = mountSheet();
    const input = w.get('[data-testid="field-date_of_birth"]');
    expect(input.element.tagName).toBe('INPUT');
    expect(input.attributes('type')).toBe('date');
  });

  it('forwards the saving state to the control', async () => {
    // Regression guard — the old slot input bound `:disabled="isSaving"`
    // too. Both directions are asserted so a control that is disabled
    // unconditionally cannot pass.
    const idle = mountSheet({ isSaving: false });
    expect(
      idle.get('[data-testid="field-date_of_birth"]').attributes('disabled'),
    ).toBeUndefined();

    const saving = mountSheet({ isSaving: true });
    expect(
      saving.get('[data-testid="field-date_of_birth"]').attributes('disabled'),
    ).toBeDefined();
  });

  it('still sends a typed date through, and an empty one as null', async () => {
    // Regression guard on the PAYLOAD, which is the thing that must
    // not move. `submit()` maps `form.date_of_birth || null`, and a
    // date input reports a cleared field as '' — so "no date" has to
    // arrive as null, never as an empty string the API would try to
    // validate as a date.
    const w = mountSheet();

    // The four fields validate() insists on before it will emit.
    await w.get('[data-testid="field-name"]').setValue('Rani Kusuma');
    await w.get('[data-testid="field-student_number"]').setValue('B-0091');
    await w.get('[data-testid="field-class_id"]').setValue('cl-1');
    await w.get('[data-testid="field-guardian_name"]').setValue('Ibu Sari');

    await w.get('[data-testid="field-date_of_birth"]').setValue('2010-05-04');
    w.findComponent(FormSheet).vm.$emit('save');
    await w.vm.$nextTick();

    let saved = w.emitted('save');
    expect(saved).toBeTruthy();
    expect((saved![0][0] as Record<string, unknown>).date_of_birth).toBe(
      '2010-05-04',
    );

    // Now clear it and save again.
    await w.get('[data-testid="field-date_of_birth"]').setValue('');
    w.findComponent(FormSheet).vm.$emit('save');
    await w.vm.$nextTick();

    saved = w.emitted('save');
    expect(saved).toHaveLength(2);
    const second = saved![1][0] as Record<string, unknown>;
    expect(second.date_of_birth).toBeNull();
    expect(second.date_of_birth).not.toBe('');
  });
});

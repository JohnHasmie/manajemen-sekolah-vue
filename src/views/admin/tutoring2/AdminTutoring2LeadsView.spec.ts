/**
 * Vitest contract spec for AdminTutoring2LeadsView.
 *
 * The web-vue package doesn't run vitest yet — this file is a
 * documentation/contract pin (see rbac.service.spec.ts for the wider
 * story). It exercises three regressions that would silently break
 * WEB-8:
 *
 *   1. mount()             — the view mounts with the service list
 *                            call unwrapping the {data, meta} envelope
 *                            and the table renders one row per lead.
 *   2. filter interaction  — flipping the status chip re-triggers the
 *                            list call with the new query param.
 *   3. convert flow        — clicking Konversi on a non-terminal lead
 *                            opens the convert modal + submitting it
 *                            POSTs /tutoring-v2/leads/{id}/convert
 *                            with the exact payload shape.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2LeadsView from './AdminTutoring2LeadsView.vue';
import { TutoringLeadsService } from '@/services/tutoring2/leads';
import type { BimbelLead } from '@/types/tutoring2/lead';

vi.mock('@/services/tutoring2/leads', () => ({
  TutoringLeadsService: {
    list: vi.fn(),
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    convert: vi.fn(),
    drop: vi.fn(),
    destroy: vi.fn(),
  },
}));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (_ability: string) => true, // grant both view + manage for tests
    canAny: () => true,
    snapshot: { value: null },
    loading: { value: false },
    error: { value: null },
    hasSnapshot: { value: true },
    isInitialLoading: { value: false },
    refresh: vi.fn(),
  }),
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

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
  }),
}));

function makeLead(overrides: Partial<BimbelLead> = {}): BimbelLead {
  return {
    id: 'ld-1',
    school_id: 'sc-1',
    name: 'Ayu Wijaya',
    phone: '+62 812',
    email: 'ayu@x',
    source: 'whatsapp',
    source_label: 'WhatsApp',
    status: 'new',
    status_label: 'Baru',
    notes: null,
    interest_program_id: null,
    interest_program_name: null,
    assigned_to_user_id: null,
    assigned_to_name: null,
    converted_enrollment_id: null,
    converted_enrollment: null,
    created_at: '2026-08-04T09:00:00+07:00',
    updated_at: '2026-08-04T09:00:00+07:00',
    ...overrides,
  };
}

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

async function mountView() {
  setActivePinia(createPinia());
  const i18n = makeI18n();
  const w = mount(AdminTutoring2LeadsView, {
    global: {
      plugins: [i18n],
      // Stub all shared feature/data/layout children — the view spec
      // asserts data-plumbing (service calls + payload shape), not the
      // pixel output of shared chrome (which each component owns).
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
        AppFilterChip: {
          props: ['label', 'value', 'iconName', 'active'],
          emits: ['click'],
          template: '<button data-testid="chip" @click="$emit(\'click\')"></button>',
        },
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
        },
        StatusBadge: true,
        Modal: {
          template: '<div data-testid="modal"><slot /></div>',
        },
        FormField: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
        },
        Button: {
          template: '<button><slot /></button>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('AdminTutoring2LeadsView', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('mounts and renders one row per lead returned by the service', async () => {
    (TutoringLeadsService.list as any).mockResolvedValue({
      items: [makeLead(), makeLead({ id: 'ld-2', name: 'Budi', status: 'contacted' })],
      pagination: undefined,
    });

    const w = await mountView();

    expect(TutoringLeadsService.list).toHaveBeenCalledTimes(1);
    expect(TutoringLeadsService.list).toHaveBeenCalledWith(
      expect.objectContaining({ per_page: 100 }),
    );
    const rows = w.findAll('[data-testid="lead-row"]');
    expect(rows).toHaveLength(2);
  });

  it('re-fetches with the status filter when the status chip flips', async () => {
    (TutoringLeadsService.list as any).mockResolvedValue({ items: [], pagination: undefined });

    const w = await mountView();
    // Initial call already made (immediate load) — one chip click flips
    // statusFilter from '' → 'new' which the watcher observes.
    const chips = w.findAll('[data-testid="chip"]');
    expect(chips.length).toBeGreaterThan(0);
    await chips[0].trigger('click');
    await flushPromises();

    // The last call must carry status: 'new'.
    const calls = (TutoringLeadsService.list as any).mock.calls;
    const last = calls[calls.length - 1][0];
    expect(last.status).toBe('new');
  });

  it('convert flow: clicking Konversi opens the modal and submitting posts the payload', async () => {
    const lead = makeLead({ id: 'ld-9', status: 'contacted' });
    (TutoringLeadsService.list as any).mockResolvedValue({
      items: [lead],
      pagination: undefined,
    });
    (TutoringLeadsService.convert as any).mockResolvedValue({
      ...lead,
      status: 'converted',
      converted_enrollment_id: 'en-1',
    });

    const w = await mountView();

    // Click the row's "Konversi" button.
    const convertBtn = w.find('[data-testid="lead-convert-btn"]');
    expect(convertBtn.exists()).toBe(true);
    await convertBtn.trigger('click');
    await flushPromises();

    // The convert-form modal should now be in the DOM.
    const form = w.find('[data-testid="lead-convert-form"]');
    expect(form.exists()).toBe(true);

    // Fill student_id (the first stubbed FormField input in the form).
    const inputs = form.findAll('input');
    expect(inputs.length).toBeGreaterThan(0);
    await inputs[0].setValue('st-42');
    await form.trigger('submit.prevent');
    await flushPromises();

    expect(TutoringLeadsService.convert).toHaveBeenCalledTimes(1);
    const [id, payload] = (TutoringLeadsService.convert as any).mock.calls[0];
    expect(id).toBe('ld-9');
    expect(payload.student_id).toBe('st-42');
    expect(payload.billing_mode).toBe('monthly');
    // program_id is NEVER sent — BE reads it from the lead's
    // interest_program_id. See ConvertLeadRequest.
    expect(payload).not.toHaveProperty('program_id');
  });
});

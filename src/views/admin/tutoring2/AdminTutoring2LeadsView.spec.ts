/**
 * Vitest contract spec for AdminTutoring2LeadsView.
 *
 * (The old header claimed "web-vue doesn't run vitest yet". That has
 * been false for a while — `npm run test` collects this file and CI
 * runs it. Corrected so nobody skips it thinking it's inert.)
 *
 * Covers:
 *
 *   1. mount()             — the view mounts with the service list
 *                            call unwrapping the {data, meta} envelope
 *                            and the table renders one row per lead.
 *   2. filter interaction  — flipping the status chip re-triggers the
 *                            list call with the new query param.
 *   3. convert flow        — clicking Konversi on a convertible lead
 *                            opens the convert modal + submitting it
 *                            POSTs /tutoring-v2/leads/{id}/convert
 *                            with the exact payload shape.
 *   4. the convert STATUS GATE, mirroring ConvertLeadAction.
 *   5. the convert ERROR SURFACING, so a 422 explains itself.
 *   6. the convert IDENTIFIER PICKERS — that every id on the wire is
 *      one the API handed us, never one a human typed.
 *
 * ── On (6), and why case 3 had to change ──
 *
 * This spec used to type 'st-42' into the first input of the convert
 * form and assert `payload.student_id === 'st-42'`. That asserted the
 * BUG: `st-…` is not a uuid, ConvertLeadRequest validates
 * `['required','uuid']`, and the admin's every attempt came back "the
 * student id field must be a valid uuid". The test agreed with the
 * placeholder instead of with the server, so the screen shipped green
 * while being impossible to complete.
 *
 * Two habits kept it invisible and are corrected below:
 *
 *   • the FormField stub rendered a bare <input> whatever `type` said,
 *     so `setValue()` would still "work" against a <select> or a
 *     picker — a fixed UI would not have gone red. The stub now
 *     renders its default SLOT when one is passed, and the picker is
 *     driven through its own emit, so what the test exercises is the
 *     control the admin actually sees.
 *
 *   • ids were indexed positionally (`findAll('input')[0]`), which
 *     silently retargets whenever a field is added or reordered.
 *     Everything below reaches for a data-testid instead.
 *
 * ── Anti-vacuity notes for (4) and (5) ──
 *
 * a. The Drop assertions are the point of the gate block, not padding.
 *    All four controls (2 convert, 2 drop) shipped with the SAME
 *    `v-if`, so a find-and-replace or one shared computed "fixes" the
 *    bug and silently removes Drop from every `new` lead — which the
 *    server happily accepts (`LeadStatus::NEW => [CONTACTED, DROPPED]`).
 *    Without these, that regression ships green.
 *
 * b. The 422 fixtures are AXIOS-SHAPED on purpose. `leads.ts` convert()
 *    has no try/catch and the http interceptor re-rejects the raw
 *    AxiosError, so a `new Error('...')` fixture would be surfaced by
 *    the OLD code too and the test would pass against the bug.
 *
 * c. `interest_program_id` gets its own case because it proves the two
 *    halves of the fix are independent: that lead IS `contacted`, so it
 *    passes the gate, and still 422s. If only the gate had been fixed,
 *    that case stays broken.
 *
 * d. Every "hidden" assertion is paired with a "still there" assertion
 *    on the same render, so a row (or a whole detail sheet) that failed
 *    to render can't masquerade as a correctly-hidden button.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2LeadsView from './AdminTutoring2LeadsView.vue';
import { TutoringLeadsService } from '@/services/tutoring2/leads';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
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

// The convert sheet's three pickers read three real endpoints. They
// MUST be mocked: an unmocked module pulls in the axios layer, and the
// view's Promise.allSettled loaders would swallow the failure into an
// empty dropdown — which is exactly the state this MR exists to
// eliminate, so a test running against it would prove nothing.
vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: {
    list: vi.fn(),
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    deactivate: vi.fn(),
  },
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listPrograms: vi.fn(),
    listPackages: vi.fn(),
    listGroups: vi.fn(),
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

// Stable module-level spies. The previous factory minted a FRESH
// vi.fn() on every useToast() call, so the spy the component held was
// unreachable from the test and `expect(toast.error)` could never
// assert anything — every toast assertion below would have been
// vacuous.
const toastError = vi.fn();
const toastSuccess = vi.fn();

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({
    success: toastSuccess,
    error: toastError,
    info: vi.fn(),
  }),
}));

/**
 * Real v4 uuids, because their SHAPE is the thing under test. The old
 * 'st-42' / 'pk-1' fixtures matched the placeholders the form used to
 * show and matched nothing the API has ever returned.
 */
const PROGRAM_ID = '3f1c9a70-6b2e-4c5a-9d81-2b7f0e4a1c33';
const STUDENT_ID = '9f0d7f5c-3b21-4f7c-bb2a-1c6a2d4e88aa';
const PACKAGE_ID = 'c41b8e02-7d55-4a9b-8f10-6e2c3a5b7d99';
const GROUP_ID = '5a7e2d13-9c48-4b6f-a021-8d3f1e6c4b77';

/** Mirrors ConvertLeadRequest's `uuid` rule — the one Luay's POST failed. */
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function makeStudent(overrides: Record<string, unknown> = {}) {
  return {
    id: STUDENT_ID,
    school_id: 'sc-1',
    name: 'Rani Kusuma',
    student_number: 'B-0091',
    guardian_name: 'Ibu Sari',
    active: true,
    ...overrides,
  };
}

/**
 * Default happy-path reference data for the three picker endpoints.
 * Called from every test that opens the convert sheet, so a test that
 * forgets one doesn't silently exercise the "endpoint unavailable"
 * branch and pass for the wrong reason.
 */
function mockPickerEndpoints() {
  (TutoringStudentsService.list as any).mockResolvedValue({
    items: [makeStudent()],
    pagination: undefined,
  });
  (TutoringBimbelService.listPrograms as any).mockResolvedValue({
    items: [{ id: PROGRAM_ID, name: 'Intensif SMA', status: 'active' }],
    pagination: undefined,
  });
  (TutoringBimbelService.listPackages as any).mockResolvedValue({
    items: [
      {
        id: PACKAGE_ID,
        program_id: PROGRAM_ID,
        name: 'Paket 12 sesi',
        price: 1200000,
        allowed_billing_modes: ['monthly', 'prepaid'],
        status: 'active',
      },
    ],
    pagination: undefined,
  });
  (TutoringBimbelService.listGroups as any).mockResolvedValue({
    items: [
      {
        id: GROUP_ID,
        program_id: PROGRAM_ID,
        name: 'Kelas A',
        kind: 'group',
        capacity: 10,
        // No `seated_count`: GET /learning-groups (index) never emits
        // it — only show() does. A fixture carrying it would let this
        // suite green-light a label the real list response can never
        // produce.
        status: 'active',
      },
    ],
    pagination: undefined,
  });
}

/**
 * A lead the server would actually accept for conversion: `contacted`
 * (the status gate) AND carrying an interest program (ConvertLeadAction's
 * first guard). Both are needed — a fixture missing the program now
 * exercises the client-side block, not the POST.
 */
function makeConvertibleLead(overrides: Partial<BimbelLead> = {}): BimbelLead {
  return makeLead({
    status: 'contacted',
    status_label: 'Dihubungi',
    interest_program_id: PROGRAM_ID,
    interest_program_name: 'Intensif SMA',
    ...overrides,
  });
}

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

/**
 * Axios-shaped rejection — this is the load-bearing detail. The
 * services post with a bare axios call and the http interceptor
 * re-rejects the raw AxiosError, so the reason lives at
 * `response.data`, NOT on `.message`. A `new Error(text)` fixture
 * would be surfaced by the old `toast.error((e as Error).message)`
 * too, and would prove nothing.
 *
 * Module-level so both the convert and the detail blocks share one
 * fixture factory — two subtly different fixtures would let a status
 * matrix pass on one path and lie about the other.
 */
function axiosFail(status: number, data: unknown) {
  return {
    // What axios itself puts on .message — the string the admin
    // actually saw before this fix.
    message: `Request failed with status code ${status}`,
    response: { status, data },
  };
}

function axios422(field: string, message: string) {
  return axiosFail(422, { message, errors: { [field]: [message] } });
}

/**
 * Exactly what Laravel returns when a row is gone — the concrete
 * MINOR-2 path: admin A's list is stale, admin B deleted the lead,
 * admin A acts on it. `ModelNotFoundException`'s message is carried
 * verbatim into `NotFoundHttpException`, and because that IS an
 * HttpException, `convertExceptionToArray` forwards it even with
 * APP_DEBUG off. The PHP class path is the leak.
 */
const LARAVEL_404_BODY = {
  message:
    'No query results for model [App\\Modules\\Tutoring\\Models\\Lead] 01a0f3c2-8e5b-4a11-9d77-2f6c0b1e4a55',
};

/**
 * Asserts the admin was never shown a namespaced PHP class path, by
 * any route. Deliberately a NEGATIVE assertion on the leaked shape
 * rather than a positive one on some replacement string: a test that
 * only checked "the generic appeared" would still pass if a second,
 * different leak were added alongside it.
 */
function expectNoClassPathLeaked() {
  for (const call of toastError.mock.calls) {
    const shown = String(call[0] ?? '');
    expect(shown).not.toContain('App\\');
    expect(shown).not.toContain('\\Models\\');
  }
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
        // Slot-aware: FormField's documented escape hatch renders a
        // caller-supplied control (the student trigger, the date
        // input). A stub that always rendered its own <input> made
        // those controls invisible to the suite while `setValue()`
        // kept "working" — which is how a form nobody could complete
        // stayed green.
        FormField: {
          props: ['modelValue', 'options', 'disabled', 'error', 'field', 'type'],
          emits: ['update:modelValue'],
          // `data-ff-*` mirror the props onto the DOM: a stub's props
          // are not reachable through findComponent (VTU does not name
          // object stubs after the key they are registered under), and
          // "this control is FormField's own, configured by prop" is
          // exactly what the date-field tests at the bottom assert.
          template:
            '<div class="ff" :data-ff-field="field" :data-ff-type="type"><slot>' +
            '<select v-if="options && options.length" :data-testid="field ? \'field-\' + field : undefined" ' +
            ':disabled="disabled" :value="modelValue" ' +
            '@change="$emit(\'update:modelValue\', $event.target.value)">' +
            '<option value=""></option>' +
            '<option v-for="o in options" :key="o.value" :value="o.value">{{ o.label }}</option>' +
            '</select>' +
            '<input v-else :data-testid="field ? \'field-\' + field : undefined" :value="modelValue" ' +
            '@input="$emit(\'update:modelValue\', $event.target.value)" />' +
            '</slot><span class="ff-error">{{ error }}</span></div>',
        },
        // Forwards `disabled` so "the button is off until a student is
        // picked" is a real assertion rather than a prop nobody reads.
        Button: {
          props: ['disabled', 'loading'],
          template: '<button :disabled="disabled"><slot /></button>',
        },
        // Renders one button per option and emits `apply` with that
        // option's KEY — so the id the view receives is the id the
        // service returned, never a string the test invented.
        //
        // The search box is part of the stub because `search` is the
        // emit this MR's headline mechanism hangs off: the real modal
        // watches its own input and re-emits every keystroke when
        // `server-search` is on (FilterFacetPickerModal.vue — `watch(
        // search, v => { if (props.serverSearch) emit('search', v) })`).
        // Without it the stub could declare `emits: ['search']` and
        // nothing would ever fire it, leaving `applyStudentSearch`,
        // the debounce and `loadStudents(q)` entirely unproven. It
        // reuses the REAL component's `facet-picker-search` testid so
        // the selector survives the stub being dropped.
        FilterFacetPickerModal: {
          props: {
            options: { type: Array, default: () => [] },
            selected: { type: String, default: '' },
            loading: { type: Boolean, default: false },
            emptyText: { type: String, default: '' },
            // Typed Boolean on purpose: `server-search` is passed
            // valueless, and an untyped (array-form) prop would hand
            // the stub the empty string — falsy — so the mode
            // assertion below would read '0' on a correctly wired
            // view. Vue's own boolean casting is what the real
            // component gets, so the stub takes it too.
            serverSearch: { type: Boolean, default: false },
          },
          emits: ['apply', 'close', 'search'],
          template:
            '<div data-testid="student-picker" :data-server-search="serverSearch ? \'1\' : \'0\'">' +
            '<input data-testid="facet-picker-search" type="search" ' +
            '@input="$emit(\'search\', $event.target.value)" />' +
            '<p data-testid="student-picker-empty">{{ emptyText }}</p>' +
            '<button v-for="o in options" :key="o.key" type="button" ' +
            'data-testid="student-option" :data-key="o.key" ' +
            '@click="$emit(\'apply\', o.key)">{{ o.label }}</button>' +
            '</div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/**
 * Open the student picker and choose the first row it offers, then
 * return the id that was chosen.
 *
 * Deliberately returns the id the PICKER carried rather than taking
 * one from the test: that is the whole contract under repair. The old
 * helpers typed 'st-1' into `findAll('input')[0]` and asserted the
 * same string came back, which proved only that the box echoed itself.
 */
async function pickFirstStudent(w: any): Promise<string> {
  await w.get('[data-testid="lead-convert-student-trigger"]').trigger('click');
  await flushPromises();
  const option = w.get('[data-testid="student-option"]');
  const key = option.attributes('data-key') as string;
  await option.trigger('click');
  await flushPromises();
  return key;
}

describe('AdminTutoring2LeadsView', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Sane defaults for the three picker endpoints, for EVERY test.
    // `loadPrograms` runs on mount, so a test that only cares about
    // the table would otherwise resolve it to `undefined` and throw an
    // unhandled rejection into whichever test happened to be running.
    // Cases that want a failing endpoint override the mock they mean.
    mockPickerEndpoints();
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

  it('convert flow: clicking Konversi opens the modal and submitting posts the picked uuid', async () => {
    const lead = makeConvertibleLead({ id: 'ld-9' });
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

    // The student list is fetched from the real endpoint, not typed.
    expect(TutoringStudentsService.list).toHaveBeenCalled();

    const chosen = await pickFirstStudent(w);
    await w.get('[data-testid="lead-convert-form"]').trigger('submit.prevent');
    await flushPromises();

    expect(TutoringLeadsService.convert).toHaveBeenCalledTimes(1);
    const [id, payload] = (TutoringLeadsService.convert as any).mock.calls[0];
    expect(id).toBe('ld-9');
    // The id on the wire is the id the SERVICE returned, and it is a
    // uuid — the exact rule Luay's POST failed.
    expect(chosen).toBe(STUDENT_ID);
    expect(payload.student_id).toBe(STUDENT_ID);
    expect(payload.student_id).toMatch(UUID_RE);
    expect(payload.billing_mode).toBe('monthly');
    // program_id is NEVER sent — BE reads it from the lead's
    // interest_program_id. See ConvertLeadRequest.
    expect(payload).not.toHaveProperty('program_id');
  });

  // ─────────────────────────────────────────────────────────────────
  // THE REPORTED BUG. Every id the convert sheet can put on the wire
  // has to be one the API issued. Before this MR all three were typed
  // into free-text boxes whose placeholders ('st-…', 'pk-…') described
  // a format the API never emits.
  // ─────────────────────────────────────────────────────────────────
  describe('convert identifier pickers', () => {
    async function openConvertSheet(overrides: Partial<BimbelLead> = {}) {
      (TutoringLeadsService.list as any).mockResolvedValue({
        items: [makeConvertibleLead({ id: 'ld-pick', ...overrides })],
        pagination: undefined,
      });
        const w = await mountView();
      await w.get('[data-testid="lead-convert-btn"]').trigger('click');
      await flushPromises();
      return w;
    }

    it('offers no free-text identifier box — student is a picker', async () => {
      const w = await openConvertSheet();
      const form = w.get('[data-testid="lead-convert-form"]');

      // The affordance that exists.
      expect(
        form.find('[data-testid="lead-convert-student-trigger"]').exists(),
      ).toBe(true);
      // The affordances that must NOT: package and group are selects
      // fed by the program-scoped endpoints, so a stubbed FormField
      // renders them as <select>, never as a typing box.
      expect(form.find('[data-testid="field-package_id"]').element.tagName).toBe(
        'SELECT',
      );
      expect(
        form.find('[data-testid="field-learning_group_id"]').element.tagName,
      ).toBe('SELECT');
    });

    it('keeps Konversi disabled until a student has been picked', async () => {
      const w = await openConvertSheet();

      const submit = () => w.get('[data-testid="lead-convert-submit"]');
      expect(submit().attributes('disabled')).toBeDefined();

      await pickFirstStudent(w);
      expect(submit().attributes('disabled')).toBeUndefined();
    });

    it('refuses to submit with no student, without troubling the server', async () => {
      const w = await openConvertSheet();
      await w.get('[data-testid="lead-convert-form"]').trigger('submit.prevent');
      await flushPromises();

      expect(TutoringLeadsService.convert).not.toHaveBeenCalled();
      expect(toastError).toHaveBeenCalledWith('Siswa wajib dipilih');
    });

    // ── SERVER-SIDE STUDENT SEARCH ────────────────────────────────
    //
    // The headline mechanism of this MR, and the one thing the rest of
    // this block cannot reach: every other case picks the FIRST option
    // the picker happens to be holding, which a purely client-side
    // filter would satisfy just as well. A bimbel with 400 students
    // returns one page; if the box only filtered that page, the other
    // 380 would be unreachable and the admin would be back to being
    // unable to complete the form — the exact failure this MR exists
    // to end, wearing a different mask.
    //
    // So: fire the modal's `search` emit and assert the QUERY reaches
    // the service. Non-vacuity was checked by dropping the argument
    // (`void loadStudents()`), which turns both cases red.
    describe('server-side student search', () => {
      /** 300ms in the view; wait past it, then let the promise settle. */
      async function afterDebounce(): Promise<void> {
        await new Promise((resolve) => setTimeout(resolve, 350));
        await flushPromises();
      }

      async function openStudentPicker(w: any) {
        await w.get('[data-testid="lead-convert-student-trigger"]').trigger('click');
        await flushPromises();
        // The initial unfiltered load already happened when the sheet
        // opened; forget it so the assertions below can only be
        // satisfied by a NEW, query-carrying call.
        (TutoringStudentsService.list as any).mockClear();
        return w.get('[data-testid="facet-picker-search"]');
      }

      it('asks the API for the typed query instead of filtering one loaded page', async () => {
        const w = await openConvertSheet();
        const box = await openStudentPicker(w);

        // The modal must be in server-search mode, or it would filter
        // `options` locally and never emit `search` at all — the emit
        // the assertions below depend on.
        expect(
          w.get('[data-testid="student-picker"]').attributes('data-server-search'),
        ).toBe('1');

        await box.setValue('rani');

        // Held by the 300ms debounce — one request per burst, not one
        // per keystroke.
        expect(TutoringStudentsService.list).not.toHaveBeenCalled();

        await afterDebounce();

        expect(TutoringStudentsService.list).toHaveBeenCalledTimes(1);
        expect(TutoringStudentsService.list).toHaveBeenCalledWith(
          expect.objectContaining({ search: 'rani', active: true }),
        );
      });

      it('collapses a burst of keystrokes into one request carrying the last query', async () => {
        const w = await openConvertSheet();
        const box = await openStudentPicker(w);

        await box.setValue('r');
        await box.setValue('ra');
        await box.setValue('ran');
        await box.setValue('rani');

        await afterDebounce();

        // The debounce must COLLAPSE the burst, not swallow it: exactly
        // one call, and it carries the final text.
        expect(TutoringStudentsService.list).toHaveBeenCalledTimes(1);
        expect(TutoringStudentsService.list).toHaveBeenCalledWith(
          expect.objectContaining({ search: 'rani' }),
        );
      });

      it('drops the search param when the box is cleared', async () => {
        const w = await openConvertSheet();
        const box = await openStudentPicker(w);

        await box.setValue('rani');
        await afterDebounce();
        (TutoringStudentsService.list as any).mockClear();

        await box.setValue('   ');
        await afterDebounce();

        // Blank must mean "no filter", not `search: '   '` — the API
        // would match nothing and the picker would look empty.
        expect(TutoringStudentsService.list).toHaveBeenCalledWith(
          expect.objectContaining({ search: undefined }),
        );
      });

      it('explains an empty result set as "no match", not as "no students"', async () => {
        const w = await openConvertSheet();
        const box = await openStudentPicker(w);
        (TutoringStudentsService.list as any).mockResolvedValue({
          items: [],
          pagination: undefined,
        });

        await box.setValue('zzz');
        await afterDebounce();

        expect(w.get('[data-testid="student-picker-empty"]').text()).toContain(
          'cocok dengan pencarian',
        );
      });
    });

    it('scopes the package + group lists to the lead\'s interest program', async () => {
      await openConvertSheet();

      // A package from another program is refused by
      // CreateEnrollmentAction ("Paket bukan milik program ini."), so
      // scoping the LIST is what stops one ever being offered.
      expect(TutoringBimbelService.listPackages).toHaveBeenCalledWith(
        PROGRAM_ID,
        expect.any(Object),
      );
      expect(TutoringBimbelService.listGroups).toHaveBeenCalledWith(
        expect.objectContaining({ program_id: PROGRAM_ID }),
      );
    });

    it('sends the picked package + group as uuids', async () => {
      const w = await openConvertSheet();
      (TutoringLeadsService.convert as any).mockResolvedValue(
        makeConvertibleLead({ id: 'ld-pick', status: 'converted' }),
      );

      await pickFirstStudent(w);
      await w
        .get('[data-testid="field-package_id"]')
        .setValue(PACKAGE_ID);
      await w
        .get('[data-testid="field-learning_group_id"]')
        .setValue(GROUP_ID);
      await w.get('[data-testid="lead-convert-form"]').trigger('submit.prevent');
      await flushPromises();

      const [, payload] = (TutoringLeadsService.convert as any).mock.calls[0];
      expect(payload.package_id).toBe(PACKAGE_ID);
      expect(payload.learning_group_id).toBe(GROUP_ID);
      expect(payload.package_id).toMatch(UUID_RE);
      expect(payload.learning_group_id).toMatch(UUID_RE);
    });

    it('prunes the optional ids when nothing was picked', async () => {
      const w = await openConvertSheet();
      (TutoringLeadsService.convert as any).mockResolvedValue(
        makeConvertibleLead({ id: 'ld-pick', status: 'converted' }),
      );

      await pickFirstStudent(w);
      await w.get('[data-testid="lead-convert-form"]').trigger('submit.prevent');
      await flushPromises();

      const [, payload] = (TutoringLeadsService.convert as any).mock.calls[0];
      expect(payload).not.toHaveProperty('package_id');
      expect(payload).not.toHaveProperty('learning_group_id');
      // start_date is prefilled with today, so it SHOULD still be sent —
      // this pairs with the two above so "nothing is sent" can't pass
      // for a form that failed to build a payload at all.
      expect(payload.start_date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    });

    // The lead has no interest program, so ConvertLeadAction's first
    // guard would refuse the POST. The screen now says so where the
    // fix is (the Detail sheet's "Program yang diminati" select, which
    // did not exist before this MR) instead of relaying a 422.
    it('blocks conversion of a lead with no interest program, and explains where to set it', async () => {
      (TutoringLeadsService.list as any).mockResolvedValue({
        items: [
          makeLead({ id: 'ld-np', status: 'contacted', interest_program_id: null }),
        ],
        pagination: undefined,
      });
  
      const w = await mountView();
      await w.get('[data-testid="lead-convert-btn"]').trigger('click');
      await flushPromises();

      const blocked = w.get('[data-testid="lead-convert-blocked"]');
      expect(blocked.text()).toContain('Program yang diminati');
      expect(w.get('[data-testid="lead-convert-submit"]').attributes('disabled'))
        .toBeDefined();

      await w.get('[data-testid="lead-convert-form"]').trigger('submit.prevent');
      await flushPromises();
      expect(TutoringLeadsService.convert).not.toHaveBeenCalled();
    });

    // The exit from the block above. Without this the previous test
    // would just be documenting a nicer dead end.
    it('lets the admin set the interest program from the detail sheet', async () => {
      const lead = makeLead({ id: 'ld-np', status: 'contacted', interest_program_id: null });
      (TutoringLeadsService.list as any).mockResolvedValue({
        items: [lead],
        pagination: undefined,
      });
      (TutoringLeadsService.get as any).mockResolvedValue(lead);
      (TutoringLeadsService.update as any).mockResolvedValue({
        ...lead,
        interest_program_id: PROGRAM_ID,
      });
  
      const w = await mountView();
      await w.get('[data-testid="lead-row"]').findAll('button')[0].trigger('click');
      await flushPromises();

      const form = w.get('[data-testid="lead-detail-form"]');
      const select = form.get('[data-testid="field-interest_program_id"]');
      await select.setValue(PROGRAM_ID);
      await form.trigger('submit.prevent');
      await flushPromises();

      const [, payload] = (TutoringLeadsService.update as any).mock.calls[0];
      expect(payload.interest_program_id).toBe(PROGRAM_ID);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // The gate. Mirrors ConvertLeadAction's inclusion set
  //   $allowed = [LeadStatus::CONTACTED, LeadStatus::TRIAL]
  // against the view's former exclusion set (everything but converted
  // / dropped), which offered Konversi on `new` leads the server then
  // refused with a 422.
  // ─────────────────────────────────────────────────────────────────
  describe('convert status gate', () => {
    const CONVERT = '[data-testid="lead-convert-btn"]';
    const DROP = '[data-testid="lead-drop-btn"]';

    async function mountOne(status: BimbelLead['status']) {
      (TutoringLeadsService.list as any).mockResolvedValue({
        items: [makeLead({ id: 'ld-gate', status })],
        pagination: undefined,
      });
      return mountView();
    }

    it('hides Konversi for a "new" lead — the server refuses it', async () => {
      const w = await mountOne('new');

      // Proves the row actually rendered, so the absence below is the
      // gate doing its job and not an empty table.
      expect(w.findAll('[data-testid="lead-row"]')).toHaveLength(1);
      expect(w.find(CONVERT).exists()).toBe(false);
    });

    // ══ REGRESSION GUARD ══
    // Drop shares the ORIGINAL v-if with Convert. The backend's own DAG
    // says NEW → [CONTACTED, DROPPED], and DropLeadAction refuses only
    // `converted`, so dropping an unresponsive `new` lead is legal and
    // common. Applying the convert gate to Drop would delete a working
    // control — a worse bug than the one being fixed, and invisible
    // without this test.
    it('STILL shows Batalkan for a "new" lead', async () => {
      const w = await mountOne('new');

      expect(w.find(DROP).exists()).toBe(true);
    });

    it.each(['contacted', 'trial'] as const)(
      'shows Konversi for a "%s" lead',
      async (status) => {
        const w = await mountOne(status);

        expect(w.find(CONVERT).exists()).toBe(true);
        expect(w.find(DROP).exists()).toBe(true);
      },
    );

    it.each(['converted', 'dropped'] as const)(
      'hides both actions for the terminal status "%s"',
      async (status) => {
        const w = await mountOne(status);

        expect(w.findAll('[data-testid="lead-row"]')).toHaveLength(1);
        expect(w.find(CONVERT).exists()).toBe(false);
        expect(w.find(DROP).exists()).toBe(false);
      },
    );

    // The detail sheet carries a SECOND pair of the same two controls.
    // Fixing only the row-level pair leaves the bug fully reachable
    // from the sheet, so both pairs get their own coverage.
    describe('detail sheet', () => {
      const D_CONVERT = '[data-testid="lead-detail-convert-btn"]';
      const D_DROP = '[data-testid="lead-detail-drop-btn"]';

      async function openDetail(status: BimbelLead['status']) {
        const lead = makeLead({ id: 'ld-sheet', status });
        (TutoringLeadsService.list as any).mockResolvedValue({
          items: [lead],
          pagination: undefined,
        });
        // MUST resolve: openDetail() overwrites activeLead with the
        // result, so an unmocked get() makes it undefined, the sheet's
        // `v-if="openSheet === 'detail' && activeLead"` goes false and
        // every "button is hidden" assertion would pass vacuously
        // against a sheet that never rendered.
        (TutoringLeadsService.get as any).mockResolvedValue(lead);

        const w = await mountView();
        // First button in the row is the lead-name button → openDetail.
        // Chosen over the "Detail" button's label so the test doesn't
        // couple to a translation string.
        await w.get('[data-testid="lead-row"]').findAll('button')[0].trigger('click');
        await flushPromises();
        return w;
      }

      it('hides Konversi for a "new" lead but keeps Batalkan', async () => {
        const w = await openDetail('new');

        // Sheet really opened — otherwise both assertions below are
        // vacuous.
        expect(w.find(D_DROP).exists()).toBe(true);
        expect(w.find(D_CONVERT).exists()).toBe(false);
      });

      it('shows Konversi for a "contacted" lead', async () => {
        const w = await openDetail('contacted');

        expect(w.find(D_CONVERT).exists()).toBe(true);
        expect(w.find(D_DROP).exists()).toBe(true);
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // The error surfacing. Independent of the gate: passing the status
  // check does not make the endpoint 422-proof.
  // ─────────────────────────────────────────────────────────────────
  describe('convert failure messages', () => {
    /**
     * Open the convert modal on a convertible lead, pick a student
     * from the picker, and submit.
     *
     * The lead MUST carry an interest program: the sheet now refuses
     * to POST without one, so a fixture missing it would never reach
     * the server and every assertion here would pass vacuously.
     */
    async function submitConvert(lead: BimbelLead) {
      (TutoringLeadsService.list as any).mockResolvedValue({
        items: [lead],
        pagination: undefined,
      });
  
      const w = await mountView();
      await w.get('[data-testid="lead-convert-btn"]').trigger('click');
      await flushPromises();

      await pickFirstStudent(w);
      await w.get('[data-testid="lead-convert-form"]').trigger('submit.prevent');
      await flushPromises();
      // Anti-vacuity: these cases assert what the SERVER said, so the
      // request has to have been made.
      expect(TutoringLeadsService.convert).toHaveBeenCalledTimes(1);
      return w;
    }

    it('surfaces the real reason when the 422 bag names `status`', async () => {
      // Stale list: the row still reads `contacted` (so it passes the
      // gate and the button is offered) but the lead moved on
      // server-side. The gate cannot prevent this race.
      const text =
        'Lead status converted tidak dapat dikonversi (butuh contacted atau trial).';
      (TutoringLeadsService.convert as any).mockRejectedValue(
        axios422('status', text),
      );

      await submitConvert(makeConvertibleLead({ id: 'ld-s' }));

      expect(toastError).toHaveBeenCalledWith(text);
      expect(toastError).not.toHaveBeenCalledWith(
        'Request failed with status code 422',
      );
    });

    // Previously this case sent a lead with interest_program_id: null
    // and checked the 422 came back readable. The sheet now stops that
    // POST before it leaves the browser (see "blocks conversion of a
    // lead with no interest program" above), so the case is kept for
    // the RACE it still covers: the row said the lead had a program,
    // and by the time the POST landed it did not.
    it('surfaces the real reason when the 422 bag names `interest_program_id`', async () => {
      const text = 'Lead belum menentukan program yang diminati.';
      (TutoringLeadsService.convert as any).mockRejectedValue(
        axios422('interest_program_id', text),
      );

      await submitConvert(makeConvertibleLead({ id: 'ld-p' }));

      expect(toastError).toHaveBeenCalledWith(text);
    });

    it('reads the bag when the 422 carries no top-level message', async () => {
      const text = 'Kelompok penuh (8 / 8).';
      (TutoringLeadsService.convert as any).mockRejectedValue({
        message: 'Request failed with status code 422',
        response: { status: 422, data: { errors: { learning_group_id: [text] } } },
      });

      await submitConvert(makeConvertibleLead({ id: 'ld-g', status: 'trial' }));

      expect(toastError).toHaveBeenCalledWith(text);
    });

    // Behaviour preservation: a failure with no server body still shows
    // the transport's own message, exactly as it did before the fix.
    it('keeps today behaviour for a non-422 failure with no response body', async () => {
      (TutoringLeadsService.convert as any).mockRejectedValue(
        new Error('Network Error'),
      );

      await submitConvert(makeConvertibleLead({ id: 'ld-n' }));

      expect(toastError).toHaveBeenCalledWith('Network Error');
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // STATUS MATRIX — what the admin is shown, per HTTP status, on BOTH
  // write paths that the convert gate leaves reachable.
  //
  // submitDetail is in here for a reason beyond symmetry: with
  // Konversi correctly hidden on a `new` lead, the detail sheet's
  // status <select> is the ONLY route that moves that lead forward,
  // and it used to answer every refusal with axios's own
  // "Request failed with status code 422".
  //
  // The rule under test (src/lib/api-error.ts): trust the response
  // body except on 404 and 5xx, where Laravel's `message` describes
  // internals rather than the user's problem. Anything the helper
  // refuses falls through to the view's transport rung, which is why
  // the 404/500 rows below expect axios's own string — that is the
  // behaviour those statuses had BEFORE !1224 introduced the ladder,
  // restored minus the leak. Giving 404 its own Indonesian copy would
  // be a product decision; it is deliberately NOT taken here.
  // ─────────────────────────────────────────────────────────────────
  describe('status matrix', () => {
    /** Open the convert modal on a convertible lead and submit it. */
    async function submitConvertWith(rejection: unknown) {
      (TutoringLeadsService.list as any).mockResolvedValue({
        items: [makeConvertibleLead({ id: 'ld-mx' })],
        pagination: undefined,
      });
        (TutoringLeadsService.convert as any).mockRejectedValue(rejection);

      const w = await mountView();
      await w.get('[data-testid="lead-convert-btn"]').trigger('click');
      await flushPromises();

      await pickFirstStudent(w);
      await w.get('[data-testid="lead-convert-form"]').trigger('submit.prevent');
      await flushPromises();
      // The whole matrix asserts what a REJECTED request shows, so a
      // request that was never sent would pass every row silently.
      expect(TutoringLeadsService.convert).toHaveBeenCalledTimes(1);
      return w;
    }

    /** Open the detail sheet and submit it. */
    async function submitDetailWith(rejection: unknown) {
      const lead = makeLead({ id: 'ld-mx', status: 'new' });
      (TutoringLeadsService.list as any).mockResolvedValue({
        items: [lead],
        pagination: undefined,
      });
      // MUST resolve — openDetail() overwrites activeLead with the
      // result, so an unmocked get() leaves it undefined, the sheet's
      // `v-if="openSheet === 'detail' && activeLead"` goes false and
      // the submit below would never reach submitDetail at all.
      (TutoringLeadsService.get as any).mockResolvedValue(lead);
      (TutoringLeadsService.update as any).mockRejectedValue(rejection);

      const w = await mountView();
      // First button in the row is the lead-name button → openDetail.
      await w.get('[data-testid="lead-row"]').findAll('button')[0].trigger('click');
      await flushPromises();

      // get(), not find() — throws loudly if the sheet never rendered,
      // instead of letting the whole case pass vacuously.
      await w.get('[data-testid="lead-detail-form"]').trigger('submit.prevent');
      await flushPromises();
      return w;
    }

    const paths: Array<[string, (r: unknown) => Promise<unknown>, () => void]> = [
      [
        'submitConvert',
        submitConvertWith,
        () => expect(TutoringLeadsService.convert).toHaveBeenCalled(),
      ],
      [
        'submitDetail',
        submitDetailWith,
        () => expect(TutoringLeadsService.update).toHaveBeenCalled(),
      ],
    ];

    describe.each(paths)('%s', (_name, submit, expectCalled) => {
      // 422 — the contract that must not change. This is the only
      // status whose message is reliably the domain reason.
      it('422 with a bag shows the server message unchanged', async () => {
        const text = 'Tidak dapat pindah dari new ke converted.';
        await submit(axios422('status', text));

        expectCalled();
        expect(toastError).toHaveBeenCalledWith(text);
        expect(toastError).not.toHaveBeenCalledWith(
          'Request failed with status code 422',
        );
      });

      it('422 with only a bag and no top-level message still reaches the user', async () => {
        const text = 'Kelompok penuh (8 / 8).';
        await submit(axiosFail(422, { errors: { learning_group_id: [text] } }));

        expectCalled();
        expect(toastError).toHaveBeenCalledWith(text);
      });

      // 403 on THESE endpoints is Laravel's English default, because
      // LeadController gates with a bare $this->authorize() and
      // Gate::before returns a plain boolean (no Response::deny
      // message anywhere in the backend). It is unhelpful but it is
      // not a leak of internals, so the body is still trusted — the
      // rule is about which statuses expose internals, not about
      // which strings read nicely.
      it('403 shows the server message (an abort(403) reason must survive)', async () => {
        const text = 'Anda tidak memiliki akses ke pengajuan honor.';
        await submit(axiosFail(403, { message: text }));

        expectCalled();
        expect(toastError).toHaveBeenCalledWith(text);
      });

      // ── MINOR 2 ──
      it('404 never shows the PHP class path', async () => {
        await submit(axiosFail(404, LARAVEL_404_BODY));

        expectCalled();
        expect(toastError).toHaveBeenCalled();
        expectNoClassPathLeaked();
        // Pinned: the helper refuses the body, so the view's transport
        // rung answers. Pre-!1224 behaviour for this status, minus the
        // leak.
        expect(toastError).toHaveBeenCalledWith(
          'Request failed with status code 404',
        );
      });

      it('500 does not show the framework body', async () => {
        await submit(axiosFail(500, { message: 'Server Error' }));

        expectCalled();
        expect(toastError).not.toHaveBeenCalledWith('Server Error');
        expect(toastError).toHaveBeenCalledWith(
          'Request failed with status code 500',
        );
      });

      // A debug-on backend puts raw exception text in `message`. This
      // is the case no literal blocklist of framework strings could
      // cover, and it is why the rule keys on status.
      it('500 with debug-mode exception text leaks neither SQL nor class path', async () => {
        await submit(
          axiosFail(500, {
            message:
              "SQLSTATE[42S02]: Base table or view not found: 1146 Table 'edu_core.bimbel_leads' doesn't exist",
            exception: 'Illuminate\\Database\\QueryException',
          }),
        );

        expectCalled();
        // Proves the loops below are not iterating an empty array.
        expect(toastError).toHaveBeenCalledWith(
          'Request failed with status code 500',
        );
        expectNoClassPathLeaked();
        for (const call of toastError.mock.calls) {
          expect(String(call[0] ?? '')).not.toContain('SQLSTATE');
        }
      });

      // ── TRAP 3 ──
      // An offline/timeout rejection has NO `response` at all (axios
      // builds those with four constructor args), so it cannot reach
      // a status branch and still shows the transport's own message
      // rather than a generic. Unchanged by this MR, on purpose.
      it('offline shows the transport message, not a generic', async () => {
        await submit(new Error('Network Error'));

        expectCalled();
        expect(toastError).toHaveBeenCalledWith('Network Error');
        expect(toastError).not.toHaveBeenCalledWith('Gagal mengonversi lead');
        expect(toastError).not.toHaveBeenCalledWith('Gagal menyimpan perubahan');
      });

      it('timeout shows the transport message', async () => {
        await submit(
          Object.assign(new Error('timeout of 30000ms exceeded'), {
            code: 'ECONNABORTED',
          }),
        );

        expectCalled();
        expect(toastError).toHaveBeenCalledWith('timeout of 30000ms exceeded');
      });
    });

    // The sheet must survive a refusal, or the admin loses the edits
    // they were told to correct. Both `openSheet = 'none'` and
    // reload() sit inside the try, so this is a real guard against a
    // future "close on submit" refactor.
    it('keeps the detail sheet open after a failure so edits are not lost', async () => {
      const w = await submitDetailWith(
        axios422('status', 'Tidak dapat pindah dari new ke converted.'),
      );

      expect(w.find('[data-testid="lead-detail-form"]').exists()).toBe(true);
      expect(TutoringLeadsService.list).toHaveBeenCalledTimes(1); // no reload()
    });
  });
});

/**
 * The convert sheet's "Tanggal mulai" field.
 *
 * It used to supply its own `<input type="date">` through FormField's
 * default slot, with a hand-pasted copy of FormField's control classes
 * — written that way because `type="date"` did not exist on FormField
 * at the time (!1267 added it).
 *
 * ── WHY THIS FIELD IS THE DANGEROUS ONE TO CONVERT ──
 *
 * Its old handler read `.value || null`, deliberately mapping an EMPTY
 * date to `null` rather than `''`. Collapsing that to a plain
 * `v-model` would have made a cleared field `''` instead. So the
 * conversion keeps the long form — `:model-value` plus an explicit
 * `@update:model-value` handler, the same idiom the package and group
 * selects two fields up already use — rather than a bare `v-model`.
 *
 * ── WHAT THE WIRE TESTS BELOW DO AND DO NOT PROVE ──
 *
 * Be precise about this. `submitConvert` prunes a FALSY `start_date`
 * out of the payload (`if (!payload.start_date) delete …`), and both
 * `''` and `null` are falsy — so on the wire the cleared case is a
 * MISSING KEY either way, and no wire assertion can tell a correct
 * conversion from a careless one. These tests therefore do NOT go red
 * against a naive `v-model` collapse; they pin the contract so that a
 * future edit to either half — the handler here or the prune there —
 * cannot quietly start sending `''` to a `date` validator.
 *
 * The assertion that DOES distinguish the two is the first one: the
 * control is FormField's own now, addressed by props, with no
 * caller-supplied input at all. That, plus the repo-wide guard in
 * `form-field-control-chrome.spec.ts` (which names this exact line
 * when the chrome is pasted back), is what pins the conversion itself.
 */
describe('AdminTutoring2LeadsView convert start date', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockPickerEndpoints();
  });

  async function openConvert() {
    (TutoringLeadsService.list as any).mockResolvedValue({
      items: [makeConvertibleLead({ id: 'ld-date' })],
      pagination: undefined,
    });
    (TutoringLeadsService.convert as any).mockResolvedValue(
      makeConvertibleLead({ id: 'ld-date', status: 'converted' }),
    );
    const w = await mountView();
    await w.get('[data-testid="lead-convert-btn"]').trigger('click');
    await flushPromises();
    return w;
  }

  async function submitAndReadPayload(w: any) {
    await w.get('[data-testid="lead-convert-form"]').trigger('submit.prevent');
    await flushPromises();
    expect(TutoringLeadsService.convert).toHaveBeenCalledTimes(1);
    return (TutoringLeadsService.convert as any).mock.calls[0][1];
  }

  it('renders the start date as a FormField date control, not a hand-rolled input', async () => {
    // RED BEFORE: the sheet passed this FormField neither `field` nor
    // `type` — it wrapped its own input — so there was no component
    // here to find by those props.
    const w = await openConvert();
    const ff = w.get('[data-ff-field="start_date"]');
    expect(ff.attributes('data-ff-type')).toBe('date');
    // No caller-supplied control inside it — the input is the one
    // FormField renders, and it still carries the E2E handle.
    const inputs = ff.findAll('input');
    expect(inputs).toHaveLength(1);
    expect(inputs[0].attributes('data-testid')).toBe('field-start_date');
  });

  it('sends a chosen start date verbatim', async () => {
    const w = await openConvert();
    await pickFirstStudent(w);
    await w.get('[data-testid="field-start_date"]').setValue('2026-10-01');

    const payload = await submitAndReadPayload(w);
    expect(payload.start_date).toBe('2026-10-01');
  });

  it('sends NO start_date when the field is cleared — never an empty string', async () => {
    // `openConvert` prefills today's date, so this really is a clear,
    // not a field that was never touched.
    const w = await openConvert();
    await pickFirstStudent(w);
    expect(
      (w.get('[data-testid="field-start_date"]').element as HTMLInputElement).value,
    ).toMatch(/^\d{4}-\d{2}-\d{2}$/);

    await w.get('[data-testid="field-start_date"]').setValue('');

    const payload = await submitAndReadPayload(w);
    // The key is absent entirely — that is what "let the backend
    // default it" looks like on this endpoint.
    expect(payload).not.toHaveProperty('start_date');
    // And explicitly not the empty string, which `start_date`'s `date`
    // rule would reject were the prune ever loosened.
    expect(payload.start_date).not.toBe('');
    // Paired with a positive assertion so a payload that failed to
    // build at all cannot pass this test.
    expect(payload.student_id).toBe(STUDENT_ID);
  });
});

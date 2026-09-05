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
    /** Open the convert modal on a convertible lead and submit it. */
    async function submitConvert(lead: BimbelLead) {
      (TutoringLeadsService.list as any).mockResolvedValue({
        items: [lead],
        pagination: undefined,
      });

      const w = await mountView();
      await w.get('[data-testid="lead-convert-btn"]').trigger('click');
      await flushPromises();

      const form = w.get('[data-testid="lead-convert-form"]');
      await form.findAll('input')[0].setValue('st-1');
      await form.trigger('submit.prevent');
      await flushPromises();
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

      await submitConvert(makeLead({ id: 'ld-s', status: 'contacted' }));

      expect(toastError).toHaveBeenCalledWith(text);
      expect(toastError).not.toHaveBeenCalledWith(
        'Request failed with status code 422',
      );
    });

    // Proves the two halves of the fix are independent. This lead IS
    // `contacted`, so the new gate is satisfied and the button is
    // correctly offered — and the request is STILL refused, because
    // ConvertLeadAction checks interest_program_id first. Had we only
    // tightened the gate, this admin would still be stuck.
    it('surfaces the real reason when the 422 bag names `interest_program_id`', async () => {
      const text = 'Lead belum menentukan program yang diminati.';
      (TutoringLeadsService.convert as any).mockRejectedValue(
        axios422('interest_program_id', text),
      );

      await submitConvert(
        makeLead({ id: 'ld-p', status: 'contacted', interest_program_id: null }),
      );

      expect(toastError).toHaveBeenCalledWith(text);
    });

    it('reads the bag when the 422 carries no top-level message', async () => {
      const text = 'Kelompok penuh (8 / 8).';
      (TutoringLeadsService.convert as any).mockRejectedValue({
        message: 'Request failed with status code 422',
        response: { status: 422, data: { errors: { learning_group_id: [text] } } },
      });

      await submitConvert(makeLead({ id: 'ld-g', status: 'trial' }));

      expect(toastError).toHaveBeenCalledWith(text);
    });

    // Behaviour preservation: a failure with no server body still shows
    // the transport's own message, exactly as it did before the fix.
    it('keeps today behaviour for a non-422 failure with no response body', async () => {
      (TutoringLeadsService.convert as any).mockRejectedValue(
        new Error('Network Error'),
      );

      await submitConvert(makeLead({ id: 'ld-n', status: 'contacted' }));

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
        items: [makeLead({ id: 'ld-mx', status: 'contacted' })],
        pagination: undefined,
      });
      (TutoringLeadsService.convert as any).mockRejectedValue(rejection);

      const w = await mountView();
      await w.get('[data-testid="lead-convert-btn"]').trigger('click');
      await flushPromises();

      const form = w.get('[data-testid="lead-convert-form"]');
      await form.findAll('input')[0].setValue('st-1');
      await form.trigger('submit.prevent');
      await flushPromises();
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

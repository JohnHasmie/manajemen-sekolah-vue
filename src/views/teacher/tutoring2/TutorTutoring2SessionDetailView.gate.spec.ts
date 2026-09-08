/**
 * The tutor session-detail action row must not offer a guaranteed 403.
 *
 * ── The defect ──
 *
 * Two of the three buttons on this screen post to endpoints that open
 * with `$this->authorize('tutoring.session.manage')`:
 *
 *   Reschedule      → POST /tutoring-v2/sessions/{id}/reschedule
 *   Tandai selesai  → POST /tutoring-v2/sessions/{id}/complete
 *
 * (`SessionController::reschedule` / `::complete`.)
 *
 * `PermissionCatalog::tutorTutoringDefaults()` does NOT grant that key —
 * a tutor gets `tutoring.session.view` + `tutoring.session.mark_attendance`,
 * and the lifecycle keys sit in `adminTutoringDefaults()`. So on a default
 * bimbel tenant both buttons were certain refusals, sitting flush against
 * "Ambil presensi", which works. Reschedule was the worse of the two: it
 * carried no condition at all, so the tutor filled in the whole
 * date/time/room form before the server said no.
 *
 * "Ambil presensi" is deliberately NOT covered here as a gated control:
 * it authorizes on `tutoring.session.mark_attendance`, which every tutor
 * holds. Gating it would be the opposite bug.
 *
 * ── Why disabled and not hidden ──
 *
 * The permission catalog is a SEED, not a ceiling. A tenant that grants
 * `tutoring.session.manage` to its tutor role through the RBAC picker
 * gets both buttons back with no code change — which is why the
 * "with the grant" half below is a real assertion and not a formality.
 * Same reasoning !1217 recorded for the two session-write ROUTES, and
 * the shape the mobile app takes for its own copy of this row in !1220
 * (still unmerged at the time of writing, so there is no path on `main`
 * to cite yet).
 *
 * ── Anti-vacuity notes ──
 *
 * 1. `grantedAbilities` starts as the DEFAULT TUTOR SET, not
 *    allow-everything. A mock that grants by default makes every
 *    "refuses" assertion below pass for the wrong reason.
 * 2. `Button` is NOT stubbed. A stub that re-renders `:disabled` is a
 *    second implementation of the thing under test; the real component
 *    is what decides whether the DOM node is actually disabled.
 * 3. Every "is disabled" assertion is preceded by an "exists" assertion.
 *    A button removed from the row would otherwise pass silently.
 * 4. The reason assertions compare against REAL Indonesian copy, and the
 *    last describe block pins that copy to what `id.json`/`en.json`
 *    actually ship. vue-i18n echoes the KEY back for a missing message
 *    (and with `missingWarn: false` it does so silently), so asserting
 *    `toContain('tutoring2.tutor.sessionDetail.noManageAbility')`
 *    would pass forever while proving nothing.
 * 5. The attribute checks are backed by BEHAVIOUR checks — but NOT by
 *    clicking the dead buttons. `@vue/test-utils` 2.4.11 refuses to
 *    dispatch on a disabled element at all (`vue-test-utils.cjs.js`:
 *    `if (this.element && !this.isDisabled())`), mirroring what a real
 *    browser does with a disabled control, so `trigger('click')` on a
 *    node this spec has already asserted is `disabled` is a guaranteed
 *    no-op: it would re-assert the attribute and prove nothing. Two
 *    such tests used to sit in the default-tutor block and have been
 *    replaced. What pins the behaviour instead:
 *      a. the handlers are invoked DIRECTLY off the component's
 *         `<script setup>` bindings, bypassing the DOM, so the
 *         in-function `if (…BlockedReason.value) return` guards — the
 *         only thing standing between a blocked caller and the dialog
 *         or the endpoint — are what has to hold; and
 *      b. the "with the grant" block drives the very same two controls
 *         while they are live, so none of the disabled-path assertions
 *         can be passing merely because nothing is wired up at all.
 * 6. `completeBlockedReason` is ability-ONLY by design; the status half
 *    lives on the button's `v-if`. That `v-if` therefore needs its own
 *    block, or removing it would fail no test here.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SessionDetail from './TutorTutoring2SessionDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

/** The one key both write buttons sit behind. */
const MANAGE = 'tutoring.session.manage';

/**
 * Exactly what `tutorTutoringDefaults()` grants on the session side.
 * This is the baseline every test starts from; a test that wants the
 * grant must say so.
 */
const TUTOR_DEFAULTS = ['tutoring.session.view', 'tutoring.session.mark_attendance'];

let grantedAbilities: string[] = [...TUTOR_DEFAULTS];

/**
 * Spied so one test can assert the view reads the /me snapshot (scoped
 * by `X-Active-Role`) via `useMe().can`, rather than reaching into the
 * auth store's unscoped `roles[].permission_keys`.
 */
const canSpy = vi.fn((ability: string) => grantedAbilities.includes(ability));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: canSpy,
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    getSession: vi.fn(),
    rescheduleSession: vi.fn(),
    completeSession: vi.fn(),
  },
}));

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'ses-1' } }),
  useRouter: () => ({ push }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

/**
 * Copy the screen must actually render. Pinned to the locale files below.
 *
 * It names the missing PERMISSION rather than a role: the catalog is a
 * seed, not a ceiling, so "only an admin can do this" would be false the
 * moment a tenant grants the key to its tutor role.
 */
const NO_MANAGE_ABILITY =
  'Peran Anda belum diberi izin untuk menjadwal ulang atau menutup sesi. Presensi yang Anda simpan tetap tersimpan — mintalah pengelola bimbel menutup sesinya, atau menambahkan izin ini ke peran Anda.';
const RESCHEDULE_CLOSED =
  'Sesi yang sudah selesai atau dibatalkan tidak bisa dijadwal ulang.';

const RESCHEDULE = '[data-testid="session-reschedule"]';
const COMPLETE = '[data-testid="session-complete"]';
const ATTENDANCE = '[data-testid="session-take-attendance"]';
const NOTICE = '[data-testid="session-action-notice"]';

/** `in_progress` on purpose: it is the only status that renders BOTH buttons. */
function session(status = 'in_progress') {
  return {
    id: 'ses-1',
    learning_group_id: 'grp-1',
    starts_at: '2026-07-18T09:00:00+07:00',
    ends_at: '2026-07-18T10:30:00+07:00',
    room: 'R1',
    status,
  };
}

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: {
            takeAttendance: 'Ambil presensi',
            reschedule: 'Reschedule',
            markDone: 'Tandai selesai',
          },
          tutor: {
            sessionDetail: {
              noManageAbility: NO_MANAGE_ABILITY,
              rescheduleClosed: RESCHEDULE_CLOSED,
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView(status = 'in_progress') {
  setActivePinia(createPinia());
  // `getSession` resolves the record directly — no `{ items }` page.
  // A wrapped value would render an empty panel and every assertion
  // below would then pass or fail for the wrong reason.
  vi.mocked(TutoringBimbelService.getSession).mockResolvedValue(
    session(status) as never,
  );

  const w = mount(SessionDetail, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        // Renders the slot: a bare `true` stub would swallow the whole
        // action row and "the button is disabled" would pass because
        // nothing exists at all.
        AsyncView: {
          props: ['state'],
          template: `<div><slot v-if="state?.status === 'content'" :data="state.data" /></div>`,
        },
        Modal: { template: '<div data-testid="modal"><slot /></div>' },
        BottomSheetFooter: true,
        // Button is intentionally left REAL — see note 2 in the header.
      },
    },
  });
  await flushPromises();
  return w;
}

/**
 * The view's own `<script setup>` bindings.
 *
 * Reaching past the DOM is deliberate, not laziness: a click on a
 * disabled node is a no-op under VTU (header note 5), so calling the
 * handler is the ONLY way to exercise — and therefore to pin — the
 * `if (…BlockedReason.value) return` guards inside them. Those guards
 * are load-bearing beyond the button: the reschedule dialog is a
 * SIBLING of the AsyncView branch that owns the row, so the button's
 * own `disabled` does not cover it.
 */
function handlers(w: { vm: unknown }) {
  return w.vm as {
    rescheduleAction: () => void;
    completeSession: () => Promise<void>;
  };
}

describe('tutor session detail — write actions are gated on tutoring.session.manage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    grantedAbilities = [...TUTOR_DEFAULTS];
  });

  it('reads the grant off the /me snapshot via useMe().can', async () => {
    await mountView();

    // Never `roles[].permission_keys`: that list is unscoped and exists
    // only for the role switcher.
    expect(canSpy).toHaveBeenCalledWith(MANAGE);
  });

  describe('default tutor (no tutoring.session.manage)', () => {
    it('still renders both controls, each keeping its label', async () => {
      const w = await mountView();

      // Existence first. Everything below is meaningless if the buttons
      // were simply removed from the row.
      expect(w.find(RESCHEDULE).exists()).toBe(true);
      expect(w.find(COMPLETE).exists()).toBe(true);
      expect(w.find(RESCHEDULE).text()).toContain('Reschedule');
      expect(w.find(COMPLETE).text()).toContain('Tandai selesai');
    });

    it('disables Reschedule', async () => {
      const w = await mountView();

      expect(w.find(RESCHEDULE).exists()).toBe(true);
      expect(w.find(RESCHEDULE).attributes('disabled')).toBeDefined();
    });

    it('disables Tandai selesai', async () => {
      const w = await mountView();

      expect(w.find(COMPLETE).exists()).toBe(true);
      expect(w.find(COMPLETE).attributes('disabled')).toBeDefined();
    });

    it('shows the reason on screen, in words, not as a translation key', async () => {
      const w = await mountView();

      const notice = w.find(NOTICE);
      expect(notice.exists()).toBe(true);
      expect(notice.text()).toContain(NO_MANAGE_ABILITY);

      // A key echoed back by vue-i18n would satisfy a naive
      // `toContain('...noManageAbility')`; it cannot satisfy this.
      expect(notice.text()).not.toContain('tutoring2.');

      // VISIBLE, unlike the sr-only reason lines the admin CTAs use —
      // a tutor who cannot press the button has to be able to read why.
      expect(notice.classes()).not.toContain('sr-only');
      expect(notice.isVisible()).toBe(true);
    });

    it('carries the reason on each control, for pointer and screen reader', async () => {
      const w = await mountView();

      for (const sel of [RESCHEDULE, COMPLETE]) {
        expect(w.find(sel).attributes('title')).toBe(NO_MANAGE_ABILITY);
        expect(w.find(sel).attributes('aria-describedby')).toBe('session-action-notice');
      }

      // The id the buttons point at must actually exist on the page.
      expect(w.find('#session-action-notice').exists()).toBe(true);
    });

    it('states the reason once, not once per blocked button', async () => {
      const w = await mountView();

      const lines = w.findAll(`${NOTICE} p`);
      expect(lines).toHaveLength(1);
      expect(lines[0].text()).toBe(NO_MANAGE_ABILITY);
    });

    it('keeps the reschedule form shut even when its handler is called outright', async () => {
      const w = await mountView();

      // Nothing open to begin with — otherwise the assertion after the
      // call could be describing a dialog that never opens for anyone.
      expect(w.find('[data-testid="modal"]').exists()).toBe(false);

      handlers(w).rescheduleAction();
      await flushPromises();

      // The behavioural half of the gate: the whole defect was a tutor
      // filling in this form before the server refused it. Deleting the
      // guard at the top of `rescheduleAction` turns this red; clicking
      // the disabled button instead would not (header note 5).
      expect(w.find('[data-testid="modal"]').exists()).toBe(false);
      expect(TutoringBimbelService.rescheduleSession).not.toHaveBeenCalled();
    });

    it('never posts to the complete endpoint even when its handler is called outright', async () => {
      const w = await mountView();

      await handlers(w).completeSession();
      await flushPromises();

      // Same shape: this is the guard inside `completeSession`, not the
      // `disabled` attribute, being held to account.
      expect(TutoringBimbelService.completeSession).not.toHaveBeenCalled();
    });

    it('leaves Ambil presensi alone', async () => {
      const w = await mountView();

      // `mark_attendance` IS a tutor key. Gating this would be the
      // opposite bug: a working button made dead.
      expect(w.find(ATTENDANCE).exists()).toBe(true);
      expect(w.find(ATTENDANCE).attributes('disabled')).toBeUndefined();

      await w.get(ATTENDANCE).trigger('click');
      expect(push).toHaveBeenCalled();
    });
  });

  describe('tenant that granted its tutor role the key', () => {
    beforeEach(() => {
      grantedAbilities = [...TUTOR_DEFAULTS, MANAGE];
    });

    it('enables Reschedule', async () => {
      const w = await mountView();

      expect(w.find(RESCHEDULE).exists()).toBe(true);
      expect(w.find(RESCHEDULE).attributes('disabled')).toBeUndefined();
    });

    it('enables Tandai selesai', async () => {
      const w = await mountView();

      expect(w.find(COMPLETE).exists()).toBe(true);
      expect(w.find(COMPLETE).attributes('disabled')).toBeUndefined();
    });

    it('drops the reason entirely — nothing is being refused', async () => {
      const w = await mountView();

      expect(w.find(NOTICE).exists()).toBe(false);
      expect(w.find(RESCHEDULE).attributes('title')).toBeUndefined();
      expect(w.find(COMPLETE).attributes('title')).toBeUndefined();
      expect(w.find(RESCHEDULE).attributes('aria-describedby')).toBeUndefined();
      expect(w.find(COMPLETE).attributes('aria-describedby')).toBeUndefined();
    });

    it('opens the reschedule form again', async () => {
      const w = await mountView();

      await w.get(RESCHEDULE).trigger('click');
      await flushPromises();

      expect(w.find('[data-testid="modal"]').exists()).toBe(true);
    });

    it('calls the complete endpoint again', async () => {
      vi.mocked(TutoringBimbelService.completeSession).mockResolvedValue({} as never);
      const w = await mountView();

      await w.get(COMPLETE).trigger('click');
      await flushPromises();

      expect(TutoringBimbelService.completeSession).toHaveBeenCalledWith('ses-1');
    });
  });

  describe('status rule for Reschedule, mirroring RescheduleSessionAction', () => {
    beforeEach(() => {
      grantedAbilities = [...TUTOR_DEFAULTS, MANAGE];
    });

    // `RescheduleSessionAction` refuses DONE and CANCELLED and nothing
    // else. That is state, knowable before the form opens — unlike
    // "ends_at must follow starts_at", which depends on what is typed
    // and still travels back as a 422.
    it.each(['done', 'cancelled'])(
      'refuses a %s session even with the ability, and says why',
      async (status) => {
        const w = await mountView(status);

        expect(w.find(RESCHEDULE).exists()).toBe(true);
        expect(w.find(RESCHEDULE).attributes('disabled')).toBeDefined();
        expect(w.find(RESCHEDULE).attributes('title')).toBe(RESCHEDULE_CLOSED);
        expect(w.find(NOTICE).text()).toContain(RESCHEDULE_CLOSED);
      },
    );

    it('allows a scheduled session', async () => {
      const w = await mountView('scheduled');

      expect(w.find(RESCHEDULE).exists()).toBe(true);
      expect(w.find(RESCHEDULE).attributes('disabled')).toBeUndefined();
    });
  });

  /**
   * The `v-if="session.status === 'in_progress'"` on "Tandai selesai".
   *
   * `completeBlockedReason` is ability-ONLY on purpose — the status half
   * is delegated to that `v-if`, and the view's docblock calls the
   * ability gate ADDITIONAL to it. Nothing else in this file looks at
   * it, so dropping the `v-if` would leave a live "Tandai selesai" on a
   * session the backend refuses to close and fail no test.
   *
   * These run WITH the grant precisely so the ability gate cannot be
   * what makes them pass.
   */
  describe('status rule for Tandai selesai, held by the v-if not by the ability', () => {
    beforeEach(() => {
      grantedAbilities = [...TUTOR_DEFAULTS, MANAGE];
    });

    it.each(['scheduled', 'done', 'cancelled'])(
      'keeps Tandai selesai off a %s session even for a tutor holding the key',
      async (status) => {
        const w = await mountView(status);

        // The row really rendered: without this the assertion below
        // would also pass on a screen that drew nothing at all.
        expect(w.find(ATTENDANCE).exists()).toBe(true);

        expect(w.find(COMPLETE).exists()).toBe(false);
      },
    );

    it('offers it on the one status that is actually running', async () => {
      const w = await mountView('in_progress');

      // The other half of the pair. Without it, a selector that matched
      // nothing would satisfy every assertion above.
      expect(w.find(COMPLETE).exists()).toBe(true);
      expect(w.find(COMPLETE).attributes('disabled')).toBeUndefined();
    });
  });

  /**
   * No grant AND a closed session — the cell neither block above mounts.
   *
   * The default-tutor block only ever looked at `in_progress`, and the
   * status block only ever ran WITH the grant, so the precedence inside
   * `rescheduleBlockedReason` — ability first, status second — was
   * never observed. `grantedAbilities` stays at the tutor defaults here.
   */
  describe('default tutor on a session that is already closed', () => {
    it.each(['done', 'cancelled'])(
      'names the missing permission, not the status, on a %s session',
      async (status) => {
        const w = await mountView(status);

        expect(w.find(RESCHEDULE).exists()).toBe(true);
        expect(w.find(RESCHEDULE).attributes('disabled')).toBeDefined();
        expect(w.find(RESCHEDULE).attributes('title')).toBe(NO_MANAGE_ABILITY);

        // One line, and it is the permission one. Telling this tutor
        // the session is closed would send them to ask for the wrong
        // thing — the grant is what they are missing, and it is what
        // they would still be missing on a session that was open.
        const lines = w.findAll(`${NOTICE} p`);
        expect(lines).toHaveLength(1);
        expect(lines[0].text()).toBe(NO_MANAGE_ABILITY);
        expect(w.find(NOTICE).text()).not.toContain(RESCHEDULE_CLOSED);

        // "Tandai selesai" is not on screen for a closed session, so no
        // reason for it may be listed either.
        expect(w.find(COMPLETE).exists()).toBe(false);
      },
    );
  });
});

/**
 * The copy asserted above has to be the copy that ships. Without this,
 * renaming a key or emptying a value would leave every assertion above
 * green against strings that no longer exist in either locale file.
 */
describe('the refusal copy ships in both locales', () => {
  const KEYS = ['noManageAbility', 'rescheduleClosed'] as const;

  it.each(['id', 'en'])('%s.json carries every reason key', async (locale) => {
    const messages = (await import(`@/locales/${locale}.json`)).default;
    const block = messages.tutoring2.tutor.sessionDetail;

    for (const key of KEYS) {
      expect(block[key], `${locale}.json is missing ${key}`).toBeTruthy();
      // Keys are English; the VALUE must be prose, not the key echoed.
      expect(block[key]).not.toContain('tutoring2.');
    }
  });

  it('id.json is the exact copy this spec asserts on screen', async () => {
    const messages = (await import('@/locales/id.json')).default;
    const block = messages.tutoring2.tutor.sessionDetail;

    expect(block.noManageAbility).toBe(NO_MANAGE_ABILITY);
    expect(block.rescheduleClosed).toBe(RESCHEDULE_CLOSED);
  });
});

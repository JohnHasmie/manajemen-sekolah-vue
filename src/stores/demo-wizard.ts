/**
 * Register-demo wizard store.
 *
 * Single source of truth for the wizard UI:
 *   - `currentStep` (0..9, indexed against DEMO_STEPS)
 *   - `payload` (the working answers; saved on every mutation)
 *   - `result` (set when provision succeeds; step 10 reads it)
 *
 * Persistence model:
 *   1. Every mutation writes to localStorage immediately so a tab
 *      reload picks up where the user left off.
 *   2. Every step change also fires DemoService.saveWizardState
 *      (debounced) so a different device can resume after Google
 *      sign-in. The auth response carries `wizard_resume` which the
 *      store uses to skip past completed steps on hydrate.
 *   3. After successful provision, both stores clear localStorage
 *      to avoid stale credentials lingering after logout.
 */
import { defineStore } from 'pinia';
import { DemoService } from '@/services/demo.service';
import { storage } from '@/lib/storage';
import { useAuthStore } from '@/stores/auth';
import {
  DEMO_STEPS,
  defaultWizardPayload,
  validateRequester,
  type DemoPendingResponse,
  type DemoStepKey,
  type DemoWizardPayload,
} from '@/types/demo';

const LS_KEY = 'demo_wizard_state_v1';

interface PersistedShape {
  currentStep: number;
  payload: DemoWizardPayload;
  updatedAt: string;
  /**
   * The user.id whose progress this represents. On hydrate we compare
   * against the currently-signed-in user — if it doesn't match, the
   * stored state is treated as belonging to a different account and
   * discarded so the new user starts at step 1 with fresh defaults.
   */
  userId?: string;
  /**
   * The pending-request receipt returned by a successful provision().
   * Persisted so a reload of the pending/"Menunggu" screen recovers the
   * receipt and keeps rendering the pending state — instead of dropping
   * the user back onto the identity FORM. In-memory `result` was lost on
   * reload before; this is the field that makes the pending state durable.
   */
  result?: DemoPendingResponse | null;
}

interface State {
  currentStep: number;
  payload: DemoWizardPayload;
  isLoading: boolean;
  isProvisioning: boolean;
  error: string | null;
  /**
   * Pending-request receipt set when submit succeeds. The demo is NOT
   * activated yet — step `done` reads this to show the "request
   * received, await validation" confirmation.
   */
  result: DemoPendingResponse | null;
  /** Set by hydrate() once we've talked to the server at least once. */
  hydrated: boolean;
  /**
   * Flipped true the first time the user hits Submit on the requester
   * step. Lets that step reveal ALL pending validation errors at once
   * (not just touched fields) so nothing required is silently missed.
   */
  requesterSubmitAttempted: boolean;
}

let saveTimer: ReturnType<typeof setTimeout> | null = null;

export const useDemoWizardStore = defineStore('demoWizard', {
  state: (): State => ({
    currentStep: 0,
    payload: defaultWizardPayload(),
    isLoading: false,
    isProvisioning: false,
    error: null,
    result: null,
    hydrated: false,
    requesterSubmitAttempted: false,
  }),

  getters: {
    currentKey: (s): DemoStepKey => DEMO_STEPS[s.currentStep] ?? 'welcome',
    /** 1-based position of the current step, for "Langkah X dari Y" copy. */
    stepNumber: (s) => s.currentStep + 1,
    /** Total wizard steps — derived from DEMO_STEPS so the counter never drifts. */
    stepTotal: () => DEMO_STEPS.length,
    canGoBack: (s) => s.currentStep > 0 && !s.isProvisioning,
    canGoNext: (s) => s.currentStep < DEMO_STEPS.length - 1 && !s.isProvisioning,
    progress: (s) => ((s.currentStep + 1) / DEMO_STEPS.length) * 100,
    /** True when the requester identity form passes client validation. */
    requesterValid: (s) => Object.keys(validateRequester(s.payload.requester)).length === 0,
    /**
     * Whether the user has produced enough wizard (school) data to be
     * allowed onto the SEPARATE identity screen. Used by that screen's
     * route guard: a direct visit / refresh with no school name means
     * the wizard was never completed, so we bounce back to its start
     * instead of letting the user submit an empty request. We key off
     * the school name because it's the first required answer and is
     * mandatory for a meaningful demo request.
     */
    hasWizardData: (s) =>
      s.payload.tenant_type === 'tutoring'
        ? (s.payload.tutoring.name ?? '').trim().length > 0
        : (s.payload.school.name ?? '').trim().length > 0,
  },

  actions: {
    /**
     * Bootstrap: load server state, fall back to localStorage, fall
     * back to defaults. Called once when the user lands on the
     * /register-demo route.
     */
    async hydrate(): Promise<void> {
      if (this.hydrated) return;
      this.isLoading = true;
      const auth = useAuthStore();
      const currentUserId = auth.user?.id ?? null;
      // Snapshot any answers the user has ALREADY typed into this live
      // store before we go fetch remote/local state. hydrate() can race
      // the hand-off to the identity screen: that screen awaits hydrate()
      // in its onMounted, and if the store wasn't flagged `hydrated` yet
      // (e.g. the wizard's fire-and-forget hydrate hadn't resolved, or
      // the debounced/flushed remote save for the latest school answer
      // hadn't committed server-side), a remote payload with a STALE,
      // empty school name would clobber the in-memory answers. That makes
      // `hasWizardData` false on the identity screen's guard and bounces
      // the user back to the wizard — the exact regression we're fixing.
      // So we treat freshly-entered in-memory data as authoritative and
      // never let server/local state overwrite a non-empty school name.
      const hadInMemoryData = this.hasWizardData;
      const inMemoryPayload = this.payload;
      const inMemoryStep = this.currentStep;
      // Restore the persisted pending-request receipt FIRST, before any
      // remote/local payload handling, so it survives every hydrate path —
      // including the early `remote?.payload` return below. Without this a
      // reload of the pending/"Menunggu" screen would null out `result` and
      // fall through to the identity FORM. Read once, guard against an empty
      // or corrupt LS entry (storage.get already swallows parse errors and
      // returns null), and never clobber a receipt already held in memory.
      const persisted = storage.get<PersistedShape>(LS_KEY);
      if (persisted?.result && !this.result) {
        this.result = persisted.result;
      }
      try {
        const remote = await DemoService.loadWizardState();
        if (remote?.payload) {
          if (hadInMemoryData) {
            // Keep the answers the user is actively entering; don't let a
            // lagging server snapshot wipe them. Persist so the freshest
            // state wins on the next cross-device resume too.
            this.payload = inMemoryPayload;
            this.currentStep = inMemoryStep;
          } else {
            this.payload = mergeWithDefaults(remote.payload);
            this.currentStep = clamp(remote.current_step, 0, DEMO_STEPS.length - 1);
          }
          this.hydrated = true;
          this._persist();
          return;
        }

        // Server returned null — that means this user has no completed
        // provision (or just signed up). Older persisted state may carry
        // a step index for the removed `requester` / `done` steps (the
        // identity + pending screens now live on a separate route). Such
        // a leftover would land the user past the wizard's real last
        // step with nothing to show, so reset to step 0 for a clean run.
        // `clamp` below also defensively caps any over-large index.
        const lsRaw = storage.get<PersistedShape>(LS_KEY);
        if (lsRaw && lsRaw.currentStep > DEMO_STEPS.length - 1) {
          storage.remove(LS_KEY);
          this.hydrated = true;
          return;
        }
        // Try localStorage second — handles offline-first-visit case.
        // But discard if the saved state belongs to a different user
        // (re-test flow: kamillabs's leftover progress shouldn't show
        // up when a different account signs in to the same browser).
        const local = storage.get<PersistedShape>(LS_KEY);
        if (local?.payload) {
          // Resume ONLY when we can prove the saved state belongs to
          // the currently-signed-in user. Without that proof — either
          // because the LS entry pre-dates the namespace patch (no
          // userId field) or the IDs don't match — wipe it. Better to
          // restart at step 1 than risk replaying someone else's
          // half-finished wizard.
          const sameUser =
            !!local.userId &&
            !!currentUserId &&
            local.userId === currentUserId;
          // Same guard as the remote branch: never let a localStorage read
          // overwrite answers the user has just typed into the live store.
          if (sameUser && !hadInMemoryData) {
            this.payload = mergeWithDefaults(local.payload);
            this.currentStep = clamp(local.currentStep, 0, DEMO_STEPS.length - 1);
          } else if (!sameUser) {
            storage.remove(LS_KEY);
          }
        }
      } catch {
        // Hydrate is best-effort. Defaults are fine.
      } finally {
        this.hydrated = true;
        this.isLoading = false;
      }
    },

    /** Replace a slice of the payload immutably + persist. */
    patchPayload<K extends keyof DemoWizardPayload>(
      key: K,
      value: Partial<DemoWizardPayload[K]>,
    ): void {
      this.payload = {
        ...this.payload,
        [key]: { ...this.payload[key], ...value },
      };
      this._persist();
      this._scheduleRemoteSave();
    },

    /**
     * Replace the whole working payload immutably. Used by the
     * conversational wizard: every question hands back a fully-built
     * next-payload via its `setValue(payload, draft)` predicate, and
     * we drop it in wholesale rather than slicing it back per-key.
     * Keeps Pinia subscriptions in one fire instead of N.
     */
    replacePayload(next: DemoWizardPayload): void {
      this.payload = next;
      this._persist();
      this._scheduleRemoteSave();
    },

    /**
     * Pick the tenant kind on the landing screen. Defaults to
     * 'school' for back-compat with persisted payloads from before
     * tenant_type existed.
     */
    setTenantType(t: 'school' | 'tutoring'): void {
      this.payload = { ...this.payload, tenant_type: t };
      this._persist();
      this._scheduleRemoteSave();
    },

    goTo(step: number): void {
      this.currentStep = clamp(step, 0, DEMO_STEPS.length - 1);
      this._persist();
      this._scheduleRemoteSave();
    },

    next(): void {
      if (this.canGoNext) this.goTo(this.currentStep + 1);
    },

    back(): void {
      if (this.canGoBack) this.goTo(this.currentStep - 1);
    },

    /**
     * Mark that the user pressed Submit on the requester step so that
     * step reveals every pending validation error at once. Idempotent.
     */
    markRequesterSubmitAttempted(): void {
      this.requesterSubmitAttempted = true;
    },

    /**
     * Submit the final demo request. NO LONGER activates a demo — it
     * records a PENDING request the KamilEdu team reviews manually.
     * Returns true on success so the view can advance to the
     * "request received" confirmation step.
     */
    async provision(): Promise<boolean> {
      this.error = null;
      this.isProvisioning = true;
      try {
        this.result = await DemoService.provision(this.payload);
        // Write the receipt to localStorage immediately so a reload of the
        // pending/"Menunggu" screen recovers it via hydrate() and keeps
        // showing the pending state rather than re-rendering the form.
        this._persist();
        return true;
      } catch (e) {
        this.error = (e as Error).message;
        return false;
      } finally {
        this.isProvisioning = false;
      }
    },

    /**
     * "Mulai ulang" from step 10's footer or settings. Clears local
     * + remote state, resets to defaults at step 0.
     */
    async reset(): Promise<void> {
      this.payload = defaultWizardPayload();
      this.currentStep = 0;
      this.result = null;
      this.error = null;
      this.requesterSubmitAttempted = false;
      storage.remove(LS_KEY);
      await DemoService.resetWizardState();
    },

    // ── Internal helpers ────────────────────────────────────────

    _persist(): void {
      const auth = useAuthStore();
      storage.set<PersistedShape>(LS_KEY, {
        currentStep: this.currentStep,
        payload: this.payload,
        updatedAt: new Date().toISOString(),
        userId: auth.user?.id,
        // Persist the pending-request receipt too so the "Menunggu" screen
        // is recoverable across reloads. clearLocalProgress()/reset() remove
        // the whole LS_KEY entry, which correctly drops this as well.
        result: this.result,
      });
    },

    /**
     * Called from the final "Masuk dashboard" handler after a
     * successful provision. Wipes localStorage so the next time this
     * browser visits /register-demo with a different account it
     * starts at step 1 with default answers. We deliberately do NOT
     * touch server state — the completed `demo_wizard_states` row is
     * the idempotency anchor and must stay.
     */
    clearLocalProgress(): void {
      storage.remove(LS_KEY);
    },

    _scheduleRemoteSave(): void {
      // The /register-demo wizard is PUBLIC, but /demo/wizard-state is behind
      // auth:sanctum. An anonymous visitor firing this autosave just gets a
      // 401 on every step change (harmless — localStorage already holds the
      // answers — but it spams the network log + LogRocket). Skip the remote
      // save until the user is authenticated; cross-device resume only matters
      // for logged-in users anyway.
      if (!useAuthStore().isAuthenticated) return;
      if (saveTimer) clearTimeout(saveTimer);
      saveTimer = setTimeout(() => {
        DemoService.saveWizardState({
          current_step: this.currentStep,
          payload: this.payload,
        });
        saveTimer = null;
      }, 700);
    },

    /**
     * Cancel any pending debounced remote save and fire it immediately.
     * Called when the user leaves the wizard for the separate identity
     * screen so the latest school answers are persisted server-side
     * right away (cross-device resume), without waiting out the debounce.
     */
    flushRemoteSave(): void {
      if (saveTimer) {
        clearTimeout(saveTimer);
        saveTimer = null;
      }
      // Same guard as _scheduleRemoteSave — no anonymous 401s.
      if (!useAuthStore().isAuthenticated) return;
      DemoService.saveWizardState({
        current_step: this.currentStep,
        payload: this.payload,
      });
    },

    /**
     * Prepare a reliable hand-off to the SEPARATE identity screen when the
     * user finishes the wizard's last step. Persist the live answers to
     * localStorage, flush the debounced remote save, and — crucially —
     * mark the store `hydrated` so the identity screen's `onMounted`
     * `await wizard.hydrate()` is a guaranteed no-op. Without that flag the
     * identity guard could re-fetch a not-yet-committed (empty) server
     * snapshot and clobber the in-memory school answers, making
     * `hasWizardData` false and bouncing the user back to the wizard.
     * The in-memory answers are the source of truth at this point.
     */
    prepareIdentityHandoff(): void {
      this._persist();
      this.flushRemoteSave();
      // The live store already holds the authoritative answers, so there's
      // nothing left to hydrate FROM — flag it hydrated so the identity
      // screen trusts the in-memory payload and never re-fetches/clobbers.
      this.hydrated = true;
    },
  },
});

function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, Math.floor(n)));
}

/**
 * Defensive merge — backend persists arbitrary JSON, but the FE
 * type defines new optional fields over time. mergeWithDefaults
 * fills in any missing keys so the form bindings never see undefined.
 *
 * Also handles cross-cutover hydration: a payload persisted before
 * the 2026-06-26 English-enum rename uses the legacy keys
 * `tenant_type: 'sekolah' | 'bimbel'` and `bimbel: {...}`. We
 * normalise those to the canonical `'school' | 'tutoring'` +
 * `tutoring: {...}` shape on hydrate so the rest of the wizard
 * never sees a mixed payload.
 */
function mergeWithDefaults(partial: Partial<DemoWizardPayload>): DemoWizardPayload {
  const d = defaultWizardPayload();
  // Normalise legacy tenant_type values to the canonical English form.
  const rawTenant = (partial.tenant_type ?? d.tenant_type) as string;
  const tenantType: DemoWizardPayload['tenant_type'] =
    rawTenant === 'bimbel' || rawTenant === 'tutoring'
      ? 'tutoring'
      : 'school';
  // The `tutoring` slice may have been persisted under the legacy
  // `bimbel` key — read both and let the new key win when present.
  const legacyTutoring = (partial as { bimbel?: Partial<typeof d.tutoring> }).bimbel;
  const partialTutoring = partial.tutoring ?? legacyTutoring;
  return {
    // tenant_type was added with the tutoring feature; a persisted payload
    // from before that has no field, leaving the wizard with `undefined`
    // and no way to fork the questions. Default to the school path.
    tenant_type: tenantType,
    school: {
      ...d.school,
      ...(partial.school ?? {}),
      // A restored payload (server wizard-state or localStorage) can carry
      // `school.name: null`. The spread above would let that null OVERRIDE
      // the '' default, and Step2School then does `query.value.length` /
      // `q.trim()` on it → "Cannot read properties of null" → the School
      // step renders blank on reload. Coerce null back to the default ''.
      name: partial.school?.name ?? d.school.name,
    },
    identity: { ...d.identity, ...(partial.identity ?? {}) },
    subjects: { ...d.subjects, ...(partial.subjects ?? {}) },
    teachers: { ...d.teachers, ...(partial.teachers ?? {}) },
    classes: { ...d.classes, ...(partial.classes ?? {}) },
    students: { ...d.students, ...(partial.students ?? {}) },
    parents: { ...d.parents, ...(partial.parents ?? {}) },
    schedule: { ...d.schedule, ...(partial.schedule ?? {}) },
    billing: { ...d.billing, ...(partial.billing ?? {}) },
    scenarios: { ...d.scenarios, ...(partial.scenarios ?? {}) },
    // The tutoring slice was added later, so any older persisted payload
    // (from server or localStorage) is missing it. Without this merge,
    // `payload.tutoring` was `undefined`, and as soon as the user picked
    // the tutoring tenant the wizard's first `p.tutoring.name` /
    // `p.tutoring.city` read crashed with "Cannot read properties of
    // undefined". Also accepts the pre-rename `bimbel` key (see above).
    tutoring: {
      ...d.tutoring,
      ...(partialTutoring ?? {}),
      // Same null-coercion pattern as `school.name`: keep the default
      // empty string if a restored payload has `name: null`.
      name: partialTutoring?.name ?? d.tutoring.name,
      // Migrate legacy Indonesian target_levels values to canonical
      // English. A user whose wizard state was persisted before the
      // Phase-4 cutover has `['SMA']` in localStorage; submitting
      // that now 422s on the backend (which only accepts
      // ELEMENTARY/JUNIOR_HIGH/SENIOR_HIGH + SNBT/KARYAWAN/UMUM).
      // SNBT/KARYAWAN/UMUM stay as-is; other values pass through.
      target_levels: (partialTutoring?.target_levels ?? d.tutoring.target_levels)
        .map((v: string) =>
          v === 'SD' ? 'ELEMENTARY'
            : v === 'SMP' ? 'JUNIOR_HIGH'
              : v === 'SMA' || v === 'SMK' ? 'SENIOR_HIGH'
                : v,
        ) as DemoWizardPayload['tutoring']['target_levels'],
    },
    requester: {
      ...d.requester,
      ...(partial.requester ?? {}),
      // Nested map needs its own merge so a partially-persisted
      // requester doesn't drop the default empty channels.
      social_media: {
        ...d.requester.social_media,
        ...(partial.requester?.social_media ?? {}),
      },
    },
  };
}

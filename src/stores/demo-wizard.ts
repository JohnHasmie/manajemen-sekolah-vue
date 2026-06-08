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
    canGoBack: (s) => s.currentStep > 0 && !s.isProvisioning,
    canGoNext: (s) => s.currentStep < DEMO_STEPS.length - 1 && !s.isProvisioning,
    progress: (s) => ((s.currentStep + 1) / DEMO_STEPS.length) * 100,
    /** True when the requester identity form passes client validation. */
    requesterValid: (s) => Object.keys(validateRequester(s.payload.requester)).length === 0,
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
      try {
        const remote = await DemoService.loadWizardState();
        if (remote?.payload) {
          this.payload = mergeWithDefaults(remote.payload);
          this.currentStep = clamp(remote.current_step, 0, DEMO_STEPS.length - 1);
          this.hydrated = true;
          this._persist();
          return;
        }

        // Server returned null — that means this user has no completed
        // provision (or just signed up). If localStorage still points
        // at the final Done step from a previous failed attempt,
        // there's no result to display and the user is stuck on the
        // "Tekan tombol Buat sekolah demo..." placeholder. Reset to
        // step 0 so they can run the wizard cleanly.
        const lsRaw = storage.get<PersistedShape>(LS_KEY);
        if (lsRaw && lsRaw.currentStep >= DEMO_STEPS.length - 1) {
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
          if (sameUser) {
            this.payload = mergeWithDefaults(local.payload);
            this.currentStep = clamp(local.currentStep, 0, DEMO_STEPS.length - 1);
          } else {
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
      if (saveTimer) clearTimeout(saveTimer);
      saveTimer = setTimeout(() => {
        DemoService.saveWizardState({
          current_step: this.currentStep,
          payload: this.payload,
        });
        saveTimer = null;
      }, 700);
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
 */
function mergeWithDefaults(partial: Partial<DemoWizardPayload>): DemoWizardPayload {
  const d = defaultWizardPayload();
  return {
    school: { ...d.school, ...(partial.school ?? {}) },
    identity: { ...d.identity, ...(partial.identity ?? {}) },
    subjects: { ...d.subjects, ...(partial.subjects ?? {}) },
    teachers: { ...d.teachers, ...(partial.teachers ?? {}) },
    classes: { ...d.classes, ...(partial.classes ?? {}) },
    students: { ...d.students, ...(partial.students ?? {}) },
    parents: { ...d.parents, ...(partial.parents ?? {}) },
    schedule: { ...d.schedule, ...(partial.schedule ?? {}) },
    billing: { ...d.billing, ...(partial.billing ?? {}) },
    scenarios: { ...d.scenarios, ...(partial.scenarios ?? {}) },
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

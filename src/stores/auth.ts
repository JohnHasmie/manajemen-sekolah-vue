/**
 * Auth store — Pinia equivalent of Flutter's AuthController + AuthState.
 *
 * State shape mirrors `lib/features/auth/presentation/controllers/auth_controller.dart`:
 *   - step:          current flow step (login | otp | school | role | done)
 *   - user:          authenticated user, populated once step === 'done'
 *   - token:         Sanctum bearer token (persisted to localStorage)
 *   - schools/roles: pickers when the response demands them
 *   - lastResponse:  normalized response from the last auth call (used by
 *                    the view to react to flow transitions)
 *   - isLoading / error
 *
 * The store is the single source of truth — the view is dumb and reads
 * `step` to decide which sub-form to render (login → otp → school → role
 * → done). This matches the Flutter screen's behaviour where the form-card
 * body is dispatched via `buildCurrentAuthStep(authState)`.
 */
import { defineStore } from 'pinia';
import { AuthService } from '@/services/auth.service';
import { SchoolService } from '@/services/schools.service';
import { TeacherService } from '@/services/teachers.service';
import { useMeStore } from '@/stores/me';
import { storage, StorageKeys } from '@/lib/storage';
import type {
  AuthResponse,
  AuthStep,
  Role,
  School,
  User,
} from '@/types/auth';

/**
 * Normalizes backend role strings to canonical FE keys used by the
 * router and components. Backend ships canonical English
 * (`teacher` / `parent` / `student`); FE uses Indonesian short-form
 * (`teacher` / `parent` / `student`) as the *internal* canonical value
 * because the components and router meta hard-code it.
 *
 * Convert at the wire boundary, never inside the app.
 */
function normalizeRole(role: string | null | undefined): Role | null {
  // Defensive: backend sometimes returns a user payload without `role`
  // (e.g. when SwitchSchoolAction's auto-pick branch fired but the
  // Eloquent model serialization dropped the dynamic attribute).
  // Returning `null` lets the caller fall back to existing state
  // instead of crashing on `undefined.toLowerCase()`.
  if (!role || typeof role !== 'string') return null;
  const r = role.toLowerCase();
  if (r === 'admin' || r === 'administrator') return 'admin';
  if (r === 'guru' || r === 'teacher' || r === 'wali_kelas') return 'guru';
  if (
    r === 'wali' ||
    r === 'parent' ||
    r === 'orang_tua' ||
    r === 'wali_murid' ||
    r === 'walimurid'
  )
    return 'wali';
  if (r === 'siswa' || r === 'student') return 'siswa';
  if (r === 'staff') return 'staff';
  return r as Role;
}

/**
 * Make a school entry safe for display: ensure both `id` and `name`
 * are present using all known backend aliases. The login response
 * sometimes returns entries with only `school_id`/`nama_sekolah`,
 * which would otherwise render as invisible rows in the SchoolPill.
 */
function normalizeSchool(raw: any): School {
  if (!raw || typeof raw !== 'object') return raw as School;
  return {
    ...raw,
    id: String(raw.id ?? raw.school_id ?? raw.sekolah_id ?? ''),
    school_id: raw.school_id ?? raw.id,
    name: String(
      raw.name ??
        raw.school_name ??
        raw.nama_sekolah ??
        raw.nama ??
        'Sekolah',
    ),
    school_name: raw.school_name ?? raw.name ?? raw.nama_sekolah,
  } as School;
}

interface AuthState {
  step: AuthStep;
  user: User | null;
  token: string | null;
  schoolId: string | null;
  role: Role | null;
  /** Email retained across the OTP / picker steps. */
  pendingEmail: string | null;
  schools: School[];
  roles: Role[];
  lastResponse: AuthResponse | null;
  isLoading: boolean;
  error: string | null;
  /** Optional debug OTP echoed by the dev backend. */
  otpDebug: string | null;
  /** Server reachability flag, set by `checkHealth()` on screen mount. */
  serverOnline: boolean;
  /**
   * `teacher_profile.id` — distinct from `user.id`. Resolved lazily by
   * `hydrateSchoolsRoles()` for teacher accounts. Required by
   * /teaching-schedule/teacher/{id}, /teaching-schedule/daily-summary,
   * /recommendations (teacher_id), and any other endpoint that scopes
   * by the teacher profile row.
   */
  teacherProfileId: string | null;
  /**
   * Homeroom classes (kelas perwalian) the teacher oversees. Resolved
   * together with `teacherProfileId` from `/teacher/{user_id}`. Drives
   * the homeroom teacher chips in `<RoleToggleChipRow>` on Schedule / Presensi
   * / Activity Kelas / Gradebook / Rapor / Rekomendasi.
   */
  homeroomClasses: { id: string; name: string }[];
  /**
   * Which sign-in method started the current auth chain.
   *
   *   'password' → email + password (and its OTP continuation)
   *   'google'   → Google Identity Services
   *   null       → no chain in progress (logged out / never logged in)
   *
   * Why a store field, not a function arg: the chain spans several
   * round-trips — `login()` → `_autoAdvancePicker()` → `selectSchool()`
   * → `selectRole()`. Every one funnels into `_applyResponse(res)`,
   * which is the SINGLE place that decides whether
   * `res.dapat_buat_demo === true` routes the user to /register-demo.
   * That auto-route is only ever valid for a brand-new Google sign-up
   * (the wizard's intended entry point); for an email/password user
   * it is a misroute regardless of which step the flag arrives on
   * (e.g. a stale flag echoed back from /switch-school).
   *
   * Bug fixed: 2026-06-15 — multiple email+password logins (student /
   * admin / parent) were being bounced into the demo wizard because
   * the per-call `_stripDapatBuatDemo` only covered the FIRST hop and
   * the flag could still slip through on a follow-up picker round-trip.
   */
  authMethod: 'password' | 'google' | null;
}

export const useAuthStore = defineStore('auth', {
  state: (): AuthState => ({
    step: 'login',
    user: null,
    token: null,
    schoolId: null,
    role: null,
    pendingEmail: null,
    schools: [],
    roles: [],
    lastResponse: null,
    isLoading: false,
    error: null,
    otpDebug: null,
    serverOnline: true,
    teacherProfileId: null,
    homeroomClasses: [],
    authMethod: null,
  }),

  getters: {
    isAuthenticated: (s) => Boolean(s.token && s.user),
    /** Convenience accessor used by the router and AppShell. */
    activeRole(): Role | null {
      return this.user?.role ?? this.role;
    },
    /**
     * True when the logged-in user holds the platform `super_admin`
     * role. Super-admins act as `admin` for routing but unlock extra
     * KamilEdu-team surfaces (the Demo Requests review page).
     *
     * Checks both the active role and the full roles list — the
     * super-admin grant can sit alongside an `admin` role and the
     * active role is usually `admin`. This getter only drives UI
     * visibility; the authoritative check is the server-side
     * EnsureSuperAdmin middleware (a non-super-admin who reaches the
     * page anyway gets a 403 + a friendly empty state).
     */
    isSuperAdmin(): boolean {
      const SUPER = ['super_admin', 'superadmin', 'super-admin'];
      const active = String(this.user?.role ?? this.role ?? '').toLowerCase();
      if (SUPER.includes(active)) return true;
      const roles = this.user?.roles ?? this.roles ?? [];
      return roles.some((r) => SUPER.includes(String(r ?? '').toLowerCase()));
    },
    /**
     * The id to pass as `teacher_id` to multi-tenant endpoints.
     * Prefers the resolved `teacher_profile.id` (set by
     * `hydrateSchoolsRoles()`), falls back to `user.id` while it
     * hasn't been resolved yet.
     */
    teacherId(): string | null {
      return this.teacherProfileId ?? this.user?.id ?? null;
    },
    /**
     * Flat list of permission tokens the active user holds (RBAC Phase A,
     * backend MR !225). Read off `user.abilities` if present. Super-admins
     * implicitly clear every check (returns a sentinel `['*']`).
     *
     * Callers should use `hasAbility()` rather than indexing this list —
     * the wildcard handling lives there.
     */
    abilities(): string[] {
      if (this.isSuperAdmin) return ['*'];
      const list = this.user?.abilities;
      return Array.isArray(list) ? list : [];
    },
    /**
     * True when the active user holds the given permission token. Super
     * admins always pass. Used to gate sidebar items + page shells; the
     * authoritative gate stays server-side.
     *
     * Phase D preference: read from `useMeStore().snapshot.abilities`
     * — the definitive per-school+role set from `GET /me`. The auth
     * store also refreshes /me on login / selectSchool / selectRole,
     * so this getter re-runs whenever the snapshot changes.
     *
     * Legacy fallback: for the brief window before the first /me lands
     * (or in tests that skip /me), fall back to `user.abilities` if the
     * login response happened to include one. When no source has data,
     * fail-closed (returns false) so the sidebar never flashes a menu
     * item the user can't actually use.
     */
    hasAbility(): (perm: string) => boolean {
      const me = useMeStore();
      const snap = me.snapshot;
      if (snap) {
        if (snap.isSuperAdmin) return () => true;
        return (perm: string) => snap.abilities.has(perm);
      }
      // Legacy fallback path.
      if (this.isSuperAdmin) return () => true;
      const list = this.user?.abilities;
      const arr = Array.isArray(list) ? list : [];
      return (perm: string) => arr.includes(perm);
    },
  },

  actions: {
    // ── State mutators ────────────────────────────────────────────────
    _setLoading(v: boolean) {
      this.isLoading = v;
      if (v) this.error = null;
    },

    _setError(message: string) {
      this.error = message;
      this.isLoading = false;
    },

    _applyResponse(res: AuthResponse) {
      this.lastResponse = res;
      this.otpDebug = res.otp_debug ?? null;

      // Save token if provided mid-flow (crucial for pickers)
      if (res.token) {
        this.token = res.token;
        storage.set(StorageKeys.token, res.token);
      }

      // ── Super-admin short-circuit ─────────────────────────────────
      // A KamilEdu-team super-admin has NO school/role to pick — the
      // backend (edu_backend_core_api MR !115) returns the completed
      // shape directly: { is_super_admin: true, role: 'super_admin',
      // school: null } with NO pilih_sekolah / pilih_role flags. We
      // must complete the login immediately and SKIP the school/role
      // pickers entirely. Placed before every picker branch (and
      // before the require_otp branch is irrelevant — verify-otp's
      // response carries this same completed shape, NOT require_otp).
      //
      // We key on the explicit `is_super_admin` flag first, then fall
      // back to the role string so an older/looser backend response
      // still routes correctly. The authoritative gate stays
      // server-side (EnsureSuperAdmin middleware).
      const isSuperAdminRes =
        res.is_super_admin === true ||
        String(res.role ?? res.user?.role ?? '').toLowerCase() ===
          'super_admin';
      if (isSuperAdminRes && res.user) {
        // Pin the role to the canonical 'super_admin' so `activeRole`,
        // the router's roleHomePath lookup, and the `isSuperAdmin`
        // getter all agree — never let it fall back to 'admin' (which
        // would route to /admin and re-expose the school picker chrome).
        res.user.role = 'super_admin';
        this.role = 'super_admin';
        if (Array.isArray(res.user.schools)) {
          res.user.schools = res.user.schools.map(normalizeSchool);
        }
        // _completeLogin sets step='done'. The super-admin has no
        // active school (school: null) — leave schoolId untouched.
        this._completeLogin(res.token || this.token || '', res.user);
        return;
      }

      if (res.require_otp) {
        this.step = 'otp';
        return;
      }
      // Google login with no schools → register-demo path. The token
      // is already saved above; we keep `pendingEmail` so the wizard
      // can prefill display + credential previews. The view layer's
      // RegisterDemo route guard reads `step === 'register_demo'` to
      // allow access while keeping /admin etc. closed.
      //
      // GATE: only honor `dapat_buat_demo` when the current chain
      // started from Google sign-in. An email/password user landing
      // here (e.g. via /switch-school echoing the flag from a stale
      // backend code path) must NEVER be silently bounced into the
      // demo wizard — they came to sign in, not to sign up. The
      // per-call `_stripDapatBuatDemo` in `login()` / `verifyOtp()`
      // still runs as belt-and-suspenders, but this gate also covers
      // continuation hops (`selectSchool` / `selectRole`) that did
      // not strip.
      if (res.dapat_buat_demo && this.authMethod === 'google') {
        if (res.user) {
          // Treat the user as authenticated (we have the token) but
          // without a role yet. AppShell won't render — only the
          // /register-demo route does.
          this.user = res.user;
        }
        this.step = 'register_demo';
        // Fresh Google login with no schools = brand-new wizard run.
        // Wipe BOTH localStorage AND server-side wizard state so the
        // user starts at step 1 with default answers. The server row
        // is the more important purge — without it, hydrate() would
        // prefer remote state over LS and resurrect the stale step
        // even after the user clears their browser storage.
        try {
          storage.remove('demo_wizard_state_v1');
          // Fire-and-forget: server-state reset doesn't need to
          // block the UI. If it fails the FE's namespace check still
          // wipes any cross-user LS data on hydrate.
          import('@/services/demo.service').then((m) =>
            m.DemoService.resetWizardState().catch(() => {}),
          );
        } catch {
          // non-fatal — wizard hydrate has its own namespace check
        }
        return;
      }
      if (res.needsSchoolSelection) {
        this.schools = (res.schools ?? []).map(normalizeSchool);
        this.step = 'school';
        return;
      }
      if (res.needsRoleSelection) {
        this.roles = res.roles ?? [];
        // CRITICAL: capture school_id from the response's `school` /
        // `sekolah` field. Without this `selectRole()` later bails
        // with "School ID tidak ditemukan" because `this.schoolId`
        // is null — the school was decided server-side but never
        // mirrored into the FE store.
        const schoolFromRes =
          res.school ?? res.sekolah ?? res.selectedSchool ?? null;
        if (schoolFromRes) {
          const normalized = normalizeSchool(schoolFromRes);
          this.schoolId = normalized.id || normalized.school_id || this.schoolId;
          if (this.schoolId) storage.set(StorageKeys.schoolId, this.schoolId);
        }
        this.step = 'role';
        return;
      }
      if (res.user) {
        // Ensure user role is normalized before completing login.
        // If the backend payload omitted role (e.g. switch-school
        // auto-pick branch), fall back to the previously known role
        // OR the role we last persisted to localStorage.
        const normalized = normalizeRole(res.user.role);
        res.user.role = (normalized ?? this.role ?? this.user?.role ?? 'admin') as Role;
        // Pick up `school_name` (alias `nama_sekolah`) the backend
        // returns at the user level. Falls back to the top-level
        // school object some endpoints return after switchSchool.
        const raw = res.user as User & {
          nama_sekolah?: string | null;
        };
        if (!raw.school_name) {
          raw.school_name =
            raw.nama_sekolah ??
            res.school?.name ??
            res.school?.school_name ??
            res.school?.nama_sekolah ??
            res.selectedSchool?.name ??
            res.sekolah?.name ??
            res.sekolah?.nama_sekolah ??
            null;
        }
        // Normalize any embedded schools array so the SchoolPill
        // never sees null name fields.
        if (Array.isArray(res.user.schools)) {
          res.user.schools = res.user.schools.map(normalizeSchool);
        }
        this._completeLogin(res.token || this.token || '', res.user);
      }
    },

    _completeLogin(token: string, user: User) {
      // CRITICAL: only overwrite the in-memory token if the caller
      // passed a real one. SwitchSchoolAction deliberately returns
      // `token: null` when the user already has a valid Sanctum token
      // (to avoid rotating + breaking concurrent requests). Earlier
      // code resolved `null || this.token || ''` to `''` when this.token
      // was somehow lost mid-flow — that emptied storage too and the
      // very next API call hit 401, redirecting to /login.
      if (token && typeof token === 'string') {
        this.token = token;
        storage.set(StorageKeys.token, token);
      }
      // Hard guarantee: if we have no in-memory token, recover from
      // storage. Without this the role hub would 401 on first call.
      if (!this.token) {
        const stored = storage.get<string>(StorageKeys.token);
        if (stored) this.token = stored;
      }

      // Preserve existing schools and roles if the new user object from
      // switch-school / switch-role doesn't include them.
      if (this.user) {
        if (!user.schools && this.user.schools) {
          user.schools = this.user.schools;
        }
        if (!user.roles && this.user.roles) {
          user.roles = this.user.roles;
        }
      }

      this.user = user;
      this.schoolId = user.school_id ?? this.schoolId;
      const normalizedRole = normalizeRole(user.role);
      this.role = normalizedRole ?? this.role;
      this.step = 'done';
      this.error = null;
      this.isLoading = false;

      storage.set(StorageKeys.user, user);
      if (this.schoolId) storage.set(StorageKeys.schoolId, this.schoolId);
      if (this.role) storage.set(StorageKeys.role, this.role);

      // Phase D (RBAC): once the auth chain lands on `done`, kick off a
      // fresh /me fetch so every downstream view can gate off abilities.
      // Non-blocking — the picker step never depends on abilities, and
      // views that need them fail-closed (`can()` returns false while
      // the snapshot is still null).
      void useMeStore()
        .refresh()
        .catch(() => {
          // non-fatal — a super-admin without /me still routes via
          // `authMethod`/`isSuperAdmin` fallbacks.
        });

      // Cross-device language hydration: when the backend returns a
      // saved `preferred_language` on the user payload, adopt it so
      // a user who picked English on their phone gets English on
      // every other device too. `hydrateFromUser` is a no-op when
      // the value is null/unsupported/already-active and crucially
      // does NOT echo a PATCH back, so there's no infinite-update
      // loop. Dynamic-imported to avoid a load-order cycle (auth
      // store ↔ preferences store ↔ settings service ↔ http ↔ auth).
      if (user.preferred_language) {
        import('./preferences')
          .then((m) => m.usePreferencesStore().hydrateFromUser(user.preferred_language))
          .catch(() => {
            // non-fatal — i18n stays on whatever the local prefs say
          });
      }
    },

    reset() {
      this.step = 'login';
      this.user = null;
      this.token = null;
      this.schoolId = null;
      this.role = null;
      this.pendingEmail = null;
      this.schools = [];
      this.roles = [];
      this.lastResponse = null;
      this.error = null;
      this.otpDebug = null;
      this.isLoading = false;
      // Clear the chain marker so the next login starts on a clean
      // slate — otherwise a previous 'google' chain could survive a
      // logout and let a follow-up password login see authMethod=google.
      this.authMethod = null;
    },

    /** Drops back one step (used by "Kembali" buttons in OTP / picker views). */
    goBack() {
      if (this.step === 'otp' || this.step === 'school' || this.step === 'role') {
        this.step = 'login';
        this.lastResponse = null;
        this.error = null;
      }
    },

    // ── Persistence ───────────────────────────────────────────────────
    restore() {
      const token = storage.get<string>(StorageKeys.token);
      const user = storage.get<User>(StorageKeys.user);
      const schoolId = storage.get<string>(StorageKeys.schoolId);
      const role = storage.get<Role>(StorageKeys.role);

      if (token && user) {
        this.token = token;
        this.user = user;
        this.schoolId = schoolId;
        this.role = role ?? user.role;
        this.step = 'done';

        // Re-apply the persisted server-side language preference on
        // reload, same hydration path as `_completeLogin`. The login
        // payload had it; we cached the whole user object in
        // localStorage, so it's still here. Dynamic import to dodge
        // the auth↔prefs circular.
        if (user.preferred_language) {
          import('./preferences')
            .then((m) => m.usePreferencesStore().hydrateFromUser(user.preferred_language))
            .catch(() => {
              // non-fatal
            });
        }
      }
    },

    // ── Server-facing actions ─────────────────────────────────────────
    async checkHealth() {
      this.serverOnline = await AuthService.health();
    },

    /**
     * Pull the user's accessible schools + roles from the backend and
     * merge into `user.schools` / `user.roles`. The login response
     * doesn't include these lists when the user only has one of each,
     * so the topbar SchoolPill, Profile page, and ProfileMenu would
     * otherwise show "—" / hide the switch affordances entirely.
     *
     * Fire-and-forget: failures are swallowed so the app keeps
     * working with whatever was cached at login.
     */
    async hydrateSchoolsRoles() {
      if (!this.token || !this.user) return;
      try {
        const isTeacherLike =
          this.activeRole === 'guru' ||
          this.activeRole === 'wali_kelas' ||
          this.activeRole === 'admin';
        const [schools, roles, activeSchool, teacherProfile] =
          await Promise.all([
            AuthService.listSchools().catch(() => null),
            AuthService.listRoles().catch(() => null),
            // Always probe /school/settings so single-school users still
            // get their school name even when /auth/schools returns [].
            SchoolService.getActiveSchool().catch(() => null),
            // Resolve the teacher_profile row (id + homeroom_classes).
            // Required for any endpoint scoped by teacher_profile.id and
            // for the parent-kelas chip strip.
            isTeacherLike && this.user?.id
              ? TeacherService.resolveProfile(this.user.id).catch(() => null)
              : Promise.resolve(null),
          ]);

        if (teacherProfile) {
          this.teacherProfileId = teacherProfile.id;
          this.homeroomClasses = teacherProfile.homeroomClasses;
        }

        let dirty = false;

        if (schools && schools.length > 0) {
          this.user.schools = schools.map(normalizeSchool);
          dirty = true;
        }
        if (roles && roles.length > 0) {
          this.user.roles = roles;
          dirty = true;
        }

        // Resolve a school_name from the most reliable source:
        // 1. The schools list we just fetched (find by active id)
        // 2. The /school/settings response
        // 3. Whatever the login payload already cached
        if (!this.user.school_name) {
          const fromList = (this.user.schools ?? []).find(
            (s) => (s.id ?? s.school_id) === this.schoolId,
          );
          const resolved =
            fromList?.name ??
            fromList?.school_name ??
            activeSchool?.name ??
            null;
          if (resolved) {
            this.user.school_name = resolved;
            dirty = true;
          }
        }

        // Ensure single-school users still have a `schools[]` entry so
        // the SchoolPill / picker has *something* to render. Use the
        // /school/settings response when the dedicated list endpoint
        // didn't return anything.
        if (
          (!this.user.schools || this.user.schools.length === 0) &&
          activeSchool
        ) {
          this.user.schools = [normalizeSchool(activeSchool)];
          dirty = true;
        }

        // Ensure single-role users still have a `roles[]` entry — even
        // if /auth/roles returned []. The active role from the session
        // is always known.
        if (
          (!this.user.roles || this.user.roles.length === 0) &&
          this.activeRole
        ) {
          this.user.roles = [this.activeRole];
          dirty = true;
        }

        if (dirty) storage.set(StorageKeys.user, this.user);

        // Fire-and-forget: warm up the academic-year store so every
        // feature page can lazily read `currentAcademicYearId()` on
        // first load. Dynamic import keeps this file free of pinia
        // circular references.
        import('./academic-year')
          .then((m) => m.useAcademicYearStore().fetchAll({ force: true }))
          .catch(() => {
            // non-fatal
          });
      } catch {
        // ignore — non-fatal
      }
    },

    /**
     * Auto-advance the picker step when there's no real choice to make:
     *   - 1 school in the school picker → auto-select it
     *   - 1 role in the role picker → auto-select it
     *   - >1 role BUT the user picked one previously → re-pick the same
     *     role from localStorage so multi-role users don't get bothered
     *     by the picker every login (they can still switch from the
     *     ProfileMenu).
     *
     * Called after every `_applyResponse(res)` that might land on a
     * picker step. Recurses via `selectSchool`/`selectRole` which both
     * call `_applyResponse` again — so a single-school + single-role
     * user reaches step='done' in one chained roundtrip.
     */
    async _autoAdvancePicker() {
      if (this.step === 'school' && this.schools.length === 1) {
        const s = this.schools[0];
        const id = String(s.id || s.school_id || '');
        if (id) {
          await this.selectSchool(id);
        }
        return;
      }

      if (this.step === 'role') {
        // 1. Single role: pick it
        if (this.roles.length === 1) {
          await this.selectRole(this.roles[0]);
          return;
        }
        // 2. Multi-role: respect the previous choice if still valid.
        //    CRITICAL: only honor the cached role when it actually
        //    appears in the picker — otherwise we'd send a role the
        //    backend will 422 on (e.g. user lost the role since last
        //    login).
        //
        //    Normalize both sides before comparing because `this.roles`
        //    holds raw backend values ('admin'/'teacher'/'parent') while
        //    the stored role may be either raw OR an older
        //    Indonesian alias ('teacher'/'parent') from a previous session.
        const stored = storage.get<Role>(StorageKeys.role);
        if (stored) {
          const normStored = normalizeRole(stored);
          const match = (this.roles as string[]).find(
            (r) => normalizeRole(r) === normStored,
          );
          if (match) {
            await this.selectRole(match as Role);
            return;
          }
        }
      }
    },

    async login(email: string, password: string) {
      this._setLoading(true);
      this.pendingEmail = email;
      // Mark the chain so every downstream `_applyResponse(res)` (this
      // call, _autoAdvancePicker → selectSchool/selectRole) refuses to
      // route an email/password user into the demo wizard even if a
      // backend response unexpectedly carries `dapat_buat_demo`.
      this.authMethod = 'password';
      try {
        const res = await AuthService.login(email, password);
        // Email/password is a *sign-in* flow, never a *sign-up* flow.
        // The `dapat_buat_demo` flag is only meaningful for Google
        // login (a brand-new social account with no schools yet) —
        // and stripping it here guarantees an email/password user
        // can never be silently bounced into the demo wizard, even
        // if a future backend tweak starts emitting the flag here
        // too. Users who want a demo must click "List Demo"
        // explicitly from the login screen.
        this._applyResponse(this._stripDapatBuatDemo(res));
        await this._autoAdvancePicker();
      } catch (e) {
        this._setError((e as Error).message);
        throw e;
      } finally {
        this.isLoading = false;
      }
    },

    /**
     * Removes the `dapat_buat_demo` (and the related `wizard_resume`)
     * affordance from an auth response so `_applyResponse` cannot route
     * the user into the demo-registration wizard. Used by the email/
     * password and OTP flows — both are sign-in only.
     */
    _stripDapatBuatDemo(res: AuthResponse): AuthResponse {
      if (res?.dapat_buat_demo) {
        const { dapat_buat_demo: _ignored, wizard_resume: _ignored2, ...rest } =
          res as AuthResponse & { wizard_resume?: unknown };
        return rest as AuthResponse;
      }
      return res;
    },

    async verifyOtp(otp: string) {
      if (!this.pendingEmail) {
        throw new Error('Email tidak tersedia. Silakan masuk ulang.');
      }
      this._setLoading(true);
      // OTP is the continuation of an email/password sign-in — re-stamp
      // the chain marker so the gate keeps the user out of /register-demo
      // even if the tab was reloaded between `login()` and `verifyOtp()`
      // (Pinia state resets on reload; without this, the gate would see
      // authMethod=null and behave correctly only by coincidence).
      this.authMethod = 'password';
      try {
        const res = await AuthService.verifyOtp(this.pendingEmail, otp);
        // OTP is the continuation of an email/password sign-in — same
        // reasoning as `login()`: never auto-enroll into the demo
        // wizard from a sign-in flow.
        this._applyResponse(this._stripDapatBuatDemo(res));
        await this._autoAdvancePicker();
      } catch (e) {
        this._setError((e as Error).message);
        throw e;
      } finally {
        this.isLoading = false;
      }
    },

    async selectSchool(schoolId: string) {
      this._setLoading(true);
      this.schoolId = schoolId;
      storage.set(StorageKeys.schoolId, schoolId);
      // Wipe the ability snapshot BEFORE the switch call — the previous
      // school's abilities are no longer valid, and views that read
      // me.can() should fail-closed during the transition rather than
      // flash a menu item the user can't actually use in the new school.
      // The auto-load in `_applyResponse(step==='done')` will refill it.
      useMeStore().reset();
      try {
        const res = await AuthService.switchSchool(schoolId);
        this._applyResponse(res);
        // Different schools may have different academic year lists —
        // wipe the cached selection and let the next page load reseed
        // via the active-year priority chain.
        import('./academic-year')
          .then((m) => {
            const store = m.useAcademicYearStore();
            store.reset();
            return store.fetchAll({ force: true });
          })
          .catch(() => {
            // non-fatal
          });
        // RBAC roles/permissions are tenant-scoped — wipe the cache so
        // the next /admin/roles visit refetches against the new school.
        import('./rbac')
          .then((m) => m.useRbacStore().reset())
          .catch(() => {
            // non-fatal — store may not be instantiated yet
          });
        // If switchSchool returned a role picker (multi-role case),
        // immediately try to auto-advance — either because there's
        // really only one role or because we remember the last pick.
        await this._autoAdvancePicker();
      } catch (e) {
        this._setError((e as Error).message);
        throw e;
      } finally {
        this.isLoading = false;
      }
    },

    async selectRole(role: Role) {
      this._setLoading(true);
      this.role = role;
      storage.set(StorageKeys.role, role);

      if (!this.schoolId) {
        this._setError('School ID tidak ditemukan. Silakan pilih sekolah kembali.');
        this.step = 'school';
        return;
      }

      // Wipe abilities for the same reason as `selectSchool`: the
      // previous role's abilities are no longer valid.
      useMeStore().reset();

      try {
        const res = await AuthService.switchRole(role, this.schoolId);
        this._applyResponse(res);
      } catch (e) {
        this._setError((e as Error).message);
        throw e;
      } finally {
        this.isLoading = false;
      }
    },

    async googleLogin(payload: {
      email: string;
      displayName?: string;
      photoUrl?: string;
      idToken?: string;
      serverAuthCode?: string;
    }) {
      this._setLoading(true);
      this.pendingEmail = payload.email;
      // Google sign-up of a brand-new account legitimately routes into
      // /register-demo via `dapat_buat_demo`; mark the chain so the
      // gate in `_applyResponse` allows that branch.
      this.authMethod = 'google';
      try {
        const res = await AuthService.googleLogin(payload);
        this._applyResponse(res);
        await this._autoAdvancePicker();
      } catch (e) {
        this._setError((e as Error).message);
        throw e;
      } finally {
        this.isLoading = false;
      }
    },

    /**
     * Called by RegisterDemoView's final step ("Masuk dashboard")
     * once provision succeeds. The user now has one school + 1-3
     * roles attached, but `auth.step` is still 'register_demo'. We
     * fetch the school list, switch to it, and let _applyResponse
     * route them like a normal multi-school login.
     *
     * If anything fails here we throw so the caller can show a
     * proper error rather than silently leaving the user stuck on
     * /login with the wizard-loading fallback.
     */
    async refreshAfterDemo() {
      // Snapshot token before any call — Google login wrote it, and
      // we must NOT lose it across the switchSchool/Role round-trips
      // even if the backend response decides to return token=null.
      const preservedToken = this.token ?? storage.get<string>(StorageKeys.token);

      const schools = await AuthService.listSchools();
      if (!schools || schools.length === 0) {
        throw new Error('Sekolah demo belum tertaut ke akun Anda. Mohon muat ulang halaman.');
      }
      const firstId = String(schools[0].id ?? schools[0].school_id ?? '');
      if (!firstId) {
        throw new Error('Sekolah demo tidak punya ID valid.');
      }

      // ── 1. Switch into the school context ─────────────────────────
      const res = await AuthService.switchSchool(firstId);
      this._applyResponse(res);

      // ── 2. Auto-pick admin role for the owner ────────────────────
      // Demo owner with `all_roles` mode ended up with admin + teacher
      // + parent. Backend returns `pilih_role` (→ step='role') for the
      // multi-role case. We auto-pick admin so the user lands straight
      // on the dashboard — they can switch role anytime from
      // ProfileMenu. Single-role demos skip this entirely.
      if (this.step === 'role' && this.schoolId) {
        // `this.roles` holds raw backend values from /switch-school's
        // role_list — they're 'admin'/'teacher'/'parent' (English).
        // Find admin; if not present (single_role teacher/parent), fall
        // back to whatever the user actually has so they still land
        // somewhere instead of being stuck on the picker.
        const pick = (this.roles as string[]).find((r) => r === 'admin')
          ?? (this.roles[0] as string | undefined);
        if (pick) {
          const res2 = await AuthService.switchRole(pick as Role, this.schoolId);
          this._applyResponse(res2);
        }
      }

      // ── 3. Defensive: restore the token if a downstream call
      //    accidentally nulled it. _completeLogin already preserves
      //    the existing token when caller passes a falsy one, but
      //    this is a belt-and-suspenders guard for the exact moment
      //    the user clicks "Masuk dashboard demo" — losing the token
      //    here means the next API call hits 401 and bounces them
      //    back to /login with session-expired toast.
      if (!this.token && preservedToken) {
        this.token = preservedToken;
        storage.set(StorageKeys.token, preservedToken);
      }

      // ── 4. Warm up schools + roles cache so the SchoolPill, role
      //    switcher in ProfileMenu, and academic-year chip all show
      //    real data on the very first dashboard render instead of
      //    "—" placeholders. Best-effort.
      this.hydrateSchoolsRoles();

      // ── 5. Sanity assertion: if we somehow ended up not at 'done',
      //    surface a clear error rather than silently routing to a
      //    picker the user just escaped from.
      if (this.step !== 'done') {
        throw new Error(
          'Login otomatis ke dashboard demo gagal. Silakan masuk ulang dari halaman /login.',
        );
      }
    },

    async logout() {
      // Logout must NEVER leave the user stuck on a broken authenticated
      // page. The server round-trip is best-effort — whatever it does
      // (200, 401 on an already-expired token, network failure), the
      // LOCAL teardown below has to run so the in-memory store + storage
      // are cleared and the caller's redirect to /login can proceed.
      //
      // We therefore wrap the server call so a rejection can never abort
      // the teardown, and run the teardown in a `finally` so it executes
      // even on the unexpected throw. `AuthService.logout()` already
      // swallows its own errors today, but we do not depend on that — a
      // future refactor (or an interceptor that re-throws) must not be
      // able to resurrect the "stuck session" bug.
      try {
        await AuthService.logout();
      } catch (e) {
        // Swallow: the server token is invalidated on its own schedule
        // (or the request never reached it). Either way the client is
        // logging out locally regardless. Log for diagnostics only.
        // eslint-disable-next-line no-console
        console.warn('[auth] server logout failed, clearing session locally', e);
      } finally {
        // ── Local teardown — ALWAYS runs ──────────────────────────────
        this.reset();
        storage.remove(StorageKeys.token);
        storage.remove(StorageKeys.user);
        storage.remove(StorageKeys.schoolId);
        storage.remove(StorageKeys.role);
        // Tear down the realtime notifications socket so a logged-out
        // browser holds no Reverb connection. Lazy-imported to avoid a
        // load-time dependency on the Echo client (which is inert unless
        // Reverb is configured). No-op when realtime was never started.
        import('@/lib/echo')
          .then((m) => m.teardown())
          .catch(() => {
            // non-fatal
          });
        // Clear cached academic-year selection so a new login starts
        // from the backend's active year.
        import('./academic-year')
          .then((m) => m.useAcademicYearStore().reset())
          .catch(() => {
            // non-fatal
          });
        // Same treatment for RBAC + abilities so the next login can't
        // transiently see the previous user's cache.
        import('./rbac')
          .then((m) => m.useRbacStore().reset())
          .catch(() => {
            // non-fatal
          });
        import('./me')
          .then((m) => m.useMeStore().reset())
          .catch(() => {
            // non-fatal
          });
      }
    },
  },
});

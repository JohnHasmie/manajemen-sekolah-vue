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
import { storage, StorageKeys } from '@/lib/storage';
import type {
  AuthResponse,
  AuthStep,
  Role,
  School,
  User,
} from '@/types/auth';

/**
 * Normalizes backend role strings to canonical keys used by the router.
 * English (backend) -> Indonesian (canonical/short).
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
  if (r === 'wali' || r === 'parent' || r === 'orang_tua' || r === 'wali_murid' || r === 'walimurid') return 'wali';
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
   * the wali kelas chips in `<RoleToggleChipRow>` on Jadwal / Presensi
   * / Kegiatan Kelas / Buku Nilai / Rapor / Rekomendasi.
   */
  homeroomClasses: { id: string; name: string }[];
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
  }),

  getters: {
    isAuthenticated: (s) => Boolean(s.token && s.user),
    /** Convenience accessor used by the router and AppShell. */
    activeRole(): Role | null {
      return this.user?.role ?? this.role;
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

      if (res.require_otp) {
        this.step = 'otp';
        return;
      }
      // Google login with no schools → register-demo path. The token
      // is already saved above; we keep `pendingEmail` so the wizard
      // can prefill display + credential previews. The view layer's
      // RegisterDemo route guard reads `step === 'register_demo'` to
      // allow access while keeping /admin etc. closed.
      if (res.dapat_buat_demo) {
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
            // for the wali-kelas chip strip.
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

    async login(email: string, password: string) {
      this._setLoading(true);
      this.pendingEmail = email;
      try {
        const res = await AuthService.login(email, password);
        this._applyResponse(res);
      } catch (e) {
        this._setError((e as Error).message);
        throw e;
      } finally {
        this.isLoading = false;
      }
    },

    async verifyOtp(otp: string) {
      if (!this.pendingEmail) {
        throw new Error('Email tidak tersedia. Silakan masuk ulang.');
      }
      this._setLoading(true);
      try {
        const res = await AuthService.verifyOtp(this.pendingEmail, otp);
        this._applyResponse(res);
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
      try {
        const res = await AuthService.googleLogin(payload);
        this._applyResponse(res);
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
      // Demo owner with `all_roles` mode ended up with admin + guru
      // + wali. Backend returns `pilih_role` (→ step='role') for the
      // multi-role case. We auto-pick admin so the user lands straight
      // on the dashboard — they can switch role anytime from
      // ProfileMenu. Single-role demos skip this entirely.
      if (this.step === 'role' && this.schoolId) {
        // `this.roles` holds raw backend values from /switch-school's
        // role_list — they're 'admin'/'teacher'/'parent' (English).
        // Find admin; if not present (single_role guru/wali), fall
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
      await AuthService.logout();
      this.reset();
      storage.remove(StorageKeys.token);
      storage.remove(StorageKeys.user);
      storage.remove(StorageKeys.schoolId);
      storage.remove(StorageKeys.role);
      // Clear cached academic-year selection so a new login starts
      // from the backend's active year.
      import('./academic-year')
        .then((m) => m.useAcademicYearStore().reset())
        .catch(() => {
          // non-fatal
        });
    },
  },
});

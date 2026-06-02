/**
 * AuthService — thin wrapper over the Laravel auth endpoints.
 *
 * Mirrors `lib/features/auth/data/auth_service.dart`. Each method returns
 * the *normalized* response (the raw envelope's `data` already unwrapped if
 * present; otherwise the raw body). Flow-control flags (`require_otp`,
 * `needsSchoolSelection`, `needsRoleSelection`) live at the top level.
 */
import { api } from '@/lib/http';
import type { AuthResponse, School, Role } from '@/types/auth';

const Endpoints = {
  login: '/auth/login',
  verifyOtp: '/auth/verify-otp',
  googleLogin: '/auth/google-login',
  logout: '/auth/logout',
  switchSchool: '/auth/switch-school',
  switchRole: '/auth/switch-role',
  // Multi-tenant lookups for the *currently authenticated* user.
  // These are the endpoints Flutter uses (`/user/...`, not
  // `/auth/...`) and they include all schools/roles the user holds
  // — used by SchoolPill, ProfileMenu, and the login wizard.
  userRoles: '/user/roles',
  userSchools: '/user/schools',
  forgotPassword: '/auth/forgot-password',
  helpRequest: '/auth/help-request',
  health: '/health',
} as const;

function normalize(payload: unknown): AuthResponse {
  let data: Record<string, any> = {};

  // 1. Unwrap Laravel envelope if present { success, data, message }
  if (
    payload &&
    typeof payload === 'object' &&
    'data' in (payload as Record<string, unknown>)
  ) {
    const wrapper = payload as { data?: any };
    if (wrapper.data && typeof wrapper.data === 'object') {
      data = { ...wrapper.data };
    } else {
      data = (payload as Record<string, any>);
    }
  } else {
    data = (payload as Record<string, any>) ?? {};
  }

  // 2. Map Indonesian backend flags to canonical frontend keys
  // This matches lib/features/auth/data/auth_service.dart in Flutter.
  if (data.pilih_sekolah === true) {
    data.needsSchoolSelection = true;
  }
  if (data.pilih_role === true) {
    data.needsRoleSelection = true;
  }

  if (data.sekolah_list && !data.schools) {
    data.schools = data.sekolah_list;
  }
  if (data.role_list && !data.roles) {
    data.roles = data.role_list;
  }

  return data as AuthResponse;
}

function pickErrorMessage(error: unknown, fallback: string): Error {
  // axios error
  const e = error as {
    response?: { data?: { error?: string; message?: string } };
    message?: string;
  };
  const msg =
    e?.response?.data?.error ??
    e?.response?.data?.message ??
    e?.message ??
    fallback;
  return new Error(msg);
}

export const AuthService = {
  async health(): Promise<boolean> {
    try {
      await api.get(Endpoints.health, { timeout: 5_000 });
      return true;
    } catch {
      return false;
    }
  },

  async login(
    email: string,
    password: string,
    opts?: { schoolId?: string; role?: Role },
  ): Promise<AuthResponse> {
    try {
      const body: Record<string, unknown> = { email, password };
      if (opts?.schoolId) body.school_id = opts.schoolId;
      if (opts?.role) body.role = opts.role;

      const res = await api.post(Endpoints.login, body);
      return normalize(res.data);
    } catch (e) {
      throw pickErrorMessage(e, 'Login gagal');
    }
  },

  async verifyOtp(
    email: string,
    otp: string,
    opts?: { schoolId?: string; role?: Role },
  ): Promise<AuthResponse> {
    try {
      const body: Record<string, unknown> = { email, otp };
      if (opts?.schoolId) body.school_id = opts.schoolId;
      if (opts?.role) body.role = opts.role;

      const res = await api.post(Endpoints.verifyOtp, body);
      return normalize(res.data);
    } catch (e) {
      throw pickErrorMessage(e, 'Verifikasi OTP gagal');
    }
  },

  async googleLogin(payload: {
    email: string;
    displayName?: string;
    photoUrl?: string;
    idToken?: string;
    serverAuthCode?: string;
  }): Promise<AuthResponse> {
    try {
      const res = await api.post(Endpoints.googleLogin, {
        email: payload.email,
        name: payload.displayName,
        avatar: payload.photoUrl,
        id_token: payload.idToken,
        server_auth_code: payload.serverAuthCode,
      });
      return normalize(res.data);
    } catch (e) {
      throw pickErrorMessage(e, 'Login Google gagal');
    }
  },

  async switchSchool(schoolId: string): Promise<AuthResponse> {
    try {
      const res = await api.post(Endpoints.switchSchool, { school_id: schoolId });
      return normalize(res.data);
    } catch (e) {
      throw pickErrorMessage(e, 'Gagal mengganti sekolah');
    }
  },

  async switchRole(role: Role, schoolId: string): Promise<AuthResponse> {
    try {
      // The backend doesn't have a dedicated /switch-role endpoint.
      // We use /switch-school with a role parameter, matching Flutter.
      //
      // IMPORTANT: The frontend normalizes roles to Indonesian canonical
      // names (teacher→guru, parent→wali), but the backend expects the
      // original English enum values. De-normalize before sending.
      const backendRole = denormalizeRole(role);
      const res = await api.post(Endpoints.switchSchool, {
        school_id: schoolId,
        role: backendRole,
      });
      return normalize(res.data);
    } catch (e) {
      throw pickErrorMessage(e, 'Gagal mengganti peran');
    }
  },

  async logout(): Promise<void> {
    try {
      await api.post(Endpoints.logout);
    } catch {
      // Ignore — logout should always succeed locally even if the server is
      // unreachable. Matches Flutter behaviour.
    }
  },

  async forgotPassword(email: string): Promise<{ message: string }> {
    try {
      const res = await api.post(Endpoints.forgotPassword, { email });
      const body = normalize(res.data);
      return { message: body.message ?? 'Tautan reset telah dikirim.' };
    } catch (e) {
      throw pickErrorMessage(e, 'Gagal mengirim tautan reset');
    }
  },

  async submitHelpRequest(payload: {
    name: string;
    email: string;
    /**
     * Optional school the requester is asking about. Wire key is
     * `requested_school_name` post the 2026_06_02 column rename
     * (was `school_name` — backend FormRequest still accepts the
     * legacy key for one release cycle).
     */
    requestedSchoolName?: string;
    message: string;
  }): Promise<{ message: string }> {
    try {
      // Send both keys for the deploy-window where prod runs the old
      // FormRequest (validates `school_name`) while staging runs the
      // new one (validates `requested_school_name`). Both are safe to
      // include — the loser of each Validator pass is silently dropped.
      const body = {
        name: payload.name,
        email: payload.email,
        message: payload.message,
        ...(payload.requestedSchoolName
          ? {
              requested_school_name: payload.requestedSchoolName,
              school_name: payload.requestedSchoolName,
            }
          : {}),
      };
      const res = await api.post(Endpoints.helpRequest, body);
      const data = normalize(res.data);
      return { message: data.message ?? 'Permintaan bantuan terkirim.' };
    } catch (e) {
      throw pickErrorMessage(e, 'Gagal mengirim permintaan bantuan');
    }
  },

  /**
   * GET /user/schools — Flutter's `getUserSchools()`. The backend
   * returns a bare array of school objects (no envelope), so we
   * unwrap defensively.
   */
  async listSchools(): Promise<School[]> {
    try {
      const res = await api.get(Endpoints.userSchools);
      const body = res.data;
      // The endpoint returns either a top-level array or an envelope
      // wrapping one — handle both.
      const raw: any[] = Array.isArray(body)
        ? body
        : Array.isArray(body?.data)
          ? body.data
          : Array.isArray(body?.schools)
            ? body.schools
            : Array.isArray(body?.sekolah_list)
              ? body.sekolah_list
              : [];
      return raw.map(normalizeSchool);
    } catch (e) {
      throw pickErrorMessage(e, 'Gagal memuat daftar sekolah');
    }
  },

  /**
   * GET /user/roles — Flutter's `getUserRoles()`. Response shape is
   * `{ available_roles: [...], current_role: '...' }`. Falls back to
   * top-level `roles` when the envelope variants are returned.
   */
  async listRoles(): Promise<Role[]> {
    try {
      const res = await api.get(Endpoints.userRoles);
      const body = res.data ?? {};
      const raw: any[] = Array.isArray(body.available_roles)
        ? body.available_roles
        : Array.isArray(body.data?.available_roles)
          ? body.data.available_roles
          : Array.isArray(body.roles)
            ? body.roles
            : Array.isArray(body.role_list)
              ? body.role_list
              : Array.isArray(body)
                ? body
                : [];
      return raw
        .map((r: any) =>
          typeof r === 'string' ? r : (r?.role ?? r?.name ?? r?.peran),
        )
        .filter((r: any): r is Role => typeof r === 'string' && r.length > 0)
        .map((r: string) => normalizeRoleString(r));
    } catch (e) {
      throw pickErrorMessage(e, 'Gagal memuat daftar peran');
    }
  },
};

/**
 * Normalize a school payload from /user/schools. The backend mixes
 * snake_case and Indonesian fields depending on the endpoint variant.
 */
function normalizeSchool(raw: any): School {
  return {
    id: String(raw.id ?? raw.school_id ?? raw.sekolah_id ?? ''),
    school_id: raw.school_id ?? raw.id,
    name: String(
      raw.name ??
        raw.school_name ??
        raw.nama_sekolah ??
        raw.nama ??
        '—',
    ),
    school_name: raw.school_name ?? raw.name ?? raw.nama_sekolah,
    address: raw.address ?? raw.alamat,
    city: raw.city ?? raw.kota,
    academic_year: raw.academic_year ?? raw.tahun_ajaran,
    // Backend column is now `schools.education_level` (was `jenjang`).
    education_level: raw.education_level ?? raw.level ?? raw.jenjang,
    level: raw.education_level ?? raw.level ?? raw.jenjang,
    logo_url: raw.logo_url ?? raw.logo ?? null,
    roles: Array.isArray(raw.roles)
      ? raw.roles.map((r: any) =>
          normalizeRoleString(typeof r === 'string' ? r : (r?.role ?? r?.name ?? '')),
        ).filter(Boolean)
      : undefined,
  };
}

function normalizeRoleString(raw: string): Role {
  const r = String(raw ?? '').toLowerCase().trim();
  if (r === 'admin' || r === 'administrator') return 'admin';
  if (r === 'guru' || r === 'teacher') return 'guru';
  if (r === 'wali_kelas' || r === 'walikelas') return 'wali_kelas';
  if (
    r === 'wali' ||
    r === 'parent' ||
    r === 'orang_tua' ||
    r === 'wali_murid' ||
    r === 'walimurid'
  ) {
    return 'wali';
  }
  if (r === 'staff' || r === 'staf') return 'staff';
  return r as Role;
}

/**
 * Converts the frontend's canonical Indonesian role names back to
 * the backend's English UserRole enum values. This is the inverse
 * of `normalizeRoleString`. Required because the backend stores
 * roles as 'teacher'/'parent' but the frontend displays and stores
 * them as 'guru'/'wali'.
 *
 * Without this, switchRole sends 'guru' to the backend which
 * doesn't match the UserRole enum and returns 422.
 */
function denormalizeRole(role: Role): string {
  switch (role) {
    case 'admin':     return 'admin';
    case 'guru':      return 'teacher';
    case 'wali_kelas': return 'teacher'; // wali_kelas is a sub-type of teacher
    case 'wali':      return 'parent';
    case 'staff':     return 'staff';
    default:          return role;
  }
}

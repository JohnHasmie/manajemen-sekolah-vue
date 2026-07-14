/**
 * SystemSecurityService — per-school account-security settings.
 *
 * Wraps the backend `SystemSettingsController` endpoints that toggle
 * two tenant-level security features:
 *
 *   · Account Activation (Opsi B) — GET/PUT
 *       /system/account-activation-settings
 *     When ON, adding a guru/murid/staf creates a password-less
 *     account + emails/WhatsApps a set-password link instead of a
 *     default password. A channel picker (email | whatsapp | both)
 *     chooses how the link is delivered.
 *
 *   · Login OTP (2FA) — GET/PUT /system/login-otp-settings
 *     When ON, members must enter an emailed OTP after passing the
 *     email + password step.
 *
 * Both are gated on `school.settings.view` (read) /
 * `school.settings.manage` (write); the route + UI enforce the same
 * abilities. Both default OFF server-side.
 *
 * Empty-school-context handling: the shared axios interceptor rewrites
 * a 400 "no active school context" on a GET into an empty envelope
 * (`{ success, data: [], _empty_context: true }`). The getters below
 * detect that and return `null` so the view can render a "pick a
 * school first" state instead of a hard error. Mutations (PUT) still
 * reject with a readable message when there's no school context.
 */
import { api } from '@/lib/http';

/** Delivery channel for the set-password activation link. */
export type ActivationChannel = 'email' | 'whatsapp' | 'both';

export interface AccountActivationSettings {
  /** ON → new members get a set-password link instead of a password. */
  account_activation_mode: boolean;
  /** How the activation link is delivered. */
  activation_channel: ActivationChannel;
}

export interface LoginOtpSettings {
  /** ON → members must enter an emailed OTP after email+password. */
  login_otp_required: boolean;
}

/** Narrow arbitrary input to a known channel, defaulting to email. */
function channelFromJson(raw: unknown): ActivationChannel {
  return raw === 'whatsapp' || raw === 'both' ? raw : 'email';
}

function activationFromJson(raw: any): AccountActivationSettings {
  return {
    account_activation_mode: raw?.account_activation_mode === true,
    activation_channel: channelFromJson(raw?.activation_channel),
  };
}

function loginOtpFromJson(raw: any): LoginOtpSettings {
  return {
    login_otp_required: raw?.login_otp_required === true,
  };
}

function humanError(e: unknown, fallback: string): string {
  const ax = e as any;
  if (ax?.response?.data) {
    const d = ax.response.data;
    if (typeof d === 'string') return d;
    if (d?.message) return String(d.message);
    if (d?.error) return String(d.error);
    if (d?.errors && typeof d.errors === 'object') {
      const first = Object.values(d.errors)[0];
      if (Array.isArray(first) && first.length > 0) return String(first[0]);
    }
  }
  if (e instanceof Error) return e.message;
  return fallback;
}

/**
 * Pull the settings object out of the Laravel `{ success, data }`
 * envelope. Returns `null` when the interceptor rewrote a missing
 * school context into its empty envelope (`_empty_context` /
 * `data: []`), signalling the caller to render the no-school state.
 */
function unwrapOrNull(body: any): any | null {
  if (!body) return null;
  if (body._empty_context === true) return null;
  const d = body.data;
  if (Array.isArray(d)) return null; // empty-context shape
  return d ?? {};
}

export const SystemSecurityService = {
  /**
   * GET /system/account-activation-settings.
   * Returns `null` when there's no active school context.
   */
  async getAccountActivation(): Promise<AccountActivationSettings | null> {
    try {
      const res = await api.get('/system/account-activation-settings');
      const data = unwrapOrNull(res.data);
      return data === null ? null : activationFromJson(data);
    } catch (e) {
      throw new Error(
        humanError(e, 'Gagal memuat pengaturan aktivasi akun.'),
      );
    }
  },

  /**
   * PUT /system/account-activation-settings — partial update; only the
   * key(s) present in `patch` are sent.
   */
  async updateAccountActivation(
    patch: Partial<AccountActivationSettings>,
  ): Promise<AccountActivationSettings> {
    try {
      const body: Record<string, unknown> = {};
      if (patch.account_activation_mode !== undefined) {
        body.account_activation_mode = patch.account_activation_mode;
      }
      if (patch.activation_channel !== undefined) {
        body.activation_channel = patch.activation_channel;
      }
      const res = await api.put(
        '/system/account-activation-settings',
        body,
      );
      // Prefer the server echo; fall back to the patch we sent.
      const data = unwrapOrNull(res.data);
      return activationFromJson(data ?? body);
    } catch (e) {
      throw new Error(
        humanError(e, 'Gagal memperbarui pengaturan aktivasi akun.'),
      );
    }
  },

  /**
   * GET /system/login-otp-settings.
   * Returns `null` when there's no active school context.
   */
  async getLoginOtp(): Promise<LoginOtpSettings | null> {
    try {
      const res = await api.get('/system/login-otp-settings');
      const data = unwrapOrNull(res.data);
      return data === null ? null : loginOtpFromJson(data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat pengaturan OTP login.'));
    }
  },

  /** PUT /system/login-otp-settings. */
  async updateLoginOtp(
    patch: Partial<LoginOtpSettings>,
  ): Promise<LoginOtpSettings> {
    try {
      const body: Record<string, unknown> = {};
      if (patch.login_otp_required !== undefined) {
        body.login_otp_required = patch.login_otp_required;
      }
      const res = await api.put('/system/login-otp-settings', body);
      const data = unwrapOrNull(res.data);
      return loginOtpFromJson(data ?? body);
    } catch (e) {
      throw new Error(
        humanError(e, 'Gagal memperbarui pengaturan OTP login.'),
      );
    }
  },
};

/**
 * /subscribe/new wizard — types.
 *
 * Payload shape matches what the Pinia store persists in localStorage
 * AND what the backend `subscription_wizard_states.payload` JSONB
 * stores. Keep the two in sync — a divergence would mean a device that
 * resumes a draft sees a broken form.
 */
import type { BillingPeriod, TenantType } from '@/types/subscription-billing';

/** Step index range [0 .. 4]. Kept as `number` to match the DB column. */
export type WizardStep = 0 | 1 | 2 | 3 | 4;

/** Sekolah `education_level` — matches the values used elsewhere. */
export type EducationLevel = 'SD' | 'SMP' | 'SMA' | 'SMK' | 'MI' | 'MTs' | 'MA';

/**
 * Snapshot the wizard writes on every keystroke (locally) and every
 * N seconds (server). All fields optional — the wizard fills them as
 * the user progresses through steps.
 */
export interface NewTenantWizardPayload {
  tenant_type?: TenantType;
  tenant_name?: string;
  education_level?: EducationLevel | null;
  city?: string;
  address?: string;
  npsn?: string;
  admin_name?: string;
  admin_job_title?: string;
  admin_whatsapp?: string;
  admin_email?: string;
  plan?: BillingPeriod;
  student_count?: number;
  staff_count?: number;
  // The gateway is currently locked to `bank_transfer_manual` on the
  // FE (Midtrans surfaces only when backend advertises it). Kept
  // optional in the payload so a future write of `midtrans` doesn't
  // require a shape change.
  gateway?: 'midtrans' | 'bank_transfer_manual';
  agreed_terms?: boolean;
}

/** Server-side wizard state row shape returned by GET /billing/subscription-wizard. */
export interface SubscriptionWizardStateRow {
  current_step: WizardStep;
  payload: NewTenantWizardPayload | null;
  last_active_at: string | null;
  completed_at: string | null;
  provisioned_subscription_id: string | null;
}

/**
 * Tutoring2 · tenant payment destination —
 * `GET /tutoring-v2/billing-settings` (admin) and
 * `GET /tutoring-v2/payment-account` (wali / siswa).
 *
 * Two types over one backend row, matching the two backend resources.
 * The split is the point: `PaymentAccount` reaches every parent on the
 * tenant, so it carries only what someone needs in order to transfer
 * money. Do not widen it into `BillingSettings` "for convenience" — the
 * admin shape describes how the tenant is configured, which is not a
 * parent's business.
 *
 * Neither shape has a `payment_gateway_config` field, and that is not an
 * oversight: it holds provider API credentials and the backend never
 * emits it. An admin gets `payment_gateway_configured` instead.
 */

/** What a wali or siswa is shown so they can pay. */
export interface PaymentAccount {
  bank_name: string | null;
  bank_account_number: string | null;
  bank_account_holder: string | null;
  qris_image_url: string | null;
  payment_instructions: string | null;
  /** Whether to offer the online path at all. */
  payment_gateway_enabled: boolean;
  /** Which SDK the checkout would load. */
  payment_gateway_provider: string | null;
}

/** Admin configuration view. A superset, minus the credentials. */
export interface BillingSettings extends PaymentAccount {
  id: string;
  school_id: string;
  /** True when a gateway is set up — never the keys themselves. */
  payment_gateway_configured: boolean;
  /** False when a wali literally cannot pay yet: no bank, QRIS, or note. */
  has_payable_destination: boolean;
  updated_at: string | null;
}

/**
 * PARTIAL update payload. Omitting a key leaves that field alone; send
 * an explicit `null` to clear it. The backend keys off which properties
 * are PRESENT, so never spread a full object with undefined values —
 * build the patch from the fields the form actually touched.
 *
 * `qris_image_url` is absent on purpose: it is written by the upload
 * endpoint, so the API rejects a caller-supplied URL.
 */
export interface BillingSettingsUpdatePayload {
  bank_name?: string | null;
  bank_account_number?: string | null;
  bank_account_holder?: string | null;
  payment_instructions?: string | null;
  payment_gateway_enabled?: boolean;
  payment_gateway_provider?: 'midtrans' | 'xendit' | null;
}

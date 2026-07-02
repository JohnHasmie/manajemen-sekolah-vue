/**
 * Types for the super-admin billing review surface.
 *
 * Wire shapes come from AdminBillingController in the backend:
 *   GET  /billing/admin/pending-approvals  → PendingApproval[]
 *   POST /billing/admin/approve/{id}       → ApproveResult
 *   POST /billing/admin/reject/{id}        → RejectResult
 *
 * Kept separate from src/types/subscription-billing.ts (customer-side)
 * so the two audiences don't leak fields into each other.
 */

/** Snake-case wire mirror of AdminBillingController::pendingApprovals(). */
export interface PendingApproval {
  id: string;
  order_id: string;
  plan: 'monthly' | 'yearly';
  amount: number;
  currency: string;
  tenant_name: string;
  /** From `pending_new_tenant.admin_email` for pending-new-tenant subs. */
  admin_email: string | null;
  /** From `pending_new_tenant.admin_whatsapp`. */
  admin_whatsapp: string | null;
  /** Raw SubscriptionStatus enum value. Older backend deployments (pre
   *  the pending_payment-inclusion patch) don't send this field — default
   *  to 'awaiting_verify' at the parse layer since that was the only
   *  status the queue could ever contain then. */
  status: 'pending_payment' | 'awaiting_verify';
  /** True iff the customer clicked "sudah transfer" (status ==
   *  awaiting_verify). Older deployments don't send this — default to
   *  false. */
  is_claimed: boolean;
  /** ISO-8601. When the pending subscription row was created. */
  created_at: string | null;
  /** ISO-8601. When the customer clicked "sudah transfer" (null when
   *  the sub is still pending_payment). Distinct from `waiting_hours`,
   *  which anchors on the most-informative timestamp available. */
  last_marked_at: string | null;
  /** Whole hours since the row entered its current state (claim time
   *  > updated_at > created_at). Server-computed so the FE doesn't
   *  need a running clock. */
  waiting_hours: number;
}

/** Laravel paginator meta. */
export interface PendingApprovalMeta {
  current_page: number;
  per_page: number;
  total: number;
  last_page: number;
}

export interface PendingApprovalListParams {
  per_page?: number;
  page?: number;
}

export interface PendingApprovalListResult {
  items: PendingApproval[];
  meta: PendingApprovalMeta;
}

export interface ApproveResult {
  status: string;
  starts_at: string | null;
  expires_at: string | null;
  already_active: boolean;
  notifications_dispatched: {
    email: boolean;
    whatsapp: boolean;
  };
}

export interface RejectResult {
  status: string;
  rejection_reason: string;
  rejected_at: string | null;
  already_canceled: boolean;
  notifications_dispatched: {
    email: boolean;
    whatsapp: boolean;
  };
}

/**
 * Waiting-time tone thresholds, matching the mockup:
 *   - green  <12h
 *   - amber  12..24h
 *   - red    ≥24h
 */
export type WaitingTone = 'ok' | 'warn' | 'critical';

export function waitingTone(hours: number): WaitingTone {
  if (hours >= 24) return 'critical';
  if (hours >= 12) return 'warn';
  return 'ok';
}

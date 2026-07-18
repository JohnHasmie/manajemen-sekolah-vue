/**
 * ReadinessService — /admin/readiness endpoint wrapper.
 *
 * Single call powers the admin "Pusat Kendali Sekolah" page (locale
 * display name is Bahasa; ALL identifiers stay English per project
 * convention). The endpoint is a CORE feature — always on, no `module:`
 * middleware — gated only by the `readiness.view` RBAC ability, so any
 * school admin holding the ability can read it regardless of paid subs.
 *
 * Two lanes come back on the same payload: `completion_needed` (Lane A,
 * scored) and `attention_needed` (Lane B, operational — reuses the
 * existing PriorityInboxItem shape). Dimensions carry a per-check pct
 * and a `required_modules` list; a dimension whose module isn't
 * entitled comes back with `active: false` and `pct: null`.
 *
 * The `level` / `streak` / `delta_pct` fields ship null in FE-2 and get
 * populated in the MR4 habit-layer backend; UI branches on `!== null`.
 */
import { api } from '@/lib/http';

// ─── Payload types ─────────────────────────────────────────────────

export type ReadinessDimensionKey =
  | 'structure'
  | 'staff'
  | 'students'
  | 'academic';

export interface ReadinessDimension {
  key: ReadinessDimensionKey;
  /** Whether the dimension is scored for this tenant (module entitled). */
  active: boolean;
  /** Completeness percentage 0..100, or null when the dimension is inactive. */
  pct: number | null;
  /** Nominal weight before re-normalization. */
  weight: number;
  /** Module keys that gate this dimension (empty = core, always active). */
  required_modules: string[];
}

export type ReadinessSeverity = 'critical' | 'warning' | 'info';

/** Lane A — scored completeness items. Fixing these moves the score up. */
export interface ReadinessCompletionItem {
  key: string;
  dimension: string;
  severity: ReadinessSeverity;
  count: number;
  /** Server-localized label (Accept-Language). */
  label: string;
  /** Server-localized subtitle line. */
  subtitle: string;
  /** Backend route hint — mapped to a real Vue route name by the view. */
  target_route: string;
  target_params: Record<string, unknown>;
}

/**
 * Lane B — operational items reusing the existing PriorityInboxItem
 * shape (same fields the shared PriorityInbox.vue already renders).
 * Kept structurally compatible so the same component can render either.
 */
export interface ReadinessAttentionItem {
  id: string;
  type: string;
  severity: ReadinessSeverity;
  label: string;
  subtitle: string;
  count: number;
  occurred_at: string;
  target_route: string;
  target_params: Record<string, unknown>;
}

/**
 * BE-5 badges slice — the endpoint ships the catalog + earned set on the
 * same call so the FE renders "3 / 7 tercapai" with a single round-trip.
 * Label + description come from the server (Indonesian), so the client
 * needs NO local copy map — just render what the API returned.
 */
export interface ReadinessBadgeCatalogItem {
  code: string;
  label: string;
  description: string;
}

export interface ReadinessBadgeEarned {
  code: string;
  meta: Record<string, unknown>;
  /** ISO timestamp of the award. */
  awarded_at: string;
  /** True within a 48h server-side window — FE renders a "Baru!" ribbon. */
  is_new: boolean;
}

export interface ReadinessBadges {
  catalog: ReadinessBadgeCatalogItem[];
  earned: ReadinessBadgeEarned[];
}

export interface ReadinessPayload {
  /** False when the tenant scope has no check catalog wired (e.g. bimbel MVP). */
  supported: boolean;
  /** Composite score 0..100. Re-normalized over active dimensions. */
  score: number;
  /** Week-over-week delta in percentage points, or null pre-snapshot. */
  delta_pct: number | null;
  /** Admin habit level — server-authoritative (BE-4). Null pre-visit. */
  level: number | null;
  /** Admin habit streak in days — server-authoritative (BE-4). */
  streak: number | null;
  dimensions: ReadinessDimension[];
  /** Lane A — scored completeness gaps. */
  completion_needed: ReadinessCompletionItem[];
  /** Lane B — operational inbox items (unscored). */
  attention_needed: ReadinessAttentionItem[];
  /**
   * BE-5 achievement badges — catalog + earned set. Copy is server-side
   * so the FE renders `label`/`description` directly (no client map).
   */
  badges: ReadinessBadges;
  /** ISO timestamp of the compute/cache moment. */
  generated_at: string;
}

// ─── Service ───────────────────────────────────────────────────────

export const ReadinessService = {
  async get(): Promise<ReadinessPayload> {
    const res = await api.get('/admin/readiness');
    return (res.data?.data ?? res.data) as ReadinessPayload;
  },
};

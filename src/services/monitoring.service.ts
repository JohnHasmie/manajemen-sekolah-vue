/**
 * MonitoringService — client for the SuperAdmin monitoring dashboard.
 * Mirrors `/api/super-admin/monitoring/*` (backend MR-3).
 *
 * One method per endpoint; each returns the shape the corresponding
 * panel expects. Every method silently returns a shaped default on
 * network error so the dashboard renders empty states instead of
 * showing red banners for a transient blip.
 */
import { api } from '@/lib/http';

// ── payload types ─────────────────────────────────────────────────

export type HealthCheckStatus = 'up' | 'down' | 'warn';

export interface HealthCheck {
  status: HealthCheckStatus;
  detail?: string;
}

export interface HealthStrip {
  database: HealthCheck;
  redis: HealthCheck;
  queue: HealthCheck;
  scheduler: HealthCheck;
  worker: HealthCheck;
  fcm_token: HealthCheck;
}

export interface OverviewKpi {
  jobs_per_minute: number;
  pending: number;
  failed_24h: number;
  fcm_delivered_today: number;
}

export interface OverviewPayload {
  health: HealthStrip;
  overview: {
    kpi: OverviewKpi;
    throughput_30m: Array<{ minute: string; jobs: number }>;
    incident: null | {
      type: string;
      message: string;
      action: string;
    };
  };
}

export interface QueueRow {
  name: string;
  pending: number;
  wait_seconds: number;
  processes: number;
}

export interface SupervisorRow {
  name: string;
  status: string;
  processes: number;
}

export interface FailedJobRow {
  id: string | null;
  name: string;
  queue: string;
  failed_at: string | null;
  exception: string | null;
}

export interface QueuePayload {
  queues: QueueRow[];
  supervisors: SupervisorRow[];
  failed_jobs: FailedJobRow[];
}

export interface RedisPayload {
  redis: {
    memory: {
      used: number;
      used_human: string | null;
      peak: number;
      peak_human: string | null;
    };
    clients: number;
    blocked_clients: number;
    evicted_keys: number;
    rejected_connections: number;
    keys_db0: number;
    keys_db1: number;
    maxmemory_policy: string | null;
  };
  system: {
    cpu: number | null;
    ram: number | null;
    disk: number | null;
  };
  maxmemory_warning: boolean;
}

export interface NotificationsPayload {
  kpi: {
    sent: number;
    delivered: number;
    failed: number;
    deactivated_24h: number;
    no_token: number;
  };
  tokens: {
    active: number;
    inactive: number;
  };
  users_without_token: Array<{
    user_id: string;
    name: string;
    email: string;
    reason: string;
  }>;
}

export type FcmLogStatus = 'delivered' | 'failed' | 'deactivated' | 'no_token';

export interface FcmLogRow {
  id: string;
  created_at: string;
  user_id: string | null;
  email: string | null;
  name: string | null;
  token_prefix: string | null;
  device_type: string | null;
  notification_type: string | null;
  status: FcmLogStatus;
  error_code: string | null;
  error_message: string | null;
  school_id: string | null;
}

export interface FcmLogsPayload {
  data: FcmLogRow[];
  meta: {
    current_page: number;
    per_page: number;
    total: number;
    last_page: number;
  };
  summary: {
    delivered: number;
    failed: number;
    deactivated: number;
    no_token: number;
  };
}

export interface FcmLogFilters {
  email?: string;
  token?: string;
  status?: string;
  type?: string;
  from?: string;
  to?: string;
  page?: number;
  per_page?: number;
}

export interface ErrorsPayload {
  exceptions: Array<{
    uuid: string;
    created_at: string;
    class: string;
    message: string;
    file: string | null;
    line: number | null;
  }>;
  slow_queries: Array<{
    uuid: string;
    created_at: string;
    sql: string;
    time_ms: number;
    connection: string | null;
  }>;
}

export interface WaBlastKpi {
  batches_24h: number;
  delivered_24h: number;
  failed_24h: number;
  queued_24h: number;
  unique_users_30d: number;
}

export type WaBlastRole = 'teacher' | 'staff' | 'parent';

export interface WaBlastBatchSummary {
  batch_id: string;
  school_id: string | null;
  school_name: string | null;
  initiated_by_name: string | null;
  started_at: string;
  total: number;
  delivered: number;
  failed: number;
  queued: number;
  /** Per-role slice — MR-H1 backend adds this; older batches carry all-0s. */
  per_role?: Record<WaBlastRole, number>;
}

export interface WaBlastMetricsPayload {
  kpi: WaBlastKpi;
  recent_batches: WaBlastBatchSummary[];
}

export type WaBlastLogStatus = 'queued' | 'delivered' | 'failed';

export interface WaBlastLogRow {
  id: string;
  batch_id: string;
  created_at: string;
  scheduled_at: string;
  sent_at: string | null;
  school_id: string | null;
  school_name: string | null;
  initiated_by_user_id: string | null;
  initiated_by_name: string | null;
  recipient_user_id: string | null;
  recipient_name: string;
  /** MR-H1 backend surfaces the role; older rows may carry null. */
  recipient_role: WaBlastRole | null;
  recipient_phone_masked: string;
  notification_type: string;
  status: WaBlastLogStatus;
  error_message: string | null;
}

export interface WaBlastLogsPayload {
  data: WaBlastLogRow[];
  meta: {
    current_page: number;
    per_page: number;
    total: number;
    last_page: number;
  };
  summary: {
    delivered: number;
    failed: number;
    queued: number;
  };
}

export interface WaBlastLogFilters {
  school_id?: string;
  batch_id?: string;
  status?: string;
  /** Comma-separated `teacher,staff,parent` — MR-H1 backend filter. */
  role?: string;
  phone?: string;
  from?: string;
  to?: string;
  page?: number;
  per_page?: number;
}

export interface AlertRule {
  key: string;
  label: string;
  threshold: Record<string, unknown>;
  enabled: boolean;
  last_fired_at: string | null;
}

export interface AlertSettingsPayload {
  channel: {
    name: string;
    webhook_masked: string;
    webhook_configured: boolean;
    bot_token_masked: string;
    bot_token_configured: boolean;
    /** OR of the two — backward compat with MR-7 UI. */
    configured: boolean;
    /** Which lane the notifier will use right now: bot_token > webhook > none. */
    active_lane: 'bot_token' | 'webhook' | 'none';
  };
  rules: AlertRule[];
}

export interface SlackConfigDraft {
  /** null = leave unchanged; '' = clear; string = set. */
  webhook?: string | null;
  bot_token?: string | null;
  channel?: string | null;
}

export interface SlackTestDraft {
  webhook?: string;
  bot_token?: string;
  channel?: string;
}

const BASE = '/super-admin/monitoring';

async function safeGet<T>(url: string, params: Record<string, unknown> = {}, fallback: T): Promise<T> {
  try {
    const res = await api.get(url, { params });
    return (res.data?.data ?? res.data) as T;
  } catch {
    return fallback;
  }
}

export const MonitoringService = {
  async getHealthStrip(): Promise<HealthStrip> {
    return safeGet<HealthStrip>(`${BASE}/health-strip`, {}, {
      database: { status: 'down' },
      redis: { status: 'down' },
      queue: { status: 'down' },
      scheduler: { status: 'down' },
      worker: { status: 'down' },
      fcm_token: { status: 'up' },
    });
  },

  async getOverview(): Promise<OverviewPayload> {
    return safeGet<OverviewPayload>(`${BASE}/overview`, {}, {
      health: {
        database: { status: 'down' },
        redis: { status: 'down' },
        queue: { status: 'down' },
        scheduler: { status: 'down' },
        worker: { status: 'down' },
        fcm_token: { status: 'up' },
      },
      overview: {
        kpi: { jobs_per_minute: 0, pending: 0, failed_24h: 0, fcm_delivered_today: 0 },
        throughput_30m: [],
        incident: null,
      },
    });
  },

  async getQueue(): Promise<QueuePayload> {
    return safeGet<QueuePayload>(`${BASE}/queue`, {}, {
      queues: [], supervisors: [], failed_jobs: [],
    });
  },

  async getRedis(): Promise<RedisPayload> {
    return safeGet<RedisPayload>(`${BASE}/redis`, {}, {
      redis: {
        memory: { used: 0, used_human: null, peak: 0, peak_human: null },
        clients: 0, blocked_clients: 0, evicted_keys: 0, rejected_connections: 0,
        keys_db0: 0, keys_db1: 0, maxmemory_policy: null,
      },
      system: { cpu: null, ram: null, disk: null },
      maxmemory_warning: false,
    });
  },

  async getNotifications(): Promise<NotificationsPayload> {
    return safeGet<NotificationsPayload>(`${BASE}/notifications`, {}, {
      kpi: { sent: 0, delivered: 0, failed: 0, deactivated_24h: 0, no_token: 0 },
      tokens: { active: 0, inactive: 0 },
      users_without_token: [],
    });
  },

  /**
   * `fcm-logs` uses a different envelope (paginated) so it doesn't
   * unwrap `.data.data` — it returns the full paginator response.
   */
  async getFcmLogs(filters: FcmLogFilters = {}): Promise<FcmLogsPayload> {
    const params = Object.fromEntries(
      Object.entries(filters).filter(([, v]) => v !== undefined && v !== ''),
    );
    try {
      const res = await api.get(`${BASE}/fcm-logs`, { params });
      return res.data as FcmLogsPayload;
    } catch {
      return {
        data: [],
        meta: { current_page: 1, per_page: 50, total: 0, last_page: 1 },
        summary: { delivered: 0, failed: 0, deactivated: 0, no_token: 0 },
      };
    }
  },

  async getErrors(): Promise<ErrorsPayload> {
    return safeGet<ErrorsPayload>(`${BASE}/errors`, {}, {
      exceptions: [], slow_queries: [],
    });
  },

  async getAlertSettings(): Promise<AlertSettingsPayload> {
    return safeGet<AlertSettingsPayload>(`${BASE}/alert-settings`, {}, {
      channel: {
        name: '',
        webhook_masked: '',
        webhook_configured: false,
        bot_token_masked: '',
        bot_token_configured: false,
        configured: false,
        active_lane: 'none',
      },
      rules: [],
    });
  },

  /**
   * Test a Slack destination. Pass ad-hoc `bot_token` + `channel` OR
   * `webhook` to verify BEFORE saving — a typo caught here prevents the
   * "save then wait for silent alerts" loop. Omit everything to test
   * whatever is currently stored (bot_token wins over webhook).
   */
  /**
   * WA Blast tab (SuperAdmin monitoring): KPI + recent batches
   * cross-tenant. Graceful empty on network / table-not-migrated.
   */
  async getWaBlasts(): Promise<WaBlastMetricsPayload> {
    return safeGet<WaBlastMetricsPayload>(`${BASE}/wa-blasts`, {}, {
      kpi: {
        batches_24h: 0, delivered_24h: 0, failed_24h: 0,
        queued_24h: 0, unique_users_30d: 0,
      },
      recent_batches: [],
    });
  },

  /**
   * Paginated per-message WA blast drill-down. Filter shape mirrors
   * getFcmLogs so the UI list component can be shared.
   */
  async getWaBlastLogs(filters: WaBlastLogFilters = {}): Promise<WaBlastLogsPayload> {
    const params = Object.fromEntries(
      Object.entries(filters).filter(([, v]) => v !== undefined && v !== ''),
    );
    try {
      const res = await api.get(`${BASE}/wa-blasts/logs`, { params });
      return res.data as WaBlastLogsPayload;
    } catch {
      return {
        data: [],
        meta: { current_page: 1, per_page: 50, total: 0, last_page: 1 },
        summary: { delivered: 0, failed: 0, queued: 0 },
      };
    }
  },

  async testWebhook(draft: SlackTestDraft = {}): Promise<{ ok: boolean; error?: string; lane?: string }> {
    try {
      const body: Record<string, string> = {};
      if (draft.webhook && draft.webhook.trim() !== '') body.webhook = draft.webhook.trim();
      if (draft.bot_token && draft.bot_token.trim() !== '') body.bot_token = draft.bot_token.trim();
      if (draft.channel && draft.channel.trim() !== '') body.channel = draft.channel.trim();
      const res = await api.post(`${BASE}/alert-settings/test-webhook`, body);
      return res.data as { ok: boolean; error?: string; lane?: string };
    } catch (e: any) {
      return { ok: false, error: e?.response?.data?.error ?? 'network' };
    }
  },

  /**
   * Persist Slack config to the `monitoring_settings` DB table.
   * For each field: `undefined`/omit = leave unchanged; empty string =
   * CLEAR the stored value; string = set. Server busts the cache so
   * the next Horizon boot / alert eval picks up the new value on the
   * next request.
   */
  async updateWebhook(draft: SlackConfigDraft): Promise<{ ok: boolean; error?: string }> {
    try {
      const body: Record<string, string> = {};
      if (draft.webhook !== undefined && draft.webhook !== null) {
        body.webhook = draft.webhook.trim();
      }
      if (draft.bot_token !== undefined && draft.bot_token !== null) {
        body.bot_token = draft.bot_token.trim();
      }
      if (draft.channel !== undefined && draft.channel !== null && draft.channel.trim() !== '') {
        body.channel = draft.channel.trim();
      }
      const res = await api.put(`${BASE}/alert-settings/webhook`, body);
      return res.data as { ok: boolean; error?: string };
    } catch (e: any) {
      return { ok: false, error: e?.response?.data?.message ?? 'network' };
    }
  },
};

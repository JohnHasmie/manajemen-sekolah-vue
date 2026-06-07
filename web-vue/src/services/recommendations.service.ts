/**
 * RecommendationService — `/recommendations/*` wrapper (AI backend).
 *
 * Mirrors Flutter's
 *  `lib/features/recommendations/data/recommendation_service.dart`.
 *
 * All endpoints live on the **kamiledu-ai** backend (separate from
 * the main Laravel API). The Vue HTTP layer routes them via the
 * `aiApi` axios instance which targets `VITE_AI_API_URL` (defaults
 * to `http://localhost:8000/api`). The main Laravel API does not
 * expose any `/recommendations/*` routes.
 *
 * Two surface layers, kept side-by-side:
 *   - Legacy "insight" surface (`list / get / generateClass /
 *     generateStudent / pollJob / markActed`) — used by the parent
 *     inbox + the teacher dashboard's quick-action card.
 *   - Per-rec parity surface (`listLearningRecs / getLearningRec /
 *     updateRecStatus / updateRec / shareRecommendation /
 *     getShareStatus / getClassSummary / generateForClass /
 *     generateForStudent / pollJobUntilComplete / remindRecipient /
 *     revokeRecipient / editAndResendRecipient /
 *     markRecommendationSharesSeenByTeacher /
 *     getStudentStatusCounts`) — used by the teacher class hub +
 *     student list + result + edit screens (Frames A–E).
 */
import { aiApi } from '@/lib/http';
import {
  normalizeRecPriority,
  normalizeRecStatus,
  parseParentInboxRow,
  parseParentSummaryChild,
  type GenerateConfig,
  type LearningRecommendation,
  type ParentInboxRow,
  type ParentSummaryResponse,
  type RecMaterial,
  type RecPriority,
  type RecShareRecipient,
  type RecShareSummary,
  type RecStatus,
  type Recommendation,
  type RecommendationClassSummary,
  type RecommendationJob,
  type RecommendationJobStatus,
  type RecommendationScope,
  type RecommendationStatus,
  type RecommendationStudent,
  type RecTone,
  type ShareAllResult,
  type ShareAllResultRow,
  type StudentStatusCounts,
} from '@/types/recommendations';

// ─── Helpers ────────────────────────────────────────────────────────

type AnyRecord = Record<string, unknown>;

function strOrNull(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === '' ? null : s;
}

function num(v: unknown): number {
  if (typeof v === 'number') return v;
  if (v === null || v === undefined) return 0;
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

/**
 * Rate-limit (429) helper — backend ships a structured payload with
 * `daily_limit / daily_usage / retry_after_seconds`. Surfaces as a
 * typed error so callers can show a friendly toast instead of a
 * generic "AI gagal".
 */
export class RateLimitError extends Error {
  readonly dailyLimit?: number;
  readonly dailyUsage?: number;
  readonly retryAfterSeconds?: number;
  constructor(message: string, payload?: AnyRecord) {
    super(message);
    this.name = 'RateLimitError';
    this.dailyLimit =
      payload?.daily_limit !== undefined ? num(payload.daily_limit) : undefined;
    this.dailyUsage =
      payload?.daily_usage !== undefined ? num(payload.daily_usage) : undefined;
    this.retryAfterSeconds =
      payload?.retry_after_seconds !== undefined
        ? num(payload.retry_after_seconds)
        : undefined;
  }
}

// ─── Legacy "insight" shape mappers ─────────────────────────────────

function studentFromJson(raw: AnyRecord): RecommendationStudent {
  return {
    student_id: String(raw.student_id ?? raw.id ?? ''),
    student_name: String(raw.student_name ?? raw.name ?? raw.nama ?? ''),
    metric_label: (raw.metric_label as string | null) ?? null,
    metric_value:
      (raw.metric_value as string | number | null) ??
      (raw.avg as string | number | null) ??
      null,
    acted: Boolean(raw.acted ?? raw.followed_up ?? false),
  };
}

function fromJson(raw: AnyRecord): Recommendation {
  const subjectObj = raw.subject as AnyRecord | undefined;
  return {
    id: String(raw.id ?? ''),
    scope: (raw.scope ?? 'class') as RecommendationScope,
    context_label: String(raw.context_label ?? raw.label ?? raw.title ?? ''),
    subject_name:
      (raw.subject_name as string | null) ??
      (subjectObj?.name as string | null) ??
      null,
    status: (raw.status ?? 'done') as RecommendationStatus,
    insight:
      (raw.insight as string | null) ??
      (raw.description as string | null) ??
      (raw.body as string | null) ??
      null,
    students: Array.isArray(raw.students)
      ? (raw.students as AnyRecord[]).map(studentFromJson)
      : [],
    meta: (raw.meta as Record<string, unknown> | null) ?? null,
    created_at: String(raw.created_at ?? new Date().toISOString()),
  };
}

// ─── Per-rec (Flutter parity) mappers ───────────────────────────────

function materialFromJson(raw: AnyRecord): RecMaterial {
  return {
    id: raw.id ? String(raw.id) : undefined,
    title: String(raw.title ?? raw.judul ?? 'Materi'),
    description:
      (raw.description as string | null) ??
      (raw.deskripsi as string | null) ??
      null,
    url: (raw.url as string | null) ?? (raw.link as string | null) ?? null,
    kind: (raw.kind as string | null) ?? (raw.type as string | null) ?? null,
    source: (raw.source as string | undefined) ?? undefined,
  };
}

function shareRecipientFromJson(raw: AnyRecord): RecShareRecipient {
  const channels =
    typeof raw.channels === 'object' && raw.channels !== null
      ? (raw.channels as AnyRecord)
      : undefined;
  return {
    id: String(raw.id ?? ''),
    parent_user_id: strOrNull(raw.parent_user_id),
    parent_name: String(raw.parent_name ?? raw.name ?? 'Wali'),
    parent_relation: strOrNull(raw.parent_relation),
    channels: channels
      ? {
          push: Boolean(channels.push),
          whatsapp: Boolean(channels.whatsapp),
        }
      : undefined,
    sent_at: strOrNull(raw.sent_at),
    delivered_at: strOrNull(raw.delivered_at),
    read_at: strOrNull(raw.read_at),
    replied_at: strOrNull(raw.replied_at),
    reply_text: strOrNull(raw.reply_text),
    revoked_at: strOrNull(raw.revoked_at),
    parent_completed_at: strOrNull(raw.parent_completed_at),
    parent_completed_note: strOrNull(raw.parent_completed_note),
    resend_count:
      typeof raw.resend_count === 'number' ? raw.resend_count : undefined,
    last_message: strOrNull(raw.last_message),
    last_tone: (raw.last_tone as RecTone | null) ?? null,
  };
}

function shareSummaryFromJson(
  raw: AnyRecord | undefined,
): RecShareSummary | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  return {
    recipient_count: num(raw.recipient_count),
    read_count: num(raw.read_count),
    replied_count: num(raw.replied_count),
    revoked_count: num(raw.revoked_count),
    latest_sent_at: strOrNull(raw.latest_sent_at),
  };
}

function learningRecFromJson(raw: AnyRecord): LearningRecommendation {
  const teacherObj = (raw.teacher as AnyRecord | undefined) ?? null;
  const studentObj = (raw.student as AnyRecord | undefined) ?? null;
  const classObj =
    (raw.class_ as AnyRecord | undefined) ??
    (raw.class as AnyRecord | undefined) ??
    null;
  const subjectObj = (raw.subject as AnyRecord | undefined) ?? null;

  const matsRaw = Array.isArray(raw.materials)
    ? (raw.materials as AnyRecord[])
    : [];
  const sharesRaw = Array.isArray(raw.share_recipients)
    ? (raw.share_recipients as AnyRecord[])
    : null;

  // Parent denorm — Flutter eager-loads `student.parents` on the
  // homeroom-scope detail call. Mengajar scope ships an empty array;
  // the share sheet's fallback walks `student.mother_name` /
  // `student.father_name` instead (handled in the sheet, not here).
  const parentsRaw = Array.isArray(studentObj?.parents)
    ? (studentObj!.parents as AnyRecord[])
    : null;

  return {
    id: String(raw.id ?? ''),
    scope: (raw.scope as RecommendationScope | undefined) ?? undefined,
    status: normalizeRecStatus(raw.status),
    priority: normalizeRecPriority(raw.priority),
    type: String(raw.type ?? raw.category ?? 'other'),

    title: String(raw.title ?? raw.judul ?? 'Rekomendasi'),
    description:
      (raw.description as string | null) ??
      (raw.deskripsi as string | null) ??
      null,
    ai_reasoning:
      (raw.ai_reasoning as string | null) ??
      (raw.reason as string | null) ??
      null,
    teacher_notes:
      (raw.teacher_notes as string | null) ??
      (raw.catatan_guru as string | null) ??
      null,

    materials: matsRaw.map(materialFromJson),

    student_id: strOrNull(raw.student_id ?? studentObj?.id) ?? undefined,
    student_name:
      (raw.student_name as string | undefined) ??
      (studentObj?.name as string | undefined) ??
      (studentObj?.nama as string | undefined) ??
      undefined,
    student_parents: parentsRaw
      ? parentsRaw.map((p) => ({
          parent_user_id: strOrNull(p.parent_user_id ?? p.user_id),
          parent_name: String(p.name ?? p.parent_name ?? 'Wali'),
          parent_relation: strOrNull(p.relation ?? p.parent_relation),
          parent_phone: strOrNull(p.phone ?? p.parent_phone),
        }))
      : undefined,

    class_id: strOrNull(raw.class_id ?? classObj?.id) ?? undefined,
    class_name:
      (raw.class_name as string | undefined) ??
      (classObj?.name as string | undefined) ??
      (classObj?.nama as string | undefined) ??
      undefined,

    subject_id: strOrNull(raw.subject_id ?? subjectObj?.id),
    subject_name:
      (raw.subject_name as string | null) ??
      (subjectObj?.name as string | null) ??
      null,

    teacher_id: strOrNull(raw.teacher_id ?? teacherObj?.id) ?? undefined,
    teacher_name:
      (raw.teacher_name as string | null) ??
      (teacherObj?.name as string | null) ??
      null,

    due_date: strOrNull(raw.due_date),
    completed_at: strOrNull(raw.completed_at),
    created_at: (raw.created_at as string | undefined) ?? undefined,
    updated_at: strOrNull(raw.updated_at),

    shared_with_parent_at: strOrNull(raw.shared_with_parent_at),
    share_summary: shareSummaryFromJson(
      (raw.share_summary as AnyRecord | undefined) ?? undefined,
    ),
    share_recipient_count:
      typeof raw.share_recipient_count === 'number'
        ? raw.share_recipient_count
        : 0,
    share_read_count:
      typeof raw.share_read_count === 'number' ? raw.share_read_count : 0,
    share_recipients: sharesRaw
      ? sharesRaw.map(shareRecipientFromJson)
      : undefined,
  };
}

// ─── Param interfaces ──────────────────────────────────────────────

interface ListParams {
  scope?: RecommendationScope | 'all';
  class_id?: string;
  subject_id?: string;
}

interface LearningRecListParams {
  /**
   * Pass exactly one of `teacher_id` (guru view) or
   * `homeroom_class_id` (wali kelas view). The backend 403s when
   * both / neither are supplied. When both are present we prefer
   * `homeroom_class_id` because that's the cross-teacher scope a
   * wali kelas actually wants — matches Flutter behavior.
   */
  teacher_id?: string;
  homeroom_class_id?: string;
  class_id?: string;
  student_id?: string;
  subject_id?: string;
  status?: RecStatus;
  priority?: RecPriority;
  category?: string;
  academic_year_id?: string;
  page?: number;
  per_page?: number;
}

interface GenerateClassPayload {
  teacher_id: string;
  class_id: string;
  subject_id: string;
  trigger_source?: string;
  force_regenerate?: boolean;
  include_on_track?: boolean;
  academic_year_id?: string;
}

interface GenerateStudentPayload extends Omit<
  GenerateClassPayload,
  'include_on_track'
> {
  student_id: string;
}

interface GenerateAsyncResponse {
  async: boolean;
  job_id?: string;
  poll_url?: string;
  /** When the backend returned a sync response, the full data payload. */
  data?: unknown;
  message?: string;
}

// ─── Service surface ───────────────────────────────────────────────

export const RecommendationService = {
  // ── Legacy "insight" surface ────────────────────────────────────
  async list(params: ListParams = {}): Promise<Recommendation[]> {
    try {
      const res = await aiApi.get('/recommendations', {
        params: {
          ...(params.scope && params.scope !== 'all'
            ? { scope: params.scope }
            : {}),
          ...(params.class_id ? { class_id: params.class_id } : {}),
          ...(params.subject_id ? { subject_id: params.subject_id } : {}),
        },
      });
      const body = res.data;
      const list = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      return list.map((r: AnyRecord) => fromJson(r));
    } catch {
      return [];
    }
  },

  /**
   * Legacy single-shot AI generate. Kept for the dashboard quick-
   * action card. New screens use `generateForClass` /
   * `generateForStudent` which surface the full async envelope.
   */
  async generateClass(payload: {
    class_id: string;
    subject_id: string;
    teacher_id?: string;
  }): Promise<{ job_id: string }> {
    const res = await aiApi.post('/recommendations/generate', payload);
    return { job_id: String(res.data?.data?.job_id ?? res.data?.job_id ?? '') };
  },

  async generateStudent(payload: {
    student_id: string;
    class_id?: string;
    subject_id?: string;
    teacher_id?: string;
  }): Promise<{ job_id: string }> {
    const res = await aiApi.post('/recommendations/generate-student', payload);
    return { job_id: String(res.data?.data?.job_id ?? res.data?.job_id ?? '') };
  },

  async pollJob(jobId: string): Promise<RecommendationJob> {
    const res = await aiApi.get(`/ai-jobs/${jobId}`);
    const body = res.data?.data ?? res.data ?? {};
    return {
      id: jobId,
      scope: (body.scope ?? 'class') as RecommendationScope,
      context_label: String(body.context_label ?? body.label ?? '—'),
      status: (body.status ?? 'pending') as RecommendationStatus,
      progress:
        typeof body.progress === 'number'
          ? body.progress
          : body.percent
            ? body.percent / 100
            : 0,
    };
  },

  async get(id: string): Promise<Recommendation | null> {
    try {
      const res = await aiApi.get(`/recommendations/${id}`);
      const body = res.data?.data ?? res.data ?? null;
      return body ? fromJson(body) : null;
    } catch {
      return null;
    }
  },

  /** Legacy mark-acted endpoint (parent flow). */
  async markActed(recId: string, studentId: string): Promise<void> {
    await aiApi.post(`/recommendations/${recId}/students/${studentId}/acted`);
  },

  // ── Per-rec (Flutter parity) surface ────────────────────────────

  /** List per-student recs paginated, with Flutter-shaped filters. */
  async listLearningRecs(params: LearningRecListParams = {}): Promise<{
    items: LearningRecommendation[];
    total: number;
    last_page: number;
  }> {
    try {
      const res = await aiApi.get('/recommendations', {
        params: {
          page: params.page ?? 1,
          per_page: params.per_page ?? 15,
          // Prefer homeroom scope when both present (matches Flutter).
          ...(params.homeroom_class_id
            ? { homeroom_class_id: params.homeroom_class_id }
            : params.teacher_id
              ? { teacher_id: params.teacher_id }
              : {}),
          ...(params.class_id ? { class_id: params.class_id } : {}),
          ...(params.student_id ? { student_id: params.student_id } : {}),
          ...(params.subject_id ? { subject_id: params.subject_id } : {}),
          ...(params.status ? { status: params.status } : {}),
          ...(params.priority ? { priority: params.priority } : {}),
          ...(params.category ? { category: params.category } : {}),
          ...(params.academic_year_id
            ? { academic_year_id: params.academic_year_id }
            : {}),
        },
      });
      const body = res.data ?? {};
      const list: AnyRecord[] = Array.isArray(body.data) ? body.data : [];
      const meta = body.meta ?? {};
      return {
        items: list.map(learningRecFromJson),
        total: Number(meta.total ?? list.length ?? 0),
        last_page: Number(meta.last_page ?? 1),
      };
    } catch {
      return { items: [], total: 0, last_page: 1 };
    }
  },

  /** Fetch one rec by id (hydrated, with relations). */
  async getLearningRec(id: string): Promise<LearningRecommendation | null> {
    try {
      const res = await aiApi.get(`/recommendations/${id}`);
      const body = res.data?.data ?? res.data ?? null;
      return body ? learningRecFromJson(body) : null;
    } catch {
      return null;
    }
  },

  /**
   * Alias for `getLearningRec` — matches Flutter naming so the
   * priority-inbox resolver call sites line up cleanly. Throws on
   * 404 so the caller can fall back to a friendly error message.
   */
  async getRecommendationById(id: string): Promise<LearningRecommendation> {
    const res = await aiApi.get(`/recommendations/${id}`);
    const body = res.data?.data ?? res.data ?? null;
    if (!body) {
      throw new Error(`Recommendation ${id} not found`);
    }
    return learningRecFromJson(body);
  },

  /**
   * PATCH /recommendations/{id}/status — toggles a rec between
   * pending / in_progress / completed / dismissed. `teacher_id` is
   * required (the AI backend checks both ownership AND wali-kelas
   * authority).
   */
  async updateRecStatus(args: {
    rec_id: string;
    status: RecStatus;
    teacher_id: string;
    teacher_notes?: string;
  }): Promise<void> {
    await aiApi.patch(`/recommendations/${args.rec_id}/status`, {
      status: args.status,
      teacher_id: args.teacher_id,
      ...(args.teacher_notes !== undefined
        ? { teacher_notes: args.teacher_notes }
        : {}),
    });
  },

  /**
   * PATCH /recommendations/{id} — full edit (title / description /
   * priority / materials / teacher_notes). Used by the edit screen.
   * `teacher_id` is required for the same authorisation reason as
   * `updateRecStatus`.
   */
  async updateRec(args: {
    rec_id: string;
    teacher_id: string;
    title?: string;
    description?: string;
    priority?: RecPriority;
    teacher_notes?: string;
    materials?: RecMaterial[];
  }): Promise<LearningRecommendation | null> {
    const res = await aiApi.patch(`/recommendations/${args.rec_id}`, {
      teacher_id: args.teacher_id,
      ...(args.title !== undefined ? { title: args.title } : {}),
      ...(args.description !== undefined
        ? { description: args.description }
        : {}),
      ...(args.priority !== undefined ? { priority: args.priority } : {}),
      ...(args.teacher_notes !== undefined
        ? { teacher_notes: args.teacher_notes }
        : {}),
      ...(args.materials !== undefined ? { materials: args.materials } : {}),
    });
    const body = res.data?.data ?? res.data ?? null;
    return body ? learningRecFromJson(body) : null;
  },

  /** POST /recommendations/{id}/share — fan out to parents. */
  async shareRecommendation(args: {
    rec_id: string;
    teacher_id: string;
    parents: Array<{
      parent_user_id?: string | null;
      parent_name: string;
      parent_phone?: string | null;
      parent_relation?: string;
    }>;
    message?: string;
    tone?: RecTone | string;
    channel_push?: boolean;
    channel_whatsapp?: boolean;
  }): Promise<LearningRecommendation | null> {
    const res = await aiApi.post(`/recommendations/${args.rec_id}/share`, {
      teacher_id: args.teacher_id,
      parents: args.parents,
      ...(args.message ? { message: args.message } : {}),
      ...(args.tone ? { tone: args.tone } : {}),
      channels: {
        push: args.channel_push ?? true,
        whatsapp: args.channel_whatsapp ?? false,
      },
    });
    const body = res.data?.data ?? res.data ?? null;
    return body ? learningRecFromJson(body) : null;
  },

  /**
   * POST /recommendations/share-all — Kirim semua ke wali.
   *
   * Bulk-shares every shareable, not-yet-shared rec (status != dismissed
   * AND shared_with_parent_at IS NULL) for `teacher_id`, optionally scoped
   * to one `class_id`. Unlike `shareRecommendation`, the client sends NO
   * `parents[]` — the backend resolves each rec's wali from the student's
   * guardian_* fields itself. Returns a tally + per-rec breakdown so the
   * caller can show a "X terkirim, Y gagal, Z dilewati" summary.
   *
   * One cover `message` / `tone` is applied to every rec.
   */
  async shareAllToParents(args: {
    teacher_id: string;
    class_id?: string;
    message?: string;
    tone?: RecTone | string;
    channel_push?: boolean;
    channel_whatsapp?: boolean;
  }): Promise<ShareAllResult> {
    const res = await aiApi.post('/recommendations/share-all', {
      teacher_id: args.teacher_id,
      ...(args.class_id ? { class_id: args.class_id } : {}),
      ...(args.message ? { message: args.message } : {}),
      ...(args.tone ? { tone: args.tone } : {}),
      channels: {
        push: args.channel_push ?? true,
        whatsapp: args.channel_whatsapp ?? false,
      },
    });
    const body = (res.data ?? {}) as AnyRecord;
    const rowsRaw = Array.isArray(body.results)
      ? (body.results as AnyRecord[])
      : [];
    const results: ShareAllResultRow[] = rowsRaw.map((r) => {
      const status = String(r.status ?? '').toLowerCase();
      return {
        recommendation_id: String(r.recommendation_id ?? r.id ?? ''),
        student_name: String(r.student_name ?? 'Siswa'),
        status:
          status === 'sent' || status === 'failed' || status === 'skipped'
            ? (status as ShareAllResultRow['status'])
            : 'failed',
        error: strOrNull(r.error),
      };
    });
    return {
      success: Boolean(body.success ?? true),
      total: num(body.total),
      sent: num(body.sent),
      failed: num(body.failed),
      skipped_no_wali: num(body.skipped_no_wali),
      results,
    };
  },

  /**
   * Count not-yet-shared, shareable recs for a teacher (optionally scoped
   * to one class). Mirrors the backend's `share-all` selection rule
   * (status != dismissed AND shared_with_parent_at IS NULL) so the UI can
   * enable/disable the "Kirim semua ke wali" button and show the count.
   *
   * Reuses the same paginated `GET /recommendations` walk as
   * `getStudentStatusCounts` — the backend has no dedicated counter.
   */
  async countUnsharedRecs(args: {
    teacher_id?: string;
    homeroom_class_id?: string;
    class_id?: string;
    academic_year_id?: string;
  }): Promise<number> {
    try {
      let page = 1;
      const perPage = 50;
      const maxPages = 50;
      let count = 0;
      while (page <= maxPages) {
        const { items, last_page } = await this.listLearningRecs({
          teacher_id: args.teacher_id,
          homeroom_class_id: args.homeroom_class_id,
          class_id: args.class_id,
          academic_year_id: args.academic_year_id,
          per_page: perPage,
          page,
        });
        for (const rec of items) {
          if (rec.status === 'dismissed') continue;
          if (!rec.shared_with_parent_at) count += 1;
        }
        if (page >= last_page) break;
        page += 1;
      }
      return count;
    } catch {
      return 0;
    }
  },

  /** GET /recommendations/{id}/share-status — per-recipient timeline. */
  async getShareStatus(recId: string): Promise<RecShareRecipient[]> {
    try {
      const res = await aiApi.get(`/recommendations/${recId}/share-status`);
      // Backend ships `{ data: { recipients: [...] } }` per the
      // Riwayat Pengiriman contract; some older shapes ship an
      // array directly. Cover both.
      const body = res.data ?? {};
      const inner = body.data ?? body;
      const list: AnyRecord[] = Array.isArray(inner)
        ? inner
        : Array.isArray(inner?.recipients)
          ? inner.recipients
          : Array.isArray(body.recipients)
            ? body.recipients
            : [];
      return list.map(shareRecipientFromJson);
    } catch {
      return [];
    }
  },

  /** POST /share/{recipientId}/remind — re-stamp sent_at + bump resend. */
  async remindRecipient(args: {
    rec_id: string;
    recipient_id: string;
  }): Promise<void> {
    await aiApi.post(
      `/recommendations/${args.rec_id}/share/${args.recipient_id}/remind`,
    );
  },

  /** POST /share/{recipientId}/revoke — flag recipient as revoked. */
  async revokeRecipient(args: {
    rec_id: string;
    recipient_id: string;
    reason?: string;
  }): Promise<void> {
    await aiApi.post(
      `/recommendations/${args.rec_id}/share/${args.recipient_id}/revoke`,
      args.reason ? { reason: args.reason } : {},
    );
  },

  /**
   * PATCH /share/{recipientId} — Edit & Kirim Ulang. Updates the
   * shared message/tone snapshot AND re-stamps sent_at without
   * losing existing read/reply state.
   */
  async editAndResendRecipient(args: {
    rec_id: string;
    recipient_id: string;
    message?: string;
    tone?: RecTone | string;
  }): Promise<void> {
    await aiApi.patch(
      `/recommendations/${args.rec_id}/share/${args.recipient_id}`,
      {
        ...(args.message !== undefined ? { message: args.message } : {}),
        ...(args.tone !== undefined ? { tone: args.tone } : {}),
      },
    );
  },

  /**
   * POST /mark-shares-seen — wali kelas marks every share recipient
   * of the rec they just opened as "seen by teacher". Fire-and-
   * forget by design (Flutter does the same): a failure should
   * never block the screen, and the dashboard auto-corrects on the
   * next refresh.
   */
  async markRecommendationSharesSeenByTeacher(recId: string): Promise<void> {
    try {
      await aiApi.post(`/recommendations/${recId}/mark-shares-seen`);
    } catch {
      // Transparent — see method docstring.
    }
  },

  /** GET /recommendations/class/{id}/summary. */
  async getClassSummary(
    classId: string,
    opts: { academic_year_id?: string } = {},
  ): Promise<RecommendationClassSummary> {
    const empty: RecommendationClassSummary = {
      total_recommendations: 0,
      by_status: { pending: 0, in_progress: 0, completed: 0, dismissed: 0 },
      by_priority: { high: 0, medium: 0, low: 0 },
      by_category: {},
    };
    try {
      const res = await aiApi.get(`/recommendations/class/${classId}/summary`, {
        params: opts.academic_year_id
          ? { academic_year_id: opts.academic_year_id }
          : {},
      });
      const data = res.data?.data ?? res.data ?? {};
      return {
        total_recommendations: Number(data.total_recommendations ?? 0),
        by_status: {
          pending: Number(data.by_status?.pending ?? 0),
          in_progress: Number(data.by_status?.in_progress ?? 0),
          completed: Number(data.by_status?.completed ?? 0),
          dismissed: Number(data.by_status?.dismissed ?? 0),
        },
        by_priority: {
          high: Number(data.by_priority?.high ?? 0),
          medium: Number(data.by_priority?.medium ?? 0),
          low: Number(data.by_priority?.low ?? 0),
        },
        by_category:
          data.by_category && typeof data.by_category === 'object'
            ? data.by_category
            : {},
        at_risk_count:
          data.at_risk_count !== undefined
            ? Number(data.at_risk_count)
            : undefined,
      };
    } catch {
      return empty;
    }
  },

  // ── AI generate (rich envelope) ────────────────────────────────

  /**
   * POST /recommendations/generate — class scope. Backend may
   * respond sync (200) OR async (202 with job_id). Returns a
   * uniform envelope so the caller can branch on `async`.
   *
   * Throws `RateLimitError` on 429 with structured payload (daily
   * usage/limit/retry_after) so the UI can show a quota banner.
   */
  async generateForClass(
    payload: GenerateClassPayload,
  ): Promise<GenerateAsyncResponse> {
    const res = await aiApi.post('/recommendations/generate', payload, {
      validateStatus: (s) => s !== null && s < 500,
    });
    const body = res.data ?? {};
    if (res.status === 429) {
      throw new RateLimitError(
        String(body.message ?? 'Batas harian AI tercapai.'),
        body,
      );
    }
    if (res.status === 202) {
      return {
        async: true,
        job_id: String(body.data?.job_id ?? body.job_id ?? ''),
        poll_url: body.data?.poll_url ?? body.poll_url,
        message: body.message ?? 'Processing…',
      };
    }
    return { async: false, data: body, message: body.message };
  },

  /** POST /recommendations/generate-student — single-student variant. */
  async generateForStudent(
    payload: GenerateStudentPayload,
  ): Promise<GenerateAsyncResponse> {
    const res = await aiApi.post('/recommendations/generate-student', payload, {
      validateStatus: (s) => s !== null && s < 500,
    });
    const body = res.data ?? {};
    if (res.status === 429) {
      throw new RateLimitError(
        String(body.message ?? 'Batas harian AI tercapai.'),
        body,
      );
    }
    if (res.status === 202) {
      return {
        async: true,
        job_id: String(body.data?.job_id ?? body.job_id ?? ''),
        poll_url: body.data?.poll_url ?? body.poll_url,
        message: body.message ?? 'Processing…',
      };
    }
    return { async: false, data: body, message: body.message };
  },

  /**
   * Poll an AI job until completion or maxAttempts. Mirrors Flutter
   * `pollJobUntilComplete` — accepts both `done` and `completed` as
   * terminal-success, `error` and `failed` as terminal-failure.
   * Transient network errors are swallowed and retried (matches
   * Flutter's silent-retry behavior).
   *
   * @param onProgress called on every successful poll with the raw
   *                   status string + the 1-indexed attempt number.
   */
  async pollJobUntilComplete(
    jobId: string,
    opts: {
      intervalMs?: number;
      maxAttempts?: number;
      onProgress?: (
        status: RecommendationJobStatus,
        attempt: number,
        rawData?: AnyRecord,
      ) => void;
    } = {},
  ): Promise<AnyRecord> {
    const intervalMs = opts.intervalMs ?? 5000;
    const maxAttempts = opts.maxAttempts ?? 60;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const res = await aiApi.get(`/ai-jobs/${jobId}`, {
          validateStatus: (s) => s !== null && s < 500,
        });
        if (res.status === 200) {
          const body = res.data ?? {};
          const data = (body.data ?? body) as AnyRecord;
          const status = String(
            data.status ?? '',
          ).toLowerCase() as RecommendationJobStatus;
          opts.onProgress?.(status, attempt, data);
          if (status === 'completed' || status === 'done') {
            return data;
          }
          if (status === 'failed' || status === 'error') {
            const errMsg =
              (data.error as string | undefined) ?? 'AI job failed';
            throw new Error(errMsg);
          }
          // still processing — fall through to wait + retry
        }
      } catch (e) {
        // Rethrow only when the job itself reported failure; transient
        // network/HTTP errors get swallowed and retried.
        if (
          e instanceof Error &&
          (e.message === 'AI job failed' || e.name === 'AIJobError')
        ) {
          throw e;
        }
        // Swallow + retry on network blips.
      }
      if (attempt < maxAttempts) {
        await new Promise((r) => setTimeout(r, intervalMs));
      }
    }
    throw new Error(
      `AI job ${jobId} did not complete within ${maxAttempts} attempts`,
    );
  },

  // ── Per-student status rollup (Frame B) ────────────────────────

  /**
   * Paginated rollup of recommendations grouped by student_id. Used
   * by the student list view to drive the "n REC" pills (and the
   * red overflow when ≥3 pending). Backend doesn't ship this as a
   * dedicated endpoint — we walk `GET /recommendations` 50/page
   * and tally, exactly like Flutter's `getStudentStatusCounts`.
   *
   * Pass `homeroom_class_id` (NOT `teacher_id`) when the caller is
   * the wali kelas — that returns recs across all authoring
   * teachers in the homeroom, which is what the wali-kelas
   * dashboard needs.
   */
  async getStudentStatusCounts(args: {
    class_id: string;
    teacher_id?: string;
    homeroom_class_id?: string;
    academic_year_id?: string;
  }): Promise<StudentStatusCounts> {
    const counts: StudentStatusCounts = {};
    try {
      let page = 1;
      const perPage = 50;
      // Hard ceiling so a runaway response never spins forever — at
      // 50/page this caps the rollup at 2 500 recs / class which is
      // far beyond any realistic homeroom.
      const maxPages = 50;
      while (page <= maxPages) {
        const { items, last_page } = await this.listLearningRecs({
          class_id: args.class_id,
          teacher_id: args.teacher_id,
          homeroom_class_id: args.homeroom_class_id,
          academic_year_id: args.academic_year_id,
          per_page: perPage,
          page,
        });
        for (const rec of items) {
          const sid = rec.student_id ?? '';
          if (!sid) continue;
          if (!counts[sid]) {
            counts[sid] = { total: 0, pending: 0, completed: 0 };
          }
          counts[sid].total += 1;
          if (rec.status === 'completed') {
            counts[sid].completed += 1;
          } else {
            counts[sid].pending += 1;
          }
        }
        if (page >= last_page) break;
        page += 1;
      }
      return counts;
    } catch {
      return counts;
    }
  },

  /**
   * Helper for the generate sheet: turns a `GenerateConfig` into one
   * or more async-envelope responses. Returns one entry per
   * (subject × student) fan-out call so the caller can poll each
   * job independently and surface per-call success/failure.
   *
   * - `at_risk` / `all` → one call per subject (class-wide).
   * - `per_student`    → one call per (subject × student).
   */
  async dispatchGenerate(args: {
    cfg: GenerateConfig;
    teacher_id: string;
    class_id: string;
    academic_year_id?: string;
  }): Promise<
    Array<{
      subject_id: string;
      student_id?: string;
      response?: GenerateAsyncResponse;
      error?: Error;
    }>
  > {
    const out: Array<{
      subject_id: string;
      student_id?: string;
      response?: GenerateAsyncResponse;
      error?: Error;
    }> = [];

    const includeOnTrack =
      args.cfg.scope === 'all' ? true : args.cfg.include_on_track;

    for (const subjectId of args.cfg.subject_ids) {
      if (args.cfg.scope === 'per_student') {
        const studentIds = args.cfg.student_ids ?? [];
        for (const studentId of studentIds) {
          try {
            const response = await this.generateForStudent({
              teacher_id: args.teacher_id,
              class_id: args.class_id,
              subject_id: subjectId,
              student_id: studentId,
              trigger_source: args.cfg.trigger_source,
              force_regenerate: args.cfg.force_regenerate,
              academic_year_id: args.academic_year_id,
            });
            out.push({
              subject_id: subjectId,
              student_id: studentId,
              response,
            });
          } catch (e) {
            out.push({
              subject_id: subjectId,
              student_id: studentId,
              error: e instanceof Error ? e : new Error(String(e)),
            });
          }
        }
      } else {
        try {
          const response = await this.generateForClass({
            teacher_id: args.teacher_id,
            class_id: args.class_id,
            subject_id: subjectId,
            trigger_source: args.cfg.trigger_source,
            force_regenerate: args.cfg.force_regenerate,
            include_on_track: includeOnTrack,
            academic_year_id: args.academic_year_id,
          });
          out.push({ subject_id: subjectId, response });
        } catch (e) {
          out.push({
            subject_id: subjectId,
            error: e instanceof Error ? e : new Error(String(e)),
          });
        }
      }
    }

    return out;
  },

  // ── Parent (wali) inbox surface ─────────────────────────────────
  //
  // Mirrors Flutter's `ApiRecommendationService.getParentInbox` /
  // `getParentSummary` / `markRecommendationRead` / `replyToRec` /
  // `markRecommendationCompletedByParent`. All hit the AI backend
  // (`aiApi`).

  /**
   * GET /recommendations/parent-inbox?parent_user_id[&student_id]
   *
   * Throws on transport errors so the view can render an error plaque
   * instead of silently rendering an empty inbox. Callers that want
   * a soft fallback can wrap in their own try/catch.
   */
  async getParentInbox(args: {
    parent_user_id: string;
    student_id?: string | null;
    unread_only?: boolean;
  }): Promise<ParentInboxRow[]> {
    const res = await aiApi.get('/recommendations/parent-inbox', {
      params: {
        parent_user_id: args.parent_user_id,
        ...(args.student_id ? { student_id: args.student_id } : {}),
        ...(args.unread_only ? { unread_only: 'true' } : {}),
      },
    });
    const body = res.data;
    const list = Array.isArray(body?.data)
      ? body.data
      : Array.isArray(body)
        ? body
        : [];
    return (list as AnyRecord[]).map(parseParentInboxRow);
  },

  /**
   * GET /recommendations/parent-summary?parent_user_id — per-child
   * summary. Throws on transport errors (see `getParentInbox`).
   */
  async getParentSummary(args: {
    parent_user_id: string;
  }): Promise<ParentSummaryResponse> {
    const res = await aiApi.get('/recommendations/parent-summary', {
      params: { parent_user_id: args.parent_user_id },
    });
    const body = res.data?.data ?? res.data ?? {};
    const children = Array.isArray(body.children) ? body.children : [];
    return {
      children: (children as AnyRecord[]).map(parseParentSummaryChild),
      totals:
        body.totals && typeof body.totals === 'object'
          ? (body.totals as Record<string, number>)
          : {},
    };
  },

  /** POST /recommendations/{id}/share/mark-read — best-effort read receipt. */
  async markRecAsRead(args: {
    recommendation_id: string;
    parent_user_id: string;
  }): Promise<void> {
    try {
      await aiApi.post(
        `/recommendations/${args.recommendation_id}/share/mark-read`,
        { parent_user_id: args.parent_user_id },
      );
    } catch {
      // Read receipts are best-effort.
    }
  },

  /** POST /recommendations/{id}/share/reply — parent reply to wali kelas. */
  async replyToRec(args: {
    recommendation_id: string;
    parent_user_id: string;
    reply_text: string;
  }): Promise<void> {
    await aiApi.post(`/recommendations/${args.recommendation_id}/share/reply`, {
      parent_user_id: args.parent_user_id,
      reply_text: args.reply_text,
    });
  },

  /**
   * POST /recommendations/{id}/share/mark-completed-by-parent — stamps
   * `parent_completed_at` (and optionally flips status to `completed`
   * so the wali kelas's hub reflects it too).
   */
  async markRecCompletedByParent(args: {
    recommendation_id: string;
    parent_user_id: string;
    note?: string | null;
    notify_teacher?: boolean;
  }): Promise<void> {
    await aiApi.post(
      `/recommendations/${args.recommendation_id}/share/mark-completed-by-parent`,
      {
        parent_user_id: args.parent_user_id,
        ...(args.note && args.note.trim() ? { note: args.note.trim() } : {}),
        notify_teacher: args.notify_teacher ?? true,
      },
    );
  },
};

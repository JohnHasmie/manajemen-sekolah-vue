/**
 * LessonPlanService — `/api/rpp/*` wrapper.
 *
 * Mirrors Flutter's `lib/features/lesson_plans/data/lesson_plan_service.dart`
 * + `admin_lesson_plan_queue_service.dart`.
 *
 * Endpoint matrix:
 *   GET    /rpp                          paginated list (teacher + admin)
 *   GET    /rpp/summary                  list + counts envelope
 *   GET    /rpp/{id}                     full detail (with format_data)
 *   POST   /rpp                          create (manual or AI seed)
 *   PUT    /rpp/{id}                     update (sections, metadata)
 *   DELETE /rpp/{id}                     delete
 *   PUT    /rpp/{id}/status              admin approve / reject / update
 *   PUT    /rpp/{id}/send-back           admin send back for revision
 *   POST   /rpp/{id}/submit              teacher submit for review
 *   GET    /rpp/{id}/reviews             review history timeline
 *   POST   /rpp/generate                 AI generation (returns job_id)
 *   GET    /ai-jobs/{id}                 AI job polling
 *   POST   /rpp/upload                   multipart file upload
 *   GET    /api/lesson-plans/admin-queue admin tier-grouped queue
 *
 * Status writes use PUT verb (matches Flutter); older approve/reject
 * shortcuts are kept as service-level wrappers so legacy callers keep
 * working while we migrate to `updateStatus`.
 */
import { aiApi, api } from '@/lib/http';
import { useAuthStore } from '@/stores/auth';
import type { Pagination } from '@/types/api';
import {
  adminQueueFromJson,
  lessonPlanFromJson,
  reviewFromJson,
  type AdminQueueResponse,
  type LessonPlan,
  type LessonPlanCounts,
  type LessonPlanFormat,
  type LessonPlanReview,
  type LessonPlanStatus,
} from '@/types/lesson-plans';

// ── List + summary ──

export interface LessonPlanListParams {
  status?: LessonPlanStatus | 'all';
  format?: LessonPlanFormat;
  subject_id?: string | null;
  class_id?: string | null;
  teacher_id?: string | null;
  /** AI vs Manual filter. */
  method?: 'ai' | 'manual';
  /** Period chip — "today" | "week" | "month" | "semester" | "year". */
  period?: string;
  page?: number;
  per_page?: number;
  search?: string;
}

export interface LessonPlanListResult {
  items: LessonPlan[];
  pagination?: Pagination;
  counts: LessonPlanCounts;
}

function unwrap(body: unknown): {
  data: Record<string, unknown>[];
  pagination?: Pagination;
  counts: LessonPlanCounts;
} {
  if (body && typeof body === 'object') {
    const b = body as Record<string, unknown>;
    const data = Array.isArray(b.data)
      ? (b.data as Record<string, unknown>[])
      : Array.isArray(body)
        ? (body as Record<string, unknown>[])
        : [];
    const countsRaw = (b.counts as Record<string, unknown> | undefined) ?? {};
    const counts: LessonPlanCounts = {
      pending: Number(countsRaw.pending ?? 0),
      approved: Number(countsRaw.approved ?? 0),
      rejected: Number(countsRaw.rejected ?? 0),
      draft:
        countsRaw.draft !== undefined ? Number(countsRaw.draft) : undefined,
      sent_back:
        countsRaw.sent_back !== undefined
          ? Number(countsRaw.sent_back)
          : undefined,
      total:
        countsRaw.total !== undefined ? Number(countsRaw.total) : undefined,
      weekly:
        countsRaw.weekly !== undefined ? Number(countsRaw.weekly) : undefined,
      monthly:
        countsRaw.monthly !== undefined
          ? Number(countsRaw.monthly)
          : undefined,
      ai_generated:
        countsRaw.ai_generated !== undefined
          ? Number(countsRaw.ai_generated)
          : undefined,
    };
    return { data, pagination: b.pagination as Pagination | undefined, counts };
  }
  return {
    data: [],
    counts: { pending: 0, approved: 0, rejected: 0 },
  };
}

/**
 * Map our canonical TS status (PascalCase) to the value the backend
 * understands. The Laravel repo does `WHERE LOWER(status) = LOWER(:s)`
 * so the case doesn't matter, but `SentBack` is `sent_back` on the
 * DB side — translate explicitly so the filter actually matches.
 */
function statusToApiValue(s: LessonPlanStatus): string {
  if (s === 'SentBack') return 'sent_back';
  return s; // Draft / Pending / Approved / Rejected pass through
}

export const LessonPlanService = {
  /**
   * Legacy paginated list — kept for callers that don't need the
   * envelope KPI. Returns items + counts block.
   */
  async list(params: LessonPlanListParams = {}): Promise<LessonPlanListResult> {
    try {
      const res = await api.get('/rpp', {
        params: {
          ...(params.status && params.status !== 'all'
            ? { status: statusToApiValue(params.status) }
            : {}),
          // Backend repository reads `formats` (plural, comma-separated
          // multi-select) — `format` singular is the chip filter on
          // /lesson-plans/admin-queue only. Send both so either endpoint
          // honours the constraint.
          ...(params.format ? { formats: params.format, format: params.format } : {}),
          ...(params.subject_id ? { subject_id: params.subject_id } : {}),
          ...(params.class_id ? { class_id: params.class_id } : {}),
          ...(params.teacher_id ? { teacher_id: params.teacher_id } : {}),
          ...(params.method ? { method: params.method } : {}),
          ...(params.period ? { period: params.period } : {}),
          ...(params.search ? { search: params.search } : {}),
          page: params.page ?? 1,
          // Flutter's RPP endpoint expects `limit`, not `per_page`.
          limit: params.per_page ?? 20,
        },
      });
      const { data, pagination } = unwrap(res.data);
      return {
        items: data.map(lessonPlanFromJson),
        pagination,
        // /rpp index doesn't ship counts — KPI block lives on /rpp/summary.
        // Caller fetches the KPI separately via getKpi() and merges.
        counts: { pending: 0, approved: 0, rejected: 0 },
      };
    } catch {
      return {
        items: [],
        counts: { pending: 0, approved: 0, rejected: 0 },
      };
    }
  },

  /**
   * `/rpp/summary` — KPI block only. Backend response shape is:
   *   { success, data: [{ subject_id, subject_name, total, statuses }],
   *     kpi:  { weekly, monthly, open, ai, approved, rejected, total } }
   *
   * The `data` field is a per-subject pivot for the dashboard chart
   * (not lesson-plan rows) — we ignore it and just lift `kpi` into
   * the LessonPlanCounts shape the chrome consumes.
   */
  async getKpi(params: LessonPlanListParams = {}): Promise<LessonPlanCounts> {
    try {
      const res = await api.get('/rpp/summary', {
        params: {
          ...(params.teacher_id ? { teacher_id: params.teacher_id } : {}),
          ...(params.search ? { search: params.search } : {}),
        },
      });
      const body = (res.data ?? {}) as Record<string, unknown>;
      const kpi = (body.kpi as Record<string, unknown> | undefined) ?? {};
      return {
        // Backend's `open` lumps draft + pending + submitted; we surface
        // it as `pending` for the "Menunggu" KPI tile (the most common
        // meaning in the teacher chrome).
        pending: Number(kpi.open ?? kpi.pending ?? 0),
        approved: Number(kpi.approved ?? 0),
        rejected: Number(kpi.rejected ?? 0),
        draft: kpi.draft !== undefined ? Number(kpi.draft) : undefined,
        sent_back:
          kpi.sent_back !== undefined ? Number(kpi.sent_back) : undefined,
        total: Number(kpi.total ?? 0),
        weekly: Number(kpi.weekly ?? 0),
        monthly: Number(kpi.monthly ?? 0),
        ai_generated: Number(kpi.ai ?? kpi.ai_generated ?? 0),
      };
    } catch {
      return { pending: 0, approved: 0, rejected: 0 };
    }
  },

  /**
   * Convenience: fetch list + KPI in parallel. Returns the combined
   * envelope so chrome callers don't have to coordinate the two
   * round-trips.
   */
  async getSummary(params: LessonPlanListParams = {}): Promise<LessonPlanListResult> {
    const [listRes, kpi] = await Promise.all([
      this.list(params),
      this.getKpi(params),
    ]);
    return {
      items: listRes.items,
      pagination: listRes.pagination,
      counts: kpi,
    };
  },

  // ── Detail / mutate ──

  /** Full detail (with format_data + nested relations). */
  async getById(id: string): Promise<LessonPlan | null> {
    try {
      const res = await api.get(`/rpp/${id}`);
      const body = res.data as Record<string, unknown>;
      const raw = (body?.data ?? body) as Record<string, unknown>;
      if (!raw || !raw.id) return null;
      return lessonPlanFromJson(raw);
    } catch {
      return null;
    }
  },

  /**
   * Teacher creates a new RPP (manual seed or AI-generated). Pass
   * format-specific fields under `format_data` so the backend stores
   * them in the structured JSON column.
   */
  async create(payload: {
    title?: string;
    subject_id: string;
    class_id: string;
    format: LessonPlanFormat;
    academic_year?: string | null;
    semester?: string | null;
    notes?: string | null;
    format_data?: Record<string, string>;
  }): Promise<LessonPlan> {
    const res = await api.post('/rpp', payload);
    const body = res.data as Record<string, unknown>;
    return lessonPlanFromJson(
      ((body.data ?? body) ?? {}) as Record<string, unknown>,
    );
  },

  /**
   * Create a `format=file` RPP from a freshly-uploaded file. Mirrors
   * Flutter's `createFileFormatLessonPlan` — the backend reads the
   * top-level `file_path / file_name / file_size / file_mime` keys
   * directly (not under `format_data`) when format=file, so this
   * method posts the flat shape Flutter ships.
   */
  async createFileFormat(payload: {
    teacher_id: string;
    subject_id: string;
    class_id: string;
    title: string;
    file_path: string;
    file_name: string;
    file_size: number;
    file_mime: string;
    file_url?: string;
    semester?: string | null;
    academic_year?: string | null;
    notes?: string | null;
  }): Promise<LessonPlan> {
    const body: Record<string, unknown> = {
      teacher_id: payload.teacher_id,
      subject_id: payload.subject_id,
      class_id: payload.class_id,
      title: payload.title,
      format: 'file',
      file_path: payload.file_path,
      file_name: payload.file_name,
      file_size: payload.file_size,
      file_mime: payload.file_mime,
      status: 'draft',
    };
    if (payload.file_url) body.file_url = payload.file_url;
    if (payload.semester) body.semester = payload.semester;
    if (payload.academic_year) body.academic_year = payload.academic_year;
    if (payload.notes) body.notes = payload.notes;

    const res = await api.post('/rpp', body);
    const respBody = res.data as Record<string, unknown>;
    return lessonPlanFromJson(
      ((respBody.data ?? respBody) ?? {}) as Record<string, unknown>,
    );
  },

  /**
   * Update one or more fields on an existing RPP. Used by:
   *   - Section editor (per-section save) — `format_data: { key: value }`
   *   - Identity edit sheet (title/class/subject)
   *   - Teacher revising before resubmitting after send-back
   */
  async update(
    id: string,
    payload: Partial<{
      title: string;
      subject_id: string;
      class_id: string;
      academic_year: string;
      semester: string;
      notes: string;
      format_data: Record<string, string>;
    }>,
  ): Promise<LessonPlan> {
    const res = await api.put(`/rpp/${id}`, payload);
    const body = res.data as Record<string, unknown>;
    return lessonPlanFromJson(
      ((body.data ?? body) ?? {}) as Record<string, unknown>,
    );
  },

  async remove(id: string): Promise<void> {
    await api.delete(`/rpp/${id}`);
  },

  // ── Status transitions ──

  /**
   * Admin status update — handles Approve / Reject / generic moves.
   * For "Send Back" use the dedicated `sendBack` method (different
   * verb + payload shape on the backend).
   */
  async updateStatus(
    id: string,
    status: LessonPlanStatus,
    note?: string,
  ): Promise<void> {
    await api.put(`/rpp/${id}/status`, {
      status: statusToApiValue(status),
      ...(note ? { catatan: note } : {}),
    });
  },

  /** Admin sends back to teacher with revision areas + notes. */
  async sendBack(
    id: string,
    args: { note: string; revision_areas?: string[] },
  ): Promise<void> {
    await api.put(`/rpp/${id}/send-back`, {
      catatan: args.note,
      ...(args.revision_areas && args.revision_areas.length > 0
        ? { revision_areas: args.revision_areas }
        : {}),
    });
  },

  /**
   * Teacher submits Draft → Pending. Backend doesn't expose a dedicated
   * `/submit` route — Flutter (`updateLessonPlanStatus`) just PUTs the
   * status endpoint with `status: 'Pending'`, so we mirror that.
   */
  async submitForReview(id: string): Promise<void> {
    return this.updateStatus(id, 'Pending');
  },

  // Legacy single-shot helpers (kept for callers that haven't migrated
  // to the unified `updateStatus`).
  async approve(id: string, note?: string): Promise<void> {
    return this.updateStatus(id, 'Approved', note);
  },
  async reject(id: string, note: string): Promise<void> {
    return this.updateStatus(id, 'Rejected', note);
  },
  async approveBulk(ids: string[]): Promise<void> {
    await api.post('/rpp/bulk-approve', { ids });
  },
  async rejectBulk(ids: string[], note: string): Promise<void> {
    await api.post('/rpp/bulk-reject', { ids, note });
  },

  // ── Review history ──

  /** Chronological audit trail per RPP. */
  async getReviews(id: string): Promise<LessonPlanReview[]> {
    try {
      const res = await api.get(`/rpp/${id}/reviews`);
      const body = res.data;
      const arr: Record<string, unknown>[] = Array.isArray(body)
        ? body
        : Array.isArray(body?.data)
          ? body.data
          : [];
      return arr.map(reviewFromJson);
    } catch {
      return [];
    }
  },

  // ── AI generation ──
  //
  // These endpoints live on the **kamiledu-ai** backend (the same one
  // the Materi flow uses), NOT the core Laravel API. We therefore hit
  // them through the `aiApi` axios instance (base = VITE_AI_API_URL),
  // exactly like `MaterialService.generateWithAi`. The AI backend keys
  // generation off a real `chapter_id` (uuid) and runs async: it
  // returns 202 `{ data: { job_id, poll_url } }`, polled via
  // `GET /ai-jobs/{id}`.
  //
  // Endpoint mapping:
  //   POST   /lesson-plans/generate   (aiApi)  → generateWithAi
  //   GET    /ai-jobs/{id}            (aiApi)  → getAiJob (poller)

  /**
   * Submit an AI generation job. Returns `job_id` for polling via
   * `getAiJob`. When the job finishes, its `result_id` is the
   * created RPP's id.
   *
   * The caller (the generate modal) passes a real `chapter_id` picked
   * from the chapter tree; we map the form shape onto the AI contract:
   *   teacher_id, subject_id, class_id, chapter_id (required) +
   *   sub_chapter_id, time_allocation (string), format, extra_context
   *   (optional).
   */
  async generateWithAi(payload: {
    subject_id: string;
    class_id: string;
    format: LessonPlanFormat;
    chapter_id: string;
    sub_chapter_id?: string;
    duration_minutes?: number;
    approach?: string;
  }): Promise<{ job_id: string; result_id?: string }> {
    const auth = useAuthStore();
    const body: Record<string, unknown> = {
      teacher_id: auth.teacherId,
      subject_id: payload.subject_id,
      class_id: payload.class_id,
      chapter_id: payload.chapter_id,
      format: payload.format,
    };
    if (payload.sub_chapter_id) body.sub_chapter_id = payload.sub_chapter_id;
    // The AI contract wants `time_allocation` as a STRING (max 50).
    if (payload.duration_minutes != null) {
      body.time_allocation = String(payload.duration_minutes);
    }
    if (payload.approach) body.extra_context = payload.approach;

    const res = await aiApi.post('/lesson-plans/generate', body);
    const data = (res.data?.data ?? res.data ?? {}) as {
      job_id?: string;
      id?: string;
      result_id?: string;
    };
    return {
      job_id: String(data.job_id ?? ''),
      result_id: data.result_id ?? data.id,
    };
  },

  async getAiJob(jobId: string): Promise<{
    status: 'pending' | 'running' | 'done' | 'error';
    progress?: number;
    result_id?: string;
    error?: string;
  }> {
    const res = await aiApi.get(`/ai-jobs/${jobId}`);
    const body = (res.data?.data ?? res.data ?? {}) as Record<string, unknown>;
    const raw = String(body.status ?? 'pending').toLowerCase();
    const status =
      raw === 'done' || raw === 'completed'
        ? 'done'
        : raw === 'running' || raw === 'processing'
          ? 'running'
          : raw === 'error' || raw === 'failed'
            ? 'error'
            : 'pending';
    return {
      status: status as 'pending' | 'running' | 'done' | 'error',
      progress:
        typeof body.progress === 'number' ? body.progress : undefined,
      result_id:
        (body.result_id as string | undefined) ??
        (body.id as string | undefined),
      error: body.error as string | undefined,
    };
  },

  /**
   * Regenerate specific sections on an existing RPP via AI.
   * Returns a new `job_id` for polling — same flow as `generateWithAi`
   * but updates instead of creating.
   */
  async regenerateSections(
    id: string,
    sectionKeys: string[],
  ): Promise<{ job_id: string }> {
    const res = await api.post(`/rpp/${id}/regenerate-sections`, {
      sections: sectionKeys,
    });
    const body = (res.data?.data ?? res.data ?? {}) as { job_id?: string };
    return { job_id: String(body.job_id ?? '') };
  },

  // ── File upload ──

  /**
   * Multipart upload for file-format RPPs. Returns the stored file
   * metadata which the caller passes back to `create({format:'file', ...})`.
   */
  async uploadFile(
    file: File,
    opts: { onProgress?: (pct: number) => void } = {},
  ): Promise<{
    file_path: string;
    file_url: string;
    file_name: string;
    file_size: number;
    file_mime: string;
  }> {
    const fd = new FormData();
    fd.append('file', file);
    // Backend exposes this at /upload/rpp (matches Flutter's
    // ApiEndpoints.uploadLessonPlan = '/upload/rpp', not /rpp/upload).
    const res = await api.post('/upload/rpp', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
      onUploadProgress: (e) => {
        if (opts.onProgress && e.total) {
          opts.onProgress(Math.round((e.loaded / e.total) * 100));
        }
      },
    });
    const body = (res.data?.data ?? res.data ?? {}) as Record<string, unknown>;
    return {
      file_path: String(body.file_path ?? ''),
      file_url: String(body.file_url ?? ''),
      file_name: String(body.file_name ?? file.name),
      file_size: Number(body.file_size ?? file.size),
      file_mime: String(body.file_mime ?? file.type),
    };
  },

  // ── Admin tier-grouped queue ──

  /**
   * `/api/lesson-plans/admin-queue` — admin hub source of truth.
   * Returns 3 tiers (Perlu Review / Disetujui / Ditolak) + KPI.
   * Filters mirror the Flutter admin filter sheet.
   */
  async getAdminQueue(params: {
    format?: LessonPlanFormat;
    subject_id?: string;
    class_id?: string;
    teacher_id?: string;
    period?: string;
    search?: string;
  } = {}): Promise<AdminQueueResponse> {
    try {
      const res = await api.get('/lesson-plans/admin-queue', {
        params: {
          ...(params.format ? { format: params.format } : {}),
          ...(params.subject_id ? { subject_id: params.subject_id } : {}),
          ...(params.class_id ? { class_id: params.class_id } : {}),
          ...(params.teacher_id ? { teacher_id: params.teacher_id } : {}),
          ...(params.period ? { period: params.period } : {}),
          ...(params.search ? { search: params.search } : {}),
        },
      });
      return adminQueueFromJson(
        (res.data ?? {}) as Record<string, unknown>,
      );
    } catch {
      return {
        tiers: [
          { key: 'perlu_review', label: 'Perlu Review', tone: 'warn', count: 0, items: [] },
          { key: 'disetujui', label: 'Disetujui', tone: 'good', count: 0, items: [] },
          { key: 'ditolak', label: 'Ditolak', tone: 'bad', count: 0, items: [] },
        ],
        kpi: { total: 0, perlu_review: 0, disetujui: 0, ditolak: 0 },
      };
    }
  },
};

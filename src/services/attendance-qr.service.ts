/**
 * AttendanceQrService — PRESENSI QR (gate QR + personnel cards).
 *
 * Wraps the App\Modules\Attendance gate-QR + card endpoints (backend
 * MR !226). All routes sit under `auth:sanctum` + RBAC permissions:
 *   - attendance.gate_qr.manage   — current / rotate
 *   - attendance.cards.issue       — issue / revoke / export.pdf
 * The axios interceptor in `@/lib/http` already injects the bearer token
 * and `X-School-ID` header.
 *
 * Routes:
 *   GET    /attendance/gate-qr/current             → current()
 *   POST   /attendance/gate-qr/rotate              → rotate()
 *   GET    /attendance/personnel-cards/list        → list(params)  (api!234)
 *   POST   /attendance/personnel-cards/issue       → issue(userIds)
 *   DELETE /attendance/personnel-cards/{cardId}    → revoke(cardId)
 *   GET    /attendance/personnel-cards/export.pdf  → exportPdf(userIds)
 *
 * Distinct from `teacher-attendance.service.ts` (the daily check-in flow)
 * and `attendance.service.ts` (per-session student attendance) — kept in
 * its own file so the gate-QR + card surfaces can move independently.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  GateQrTokenInfo,
  PersonnelCardIssueResult,
  PersonnelCardListParams,
  PersonnelCardListRow,
  PersonnelRole,
  StudentCardIssueResult,
  StudentCardListMeta,
  StudentCardListParams,
  StudentCardListRow,
} from '@/types/attendance-qr';

const Endpoints = {
  gateQrCurrent: '/attendance/gate-qr/current',
  gateQrRotate: '/attendance/gate-qr/rotate',
  cardsList: '/attendance/personnel-cards/list',
  cardsIssue: '/attendance/personnel-cards/issue',
  cardsBase: '/attendance/personnel-cards',
  cardsExportPdf: '/attendance/personnel-cards/export.pdf',
  // Student-card endpoints — separate controller because students are
  // account-less (`students.user_id` points at the guardian, not the
  // student). See StudentCardController on the backend (MR !484).
  studentCardsList: '/attendance/student-cards',
  studentCardsIssue: '/attendance/student-cards/issue',
  studentCardsBase: '/attendance/student-cards',
  studentCardsExportPdf: '/attendance/student-cards/export.pdf',
} as const;

/**
 * Pull a human Indonesian message out of a Laravel error response.
 * Mirrors the helper in teacher-attendance.service.ts so error messages
 * stay consistent across the attendance surfaces.
 */
function humanError(e: unknown, fallback: string): string {
  const ax = e as {
    response?: {
      data?: {
        message?: string;
        error?: string;
        errors?: Record<string, string[]>;
      };
    };
  };
  const d = ax?.response?.data;
  if (d) {
    if (d.message) return String(d.message);
    if (d.error) return String(d.error);
    if (d.errors && typeof d.errors === 'object') {
      const first = Object.values(d.errors)[0];
      if (Array.isArray(first) && first.length > 0) return String(first[0]);
    }
  }
  if (e instanceof Error) return e.message;
  return fallback;
}

function asInt(v: unknown, fallback: number): number {
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n) : fallback;
}

/** Normalize a raw token payload. The server returns nested `{data: {…}}`. */
function tokenFromJson(body: unknown): GateQrTokenInfo {
  const raw = (body as { data?: Record<string, unknown> })?.data
    ?? (body as Record<string, unknown>)
    ?? {};
  const r = raw as Record<string, unknown>;
  return {
    token: String(r.token ?? ''),
    token_id: String(r.token_id ?? r.id ?? ''),
    school_id: String(r.school_id ?? ''),
    valid_from: String(r.valid_from ?? ''),
    valid_until: String(r.valid_until ?? ''),
    seconds_until_rotation: Math.max(0, asInt(r.seconds_until_rotation, 0)),
    server_time: String(r.server_time ?? ''),
  };
}

/**
 * Trigger a browser download for a Blob. The anchor click + revoke
 * dance is the same as in `admin-data-excel.service.ts`; inlined here
 * so this service stays self-contained.
 */
function triggerBlobDownload(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  try {
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
  } finally {
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}

/**
 * Coerce a personnel row from the wire into the FE shape. Defensive
 * against nulls / missing keys — the backend was still evolving through
 * api!234, and we'd rather show "–" than crash the table.
 */
function personnelRowFromJson(raw: unknown): PersonnelCardListRow {
  const r = (raw as Record<string, unknown>) ?? {};
  const roleRaw = String(r.role ?? 'teacher');
  const role: PersonnelRole =
    roleRaw === 'staff' || roleRaw === 'student' ? roleRaw : 'teacher';
  const cardRaw = r.card as Record<string, unknown> | null | undefined;
  return {
    user_id: String(r.user_id ?? ''),
    user_name: String(r.user_name ?? ''),
    user_email: String(r.user_email ?? ''),
    role,
    card: cardRaw
      ? {
          id: String(cardRaw.id ?? ''),
          qr_token: String(cardRaw.qr_token ?? ''),
          issued_at: String(cardRaw.issued_at ?? ''),
          revoked_at:
            cardRaw.revoked_at == null ? null : String(cardRaw.revoked_at),
        }
      : null,
  };
}

/**
 * Normalize the `meta` block that /list returns into the app-wide
 * `Pagination` shape the existing `<Pagination>` widget expects.
 *
 * The backend returns Laravel's default paginator envelope
 *   `{ current_page, last_page, total, per_page? }`,
 * which is *not* the app's canonical shape from `@/types/api`
 *   `{ total_items, total_pages, current_page, per_page,
 *      has_next_page, has_prev_page }`.
 * Rather than teach every downstream widget a second shape, we map
 * once here — cheap, and it means the `<Pagination>` component just
 * works when the view drops it under the table.
 */
function paginationFromMeta(
  raw: unknown,
  fallbackPerPage: number,
): Pagination {
  const m = (raw as Record<string, unknown>) ?? {};
  const currentPage = Math.max(1, Math.round(Number(m.current_page ?? 1)));
  const lastPage = Math.max(1, Math.round(Number(m.last_page ?? 1)));
  const total = Math.max(0, Math.round(Number(m.total ?? 0)));
  const perPage = Math.max(
    1,
    Math.round(Number(m.per_page ?? fallbackPerPage)),
  );
  return {
    total_items: total,
    total_pages: lastPage,
    current_page: currentPage,
    per_page: perPage,
    has_next_page: currentPage < lastPage,
    has_prev_page: currentPage > 1,
  };
}

export interface PersonnelCardListResult {
  items: PersonnelCardListRow[];
  pagination: Pagination;
}

/**
 * The student-list response bundles both the row-level pagination and
 * the aggregate KPI counters (total / issued / missing) so the KPI
 * strip stays honest even when the row list is filtered by card status.
 * Kept as a single result object rather than two separate calls — one
 * fetch, one paint.
 */
export interface StudentCardListResult {
  items: StudentCardListRow[];
  pagination: Pagination;
  meta: StudentCardListMeta;
}

/**
 * Coerce one student row from the wire into the FE shape. Same defensive
 * shape as personnelRowFromJson — nulls become nulls (not empty strings)
 * so the template's `class_label ?? '—'` fallback reads honestly.
 */
function studentRowFromJson(raw: unknown): StudentCardListRow {
  const r = (raw as Record<string, unknown>) ?? {};
  const studentNumber = r.student_number;
  const classId = r.class_id;
  const classLabel = r.class_label;
  const cardId = r.card_id;
  const cardIssuedAt = r.card_issued_at;
  return {
    student_id: String(r.student_id ?? ''),
    name: String(r.name ?? ''),
    student_number:
      studentNumber == null || studentNumber === ''
        ? null
        : String(studentNumber),
    class_id: classId == null || classId === '' ? null : String(classId),
    class_label:
      classLabel == null || classLabel === '' ? null : String(classLabel),
    has_card: Boolean(r.has_card),
    card_id: cardId == null || cardId === '' ? null : String(cardId),
    card_issued_at:
      cardIssuedAt == null || cardIssuedAt === ''
        ? null
        : String(cardIssuedAt),
  };
}

/**
 * Pull the student KPI counters out of the meta block. Defaults to
 * zeros so the KPI strip renders three flat "0"s while the fetch is
 * still pending rather than blanks or NaN.
 */
function studentMetaFromJson(raw: unknown): StudentCardListMeta {
  const m = (raw as Record<string, unknown>) ?? {};
  return {
    total_students: Math.max(0, asInt(m.total_students, 0)),
    issued_count: Math.max(0, asInt(m.issued_count, 0)),
    missing_count: Math.max(0, asInt(m.missing_count, 0)),
  };
}

export const AttendanceQrService = {
  /**
   * GET /attendance/gate-qr/current — the active token. 401/403 when the
   * caller lacks `attendance.gate_qr.manage`. Used by both the
   * projector display (polls + redraws on each rotation) and the
   * settings preview tile.
   */
  async getCurrentGateQrToken(): Promise<GateQrTokenInfo> {
    try {
      const res = await api.get(Endpoints.gateQrCurrent);
      return tokenFromJson(res.data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat QR gerbang aktif.'));
    }
  },

  /**
   * POST /attendance/gate-qr/rotate — mint a fresh token immediately.
   * Returns the new token (same shape as current). Used by the
   * "Rotasi sekarang" button and by the projector's countdown
   * timer when it hits zero (so the displayed QR matches what the
   * mobile scanner will accept after the rollover).
   */
  async rotateGateQrToken(): Promise<GateQrTokenInfo> {
    try {
      const res = await api.post(Endpoints.gateQrRotate);
      return tokenFromJson(res.data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memutar token QR gerbang.'));
    }
  },

  /**
   * GET /attendance/personnel-cards/list — paginated roster of
   * card-issuable personnel (teachers, staff, opt-in students) with
   * their current card state inline (`card: null` when no active card).
   *
   * Replaces the earlier "reuse the teacher list" fallback that keyed
   * rows on `teachers.id` — the backend's IssuePersonnelQrCardAction
   * looks up membership via `users_schools.user_id`, so submitting a
   * teacher-id at issue time returned every row as `skipped:
   * not_a_school_member`. The `/list` endpoint returns `user_id`
   * directly, wiring the correct key through selection → issue → PDF.
   */
  async listPersonnelCards(
    params: PersonnelCardListParams = {},
  ): Promise<PersonnelCardListResult> {
    try {
      const perPage = params.per_page ?? 20;
      const res = await api.get(Endpoints.cardsList, {
        params: {
          // Cache-buster so the list refreshes after issue / revoke —
          // matches the pattern in teachers.service.ts.
          _t: Date.now(),
          page: params.page ?? 1,
          per_page: perPage,
          ...(params.role && params.role !== 'all' ? { role: params.role } : {}),
          ...(params.has_card === undefined
            ? {}
            : { has_card: params.has_card ? 'true' : 'false' }),
          ...(params.search ? { search: params.search } : {}),
        },
      });
      const body = (res.data ?? {}) as {
        data?: unknown[];
        meta?: Record<string, unknown>;
      };
      const rows = Array.isArray(body.data) ? body.data : [];
      return {
        items: rows.map(personnelRowFromJson),
        pagination: paginationFromMeta(body.meta, perPage),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat daftar personel.'));
    }
  },

  /**
   * POST /attendance/personnel-cards/issue — batch-issue cards for the
   * given user ids. The endpoint accepts a batch of users and returns
   * one row per id; the caller decides what to do with `skipped` /
   * `error` rows (typically a toast listing the names).
   *
   * The server enforces `attendance.cards.issue` and rejects users
   * outside the active school.
   */
  async issuePersonnelCards(
    userIds: string[],
  ): Promise<PersonnelCardIssueResult[]> {
    try {
      const res = await api.post(Endpoints.cardsIssue, { user_ids: userIds });
      const body = (res.data ?? {}) as { data?: PersonnelCardIssueResult[] };
      const rows = Array.isArray(body.data) ? body.data : [];
      return rows.map((r) => ({
        user_id: String(r.user_id ?? ''),
        qr_token: r.qr_token ? String(r.qr_token) : undefined,
        status: (r.status === 'ok' || r.status === 'skipped' || r.status === 'error')
          ? r.status
          : 'error',
        reason: r.reason ? String(r.reason) : undefined,
      }));
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menerbitkan kartu QR personel.'));
    }
  },

  /**
   * DELETE /attendance/personnel-cards/{cardId} — revoke a single card.
   * After revoke the user's printed badge stops working immediately;
   * a fresh issue is required to mint a new token.
   */
  async revokePersonnelCard(
    cardId: string,
  ): Promise<{ id: string; revoked_at: string }> {
    try {
      const res = await api.delete(`${Endpoints.cardsBase}/${cardId}`);
      const data = (res.data?.data ?? res.data ?? {}) as Record<string, unknown>;
      return {
        id: String(data.id ?? cardId),
        revoked_at: String(data.revoked_at ?? ''),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mencabut kartu QR personel.'));
    }
  },

  /**
   * GET /attendance/personnel-cards/export.pdf?user_ids[]=… — download
   * the printable PDF of cards for the given users. The browser saves
   * the blob via an anchor click; no return value (success = no throw).
   */
  async exportPersonnelCardsPdf(
    userIds: string[],
    suggestedName = 'kartu-qr-personel.pdf',
  ): Promise<void> {
    try {
      const res = await api.get(Endpoints.cardsExportPdf, {
        params: { user_ids: userIds },
        // Emit brackets (`user_ids[]=a&user_ids[]=b`) — Laravel's
        // `array` validator only unpacks a query key when the brackets
        // are present. Bare `user_ids=a&user_ids=b` (axios `indexes: null`)
        // collapses to the last value on the PHP side and returns 422.
        paramsSerializer: {
          indexes: false,
        },
        responseType: 'blob',
      });
      triggerBlobDownload(res.data as Blob, suggestedName);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengunduh PDF kartu QR.'));
    }
  },

  // ── Student cards (account-less siswa flow, backend MR !484) ──────

  /**
   * GET /attendance/student-cards — paginated roster of students in the
   * active school with their current card state inline. Keyed on
   * `student_id` (the *only* stable key — students never have a `users`
   * row). Backend LEFT-JOINs `student_classes` for the requested AY so a
   * student with no enrollment still appears (class_id / class_label
   * come back null).
   *
   * The response also carries a `meta` block with total_students /
   * issued_count / missing_count — those are computed against the base
   * query BEFORE the `card_status` filter is applied, so the KPI strip
   * stays honest even when the row list is narrowed to only-missing.
   *
   * NOT the same endpoint as /personnel-cards/list — the personnel path
   * requires a `users_schools` membership + role, which every imported
   * student would silently fail (that was exactly the "empty Siswa tab"
   * bug the Kartu QR Personal redesign is fixing).
   */
  async listStudentCards(
    params: StudentCardListParams,
  ): Promise<StudentCardListResult> {
    try {
      const perPage = params.per_page ?? 25;
      const res = await api.get(Endpoints.studentCardsList, {
        params: {
          // Cache-buster so the list refreshes after issue / revoke /
          // export (which auto-issues) — same pattern as listPersonnelCards.
          _t: Date.now(),
          academic_year_id: params.academic_year_id,
          page: params.page ?? 1,
          per_page: perPage,
          ...(params.class_id ? { class_id: params.class_id } : {}),
          ...(params.search ? { search: params.search } : {}),
          ...(params.card_status ? { card_status: params.card_status } : {}),
        },
      });
      const body = (res.data ?? {}) as {
        data?: unknown[];
        meta?: Record<string, unknown>;
      };
      const rows = Array.isArray(body.data) ? body.data : [];
      return {
        items: rows.map(studentRowFromJson),
        pagination: paginationFromMeta(body.meta, perPage),
        meta: studentMetaFromJson(body.meta),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat daftar kartu siswa.'));
    }
  },

  /**
   * POST /attendance/student-cards/issue — batch-issue cards for the
   * given student ids. Idempotent: a student that already has an active
   * card returns `status='exists'` (NOT an error) with the same
   * `qr_token` — so re-clicking the button never blows up the roster.
   * Cross-tenant ids return `status='skipped'` with reason='cross_tenant'.
   *
   * The server enforces `attendance.cards.issue` AND the
   * `issue_student_cards` opt-in flag before minting anything.
   */
  async issueStudentCards(
    studentIds: string[],
  ): Promise<StudentCardIssueResult[]> {
    try {
      const res = await api.post(Endpoints.studentCardsIssue, {
        student_ids: studentIds,
      });
      const body = (res.data ?? {}) as { data?: StudentCardIssueResult[] };
      const rows = Array.isArray(body.data) ? body.data : [];
      return rows.map((r) => ({
        student_id: String(r.student_id ?? ''),
        qr_token: r.qr_token ? String(r.qr_token) : undefined,
        card_id: r.card_id ? String(r.card_id) : undefined,
        status:
          r.status === 'issued' || r.status === 'exists' || r.status === 'skipped'
            ? r.status
            : 'skipped',
        reason: r.reason ? String(r.reason) : undefined,
      }));
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menerbitkan kartu QR siswa.'));
    }
  },

  /**
   * DELETE /attendance/student-cards/{cardId} — revoke a single card.
   * Server-side this sets `revoked_at`; the next scan of that QR is
   * rejected at the gate. Re-issuing mints a fresh token.
   */
  async revokeStudentCard(
    cardId: string,
  ): Promise<{ id: string; revoked_at: string }> {
    try {
      const res = await api.delete(`${Endpoints.studentCardsBase}/${cardId}`);
      const data = (res.data?.data ?? res.data ?? {}) as Record<
        string,
        unknown
      >;
      return {
        id: String(data.id ?? cardId),
        revoked_at: String(data.revoked_at ?? ''),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mencabut kartu QR siswa.'));
    }
  },

  /**
   * GET /attendance/student-cards/export.pdf?student_ids[]=… — download
   * an A4 sheet of the requested students' cards. Backend auto-issues
   * any missing cards for the listed students BEFORE rendering the PDF
   * (idempotent), so the mockup's one-click "Terbitkan & Cetak" always
   * lands a complete sheet — no separate issue-then-print two-step.
   *
   * Same blob-download dance as exportPersonnelCardsPdf; the anchor
   * click + revoke is centralised in `triggerBlobDownload`.
   */
  async exportStudentCardsPdf(
    studentIds: string[],
    suggestedName?: string,
  ): Promise<void> {
    // Default filename `kartu-qr-siswa-YYYY-MM-DD.pdf` — matches the
    // personnel-cards convention and gives the school a dated file
    // without having to rename it after download.
    const filename = suggestedName ??
      `kartu-qr-siswa-${new Date().toISOString().slice(0, 10)}.pdf`;
    try {
      const res = await api.get(Endpoints.studentCardsExportPdf, {
        params: { student_ids: studentIds },
        // Same reason as personnel: Laravel's `array` validator only
        // unpacks bracketed query keys.
        paramsSerializer: {
          indexes: false,
        },
        responseType: 'blob',
      });
      triggerBlobDownload(res.data as Blob, filename);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengunduh PDF kartu QR siswa.'));
    }
  },
};

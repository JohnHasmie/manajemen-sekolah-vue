/**
 * ParentService - aggregates the parent-side reads.
 * Mirrors various Flutter parent_*_service.dart files.
 */
import { api } from '@/lib/http';
import type {
  Announcement,
  Child,
  ParentAttendanceEntry,
  ParentGradeEntry,
  ParentGradeRow,
  ReportCard,
  ReportCardDetail,
} from '@/types/parent';
import { parseParentAttendanceStatus } from '@/types/parent';

function asNum(v: unknown): number | null {
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v === 'string' && v.trim() !== '') {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

function parentAttendanceFromJson(raw: any): ParentAttendanceEntry {
  const lessonHour = raw.lesson_hour ?? raw.lessonHour ?? null;
  return {
    id: String(raw.id ?? ''),
    date: String(raw.date ?? raw.tanggal ?? ''),
    lesson_hour_name:
      raw.lesson_hour_name ??
      lessonHour?.name ??
      (raw.jam_ke ? `JP ${raw.jam_ke}` : null),
    lesson_hour_id: raw.lesson_hour_id ?? lessonHour?.id ?? null,
    subject_id: raw.subject_id ?? raw.subject?.id ?? null,
    session: raw.session ?? raw.sesi ?? null,
    subject_name: String(
      raw.subject_name ??
        raw.subject?.name ??
        raw.mata_pelajaran ??
        raw.mapel ??
        '',
    ),
    status: parseParentAttendanceStatus(raw.status ?? raw.attendance_status),
    notes: raw.notes ?? raw.catatan ?? null,
    is_read:
      typeof raw.is_read === 'boolean'
        ? raw.is_read
        : raw.read_at != null
          ? true
          : undefined,
  };
}

/**
 * Resolve the backend grade row (shape varies — top-level fields, nested
 * `assessment`, nested `subject`, Indonesian aliases) into a flat
 * `ParentGradeEntry`. Field chain mirrors `GradeRepository::applyDerivedFieldsToCollection`.
 */
function parentGradeEntryFromJson(raw: any): ParentGradeEntry {
  const assessment = raw.assessment ?? {};
  const subject =
    raw.subject ?? assessment.subject ?? {};
  const subjectName =
    raw.subject_name ??
    raw.mata_pelajaran ??
    subject.name ??
    subject.nama ??
    '—';
  const type =
    raw.type ??
    raw.grade_type ??
    assessment.type ??
    'Tugas';
  const title =
    raw.title ??
    raw.assessment_name ??
    raw.name ??
    assessment.title ??
    '';
  const date =
    raw.date ??
    raw.assessment_date ??
    assessment.date ??
    '';
  return {
    id: String(raw.id ?? ''),
    subject_id: String(raw.subject_id ?? subject.id ?? ''),
    subject_name: String(subjectName),
    type: String(type),
    title: String(title ?? ''),
    date: String(date ?? '').slice(0, 10),
    score: asNum(raw.score ?? raw.nilai ?? raw.value),
    kkm: Number(raw.kkm ?? subject.kkm ?? 75),
    is_read:
      raw.is_read === true || raw.is_read === 1 || raw.is_read === '1',
  };
}

function childFromJson(raw: any): Child {
  // Class name lives in several places across the backend (flat,
  // nested relation, nested enrolment array). Port the same
  // resolution chain as Flutter's `Student.fromJson`.
  let className =
    raw.class_name ?? raw.kelas_nama ?? raw.className ?? raw.kelas ?? null;
  if (className == null && raw.class && typeof raw.class === 'object') {
    className = raw.class.name ?? raw.class.nama ?? null;
  }
  if (
    className == null &&
    Array.isArray(raw.student_classes) &&
    raw.student_classes.length > 0
  ) {
    const first = raw.student_classes[0];
    if (first && typeof first === 'object') {
      if (first.class && typeof first.class === 'object') {
        className = first.class.name ?? first.class.nama ?? null;
      }
      className ??= first.class_name ?? first.kelas_nama ?? null;
    }
  }
  return {
    student_id: String(raw.student_id ?? raw.id ?? ''),
    name: String(raw.name ?? raw.nama ?? ''),
    class_name: String(className ?? ''),
    avatar: raw.avatar ?? null,
  };
}

function announcementFromJson(raw: any): Announcement {
  return {
    id: String(raw.id ?? ''),
    title: String(raw.title ?? raw.judul ?? ''),
    body: String(raw.body ?? raw.isi ?? raw.konten ?? ''),
    source: String(raw.source ?? raw.sumber ?? raw.author ?? 'Sekolah'),
    category: raw.category ?? raw.kategori ?? 'pengumuman',
    read_at: raw.read_at ?? null,
    created_at: String(raw.created_at ?? new Date().toISOString()),
  };
}

function reportCardFromJson(raw: any): ReportCard {
  return {
    id: String(raw.id ?? ''),
    semester: String(raw.semester ?? 'Semester 2'),
    academic_year: String(raw.academic_year ?? raw.tahun_ajaran ?? ''),
    class_name: String(raw.class_name ?? raw.kelas ?? ''),
    avg_grade: asNum(raw.avg_grade ?? raw.rata_rata),
    remed_count: Number(raw.remed_count ?? raw.jumlah_remedial ?? 0),
    published_at: raw.published_at ?? null,
    pdf_url: raw.pdf_url ?? null,
  };
}

export const ParentService = {
  /**
   * Fetch all students linked to this parent. Mirrors Flutter's
   * `ApiStudentService.getStudent(userId, guardianEmail)` —
   * hits `GET /student?user_id&guardian_email` (the same endpoint
   * admin/teacher screens use, just scoped by guardian identifiers).
   *
   * Caller passes the signed-in user's `id` and `email`; both are
   * forwarded because some accounts are linked by id (Google SSO)
   * while older accounts only match by email.
   */
  async listChildren(opts: {
    user_id?: string | null;
    guardian_email?: string | null;
  } = {}): Promise<Child[]> {
    try {
      const params: Record<string, string> = {};
      if (opts.user_id) params.user_id = opts.user_id;
      if (opts.guardian_email) params.guardian_email = opts.guardian_email;
      const res = await api.get('/student', { params });
      const body = res.data?.data ?? res.data ?? [];
      return Array.isArray(body) ? body.map(childFromJson) : [];
    } catch {
      return [];
    }
  },

  // ── Attendance ──

  /**
   * Per-month attendance fetch. Kept for back-compat with existing
   * callers; prefer `attendanceYear` for the new parent screens.
   *
   * Hits `GET /attendance?student_id&date_start&date_end&academic_year_id`
   * (Flutter parity — Flutter sends both `date_start`/`date_end` and
   * `academic_year_id` when scoping per-student).
   */
  async attendance(
    studentId: string,
    monthIso: string,
    opts: { academic_year_id?: string | null } = {},
  ): Promise<ParentAttendanceEntry[]> {
    try {
      const [yr, mo] = monthIso.split('-').map(Number);
      const start = `${yr}-${String(mo).padStart(2, '0')}-01`;
      const lastDay = new Date(yr, mo, 0).getDate();
      const end = `${yr}-${String(mo).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
      const res = await api.get('/attendance', {
        params: {
          student_id: studentId,
          date_start: start,
          date_end: end,
          ...(opts.academic_year_id
            ? { academic_year_id: opts.academic_year_id }
            : {}),
          limit: 500,
        },
      });
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map(parentAttendanceFromJson);
    } catch {
      return [];
    }
  },

  /**
   * Fetch the FULL academic year worth of attendance for a single
   * child. Mirrors Flutter's `AttendanceService.getAttendance(studentId,
   * academicYearId)` — the parent calendar/list screen slices by month
   * client-side so flipping months is instant (no extra round-trip).
   *
   * Returns all rows sorted by date desc. When `academicYearId` is
   * omitted the active store year is used.
   */
  async attendanceYear(
    studentId: string,
    opts: { academic_year_id?: string | null } = {},
  ): Promise<ParentAttendanceEntry[]> {
    try {
      const res = await api.get('/attendance', {
        params: {
          student_id: studentId,
          ...(opts.academic_year_id
            ? { academic_year_id: opts.academic_year_id }
            : {}),
          limit: 2000,
        },
      });
      const body = res.data?.data ?? res.data ?? [];
      const rows: ParentAttendanceEntry[] = (Array.isArray(body) ? body : []).map(
        parentAttendanceFromJson,
      );
      // Most recent first — mirrors Flutter's getAttendance default.
      return rows.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
    } catch {
      return [];
    }
  },

  /**
   * POST /attendance/mark-read — mark a list of attendance row ids
   * as read for the signed-in parent. Mirrors Flutter's
   * `markPresenceAsRead([ids])`. Best-effort: server errors are
   * swallowed so the visible list keeps scrolling without showing
   * an error toast.
   */
  async markPresenceAsRead(ids: string[]): Promise<void> {
    if (ids.length === 0) return;
    try {
      await api.post('/attendance/mark-read', { ids });
    } catch {
      // non-fatal — header badge will catch up on next poll.
    }
  },

  /**
   * POST /attendance/mark-read?student_id — mark every unread row
   * for ONE child as read. Mirrors Flutter's `markAttendanceRead`,
   * called once when the screen first paints with a selected child.
   */
  async markAttendanceRead(studentId: string): Promise<void> {
    if (!studentId) return;
    try {
      await api.post('/attendance/mark-read', { student_id: studentId });
    } catch {
      // non-fatal
    }
  },

  // ── Grades (read-only matrix) ──
  async grades(studentId: string, semester: string): Promise<ParentGradeRow[]> {
    try {
      const res = await api.get('/grades', {
        params: { student_id: studentId, semester },
      });
      const body = res.data?.data ?? res.data ?? [];
      const entries: any[] = Array.isArray(body) ? body : [];
      if (entries.length === 0) return [];

      // If the backend already returns the bucketed shape we want,
      // pass it through. Otherwise pivot the flat list by subject.
      if (entries[0]?.scores !== undefined) {
        return entries.map((r: any) => ({
          subject_id: String(r.subject_id ?? r.id ?? ''),
          subject_name: String(r.subject_name ?? r.nama ?? ''),
          kkm: Number(r.kkm ?? 75),
          scores: Array.isArray(r.scores)
            ? r.scores.map((s: any) => ({
                assessment: String(s.assessment ?? s.label ?? ''),
                score: asNum(s.score ?? s.nilai),
              }))
            : [],
          average: asNum(r.average ?? r.rata_rata),
        }));
      }

      // Flat path — one entry per grade record.
      const bySubject = new Map<string, ParentGradeRow>();
      for (const e of entries) {
        const sid = String(e.subject_id ?? e.subject?.id ?? '');
        if (!sid) continue;
        const row =
          bySubject.get(sid) ?? {
            subject_id: sid,
            subject_name: String(
              e.subject_name ?? e.subject?.name ?? e.mata_pelajaran ?? '—',
            ),
            kkm: Number(e.kkm ?? e.subject?.kkm ?? 75),
            scores: [] as ParentGradeRow['scores'],
            average: null as ParentGradeRow['average'],
          };
        const label = String(
          e.assessment_name ??
            e.name ??
            e.grade_type ??
            e.type ??
            'Nilai',
        );
        row.scores.push({
          assessment: label,
          score: asNum(e.score ?? e.nilai ?? e.value),
        });
        bySubject.set(sid, row);
      }

      // Compute per-row averages.
      const rows = Array.from(bySubject.values()).map((row) => {
        const nums = row.scores
          .map((s) => s.score)
          .filter((n): n is number => typeof n === 'number');
        const avg = nums.length
          ? Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 10) / 10
          : null;
        return { ...row, average: avg };
      });
      return rows;
    } catch {
      return [];
    }
  },

  /**
   * Flat one-row-per-assessment fetch — mirrors the Flutter mobile
   * parent Nilai screen. Hits `GET /grades?student_id&semester` and
   * normalises every paginated row into `ParentGradeEntry`.
   *
   * Pagination: pulls up to `limit` rows in one shot (default 500)
   * because the parent screen renders the full per-subject grouped
   * list, not a paginated feed.
   */
  async gradesFlat(
    studentId: string,
    semester: string,
    opts: { limit?: number } = {},
  ): Promise<ParentGradeEntry[]> {
    try {
      const res = await api.get('/grades', {
        params: {
          student_id: studentId,
          semester,
          limit: opts.limit ?? 500,
        },
      });
      const body = res.data?.data ?? res.data ?? [];
      const rows: any[] = Array.isArray(body) ? body : [];
      return rows.map(parentGradeEntryFromJson);
    } catch {
      return [];
    }
  },

  /**
   * POST /grade/mark-read — flag a batch of grade rows as read for
   * the signed-in parent. Best-effort: server errors are swallowed so
   * the visible list keeps scrolling without showing an error toast.
   */
  async markGradeRead(ids: string[]): Promise<void> {
    if (ids.length === 0) return;
    try {
      await api.post('/grade/mark-read', { ids });
    } catch {
      // non-fatal — header badge will catch up on next poll.
    }
  },

  // ── Announcements ──
  async announcements(): Promise<Announcement[]> {
    try {
      const res = await api.get('/announcement');
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map(announcementFromJson);
    } catch {
      return [];
    }
  },

  async markAnnouncementRead(id: string): Promise<void> {
    await api.post(`/announcement/${id}/mark-read`);
  },

  // ── Report cards ──
  /**
   * ── BUGFIX (Rapor Phase 1) ── used to hit `/raports?student_id=…`
   * which is the teacher class-roster endpoint that *ignores*
   * student_id filtering, so this always returned empty.
   *
   * Now delegates to `GET /parent/raports` (the canonical parent
   * inbox endpoint) and filters client-side to the requested
   * studentId. Backend only ships rows with `status='published'`.
   *
   * Phase 5 rewrites the parent rapor view to consume the richer
   * `ParentRaportRow` shape directly; this wrapper just preserves
   * the legacy `ReportCard[]` contract until then.
   */
  async reportCards(studentId: string): Promise<ReportCard[]> {
    try {
      const res = await api.get('/parent/raports');
      const body = res.data?.data ?? res.data ?? [];
      const list = Array.isArray(body) ? body : [];
      return list
        .filter((row: any) => {
          const sid =
            row?.student?.id ?? row?.student_id ?? row?.studentId;
          return !sid || String(sid) === String(studentId);
        })
        .map((row: any) => {
          // /parent/raports nests the raport under `reportCard`.
          // Reshape so the legacy `reportCardFromJson` parser still
          // finds the fields it expects (id, student_name, etc).
          const inner = row.reportCard ?? row;
          return reportCardFromJson({
            ...inner,
            student_id: row?.student?.id ?? inner?.student_id,
            student_name: row?.student?.name ?? inner?.student_name,
            class_name:
              row?.student?.class_name ??
              inner?.class_name ??
              inner?.class?.name,
            rank: row?.rank ?? null,
            total_in_class: row?.total_in_class ?? null,
            average_score: row?.average_score ?? null,
            attendance_pct: row?.attendance_pct ?? null,
          });
        });
    } catch {
      return [];
    }
  },

  /**
   * Fetch the hydrated raport. Flutter uses `/raport/show` with a
   * (student_class_id, academic_year_id, semester_id) tuple, not a
   * bare id. We don't always have those, so we fall back to the by-id
   * route when it exists on the backend.
   */
  async reportCardDetail(
    idOrCtx:
      | string
      | {
          student_class_id: string;
          academic_year_id: string;
          semester_id: string;
        },
  ): Promise<ReportCardDetail | null> {
    try {
      const res =
        typeof idOrCtx === 'string'
          ? await api.get(`/raport/${idOrCtx}`).catch(() =>
              api.get(`/raports/${idOrCtx}`),
            )
          : await api.get('/raport/show', { params: idOrCtx });
      const body = res.data?.data ?? res.data ?? null;
      if (!body) return null;
      const base = reportCardFromJson(body);
      const entries: ReportCardDetail['entries'] = Array.isArray(body.entries ?? body.grades ?? body.subjects)
        ? (body.entries ?? body.grades ?? body.subjects).map((e: any) => ({
            subject_id: String(e.subject_id ?? ''),
            subject_name: String(e.subject_name ?? e.name ?? ''),
            score: Number(e.score ?? e.knowledge_score ?? 0),
            kkm: Number(e.kkm ?? 75),
            predicate: e.predicate ?? e.knowledge_predicate ?? 'C',
            notes: e.notes ?? e.knowledge_description ?? null,
          }))
        : [];
      return {
        ...base,
        entries,
        attendance_summary: body.attendance_summary ?? undefined,
        homeroom_notes: body.homeroom_notes ?? body.notes ?? null,
      };
    } catch {
      return null;
    }
  },
};

/**
 * GradeService - /grades/* endpoint wrapper.
 * Mirrors `lib/features/grades/data/grade_service.dart`.
 *
 * The matrix endpoint is conventionally GET /grades/matrix with
 * {class_id, subject_id, semester}. If the backend doesn't expose a
 * matrix endpoint yet, we fall back to a synthesized empty matrix.
 */
import { api } from '@/lib/http';
import { localISODate } from '@/lib/format';
import { StudentService } from '@/services/students.service';
import {
  adminGradeOverviewFromJson,
  ASSESSMENT_LABELS,
  normalizeAssessmentType,
  teacherGradeSummaryFromJson,
  type AdminGradeOverview,
  type Assessment,
  type AssessmentType,
  type GradeCell,
  type GradeMatrix,
  type GradeRow,
  type TeacherGradeSummaryClass,
} from '@/types/grades';

interface MatrixParams {
  class_id: string;
  subject_id: string;
  semester?: string;
  type?: AssessmentType | 'all';
}

function asNum(v: unknown): number | null {
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v === 'string' && v.trim() !== '') {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

function assessmentFromJson(raw: any): Assessment {
  return {
    id: String(raw.id ?? ''),
    name: String(raw.name ?? raw.nama ?? ''),
    // Normalise to the canonical English key so the matrix
    // type-filter (which compares against canonical keys) matches.
    type: normalizeAssessmentType(raw.type ?? raw.jenis),
    weight: asNum(raw.weight) ?? undefined,
    date: raw.date ?? raw.tanggal ?? undefined,
  };
}

function rowFromJson(raw: any, assessments: Assessment[]): GradeRow {
  const cellsRaw = (raw.cells ?? raw.grades ?? {}) as Record<string, any>;
  const cells: Record<string, GradeCell> = {};
  // If backend returns an array of cells, pivot to keyed map.
  if (Array.isArray(cellsRaw)) {
    for (const c of cellsRaw) {
      const aid = String(c.assessment_id ?? c.id ?? '');
      if (!aid) continue;
      cells[aid] = {
        id: c.id ? String(c.id) : undefined,
        student_id: String(raw.student_id ?? raw.id ?? ''),
        assessment_id: aid,
        score: asNum(c.score ?? c.nilai),
        notes: c.notes ?? null,
      };
    }
  } else {
    for (const [aid, c] of Object.entries(cellsRaw)) {
      const cell = c as any;
      cells[aid] = {
        id: cell?.id ? String(cell.id) : undefined,
        student_id: String(raw.student_id ?? raw.id ?? ''),
        assessment_id: aid,
        score: asNum(cell?.score ?? cell?.nilai ?? cell),
        notes: cell?.notes ?? null,
      };
    }
  }

  // Ensure every assessment has a cell (even if empty) so UI can render.
  for (const a of assessments) {
    if (!cells[a.id]) {
      cells[a.id] = {
        student_id: String(raw.student_id ?? raw.id ?? ''),
        assessment_id: a.id,
        score: null,
      };
    }
  }

  return {
    student_id: String(raw.student_id ?? raw.id ?? ''),
    student_name: String(raw.student_name ?? raw.nama ?? raw.name ?? ''),
    student_number: String(raw.student_number ?? raw.nis ?? raw.nisn ?? ''),
    alert: raw.alert ?? null,
    alert_tone: raw.alert_tone ?? null,
    cells,
    average: asNum(raw.average ?? raw.rata_rata),
  };
}

export const GradeService = {
  /**
   * School-wide grade overview for the admin Gradebook page.
   *
   * Mirrors Flutter `GradeService.getAdminOverview`:
   *   `GET /grades/admin-overview?academic_year_id=…`
   *
   * Returns `{ school_stats, teachers[] }`. Backend caches the
   * response for 5 minutes per (school × academic_year).
   */
  async getAdminOverview(args: {
    academic_year_id?: string;
  } = {}): Promise<AdminGradeOverview> {
    try {
      const res = await api.get('/grades/admin-overview', {
        params: args.academic_year_id
          ? { academic_year_id: args.academic_year_id }
          : {},
      });
      const body = res.data?.data ?? res.data ?? {};
      return adminGradeOverviewFromJson(body as Record<string, unknown>);
    } catch {
      return {
        school_stats: {
          total_grades: 0,
          total_assessments: 0,
          total_teachers: 0,
          total_students: 0,
          avg_score: 0,
          highest_score: 0,
          lowest_score: 0,
          passed: 0,
          failed: 0,
          pass_rate: 0,
          distribution: { high: 0, mid: 0, low: 0 },
        },
        teachers: [],
      };
    }
  },

  /**
   * Default landing data for the Grade page — one item per (class,
   * subject) combo the teacher teaches, with a precomputed `avg_score`
   * + per-assessment averages so the dashboard card renders without a
   * second round-trip.
   *
   * Mirrors Flutter `getTeacherGradeSummary` →
   * `GET /grades/teacher-summary?teacher_id=&view=teaching|homeroom_teacher
   *  [&academic_year_id&class_id&subject_id]`.
   *
   * `view` defaults to `teaching` (teacher's own classes); pass
   * `homeroom_teacher` to fetch the homeroom's full subject grid.
   */
  async getTeacherSummary(args: {
    teacher_id: string;
    view?: 'teaching' | 'homeroom_teacher';
    academic_year_id?: string;
    class_id?: string;
    subject_id?: string;
  }): Promise<TeacherGradeSummaryClass[]> {
    try {
      const res = await api.get('/grades/teacher-summary', {
        params: {
          teacher_id: args.teacher_id,
          view: args.view ?? 'teaching',
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
          ...(args.class_id ? { class_id: args.class_id } : {}),
          ...(args.subject_id ? { subject_id: args.subject_id } : {}),
        },
      });
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map((row) =>
        teacherGradeSummaryFromJson(row as Record<string, unknown>),
      );
    } catch {
      return [];
    }
  },

  /**
   * Build the grade-book matrix from a two-phase load:
   *   1. `/student/class/{class_id}` — full roster (name + NIS)
   *   2. `/grades?class_id&subject_id` — saved score entries
   *
   * Mirrors the Flutter
   * `teacher_grade_controller._loadGradeData()` flow (matches the
   * pattern we already use for AttendanceService.getRoster).
   *
   * Why two phases:
   *   - `/grades` only returns rows for cells that were actually
   *     entered. On a fresh class with assessments scheduled but no
   *     scores yet, the response is `[]` and the UI would render an
   *     empty matrix even though students + assessments exist.
   *   - The student roster comes from `/student/class/{id}` so
   *     names/NIS are always populated.
   *
   * Optional `assessments_seed` (passed by the summary card flow)
   * pre-populates the assessment columns from the summary payload,
   * so a class with N assessments + 0 cells still renders N empty
   * columns × every student.
   *
   * If the backend ever returns a pre-built `{assessments, rows, kkm}`
   * envelope, that shortcut is honoured first.
   */
  async getMatrix(
    params: MatrixParams & {
      teacher_id?: string;
      academic_year_id?: string;
      assessments_seed?: Assessment[];
    },
  ): Promise<GradeMatrix> {
    if (!params.class_id || !params.subject_id) {
      return { assessments: [], rows: [], kkm: 75 };
    }
    try {
      // Phase 1+2 in parallel — student roster + saved grade entries.
      //
      // Endpoint parity with Flutter `GradeDataProcessor` →
      // `/grades/teacher?subject_id&limit=500[&academic_year_id]`.
      // Flutter does NOT pass class_id or teacher_id to this
      // endpoint — the response is all grades for the subject across
      // every class. We filter client-side via the student roster
      // (only students in `params.class_id` appear in the matrix).
      const studentsPromise = StudentService.byClass(params.class_id);
      const gradesPromise = api
        .get('/grades/teacher', {
          params: {
            subject_id: params.subject_id,
            ...(params.academic_year_id
              ? { academic_year_id: params.academic_year_id }
              : {}),
            limit: 500,
          },
        })
        .then((res) => res.data?.data ?? res.data ?? [])
        .catch(() => [] as any);

      const [students, gradesBody] = await Promise.all([
        studentsPromise,
        gradesPromise,
      ]);

      // Pre-built envelope shortcut (untouched).
      if (
        !Array.isArray(gradesBody) &&
        gradesBody &&
        Array.isArray(gradesBody.assessments)
      ) {
        const assessments: Assessment[] =
          gradesBody.assessments.map(assessmentFromJson);
        const rowsRaw: any[] = Array.isArray(gradesBody.rows)
          ? gradesBody.rows
          : Array.isArray(gradesBody.students)
            ? gradesBody.students
            : [];
        const rows = rowsRaw.map((r) => rowFromJson(r, assessments));
        const kkm = asNum(gradesBody.kkm ?? gradesBody.minimum_score) ?? 75;
        return { assessments, rows, kkm };
      }

      const entries: any[] = Array.isArray(gradesBody)
        ? gradesBody
        : Array.isArray(gradesBody?.data)
          ? gradesBody.data
          : [];

      /**
       * Extract a normalised `{aid, name, type, date}` tuple from one
       * raw `/grades/teacher` row. Flutter's `_normalizeGradeItems`
       * accepts both nested `assessment.{id,title,type,date}` and
       * flat field aliases — we honour the same fallbacks so the
       * matrix works whether the backend serialises eager-loaded or
       * not.
       */
      function extractAssessment(e: any): {
        aid: string;
        name: string;
        raw_title: string | null;
        type: AssessmentType;
        date: string | null;
      } {
        const ass = (e?.assessment ?? null) as Record<string, unknown> | null;
        // Raw wire value — kept only for the display-name fallback +
        // synthetic id below. The matrix type-filter compares against
        // the canonical key, so `type` must be normalised.
        const rawType = String(
          ass?.type ?? e.grade_type ?? e.type ?? e.jenis ?? 'lainnya',
        ).toLowerCase();
        const type: AssessmentType = normalizeAssessmentType(rawType);
        // Preserve the exact backend title (including null) so
        // POST /grades can echo it verbatim without spawning a
        // duplicate assessment row.
        const rawTitleRaw =
          ass?.title ?? e.assessment_name ?? e.title ?? e.name ?? e.nama;
        const raw_title =
          rawTitleRaw === undefined || rawTitleRaw === null
            ? null
            : String(rawTitleRaw);
        // Display name — fallback for null-titled assessments adds a
        // "(tanpa judul)" suffix so the column is visually distinct
        // from a sibling assessment that genuinely has the same name.
        // Use the Indonesian label (e.g. "UTS") rather than the
        // canonical key so the header reads naturally.
        const name =
          raw_title ||
          `${ASSESSMENT_LABELS[type]} (tanpa judul)`;
        const date = (ass?.date ?? e.date ?? e.tanggal ?? null) as
          | string
          | null;
        const aid = String(
          e.assessment_id ?? ass?.id ?? `${rawType}-${name}-${date ?? ''}`,
        );
        return { aid, name, raw_title, type, date };
      }

      // 1. Build the assessment list. Entries from `/grades/teacher`
      //    carry the canonical backend assessment_id — POST/PUT
      //    payloads must echo it verbatim; mismatched ids would
      //    cause the backend to silently spawn a duplicate column
      //    on save.
      //
      //    The summary seed only tops up assessments with zero cells
      //    yet. Dedup key uses the LITERAL backend title (incl. null
      //    sentinel) + type, so two columns with the same display
      //    fallback (e.g. one with title="UH" and one with title=NULL
      //    both showing as "UH") still get separate columns — the DB
      //    unique index treats them as distinct rows too.
      const normaliseName = (s: string) =>
        s.trim().toLowerCase().replace(/\s+/g, ' ');
      const dedupKeyFor = (
        type: AssessmentType,
        raw_title: string | null | undefined,
      ) =>
        `${type}::${
          raw_title === null || raw_title === undefined
            ? '__NULL_TITLE__'
            : normaliseName(raw_title)
        }`;
      const seen = new Map<string, Assessment>();
      const dedupKeyToId = new Map<string, string>();

      // Pass 1 — entries are authoritative.
      for (const e of entries) {
        const { aid, name, raw_title, type, date } = extractAssessment(e);
        const dk = dedupKeyFor(type, raw_title);
        if (!seen.has(aid)) {
          seen.set(aid, {
            id: aid,
            name,
            raw_title,
            type,
            date: date ?? undefined,
          });
          dedupKeyToId.set(dk, aid);
        }
      }

      // Pass 2 — top up with seed assessments that aren't already
      // represented by an entry-derived row.
      if (Array.isArray(params.assessments_seed)) {
        for (const a of params.assessments_seed) {
          const dk = dedupKeyFor(a.type, a.raw_title);
          if (dedupKeyToId.has(dk)) continue;
          if (!seen.has(a.id)) {
            seen.set(a.id, a);
            dedupKeyToId.set(dk, a.id);
          }
        }
      }
      const assessments = Array.from(seen.values());

      // 2. Bucket grade entries by student_id → { [assessment_id]: cell }.
      const cellsByStudent = new Map<string, Record<string, GradeCell>>();
      for (const e of entries) {
        const sid = String(
          e.student_id ?? e.siswa_id ?? e.student?.id ?? e.siswa?.id ?? '',
        );
        if (!sid) continue;
        const { aid } = extractAssessment(e);
        const bucket = cellsByStudent.get(sid) ?? {};
        bucket[aid] = {
          id: e.id ? String(e.id) : undefined,
          student_id: sid,
          assessment_id: aid,
          score: asNum(e.score ?? e.nilai ?? e.value),
          notes: e.notes ?? e.deskripsi ?? e.catatan ?? null,
        };
        cellsByStudent.set(sid, bucket);
      }

      // 3. Build one row per enrolled student — always — backfilling
      //    empty cells so the UI renders the full grid even when
      //    nothing has been scored yet. `student_class_id` is captured
      //    from the StudentService payload because the backend POST
      //    /grades payload requires it (422 otherwise).
      const rows: GradeRow[] = students.map((s) => {
        const cells: Record<string, GradeCell> =
          cellsByStudent.get(s.id) ?? {};
        for (const a of assessments) {
          if (!cells[a.id]) {
            cells[a.id] = {
              student_id: s.id,
              assessment_id: a.id,
              score: null,
            };
          }
        }
        const scores = Object.values(cells)
          .map((c) => c.score)
          .filter((v): v is number => typeof v === 'number');
        const average = scores.length
          ? Math.round(
              (scores.reduce((a, b) => a + b, 0) / scores.length) * 10,
            ) / 10
          : null;
        return {
          student_id: s.id,
          student_class_id: s.student_class_id ?? null,
          student_name: s.name || 'Tanpa nama',
          student_number: s.student_number || '—',
          alert: null,
          alert_tone: null,
          cells,
          average,
        };
      });

      return { assessments, rows, kkm: 75 };
    } catch {
      return { assessments: [], rows: [], kkm: 75 };
    }
  },

  /**
   * Save a single grade cell.
   *
   * Backend wire format (Flutter `GradeService.createGrade` /
   * `updateGrade` parity — 10 required fields, else 422):
   *
   *   {
   *     student_id, student_class_id, teacher_id, subject_id,
   *     assessment_id, type, date, title, score, notes
   *   }
   *
   * Pass `cell` for the score + ids, plus the matrix `row` (gives
   * `student_class_id`) and the `assessment` record (gives type +
   * date + title). Sends PUT when `cell.id` is present, POST when not.
   */
  async saveCell(payload: {
    cell: GradeCell;
    row: GradeRow;
    assessment: Assessment;
    subject_id: string;
    teacher_id: string;
  }): Promise<GradeCell> {
    // Date fallback: backend rejects `null` / missing on POST, so
    // default to today (YYYY-MM-DD) when the assessment record has
    // no date attached — matches the cell's effective recording date.
    const dateIso = payload.assessment.date || localISODate();

    // Title MUST be the verbatim backend value (incl. null) — the
    // unique index `(teacher, subject, type, date, title)` treats
    // NULL ≠ "UH"; sending a fabricated display name spawns a
    // phantom duplicate assessment row server-side.
    const title =
      payload.assessment.raw_title === undefined
        ? payload.assessment.name
        : payload.assessment.raw_title;

    // Synthetic ids (`__new__…` from applyAddAsesmen, `__rename__…` from
    // renameAssessment) mark columns that don't yet have a backend
    // Assessment row. Sending them as `assessment_id` trips the backend
    // rule `nullable|uuid` with "The assessment id field must be a
    // valid UUID." — the value is a string but not UUID-shaped. Omit
    // the field so CreateGradeAction falls through to its find-or-
    // create-by-attrs path, which is the intended way to materialise
    // the column server-side. The matrix refetch reconciles the real
    // id afterwards.
    const rawAid = payload.cell.assessment_id;
    const uuidRe =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const assessmentId =
      typeof rawAid === 'string' && uuidRe.test(rawAid) ? rawAid : null;

    const body: Record<string, unknown> = {
      student_id: payload.cell.student_id,
      student_class_id: payload.row.student_class_id ?? null,
      teacher_id: payload.teacher_id,
      subject_id: payload.subject_id,
      type: payload.assessment.type,
      date: dateIso,
      title,
      score:
        typeof payload.cell.score === 'number' ? payload.cell.score : 0,
      notes: payload.cell.notes ?? '',
    };
    // Only include the id when it's a real UUID — omitting is more
    // portable than sending null (some clients strip null keys).
    if (assessmentId !== null) {
      body.assessment_id = assessmentId;
    }

    if (payload.cell.id) {
      const res = await api.put(`/grades/${payload.cell.id}`, body);
      const saved = (res.data?.data ?? {}) as Partial<GradeCell>;
      return { ...payload.cell, ...saved, dirty: false };
    }
    const res = await api.post('/grades', body);
    const saved = (res.data?.data ?? {}) as Partial<GradeCell>;
    return { ...payload.cell, ...saved, dirty: false };
  },

  /**
   * Batched save — fans out only dirty cells. Caller passes the
   * whole matrix (so we can look up student_class_id and the
   * matching Assessment) plus the active teacher_id.
   *
   * Empty-score cells with no existing id are skipped (matches
   * Flutter — POST only happens when value is not empty; PUT still
   * fires for previously-saved cells whose score was cleared).
   */
  async saveDirty(payload: {
    matrix: GradeMatrix;
    subject_id: string;
    teacher_id: string;
  }): Promise<void> {
    const assessmentById = new Map(
      payload.matrix.assessments.map((a) => [a.id, a]),
    );
    const tasks: Promise<unknown>[] = [];
    for (const row of payload.matrix.rows) {
      for (const cell of Object.values(row.cells)) {
        if (!cell.dirty) continue;
        // Skip "new + empty" cells — backend would reject POST with
        // empty score; nothing to persist either.
        if (!cell.id && (cell.score === null || cell.score === undefined))
          continue;
        const assessment = assessmentById.get(cell.assessment_id);
        if (!assessment) continue;
        tasks.push(
          GradeService.saveCell({
            cell,
            row,
            assessment,
            subject_id: payload.subject_id,
            teacher_id: payload.teacher_id,
          }),
        );
      }
    }
    await Promise.all(tasks);
  },

  /**
   * Delete every grade row tied to one assessment in one shot.
   *
   * Mirrors Flutter `GradeService.deleteAssessmentBatch`:
   *   `DELETE /grades/batch?mata_pelajaran_id=&jenis=&tanggal=[&title=]`
   *
   * Backend matches the composite key on (subject_school_id, type,
   * date, title) so all grade rows + the implicit assessment row are
   * removed together. Pass `title=null` when the assessment's DB
   * column is NULL — we OMIT the `title` query param entirely in
   * that case (matches Flutter).
   */
  async deleteAssessmentBatch(args: {
    subject_id: string;
    type: AssessmentType;
    date: string;
    title?: string | null;
  }): Promise<void> {
    const params: Record<string, string> = {
      mata_pelajaran_id: args.subject_id,
      jenis: args.type,
      tanggal: args.date,
    };
    // Distinguish "match NULL" from "any title". Passing an empty
    // string tells the backend's ApplyTitleFilter to treat the filter
    // as `WHERE title IS NULL`; omitting the param altogether means
    // "no title filter", which then matches every same-day column
    // regardless of title — dangerous when a null-titled column is
    // being reshuffled and a differently-titled column already sits
    // in the same (subject, type, date) slot.
    if (args.title !== null && args.title !== undefined) {
      params.title = args.title;
    }
    await api.delete('/grades/batch', { params });
  },

  /**
   * Delete a single assessment by its DB id — precise and immune to
   * the (subject, type, date, title) collision that
   * [deleteAssessmentBatch] can hit when a null-titled column is
   * being reshuffled. Used by [renameAssessment]'s second phase so
   * the freshly-created new-title assessment can't be swept up as
   * collateral.
   *
   * Sends the assessment_id via query param so the backend
   * BatchDestroyGradesAction routes into its `byAssessment` branch,
   * which deletes exactly that assessment + its grades.
   */
  async deleteAssessmentById(assessmentId: string): Promise<void> {
    await api.delete('/grades/batch', {
      params: { assessment_id: assessmentId },
    });
  },

  /**
   * Edit an existing assessment column's details (title / type / date).
   *
   * The backend has no dedicated "update assessment" endpoint — the
   * `assessments` row is implicit, keyed by the composite unique index
   * `(teacher_id, subject_id, type, date, title)`, and only the
   * delete-batch + grade-POST operations touch it. So an "edit" is
   * expressed with the exact same primitives the rest of this service
   * already uses:
   *
   *   1. Re-POST every *scored* cell of the column under the NEW
   *      (type, date, title) — this lazily creates the new assessment
   *      row + migrates the grades (POST /grades, same path as add +
   *      autosave).
   *   2. DELETE /grades/batch on the OLD (type, date, title) — removes
   *      the now-orphaned original assessment + its grades.
   *
   * Ordering matters: create-new BEFORE delete-old so a mid-flight
   * failure can never leave the teacher with zero columns. If the new
   * key equals the old key (nothing actually changed) the caller
   * should short-circuit and never reach here.
   *
   * `old.date` is required by the batch-delete filter; a column with no
   * date can't be migrated from the web (same limitation the delete
   * flow already surfaces). When the column has no scored cells yet
   * there's nothing to re-POST — we still create a placeholder so the
   * renamed column survives; the caller handles that by re-seeding the
   * matrix locally.
   */
  async renameAssessment(payload: {
    rows: GradeRow[];
    old: { type: AssessmentType; date: string; title: string | null };
    next: { type: AssessmentType; date: string; title: string | null };
    assessmentId: string;
    subject_id: string;
    teacher_id: string;
  }): Promise<void> {
    const nextAssessment: Assessment = {
      // Synthetic id — the backend assigns the real id on first POST;
      // the matrix refetch reconciles it afterwards.
      id: `__rename__${Date.now()}`,
      name: payload.next.title || ASSESSMENT_LABELS[payload.next.type],
      raw_title: payload.next.title,
      type: payload.next.type,
      date: payload.next.date,
    };

    // 1. Re-POST scored cells under the new key. Cells are sent with
    //    their id stripped so saveCell takes the POST path (create),
    //    landing the grade on the new/looked-up assessment row.
    const tasks: Promise<unknown>[] = [];
    for (const row of payload.rows) {
      const cell = row.cells[payload.assessmentId];
      if (!cell || typeof cell.score !== 'number') continue;
      tasks.push(
        GradeService.saveCell({
          cell: {
            student_id: cell.student_id,
            assessment_id: nextAssessment.id,
            score: cell.score,
            notes: cell.notes ?? null,
          },
          row,
          assessment: nextAssessment,
          subject_id: payload.subject_id,
          teacher_id: payload.teacher_id,
        }),
      );
    }
    await Promise.all(tasks);

    // 2. Delete the old column by its DB id — bypasses the
    //    (subject, type, date, title) filter path entirely so the
    //    just-created NEW assessment can't be swept up as a false
    //    match (which would happen for a null-titled OLD column,
    //    where the batch filter couldn't distinguish old from new).
    await GradeService.deleteAssessmentById(payload.assessmentId);
  },
};

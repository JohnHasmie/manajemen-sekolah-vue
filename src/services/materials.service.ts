/**
 * MaterialService - chapter / sub-chapter tree + sub-chapter detail
 * (manual content, AI-generated material, quizzes, references).
 *
 * Mirrors Flutter's two-tier data layer:
 *   - core_api (`api` instance): chapters, sub-chapters, mark-done,
 *     manual content materials.
 *   - kamiledu-ai (`aiApi` instance): generated-materials check-cache /
 *     fetch / regenerate endpoints.
 *
 * The Flutter `SubBabDetailPage` uses a cascading cache (local prefs →
 * pointer cache → check-cache → list fallback → teacher-agnostic check)
 * before falling back to a fresh fetch. For the web port we keep the
 * fetch path explicit (no offline cache) and rely on Pinia/component
 * state for in-session caching.
 */
import { aiApi, api } from '@/lib/http';
import type {
  Chapter,
  ContentMaterial,
  GeneratedMaterial,
  MaterialContentParsed,
  MaterialTree,
  QuizItem,
  ReferenceItem,
  SubChapter,
} from '@/types/materials';

interface TreeParams {
  /**
   * Grade level 1-12 to scope the bab list to. When set, the backend
   * returns chapters matching that grade AND legacy universal rows
   * (grade IS NULL) so the pre-existing chapter set stays discoverable.
   * Accepts a string OR number — coerced to an integer for the API.
   */
  grade_level?: string | number | null;
  subject_id: string;
  semester?: string;
  /**
   * When provided, second-phase fetches `/material-progress` and
   * merges per-sub-chapter `is_checked` / `is_generated` flags into
   * the tree so reload restores the teacher's progress state.
   * Without this, the chapter list endpoint returns false for
   * every `done` flag (it's teacher-agnostic).
   */
  teacher_id?: string;
  class_id?: string;
}

function subFromJson(raw: any): SubChapter {
  return {
    id: String(raw.id ?? ''),
    // `urutan` is the canonical ordering column on the Laravel
    // backend (Indonesian); `number` / `nomor` are kept for
    // any other shape that might ship one day.
    number: String(raw.number ?? raw.nomor ?? raw.urutan ?? raw.order ?? ''),
    // Backend ships `judul_sub_bab` / `judul_bab` for the title;
    // older Vue mockups expected `name` / `nama` / `title`.
    name: String(
      raw.sub_chapter_title ??
        raw.judul_sub_bab ??
        raw.judul ??
        raw.name ??
        raw.nama ??
        raw.title ??
        '',
    ),
    done: Boolean(raw.done ?? raw.is_done ?? raw.taught ?? false),
    taught_at: raw.taught_at ?? raw.tanggal_ajar ?? null,
    ai_generated: Boolean(raw.ai_generated ?? raw.is_ai ?? false),
    // Backend uses `bab_id`; flat list endpoint and lazy fetch both
    // honor it. `chapter_id` is the FE-canonical alias.
    chapter_id: raw.chapter_id ?? raw.bab_id ?? null,
    subject_name: raw.subject_name ?? raw.mata_pelajaran ?? null,
  };
}

function chapterFromJson(raw: any): Chapter {
  const subsRaw: any[] = Array.isArray(raw.sub_chapters ?? raw.subchapters ?? raw.subBab)
    ? (raw.sub_chapters ?? raw.subchapters ?? raw.subBab)
    : [];
  const sub_chapters = subsRaw.map((s) =>
    subFromJson({ ...s, chapter_id: s.chapter_id ?? s.bab_id ?? raw.id ?? null }),
  );
  const done_count = sub_chapters.filter((s) => s.done).length;
  // `urutan` is the chapter sequence number — drives "Bab N".
  const seq = raw.number ?? raw.nomor ?? raw.urutan ?? raw.order ?? '';
  // Grade column added by 2026_07_16 migration; older API responses
  // (or legacy rows) may omit it → coerce to null so the UI shows
  // "Universal" badge instead of a bogus "Kelas 0".
  const rawGrade = raw.grade;
  const grade =
    rawGrade == null
      ? null
      : typeof rawGrade === 'number'
        ? Math.trunc(rawGrade)
        : (() => {
            const n = Number.parseInt(String(rawGrade), 10);
            return Number.isFinite(n) ? n : null;
          })();
  return {
    id: String(raw.id ?? ''),
    label: String(raw.label ?? `Bab ${seq}`).trim(),
    name: String(
      raw.chapter_title ??
        raw.judul_bab ??
        raw.judul ??
        raw.name ??
        raw.nama ??
        raw.title ??
        '',
    ),
    meta: raw.chapter_description ?? raw.meta ?? raw.deskripsi_bab ?? raw.deskripsi ?? '',
    grade,
    sub_chapters,
    done_count,
    total_count: sub_chapters.length,
  };
}

function contentFromJson(raw: any): ContentMaterial {
  const mime = String(raw.file_mime ?? raw.mime ?? '');
  const url = raw.file_url ?? raw.url ?? raw.link ?? null;
  let kind = raw.kind ?? null;
  if (!kind && url) {
    const lower = String(url).toLowerCase();
    if (lower.endsWith('.pdf')) kind = 'PDF';
    else if (lower.endsWith('.doc') || lower.endsWith('.docx')) kind = 'DOCX';
    else if (lower.endsWith('.mp4') || lower.endsWith('.mov')) kind = 'VIDEO';
    else if (lower.startsWith('http')) kind = 'LINK';
  }
  if (!kind && mime) kind = mime.split('/')[1]?.toUpperCase() ?? mime;
  return {
    id: String(raw.id ?? ''),
    title: String(raw.judul_konten ?? raw.title ?? raw.nama ?? 'Lampiran'),
    description: raw.isi_konten ?? raw.description ?? raw.deskripsi ?? null,
    file_url: url,
    kind,
    created_at: raw.created_at ?? raw.tanggal_buat ?? null,
  };
}

function quizFromJson(raw: any): QuizItem {
  const type = String(raw.question_type ?? raw.type ?? 'multiple_choice');

  // AI backend (kamiledu-ai) ships options as
  //   [{ label: 'A', text: '…', is_correct: true }, …]
  // older / alternate shapes might just be strings. Coerce to a
  // flat `text` string array so the template can render uniformly
  // (it already renders an A/B/C/D bubble badge alongside each
  // option, so prepending the label would duplicate it).
  //
  // When `correct_answer` is absent, derive it from the option
  // marked `is_correct: true` — backend sometimes stores it only
  // on the option object.
  let opts: string[] | undefined;
  let derivedCorrect: string | undefined;
  if (Array.isArray(raw.options)) {
    opts = raw.options.map((o: any) => {
      if (o && typeof o === 'object') {
        if (o.is_correct && o.label) derivedCorrect = String(o.label);
        return String(o.text ?? o.value ?? o.label ?? '');
      }
      return String(o);
    });
  }

  return {
    question_type: type === 'essay' ? 'essay' : 'multiple_choice',
    question: String(raw.question ?? raw.pertanyaan ?? ''),
    options: opts,
    correct_answer:
      raw.correct_answer ??
      raw.kunci_jawaban ??
      derivedCorrect ??
      undefined,
    explanation: raw.explanation ?? raw.penjelasan ?? undefined,
    answer_key: raw.answer_key ?? raw.kunci ?? undefined,
    difficulty: raw.difficulty ?? raw.tingkat ?? undefined,
  };
}

function referenceFromJson(raw: any): ReferenceItem {
  return {
    title: String(raw.title ?? raw.judul ?? raw.name ?? 'Referensi'),
    url: raw.url ?? raw.link ?? undefined,
    kind: raw.kind ?? raw.tipe ?? raw.type ?? undefined,
    description: raw.description ?? raw.deskripsi ?? raw.keterangan ?? undefined,
  };
}

/**
 * Decode `material_content`. The backend stores it as TEXT but most
 * payloads come down as Map<String, dynamic>; tolerate both shapes.
 */
function parseMaterialContent(raw: unknown): MaterialContentParsed | null {
  if (!raw) return null;
  if (typeof raw === 'object') return raw as MaterialContentParsed;
  if (typeof raw === 'string') {
    const trimmed = raw.trim();
    if (!trimmed) return null;
    try {
      const decoded = JSON.parse(trimmed);
      if (decoded && typeof decoded === 'object') {
        return decoded as MaterialContentParsed;
      }
    } catch {
      // Plain-text material_content → keep as ringkasan placeholder.
      return { ringkasan: trimmed };
    }
  }
  return null;
}

function materialFromJson(raw: any): GeneratedMaterial {
  const data = raw?.data ?? raw ?? {};
  const quizzesRaw: any[] = Array.isArray(data.quizzes) ? data.quizzes : [];
  const refsRaw: any[] = Array.isArray(data.references) ? data.references : [];
  return {
    id: String(data.id ?? data.material_id ?? ''),
    sub_chapter_id: data.sub_chapter_id ?? data.sub_bab_id ?? undefined,
    chapter_id: data.chapter_id ?? data.bab_id ?? undefined,
    material_content_raw: data.material_content ?? null,
    parsed_content: parseMaterialContent(data.material_content),
    quizzes: quizzesRaw.map(quizFromJson),
    references: refsRaw.map(referenceFromJson),
    created_at: data.created_at ?? null,
    updated_at: data.updated_at ?? null,
  };
}

/**
 * Translate an axios failure from `POST /generated-materials/generate`
 * into a Bahasa Indonesia message the AI sheet can show verbatim.
 *
 * Priority:
 *   1. `response.data.message` — the backend's own actionable string
 *      (e.g. "Isi minimal salah satu: nama bab/sub-bab atau topik
 *      utama." from GenerateMaterialRequest::withValidator).
 *   2. `response.data.errors.<field>[0]` — Laravel's default validator
 *      shape when no top-level `message` was supplied.
 *   3. Status-code fallback for 429 / 5xx / network — these usually
 *      reach us with no body, so we have to write the copy ourselves.
 *
 * Returning a string (not throwing) makes the call site simpler:
 *   throw new Error(translateGenerateMaterialError(err))
 */
function translateGenerateMaterialError(err: unknown): string {
  const axiosErr = err as {
    response?: { status?: number; data?: { message?: string; errors?: Record<string, string[]> } };
    code?: string;
    message?: string;
  };
  const status = axiosErr.response?.status;
  const body = axiosErr.response?.data;

  if (body?.message && typeof body.message === 'string') {
    return body.message;
  }
  if (body?.errors) {
    const firstField = Object.keys(body.errors)[0];
    const firstMsg = firstField ? body.errors[firstField]?.[0] : undefined;
    if (firstMsg) return firstMsg;
  }

  if (status === 422) {
    return 'Form tidak valid. Pastikan bab/sub-bab atau topik utama terisi.';
  }
  if (status === 429) {
    return 'Kuota AI sekolah ini sudah habis untuk hari ini. Silakan coba lagi besok atau hubungi admin.';
  }
  if (status === 503 || status === 502) {
    return 'Layanan AI sedang sibuk. Mohon coba lagi beberapa saat.';
  }
  if (status && status >= 500) {
    return 'Terjadi kesalahan pada server. Mohon coba lagi.';
  }

  if (axiosErr.code === 'ECONNABORTED' || axiosErr.message?.includes('timeout')) {
    return 'Permintaan terlalu lama. Coba lagi dengan koneksi yang lebih stabil.';
  }
  if (axiosErr.message === 'Network Error' || axiosErr.code === 'ERR_NETWORK') {
    return 'Koneksi terputus. Periksa internet Anda lalu coba lagi.';
  }

  return 'Gagal menggenerate materi. Mohon coba lagi.';
}

export const MaterialService = {
  /**
   * Fetch the chapter tree for a subject.
   *
   * The backend exposes two flat list endpoints (`/chapters` for
   * chapters, `/sub-chapters?chapter_id=…` for sub-chapters per
   * chapter); there is no combined `/chapter` endpoint. We fetch the
   * chapters first, then fan out per-chapter for sub-chapters.
   */
  async getTree(params: TreeParams): Promise<MaterialTree> {
    try {
      // Coerce grade_level to the integer the backend `?grade=N` filter
      // expects. Non-numeric strings and null both fall through to the
      // unscoped list (which still includes universal rows).
      const gradeInt =
        params.grade_level == null
          ? null
          : (() => {
              const n =
                typeof params.grade_level === 'number'
                  ? params.grade_level
                  : Number.parseInt(String(params.grade_level), 10);
              return Number.isFinite(n) ? n : null;
            })();
      const chapterRes = await api.get('/chapters', {
        params: {
          subject_id: params.subject_id,
          ...(gradeInt != null ? { grade: gradeInt } : {}),
          ...(params.semester ? { semester: params.semester } : {}),
        },
      });
      const chapterBody = chapterRes.data?.data ?? chapterRes.data ?? [];
      const chaptersRaw: any[] = Array.isArray(chapterBody)
        ? chapterBody
        : [];

      // Fan-out for sub-chapters. Each chapter row may already include
      // its sub-chapters (eager-loaded by backend); if not, fetch.
      const chapters: Chapter[] = await Promise.all(
        chaptersRaw.map(async (raw) => {
          const hasInlineSubs =
            Array.isArray(raw.sub_chapters) ||
            Array.isArray(raw.subchapters) ||
            Array.isArray(raw.subBab);
          if (hasInlineSubs) return chapterFromJson(raw);
          try {
            const subRes = await api.get('/sub-chapters', {
              params: { chapter_id: raw.id ?? raw.bab_id },
            });
            const subBody = subRes.data?.data ?? subRes.data ?? [];
            return chapterFromJson({
              ...raw,
              sub_chapters: Array.isArray(subBody) ? subBody : [],
            });
          } catch {
            return chapterFromJson({ ...raw, sub_chapters: [] });
          }
        }),
      );

      // Second-phase: merge per-sub-chapter progress (done /
      // ai_generated) when teacher_id is known. The chapter list
      // endpoint is teacher-agnostic so without this every reload
      // would flush the teacher's check marks.
      if (params.teacher_id) {
        const progress = await this.listProgress({
          teacher_id: params.teacher_id,
          subject_id: params.subject_id,
          class_id: params.class_id,
        });
        if (progress.length > 0) {
          const bySubId = new Map<string, (typeof progress)[number]>();
          for (const p of progress) {
            if (p.sub_chapter_id) bySubId.set(p.sub_chapter_id, p);
          }
          for (const c of chapters) {
            for (const s of c.sub_chapters) {
              const p = bySubId.get(s.id);
              if (!p) continue;
              s.done = p.is_checked;
              s.ai_generated = p.is_generated;
            }
            c.done_count = c.sub_chapters.filter((s) => s.done).length;
          }
        }
      }

      const done_total = chapters.reduce((s, c) => s + c.done_count, 0);
      const total_total = chapters.reduce((s, c) => s + c.total_count, 0);
      return { chapters, done_total, total_total };
    } catch {
      return { chapters: [], done_total: 0, total_total: 0 };
    }
  },

  /**
   * Fetch the teacher's saved progress map for a (subject) — returns
   * one row per (chapter, sub_chapter) the teacher has ever touched
   * with `is_checked` + `is_generated` flags. Used by `getTree` to
   * merge `done` state into the chapter tree on reload (the chapter
   * list endpoint itself is teacher-agnostic).
   */
  async listProgress(args: {
    teacher_id: string;
    subject_id: string;
    class_id?: string;
  }): Promise<
    Array<{
      chapter_id: string;
      sub_chapter_id: string | null;
      is_checked: boolean;
      is_generated: boolean;
    }>
  > {
    try {
      const res = await api.get('/material-progress', {
        params: {
          teacher_id: args.teacher_id,
          subject_id: args.subject_id,
          ...(args.class_id ? { class_id: args.class_id } : {}),
        },
      });
      const body = res.data;
      const arr: any[] = Array.isArray(body)
        ? body
        : Array.isArray(body?.data)
          ? body.data
          : [];
      return arr.map((r) => ({
        chapter_id: String(r.chapter_id ?? r.bab_id ?? ''),
        sub_chapter_id: r.sub_chapter_id ?? r.sub_bab_id ?? null,
        is_checked: Boolean(r.is_checked ?? r.done ?? false),
        is_generated: Boolean(r.is_generated ?? r.ai_generated ?? false),
      }));
    } catch {
      return [];
    }
  },

  /**
   * Mark / unmark a sub-chapter as taught.
   *
   * Backend (`UpdateMaterialProgressRequest`) validates a fuller
   * payload than the old shim assumed — it needs the full
   * (teacher, subject, chapter) tuple plus the `is_checked`
   * boolean. Missing any of those fields trips a 422.
   *
   * `is_generated` is optional and flipped separately by the AI
   * generate flow; pass it through when known so the row gets
   * updated atomically.
   */
  async toggleSubChapter(args: {
    teacher_id: string;
    subject_id: string;
    chapter_id: string;
    sub_chapter_id: string;
    is_checked: boolean;
    is_generated?: boolean;
  }): Promise<void> {
    await api.post('/material-progress', {
      teacher_id: args.teacher_id,
      subject_id: args.subject_id,
      chapter_id: args.chapter_id,
      sub_chapter_id: args.sub_chapter_id,
      is_checked: args.is_checked,
      ...(args.is_generated !== undefined
        ? { is_generated: args.is_generated }
        : {}),
    });
  },

  /** Manual content materials (lampiran) attached to the sub-chapter. */
  async getContentMaterials(subChapterId: string): Promise<ContentMaterial[]> {
    try {
      const res = await api.get('/content-material', {
        params: { sub_chapter_id: subChapterId },
      });
      const body = res.data;
      const items: any[] = Array.isArray(body)
        ? body
        : Array.isArray(body?.data)
          ? body.data
          : [];
      return items.map(contentFromJson);
    } catch {
      return [];
    }
  },

  /**
   * Generate a new AI material payload for a sub-chapter. The Laravel
   * proxy may return a 200 with the inline payload OR a 202 with a
   * job_id that the caller polls via the AI-jobs endpoint.
   *
   * Axios errors are translated into Bahasa Indonesia messages so the
   * UI toast doesn't show "Request failed with status code 422" when
   * the backend validator rejects, or raw "Network Error" on a
   * connectivity drop. When the backend responds with a structured
   * `message`, we surface that verbatim — the backend already emits
   * locale-friendly, actionable strings and re-translating loses
   * detail. Status-code fallbacks cover the cases where the backend
   * couldn't supply a message (5xx, timeouts).
   */
  async generateWithAi(payload: {
    teacher_id?: string;
    subject_id: string;
    class_id?: string;
    chapter_id?: string;
    sub_chapter_id?: string;
    grade_level?: string;
    chapter_label?: string;
    topic?: string;
  }): Promise<{ job_id?: string; material_id?: string }> {
    try {
      // AI service mounts this under the `generated-materials` prefix
      // (routes/api_ai_features.php) — `/material/generate` 404s.
      const res = await aiApi.post('/generated-materials/generate', payload);
      const body = res.data?.data ?? res.data ?? {};
      return {
        job_id: body.job_id ?? undefined,
        material_id: body.material_id ?? body.id ?? undefined,
      };
    } catch (err: unknown) {
      throw new Error(translateGenerateMaterialError(err));
    }
  },

  /**
   * Check whether an AI-generated material already exists for the
   * (teacher?, chapter, sub_chapter) tuple. `teacher_id` may be omitted
   * for the teacher-agnostic lookup.
   */
  async checkMaterialCache(args: {
    teacher_id?: string;
    chapter_id: string;
    sub_chapter_id?: string;
  }): Promise<{ cached: boolean; material_id?: string }> {
    try {
      const res = await aiApi.get('/generated-materials/check-cache', {
        params: {
          ...(args.teacher_id ? { teacher_id: args.teacher_id } : {}),
          chapter_id: args.chapter_id,
          ...(args.sub_chapter_id ? { sub_chapter_id: args.sub_chapter_id } : {}),
        },
      });
      const body = res.data?.data ?? res.data ?? {};
      return {
        cached: Boolean(body.cached),
        material_id: body.material_id ?? body.id ?? undefined,
      };
    } catch {
      return { cached: false };
    }
  },

  /** Fetch the full AI payload by material_id (kamiledu-ai). */
  async getGeneratedMaterial(
    materialId: string,
    opts: { class_id?: string } = {},
  ): Promise<GeneratedMaterial | null> {
    try {
      const res = await aiApi.get(`/generated-materials/${materialId}`, {
        params: opts.class_id ? { class_id: opts.class_id } : {},
      });
      return materialFromJson(res.data);
    } catch {
      return null;
    }
  },

  /** Fallback list endpoint used when check-cache is unavailable. */
  async listGeneratedMaterials(args: {
    teacher_id: string;
    subject_id?: string;
    chapter_id?: string;
  }): Promise<Array<{ id: string; sub_chapter_id?: string }>> {
    try {
      const res = await aiApi.get('/generated-materials', {
        params: {
          teacher_id: args.teacher_id,
          ...(args.subject_id ? { subject_id: args.subject_id } : {}),
          ...(args.chapter_id ? { chapter_id: args.chapter_id } : {}),
        },
      });
      const body = res.data?.data ?? res.data ?? [];
      const items: any[] = Array.isArray(body) ? body : [];
      return items.map((m) => ({
        id: String(m.id ?? ''),
        sub_chapter_id: m.sub_chapter_id ?? m.sub_bab_id ?? undefined,
      }));
    } catch {
      return [];
    }
  },

  /**
   * High-level resolver used by the sub-chapter detail screen.
   * Combines the cache-check → list fallback chain into one call.
   * Returns the resolved GeneratedMaterial or null if none exists.
   */
  async resolveAiMaterial(args: {
    teacher_id?: string;
    chapter_id: string;
    sub_chapter_id: string;
    class_id?: string;
  }): Promise<GeneratedMaterial | null> {
    // Tier 1 — check-cache by teacher (if provided)
    if (args.teacher_id) {
      const c = await this.checkMaterialCache({
        teacher_id: args.teacher_id,
        chapter_id: args.chapter_id,
        sub_chapter_id: args.sub_chapter_id,
      });
      if (c.cached && c.material_id) {
        const m = await this.getGeneratedMaterial(c.material_id, {
          class_id: args.class_id,
        });
        if (m) return m;
      }
    }
    // Tier 2 — teacher-agnostic check-cache
    const agnostic = await this.checkMaterialCache({
      chapter_id: args.chapter_id,
      sub_chapter_id: args.sub_chapter_id,
    });
    if (agnostic.cached && agnostic.material_id) {
      return this.getGeneratedMaterial(agnostic.material_id, {
        class_id: args.class_id,
      });
    }
    // Tier 3 — list fallback
    if (args.teacher_id) {
      const list = await this.listGeneratedMaterials({
        teacher_id: args.teacher_id,
        chapter_id: args.chapter_id,
      });
      const match = list.find((x) => x.sub_chapter_id === args.sub_chapter_id);
      if (match) {
        return this.getGeneratedMaterial(match.id, { class_id: args.class_id });
      }
    }
    return null;
  },

  /** Regenerate only the material_content (keeps quiz + refs). */
  async regenerateMaterialContent(materialId: string): Promise<void> {
    await aiApi.post(`/generated-materials/${materialId}/regenerate-material`);
  },

  /** Add more quiz items to an existing generated material. */
  async regenerateQuiz(materialId: string): Promise<void> {
    await aiApi.post(`/generated-materials/${materialId}/regenerate-quiz`);
  },

  /** Regenerate the reference list. */
  async regenerateReferences(materialId: string): Promise<void> {
    await aiApi.post(`/generated-materials/${materialId}/regenerate-reference`);
  },
};

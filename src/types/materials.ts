/**
 * Materials types - chapter + sub-chapter tree + AI-generated detail.
 * Mirrors Flutter's materi model (lib/features/materials).
 */

export interface SubChapter {
  id: string;
  /** Numbered label e.g. "4.2". */
  number: string;
  name: string;
  /** True once the teacher has marked this sub-chapter as taught. */
  done: boolean;
  /** ISO date the sub-chapter was last taught, if done. */
  taught_at?: string | null;
  /** AI-generated content flag — drives the "AI" pill on the row. */
  ai_generated?: boolean;
  /** Parent chapter id, when known. Useful when opening the detail. */
  chapter_id?: string | null;
  /** Optional subject name resolved from the chapter context. */
  subject_name?: string | null;
}

export interface Chapter {
  id: string;
  /** Numbered label e.g. "Bab 4". */
  label: string;
  name: string;
  /** Total page count or estimated minutes — display-only. */
  meta?: string;
  /**
   * Grade level 1-12 the chapter is scoped to. `null` means the
   * chapter is legacy / universal — it predates the per-grade
   * column and applies across all grades until an admin classifies
   * it. Backend column: `chapters.grade`.
   */
  grade: number | null;
  sub_chapters: SubChapter[];
  /** Computed: count of sub-chapters marked done. */
  done_count: number;
  /** Computed: total sub-chapters. */
  total_count: number;
}

export interface MaterialTree {
  chapters: Chapter[];
  /** Computed sum across all chapters. */
  done_total: number;
  total_total: number;
}

/**
 * Manual content material (lampiran) attached to a sub-chapter.
 *
 * The Laravel API returns Indonesian + English aliases:
 *  - judul_konten / title
 *  - isi_konten / description
 *  - file_url / link
 */
export interface ContentMaterial {
  id: string;
  title: string;
  description?: string | null;
  file_url?: string | null;
  /** Display-friendly mime label (PDF, DOCX, MP4, …). */
  kind?: string | null;
  created_at?: string | null;
}

/**
 * One quiz item inside `generated_materials.quizzes`.
 *
 * Mirrors the kamiledu-ai response shape:
 *   {
 *     question_type: 'multiple_choice' | 'essay',
 *     question: '…',
 *     options: ['A', 'B', 'C', 'D'],      // MC only
 *     correct_answer: 'B',                  // MC only
 *     explanation: '…',
 *     answer_key: '…',                      // essay only
 *     difficulty: 'easy' | 'medium' | 'hard',
 *   }
 */
export interface QuizItem {
  question_type: 'multiple_choice' | 'essay';
  question: string;
  options?: string[];
  correct_answer?: string;
  explanation?: string;
  answer_key?: string;
  difficulty?: 'easy' | 'medium' | 'hard' | string;
}

export interface ReferenceItem {
  title: string;
  url?: string;
  /** Display label e.g. "Buku Paket", "Artikel Web", "Video". */
  kind?: string;
  description?: string;
}

/**
 * Parsed `material_content` JSON. The backend stores this as TEXT, so we
 * may receive either a Map or a string-encoded JSON; the service decodes
 * both shapes before exposing this type.
 */
export interface MaterialContentParsed {
  ringkasan?: string;
  tujuan_pembelajaran?: string | string[];
  poin_utama?: string[];
  cara_mengajar?: string;
  /** Backend may include extra fields — keep them under .extras. */
  [extra: string]: unknown;
}

/**
 * Full AI-generated material for a single sub-chapter, returned from
 * `GET /generated-materials/{id}`.
 */
export interface GeneratedMaterial {
  id: string;
  sub_chapter_id?: string;
  chapter_id?: string;
  /** Raw material_content as returned (may be string OR object). */
  material_content_raw?: unknown;
  /** Decoded material_content. */
  parsed_content: MaterialContentParsed | null;
  quizzes: QuizItem[];
  references: ReferenceItem[];
  created_at?: string | null;
  updated_at?: string | null;
}

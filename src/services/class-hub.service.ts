// API for the class-first "Kelas" hub. Thin object over the shared `api`
// axios client, mirroring the other *.service.ts files.

import { api } from '@/lib/http';
import {
  classCardFromJson,
  classFeedItemFromJson,
  type ClassCard,
  type ClassFeedItem,
} from '@/types/class-hub';

function asRows(body: unknown): Record<string, unknown>[] {
  const data =
    body && typeof body === 'object'
      ? (body as { data?: unknown }).data
      : undefined;
  if (Array.isArray(data)) return data as Record<string, unknown>[];
  if (Array.isArray(body)) return body as Record<string, unknown>[];
  return [];
}

export const ClassHubService = {
  /** The caller's classes. Pass `studentId` for the parent → child's classes. */
  async myClasses(studentId?: string): Promise<ClassCard[]> {
    const res = await api.get('/classes/mine', {
      params: studentId ? { student_id: studentId } : {},
    });
    return asRows(res.data).map(classCardFromJson);
  },

  /** School-wide read-only oversight (admin) — every class + health signals. */
  async oversight(): Promise<ClassCard[]> {
    const res = await api.get('/classes/oversight');
    return asRows(res.data).map(classCardFromJson);
  },

  /** One class's "Riwayat Sesi" feed. */
  async feed(
    classId: string,
    opts: { subjectId?: string; before?: string; limit?: number } = {},
  ): Promise<ClassFeedItem[]> {
    const res = await api.get(`/classes/${classId}/feed`, {
      params: {
        limit: opts.limit ?? 20,
        ...(opts.subjectId ? { subject_id: opts.subjectId } : {}),
        ...(opts.before ? { before: opts.before } : {}),
      },
    });
    return asRows(res.data).map(classFeedItemFromJson);
  },
};

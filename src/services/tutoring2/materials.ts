/**
 * Tutoring2 · teaching materials.
 *
 * Both screens that use this shipped against hardcoded sample data —
 * the list rendered four materials that did not exist, and the upload
 * form fired a success toast without calling anything. This service is
 * what replaces the fiction.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  Material,
  MaterialCreatePayload,
  MaterialListParams,
  MaterialUploadResult,
} from '@/types/tutoring2/material';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

export const MaterialsService = {
  async list(params: MaterialListParams = {}) {
    const r = await api.get<ListEnvelope<Material>>('/tutoring-v2/materials', { params });
    return { items: r.data.data, pagination: r.data.meta };
  },

  /**
   * Step 1 of 2. Stores the file and returns the reference plus its
   * metadata; nothing is visible to anyone until create() runs.
   *
   * Split because a material row needs a title, a kind and a group —
   * none of which a file picker knows.
   */
  async uploadFile(file: File): Promise<MaterialUploadResult> {
    const form = new FormData();
    form.append('file', file);
    const r = await api.post<OneEnvelope<MaterialUploadResult>>(
      '/tutoring-v2/materials/upload',
      form,
    );
    return r.data.data;
  },

  /** Step 2 of 2 — pass `file_url` straight from uploadFile(), or an external URL. */
  async create(payload: MaterialCreatePayload): Promise<Material> {
    const r = await api.post<OneEnvelope<Material>>('/tutoring-v2/materials', payload);
    return r.data.data;
  },

  async destroy(id: string): Promise<void> {
    await api.delete(`/tutoring-v2/materials/${id}`);
  },
};

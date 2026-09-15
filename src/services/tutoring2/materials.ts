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
  MaterialUpdatePayload,
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
   * One material, by id — `GET /tutoring-v2/materials/{id}`.
   *
   * Not a client-side `find` over a page of `list()`: `show` applies the
   * same read scope as the index BEFORE `findOrFail`, so an id outside
   * this tutor's groups and programmes 404s instead of being quietly
   * absent from a page. It also eager-loads the group, the programme and
   * the uploader, which the list rows may not carry.
   *
   * And it is the ONLY way to obtain a usable `file_url`: the backend
   * re-signs the stored path on every read with a 30-minute window, so a
   * cached one goes dead. Re-read the material rather than keeping the
   * URL.
   */
  async show(id: string): Promise<Material> {
    const r = await api.get<OneEnvelope<Material>>(`/tutoring-v2/materials/${id}`);
    return r.data.data;
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

  /**
   * `PUT /tutoring-v2/materials/{id}`.
   *
   * The payload type is built from the FormRequest rules — see
   * `MaterialUpdatePayload`. Two things about it are worth keeping in
   * mind at the call site:
   *
   * 1. NEVER send back a `file_url` that came out of a GET. On READ the
   *    backend replaces the stored value with a resolved URL: a storage
   *    path is signed for 30 minutes against the bucket. On WRITE the
   *    column takes whatever arrives, and `Material::fileUrl()`
   *    afterwards sees a value already starting with `https://` and
   *    passes it through untouched, forever. Round-tripping a GET
   *    payload therefore stores an expiring URL permanently and loses
   *    the real disk key — a dead link half an hour later. The only
   *    legitimate `file_url` to send is a fresh PATH from
   *    `uploadFile()`.
   *
   * 2. The response is NOT interchangeable with `show()`. The controller
   *    returns the Action's `fresh()` with no eager loads, and
   *    `learning_group_name` / `program_name` / `uploaded_by_name` are
   *    `whenLoaded`, so they are ABSENT from it rather than null. Re-read
   *    with `show()` instead of splicing this into a rendered row.
   */
  async update(id: string, payload: MaterialUpdatePayload): Promise<Material> {
    const r = await api.put<OneEnvelope<Material>>(
      `/tutoring-v2/materials/${id}`,
      payload,
    );
    return r.data.data;
  },

  /**
   * "Kirim ke wali" — `POST /tutoring-v2/materials/{id}/publish`.
   *
   * ── Why this exists ──
   *
   * `CreateMaterialAction` never sets `published_at`, so a material is
   * born a DRAFT, and `MaterialController@index` hides drafts from any
   * caller without `tutoring.material.manage`:
   *
   *     ->when(! $canManage, fn ($b) => $b->whereNotNull('published_at'))
   *
   * The draft default is deliberate — a tutor's own lesson prep should
   * not appear in a parent's app the moment it is uploaded. But until
   * these two routes shipped there was no way to lift it, so the
   * practical outcome was that no wali and no siswa could see a single
   * teaching material, ever.
   *
   * ── Why a verb and not a flag on update() ──
   *
   * `published_at` is absent from `UpdateMaterialRequest::rules()`, and
   * `UpdateMaterialAction` applies its own allowlist over the same seven
   * names. Sending it through `update()` answers 200 and changes
   * nothing. Both layers would have to change; neither did.
   *
   * ── The response IS renderable ──
   *
   * Unlike `update()`, whose response drops the eager loads, the
   * controller re-`load()`s `learningGroup`, `program` and `uploadedBy`
   * before wrapping, so `learning_group_name` and its siblings are
   * present here. Callers may still prefer a `show()` re-read when a
   * fresh signed `file_url` matters.
   *
   * Authorizes `tutoring.material.manage`. Idempotent — sending an
   * already-sent material is a no-op, not a 422.
   */
  async publish(id: string): Promise<Material> {
    const r = await api.post<OneEnvelope<Material>>(
      `/tutoring-v2/materials/${id}/publish`,
      {},
    );
    return r.data.data;
  },

  /**
   * "Tarik dari wali" — `POST /tutoring-v2/materials/{id}/unpublish`.
   *
   * Clears `published_at`, so the material drops out of the wali and
   * siswa index again and goes back to being visible only to callers
   * holding `tutoring.material.manage`. Same authorization, and
   * idempotent in this direction too.
   */
  async unpublish(id: string): Promise<Material> {
    const r = await api.post<OneEnvelope<Material>>(
      `/tutoring-v2/materials/${id}/unpublish`,
      {},
    );
    return r.data.data;
  },

  async destroy(id: string): Promise<void> {
    await api.delete(`/tutoring-v2/materials/${id}`);
  },
};

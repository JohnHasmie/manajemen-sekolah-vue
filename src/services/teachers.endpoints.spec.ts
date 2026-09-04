import { beforeEach, describe, expect, it, vi } from 'vitest';

import { TeacherService } from './teachers.service';
import { api } from '@/lib/http';

/**
 * Request-path guard for the by-id teacher endpoints.
 *
 * Why this file exists: the singular `/teacher/{id}` paths look like a
 * typo next to `POST /teachers/{id}/reset-password`, and a reader who
 * greps `routes/api.php` for `apiResource('teachers'` — and stops
 * there — concludes the six by-id calls in `teachers.service.ts` all
 * 404. They do not. `routes/api.php` registers the singular resource
 * too (`Route::apiResource('teacher', TeacherController::class)`),
 * unconditionally and in the same group as the plural one, and both
 * dispatch to the same `TeacherController`.
 *
 * That misreading nearly landed as a six-line "fix". The dangerous half
 * is `resolveProfile`, which passes a USER id — `TeacherController::show()`
 * matches `id` OR `user_id` on purpose to serve it — so retargeting it
 * at a teacher-id-only endpoint would break the teacher/wali-kelas nav
 * for every user, silently, because the caller swallows the failure.
 *
 * These assertions therefore pin the path STRING, not the behaviour.
 * If a future change really does mean to move to the plural resource,
 * that is a deliberate edit to this file plus the service — not a
 * side effect of a sweep.
 */

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

const mockedGet = vi.mocked(api.get);
const mockedPut = vi.mocked(api.put);
const mockedDelete = vi.mocked(api.delete);

const TEACHER_ID = '019fe622-e3d6-7168-ba19-893908bcbc04';
const USER_ID = '019fe700-1111-7222-8333-444455556666';

describe('TeacherService by-id endpoints use the singular /teacher resource', () => {
  beforeEach(() => {
    mockedGet.mockReset();
    mockedPut.mockReset();
    mockedDelete.mockReset();
  });

  it('get() requests GET /teacher/{id}', async () => {
    mockedGet.mockResolvedValue({ data: { data: { id: TEACHER_ID } } } as never);

    await TeacherService.get(TEACHER_ID);

    expect(mockedGet).toHaveBeenCalledWith(`/teacher/${TEACHER_ID}`);
  });

  it('update() requests PUT /teacher/{id} with the payload', async () => {
    mockedPut.mockResolvedValue({ data: { data: { id: TEACHER_ID } } } as never);
    const payload = { employment_status: 'permanent' };

    await TeacherService.update(TEACHER_ID, payload);

    expect(mockedPut).toHaveBeenCalledWith(`/teacher/${TEACHER_ID}`, payload);
  });

  it('remove() requests DELETE /teacher/{id}', async () => {
    mockedDelete.mockResolvedValue({ data: {} } as never);

    await TeacherService.remove(TEACHER_ID);

    expect(mockedDelete).toHaveBeenCalledWith(`/teacher/${TEACHER_ID}`);
  });

  it('bulkUpdate() PUTs /teacher/{id} once per id', async () => {
    mockedPut.mockResolvedValue({ data: {} } as never);
    const payload = { employment_status: 'contract' };

    const res = await TeacherService.bulkUpdate(['a1', 'b2'], payload);

    expect(mockedPut).toHaveBeenNthCalledWith(1, '/teacher/a1', payload);
    expect(mockedPut).toHaveBeenNthCalledWith(2, '/teacher/b2', payload);
    expect(res).toEqual({ updated: 2, failed: 0 });
  });

  it('bulkRemove() DELETEs /teacher/{id} once per id', async () => {
    mockedDelete.mockResolvedValue({ data: {} } as never);

    const res = await TeacherService.bulkRemove(['a1', 'b2']);

    expect(mockedDelete).toHaveBeenNthCalledWith(1, '/teacher/a1');
    expect(mockedDelete).toHaveBeenNthCalledWith(2, '/teacher/b2');
    expect(res).toEqual({ deleted: 2, failed: 0 });
  });

  /**
   * The one call whose id is NOT a teacher id. `TeacherController::show()`
   * resolves `id` OR `user_id`, scoped to the active school, specifically
   * so the auth store can trade the token's user id for a
   * `teacher_profile.id`. Keep the user id going to the singular path.
   */
  it('resolveProfile() sends the USER id to GET /teacher/{user_id}', async () => {
    mockedGet.mockResolvedValue({
      data: { id: TEACHER_ID, homeroom_classes: [] },
    } as never);

    const profile = await TeacherService.resolveProfile(USER_ID);

    expect(mockedGet).toHaveBeenCalledWith(`/teacher/${USER_ID}`);
    expect(profile?.id).toBe(TEACHER_ID);
  });

  it('resolveProfile() degrades to null when the row is absent (404)', async () => {
    // An admin who is not also a teacher at the active school. The auth
    // store calls this anyway; a 404 must stay non-fatal.
    mockedGet.mockRejectedValue(new Error('Request failed with status code 404'));

    await expect(TeacherService.resolveProfile(USER_ID)).resolves.toBeNull();
  });
});

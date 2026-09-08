/**
 * Vitest contract spec for the two session wrappers added with the
 * admin session detail: `getSession` (show) and `updateSession`.
 *
 * What it pins, and why each one is load-bearing:
 *
 *   - The URL anchors. `show` and `update` share a path and differ only
 *     by verb, so a refactor that reaches for the wrong one produces a
 *     405 rather than a type error.
 *
 *   - `tutor_id` NEVER reaches the wire. `UpdateSessionRequest::rules()`
 *     accepts it, and `SessionController::update` writes it, so nothing
 *     server-side would refuse a payload carrying it — the exclusion
 *     exists only on this side and is therefore only as strong as this
 *     test. Reassigning a session's tutor is out of scope for the edit
 *     surface by product decision.
 *
 *   - ABSENT is not NULL. The controller copies a key only when
 *     `$request->has($k)`, so an omitted key leaves the column alone
 *     while an explicit `null` clears it. A wrapper that "helpfully"
 *     filled in missing keys would silently blank notes the admin never
 *     opened.
 */
// @ts-nocheck — vitest types optional in this workspace (matches the
// trash.service.spec + rbac.service.spec pattern in this repo).
import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  BIMBEL_SESSION_UPDATE_FIELDS,
  TutoringBimbelService,
} from './tutoring-bimbel.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

/** A minimal `SessionResource` payload. */
function sessionPayload(over = {}) {
  return {
    id: 'ses-1',
    learning_group_id: 'grp-1',
    learning_group_name: 'UTBK Pagi A',
    tutor_id: 'tut-1',
    tutor_name: 'Ust. Ali',
    starts_at: '2026-09-08T08:00:00+07:00',
    ends_at: '2026-09-08T10:00:00+07:00',
    room: 'R-101',
    status: 'scheduled',
    status_label: 'Terjadwal',
    materials_note: null,
    tutor_note: null,
    ...over,
  };
}

describe('TutoringBimbelService.getSession', () => {
  beforeEach(() => vi.clearAllMocks());

  it('GETs the single-session endpoint and unwraps the envelope', async () => {
    (api.get as any).mockResolvedValueOnce({ data: { data: sessionPayload() } });

    const s = await TutoringBimbelService.getSession('ses-1');

    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/sessions/ses-1');
    expect(s.learning_group_name).toBe('UTBK Pagi A');
  });
});

describe('TutoringBimbelService.updateSession', () => {
  beforeEach(() => vi.clearAllMocks());

  it('PUTs to the same path the show endpoint reads', async () => {
    (api.put as any).mockResolvedValueOnce({ data: { data: sessionPayload() } });

    await TutoringBimbelService.updateSession('ses-1', { room: 'R-202' });

    expect(api.put).toHaveBeenCalledWith('/tutoring-v2/sessions/ses-1', {
      room: 'R-202',
    });
  });

  it('sends ONLY the keys it was given — an absent key is left alone', async () => {
    (api.put as any).mockResolvedValueOnce({ data: { data: sessionPayload() } });

    await TutoringBimbelService.updateSession('ses-1', { tutor_note: 'Selesai bab 3' });

    const [, body] = (api.put as any).mock.calls[0];
    // Not `toMatchObject` — the point is what is ABSENT. `room` and
    // `materials_note` were never mentioned, so the controller must not
    // see them at all.
    expect(Object.keys(body)).toEqual(['tutor_note']);
  });

  it('forwards an explicit null, which is how a note is cleared', async () => {
    (api.put as any).mockResolvedValueOnce({ data: { data: sessionPayload() } });

    await TutoringBimbelService.updateSession('ses-1', { tutor_note: null });

    const [, body] = (api.put as any).mock.calls[0];
    // `'tutor_note' in body` distinguishes "sent as null" (clear it)
    // from "omitted" (leave it) — a truthiness filter in the wrapper
    // would collapse the two and make a note impossible to erase.
    expect('tutor_note' in body).toBe(true);
    expect(body.tutor_note).toBeNull();
  });

  it('strips tutor_id even when a caller casts the type away', async () => {
    (api.put as any).mockResolvedValueOnce({ data: { data: sessionPayload() } });

    // `as any` is the whole point: `tutor_id?: never` already makes this
    // a compile error, and this asserts the RUNTIME allowlist that has
    // to hold when someone reaches past the type.
    await TutoringBimbelService.updateSession('ses-1', {
      room: 'R-202',
      tutor_id: 'tut-99',
    } as any);

    const [, body] = (api.put as any).mock.calls[0];
    expect(body).toEqual({ room: 'R-202' });
    expect('tutor_id' in body).toBe(false);
  });

  it('allowlists exactly the three editable fields', () => {
    // A regression guard on the constant itself: widening it is how
    // `tutor_id` would come back, and it would otherwise only show up
    // as a behaviour change with no test pointing at the cause.
    expect([...BIMBEL_SESSION_UPDATE_FIELDS]).toEqual([
      'room',
      'materials_note',
      'tutor_note',
    ]);
  });
});

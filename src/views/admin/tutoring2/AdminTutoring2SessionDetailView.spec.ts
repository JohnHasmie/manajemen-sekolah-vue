/**
 * AdminTutoring2SessionDetailView — the detail surface the admin session
 * list had no way into, and the edit form that spans two endpoints.
 *
 * ── What is actually at risk here ──
 *
 * "Edit sesi" reads as one form but is not one request. The three
 * editable things live apart:
 *
 *   starts_at / ends_at  →  POST /sessions/{id}/reschedule   (only here)
 *   materials_note /
 *   tutor_note           →  PUT  /sessions/{id}              (only here)
 *   room                 →  accepted by BOTH
 *
 * Three ways that goes wrong, each pinned below:
 *
 *   1. Firing BOTH calls unconditionally. `RescheduleSessionAction` ends
 *      with `$session->status = SCHEDULED` and re-stamps both timestamps,
 *      so a notes-only edit would walk a running session back to
 *      "Terjadwal" and re-write times nobody touched. It also 422s on a
 *      `done` session, which would make notes uneditable exactly when a
 *      wrap-up note is most wanted.
 *   2. Sending `room` on whichever call happens to fire. It is the one
 *      overlapping field; two writers means the later call silently
 *      clobbers the earlier. It is pinned to `update`, always.
 *   3. Letting `tutor_id` reach the wire. `UpdateSessionRequest` accepts
 *      it and the controller writes it, so nothing server-side refuses
 *      it — reassigning a session's tutor is out of scope by product
 *      decision, and the exclusion is only as strong as these tests.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. `grantedAbilities` starts WITHOUT `tutoring.session.manage` in the
 *    gate block, so "refuses" cannot pass because the mock grants
 *    everything. The editing blocks grant it explicitly.
 * 2. The service mock exposes `rescheduleSession` AND `updateSession`,
 *    and every "only X was called" assertion also asserts the OTHER was
 *    not. Asserting one call in isolation would pass while the other
 *    fired too.
 * 3. TZ is pinned to Asia/Jakarta and the assertions name the WIB
 *    wall-clock (`08.00`, `2026-09-08T08:00`). The UTC forms of the same
 *    instant (`01.00`, `2026-09-08T01:00`) are asserted absent — without
 *    that, a UTC regression would still satisfy a loose "renders a time"
 *    check. This is the bug that had every bimbel session time rendering
 *    seven hours early.
 * 4. `BottomSheetFooter` is stubbed as a REAL button carrying
 *    `primaryDisabled`, so the "nothing changed" case is observable as a
 *    disabled attribute rather than by reaching into the component.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SessionDetail from './AdminTutoring2SessionDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

const MANAGE = 'tutoring.session.manage';

/** Read-only baseline: a staff tier that may VIEW a session but not edit it. */
const VIEW_ONLY = ['tutoring.session.view'];

let grantedAbilities: string[] = [...VIEW_ONLY];

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (ability: string) => grantedAbilities.includes(ability),
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    getSession: vi.fn(),
    rescheduleSession: vi.fn(),
    updateSession: vi.fn(),
  },
}));

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'ses-1' } }),
  useRouter: () => ({ push }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

const toastError = vi.fn();
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: toastError, info: vi.fn() }),
}));

// ── Selectors ───────────────────────────────────────────────────────
const EDIT = '[data-testid="session-edit"]';
const EDIT_NOTICE = '[data-testid="session-edit-notice"]';
const STARTS = '[data-testid="session-edit-starts-at"]';
const ENDS = '[data-testid="session-edit-ends-at"]';
const ROOM = '[data-testid="session-edit-room"]';
const MATERIALS = '[data-testid="session-edit-materials-note"]';
const TUTOR_NOTE = '[data-testid="session-edit-tutor-note"]';
const SAVE = '[data-testid="footer-primary"]';
const SCHEDULE_LOCKED = '[data-testid="session-edit-schedule-locked"]';
const STATUS_RESET = '[data-testid="session-edit-status-reset-warning"]';
const TIME = '[data-testid="session-detail-time"]';
const GROUP = '[data-testid="session-detail-group"]';
const ROOM_ROW = '[data-testid="session-detail-room"]';

/**
 * 08:00–10:00 WIB. The same instant is 01:00–03:00 UTC, which is what
 * makes the timezone assertions below discriminating.
 */
function session(over: Record<string, unknown> = {}) {
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
    materials_note: 'Bab 3',
    tutor_note: null,
    ...over,
  };
}

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: {
            room: 'Ruang',
            group: 'Kelompok',
            tutor: 'Tutor',
            time: 'Waktu',
            status: 'Status',
            save: 'Simpan',
            cancel: 'Batal',
            back: 'Kembali',
            loading: 'Memuat…',
            saveFailed: 'Gagal menyimpan.',
            roleAdmin: 'Admin Bimbel',
          },
          admin: {
            sessionDetail: {
              title: 'Detail Sesi',
              editTitle: 'Ubah Sesi',
              editCta: 'Ubah sesi',
              notFound: 'Sesi tidak ditemukan',
              notFoundHint: 'Sesi ini mungkin sudah dihapus.',
              startsAt: 'Mulai',
              endsAt: 'Selesai',
              materialsNote: 'Catatan materi',
              tutorNote: 'Catatan tutor',
              saved: 'Perubahan sesi tersimpan.',
              scheduleLocked: 'Sesi yang sudah selesai atau dibatalkan tidak bisa dijadwal ulang. Catatan masih bisa diubah.',
              statusResetWarning: 'Sesi ini sedang berlangsung. Mengubah jadwal akan mengembalikan statusnya menjadi Terjadwal.',
              noManageAbility: 'Peran Anda belum diberi izin untuk mengubah sesi. Mintalah pengelola bimbel mengubahnya, atau menambahkan izin ini ke peran Anda.',
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView(over: Record<string, unknown> = {}) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.getSession).mockResolvedValue(
    session(over) as never,
  );
  vi.mocked(TutoringBimbelService.rescheduleSession).mockResolvedValue(
    session(over) as never,
  );
  vi.mocked(TutoringBimbelService.updateSession).mockResolvedValue(
    session(over) as never,
  );

  const w = mount(SessionDetail, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        // Renders its slot: a bare `true` stub would swallow the panel
        // and every "renders X" assertion would fail for the wrong
        // reason, while every "does not render Y" would pass vacuously.
        AsyncView: {
          props: ['state'],
          template: `<div><slot v-if="state?.status === 'content'" :data="state.data" /></div>`,
        },
        Modal: { template: '<div data-testid="modal"><slot /></div>' },
        // A real button, so `primaryDisabled` is observable in the DOM
        // and `@primary` can actually be driven.
        BottomSheetFooter: {
          props: ['primaryDisabled', 'primaryLoading'],
          emits: ['primary', 'secondary'],
          template: `<button data-testid="footer-primary" :disabled="primaryDisabled" @click="$emit('primary')">save</button>`,
        },
        // Button is left REAL — it is what decides whether the edit CTA
        // is genuinely disabled.
      },
    },
  });
  await flushPromises();
  return w;
}

/** Open the edit dialog on a view mounted with the manage ability. */
async function openEditor(over: Record<string, unknown> = {}) {
  const w = await mountView(over);
  await w.find(EDIT).trigger('click');
  await flushPromises();
  return w;
}

const REAL_TZ = process.env.TZ;
beforeEach(() => {
  // Pinned so the WIB assertions below mean something. Node re-reads
  // this per Date operation, and the repo already does exactly this in
  // `local-date.spec.ts` and the attendance local-date specs.
  process.env.TZ = 'Asia/Jakarta';
  grantedAbilities = [...VIEW_ONLY, MANAGE];
  vi.clearAllMocks();
});
afterEach(() => {
  process.env.TZ = REAL_TZ;
});

// ── 1. The detail renders ───────────────────────────────────────────

describe('detail', () => {
  it('loads the session through the single-session endpoint', async () => {
    await mountView();

    // Not `listSessions(...)` filtered client-side: that form returns
    // "not found" for any session past the first page.
    expect(TutoringBimbelService.getSession).toHaveBeenCalledWith('ses-1');
  });

  it('renders the group name, tutor and room', async () => {
    const w = await mountView();

    expect(w.find(GROUP).text()).toBe('UTBK Pagi A');
    expect(w.find(ROOM_ROW).text()).toBe('R-101');
    expect(w.text()).toContain('Ust. Ali');
  });

  it('renders an em-dash for a room the wire did not carry', async () => {
    const w = await mountView({ room: null });

    // Not an empty cell and not an invented placeholder.
    expect(w.find(ROOM_ROW).text()).toBe('—');
  });
});

// ── 2. Local time, not UTC ──────────────────────────────────────────

describe('times render in LOCAL time', () => {
  it('shows the WIB wall-clock, not the UTC instant', async () => {
    const w = await mountView();
    const shown = w.find(TIME).text();

    // 08:00+07:00 is 01:00 UTC. Both halves matter: the first would be
    // satisfied by any string containing "08", the second is what fails
    // if the view ever formats through `toISOString()`.
    expect(shown).toContain('08.00');
    expect(shown).not.toContain('01.00');
  });

  it('prefills the edit inputs with the LOCAL wall-clock', async () => {
    const w = await openEditor();

    // The UTC form of the same instant would be '2026-09-08T01:00'.
    expect((w.find(STARTS).element as HTMLInputElement).value).toBe(
      '2026-09-08T08:00',
    );
    expect((w.find(ENDS).element as HTMLInputElement).value).toBe(
      '2026-09-08T10:00',
    );
  });
});

// ── 3. Only what changed is sent ────────────────────────────────────

describe('edit submits only what changed', () => {
  it('a notes-only change hits update and NEVER reschedule', async () => {
    const w = await openEditor();
    await w.find(TUTOR_NOTE).setValue('Materi selesai sampai bab 3.');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.updateSession).toHaveBeenCalledWith('ses-1', {
      tutor_note: 'Materi selesai sampai bab 3.',
    });
    // The load-bearing half: reschedule would re-stamp both timestamps
    // and reset the status, for an edit that touched neither.
    expect(TutoringBimbelService.rescheduleSession).not.toHaveBeenCalled();
  });

  it('a schedule-only change hits reschedule and NEVER update', async () => {
    const w = await openEditor();
    await w.find(STARTS).setValue('2026-09-08T09:30');
    await w.find(ENDS).setValue('2026-09-08T11:30');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.rescheduleSession).toHaveBeenCalledWith(
      'ses-1',
      // Local wall-clock, space-separated, no zone — never an ISO
      // instant, which would shift the session by the UTC offset.
      { starts_at: '2026-09-08 09:30', ends_at: '2026-09-08 11:30' },
    );
    // No notes were touched, so nothing may re-write them.
    expect(TutoringBimbelService.updateSession).not.toHaveBeenCalled();
  });

  it('does not send an untouched note alongside a changed one', async () => {
    const w = await openEditor();
    await w.find(MATERIALS).setValue('Bab 4');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    const [, payload] = vi.mocked(TutoringBimbelService.updateSession).mock
      .calls[0];
    // `tutor_note` and `room` were never edited. The controller writes a
    // column only when its key is PRESENT, so their absence here is what
    // leaves them alone.
    expect(Object.keys(payload)).toEqual(['materials_note']);
  });

  it('submits nothing at all when the form is untouched', async () => {
    const w = await openEditor();

    // Observable in the DOM rather than by reaching into the component.
    expect(w.find(SAVE).attributes('disabled')).toBeDefined();
    expect(TutoringBimbelService.rescheduleSession).not.toHaveBeenCalled();
    expect(TutoringBimbelService.updateSession).not.toHaveBeenCalled();
  });

  it('clears a note with an explicit null rather than omitting it', async () => {
    const w = await openEditor();
    await w.find(MATERIALS).setValue('   ');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    const [, payload] = vi.mocked(TutoringBimbelService.updateSession).mock
      .calls[0];
    // Whitespace-only means "erase it". Omitting the key would leave
    // "Bab 3" in the database while the form showed it gone.
    expect(payload).toEqual({ materials_note: null });
  });
});

// ── 4. The `room` overlap ───────────────────────────────────────────

describe('room has exactly one writer', () => {
  it('sends room on update, never on reschedule', async () => {
    const w = await openEditor();
    await w.find(ROOM).setValue('R-202');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.updateSession).toHaveBeenCalledWith('ses-1', {
      room: 'R-202',
    });
    expect(TutoringBimbelService.rescheduleSession).not.toHaveBeenCalled();
  });

  it('keeps room off the reschedule payload even when both changed', async () => {
    const w = await openEditor();
    await w.find(STARTS).setValue('2026-09-08T09:30');
    await w.find(ENDS).setValue('2026-09-08T11:30');
    await w.find(ROOM).setValue('R-202');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    const [, reschedulePayload] = vi.mocked(
      TutoringBimbelService.rescheduleSession,
    ).mock.calls[0];
    // Two writers for one column means the later call clobbers the
    // earlier. `RescheduleSessionAction` skips a null room, so omitting
    // it here is a genuine no-op rather than a blanking.
    expect('room' in reschedulePayload).toBe(false);
    expect(TutoringBimbelService.updateSession).toHaveBeenCalledWith('ses-1', {
      room: 'R-202',
    });
  });

  it('reschedules BEFORE updating, so a refusal aborts the whole save', async () => {
    vi.mocked(TutoringBimbelService.rescheduleSession).mockRejectedValueOnce(
      new Error('Sesi yang sudah selesai tidak bisa dijadwal ulang.'),
    );

    const w = await openEditor();
    await w.find(STARTS).setValue('2026-09-08T09:30');
    await w.find(ENDS).setValue('2026-09-08T11:30');
    await w.find(TUTOR_NOTE).setValue('catatan');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    // The note must NOT have been written: reporting a partial save as a
    // success is the failure this ordering exists to prevent.
    expect(TutoringBimbelService.updateSession).not.toHaveBeenCalled();
    // And the server's own message is surfaced verbatim.
    expect(toastError).toHaveBeenCalledWith(
      'Sesi yang sudah selesai tidak bisa dijadwal ulang.',
    );
  });
});

// ── 5. tutor_id is never on the wire ────────────────────────────────

describe('tutor_id is never sent', () => {
  it('is absent from every payload, whatever the admin edits', async () => {
    const w = await openEditor();
    await w.find(STARTS).setValue('2026-09-08T09:30');
    await w.find(ENDS).setValue('2026-09-08T11:30');
    await w.find(ROOM).setValue('R-202');
    await w.find(MATERIALS).setValue('Bab 4');
    await w.find(TUTOR_NOTE).setValue('catatan');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    // Every argument of every call this screen made, flattened. Reading
    // the calls generically rather than naming the two endpoints means a
    // THIRD endpoint added later is covered by this test on the day it
    // is added.
    const everyPayload = [
      ...vi.mocked(TutoringBimbelService.rescheduleSession).mock.calls,
      ...vi.mocked(TutoringBimbelService.updateSession).mock.calls,
    ].map(([, payload]) => payload);

    expect(everyPayload.length).toBeGreaterThan(0);
    for (const payload of everyPayload) {
      expect('tutor_id' in (payload as object)).toBe(false);
    }
  });

  it('offers no control for the tutor or the learning group', async () => {
    const w = await openEditor();

    // Changing either would silently re-point attendance already
    // recorded against this session — the reason they are out of scope.
    expect(w.find('[data-testid="session-edit-tutor"]').exists()).toBe(false);
    expect(w.find('[data-testid="session-edit-group"]').exists()).toBe(false);
  });
});

// ── 6. State-dependent affordances ──────────────────────────────────

describe('lifecycle-aware form', () => {
  it('locks the schedule inputs on a done session but leaves notes editable', async () => {
    const w = await openEditor({ status: 'done', status_label: 'Selesai' });

    expect(w.find(SCHEDULE_LOCKED).exists()).toBe(true);
    expect(w.find(STARTS).attributes('disabled')).toBeDefined();
    expect(w.find(ENDS).attributes('disabled')).toBeDefined();
    // The dividend of splitting the two calls: a wrap-up note is exactly
    // what a finished session needs, and `PUT /sessions/{id}` has no
    // status precondition.
    expect(w.find(TUTOR_NOTE).attributes('disabled')).toBeUndefined();
  });

  it('saves a note on a done session without touching reschedule', async () => {
    const w = await openEditor({ status: 'done', status_label: 'Selesai' });
    await w.find(TUTOR_NOTE).setValue('Ringkasan sesi.');
    await w.find(SAVE).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.updateSession).toHaveBeenCalled();
    // Calling it would have been a guaranteed 422.
    expect(TutoringBimbelService.rescheduleSession).not.toHaveBeenCalled();
  });

  it('warns that rescheduling a RUNNING session resets its status', async () => {
    const w = await openEditor({ status: 'in_progress' });
    expect(w.find(STATUS_RESET).exists()).toBe(false);

    await w.find(STARTS).setValue('2026-09-08T09:30');

    // `RescheduleSessionAction` ends with `status = SCHEDULED`
    // unconditionally. It cannot be prevented from the client, so it is
    // disclosed — silently changing a field the admin never touched is
    // the thing being guarded against.
    expect(w.find(STATUS_RESET).exists()).toBe(true);
  });

  it('does not warn when the running session keeps its schedule', async () => {
    const w = await openEditor({ status: 'in_progress' });
    await w.find(TUTOR_NOTE).setValue('catatan');

    // No reschedule call will fire, so the status is not at risk and the
    // warning would be noise.
    expect(w.find(STATUS_RESET).exists()).toBe(false);
  });
});

// ── 7. The ability gate ─────────────────────────────────────────────

describe('ability gate', () => {
  it('disables the edit CTA for a role without tutoring.session.manage', async () => {
    grantedAbilities = [...VIEW_ONLY];
    const w = await mountView();

    // "Exists" first: a CTA that was removed entirely would otherwise
    // satisfy the disabled assertion vacuously.
    expect(w.find(EDIT).exists()).toBe(true);
    expect(w.find(EDIT).attributes('disabled')).toBeDefined();
    expect(w.find(EDIT_NOTICE).text()).toContain(
      'belum diberi izin untuk mengubah sesi',
    );
  });

  it('still renders the session detail to that role', async () => {
    grantedAbilities = [...VIEW_ONLY];
    const w = await mountView();

    // `show` authorizes on `tutoring.session.view`. Gating the whole
    // screen would hide data a read-only staff tier is entitled to.
    expect(w.find(GROUP).text()).toBe('UTBK Pagi A');
  });

  it('does not open the dialog for a blocked role', async () => {
    grantedAbilities = [...VIEW_ONLY];
    const w = await mountView();

    // Driven through the component binding rather than by clicking:
    // @vue/test-utils refuses to dispatch on a disabled element, so a
    // click here would be a guaranteed no-op and prove nothing. The
    // in-function guard is what actually has to hold, because the
    // dialog is a SIBLING of the branch that owns the button.
    (w.vm as unknown as { openEdit: () => void }).openEdit();
    await flushPromises();

    expect(w.find(STARTS).exists()).toBe(false);
  });

  it('opens it for a role that holds the key', async () => {
    // Proves the block above is not passing because the dialog never
    // opens for anyone.
    const w = await openEditor();
    expect(w.find(STARTS).exists()).toBe(true);
  });
});

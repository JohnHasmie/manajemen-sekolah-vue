/**
 * "Simpan & tandai selesai" must actually mark the session selesai.
 *
 * ── The defect ──
 *
 * The button said "Simpan & tandai selesai" and `onSave` called only
 * `markSessionAttendance`. `MarkAttendanceAction` never writes
 * `$session->status`, and there is no Session observer, so the session
 * stayed `scheduled`. `bimbelSessionDisplayStatus` derives "Terlewat"
 * from `status === 'scheduled'` plus a past `ends_at`, so the sessions
 * list kept reading Terlewat no matter how many times the tutor pressed
 * the button. The separate `POST /sessions/{id}/complete` was never
 * called by this screen.
 *
 * The expectation came from v1: `RecordTutoringAttendanceAction` DID
 * flip SCHEDULED → DONE when attendance was recorded. v2 deliberately
 * dropped that (an auto-close would make "Selesai" mean "the clock
 * passed" rather than "the class happened"), and the label kept the old
 * promise.
 *
 * ── The other half of the fix ──
 *
 * `SessionController::complete` authorizes `tutoring.session.manage`,
 * which `PermissionCatalog::tutorTutoringDefaults()` does NOT grant. So
 * "just call complete" would turn a silently-wrong button into a
 * reliably-403 one. The button therefore closes the session only when
 * the role holds the key, and otherwise degrades its label to plain
 * "Simpan" and explains itself in Indonesian.
 *
 * ── Ordering ──
 *
 * Save first, then complete. A failed complete leaves the marks stored
 * and the session open — recoverable. The reverse would leave a session
 * reading "Selesai" with no attendance behind it, and `done` is the
 * basis for tutor honor. The order is asserted, not assumed.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. `grantedAbilities` starts as the DEFAULT TUTOR SET, not
 *    allow-everything. A mock that grants by default would make the
 *    "does not complete" assertions pass for the wrong reason.
 * 2. Both service calls are recorded WITH THEIR ARGUMENTS into one
 *    shared log, so the session id, the marked rows, and the call ORDER
 *    are all real assertions. A mock that ignored arguments would make
 *    this whole file vacuous.
 * 3. `TutoringAttendanceRoster` is NOT stubbed — the real footer button
 *    is what gets clicked, so the label and the notice are the rendered
 *    ones. A stub would be a second implementation of the thing under
 *    test.
 * 4. Toast copy is asserted against REAL Indonesian strings, and the
 *    last block pins those strings to what `id.json` actually ships.
 *    vue-i18n echoes the KEY back for a missing message, so asserting
 *    `toContain('tutoring2.tutor.attendance.savedNotCompleted')` would
 *    pass forever while proving nothing.
 * 5. The partial-failure test asserts the message mentions the marks
 *    ARE saved. A blanket "gagal" would tell the tutor their work was
 *    lost, which is the failure mode this test exists to prevent.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AttendanceView from './TutorTutoring2AttendanceView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import idMessages from '@/locales/id.json';

const SESSION_ID = 'ses-7f3c';
const MANAGE = 'tutoring.session.manage';

/** Exactly what `tutorTutoringDefaults()` grants on the session side. */
const TUTOR_DEFAULTS = ['tutoring.session.view', 'tutoring.session.mark_attendance'];

let grantedAbilities: string[] = [...TUTOR_DEFAULTS];

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (ability: string) => grantedAbilities.includes(ability),
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listSessionAttendance: vi.fn(),
    markSessionAttendance: vi.fn(),
    completeSession: vi.fn(),
  },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { sessionId: SESSION_ID } }),
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

const toastSuccess = vi.fn();
const toastError = vi.fn();
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: toastSuccess, error: toastError, info: vi.fn() }),
}));

/**
 * One ordered log of every service call, with arguments. This is what
 * makes "save before complete" an assertion rather than a hope.
 */
type Call = { fn: 'mark' | 'complete'; args: unknown[] };
let calls: Call[] = [];

/** Real copy, pinned to `id.json` by the last describe block. */
const SAVED_ONLY = 'Presensi tersimpan (2 siswa)';
const SAVED_AND_COMPLETED = 'Presensi tersimpan (2 siswa) dan sesi ditandai selesai';
const SAVED_NOT_COMPLETED =
  'Presensi tersimpan (2 siswa), tetapi sesi belum bisa ditandai selesai: Sesi dibatalkan tidak bisa ditandai selesai.';
const SAVE_FAILED = 'Gagal menyimpan presensi: Network down';
const NO_MANAGE_ABILITY =
  'Peran Anda belum diberi izin untuk menjadwal ulang atau menutup sesi. Presensi yang Anda simpan tetap tersimpan — mintalah pengelola bimbel menutup sesinya, atau menambahkan izin ini ke peran Anda.';

const SAVE_BUTTON = '[data-testid="roster-save"]';
const NOTICE = '[data-testid="roster-complete-notice"]';

function rosterRows() {
  return [
    {
      enrollment_id: 'enr-1',
      student_id: 'stu-1',
      student_name: 'Nadia Putri',
      student_number: '2026-001',
      status: 'hadir',
      alert: null,
      alert_tone: null,
      notes: undefined,
    },
    {
      enrollment_id: 'enr-2',
      student_id: 'stu-2',
      student_name: 'Bagas Pratama',
      student_number: '2026-002',
      status: 'sakit',
      alert: null,
      alert_tone: null,
      notes: 'demam',
    },
  ];
}

function makeI18n() {
  // The REAL id.json, so a renamed or deleted key fails here rather
  // than silently echoing itself back as the toast text.
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    // `as never` is the repo's established shape for this — see
    // `locale-messages-render.spec.ts`, which mounts the same way.
    messages: { id: idMessages } as never,
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listSessionAttendance).mockResolvedValue({
    items: rosterRows(),
    pagination: undefined,
  } as never);

  const w = mount(AttendanceView, {
    global: {
      plugins: [makeI18n()],
      stubs: { BrandPageHeader: true },
    },
  });
  await flushPromises();
  return w;
}

beforeEach(() => {
  vi.clearAllMocks();
  calls = [];
  grantedAbilities = [...TUTOR_DEFAULTS];

  vi.mocked(TutoringBimbelService.markSessionAttendance).mockImplementation(
    async (...args: unknown[]) => {
      calls.push({ fn: 'mark', args });
      return [] as never;
    },
  );
  vi.mocked(TutoringBimbelService.completeSession).mockImplementation(
    async (...args: unknown[]) => {
      calls.push({ fn: 'complete', args });
      return { id: SESSION_ID, status: 'done' } as never;
    },
  );
});

describe('a tutor holding tutoring.session.manage', () => {
  beforeEach(() => {
    grantedAbilities = [...TUTOR_DEFAULTS, MANAGE];
  });

  it('saves the marks AND closes the session, in that order, for the right session', async () => {
    const w = await mountView();

    const btn = w.get(SAVE_BUTTON);
    expect(btn.text()).toBe('Simpan & tandai selesai');
    await btn.trigger('click');
    await flushPromises();

    // Both happened...
    expect(calls.map((c) => c.fn)).toEqual(['mark', 'complete']);

    // ...against the right session, with the real marked rows.
    expect(calls[0].args[0]).toBe(SESSION_ID);
    expect(calls[0].args[1]).toEqual([
      { enrollment_id: 'enr-1', status: 'hadir', notes: undefined },
      { enrollment_id: 'enr-2', status: 'sakit', notes: 'demam' },
    ]);
    expect(calls[1].args[0]).toBe(SESSION_ID);
  });

  it('only then claims both happened', async () => {
    const w = await mountView();
    await w.get(SAVE_BUTTON).trigger('click');
    await flushPromises();

    expect(toastSuccess).toHaveBeenCalledWith(SAVED_AND_COMPLETED);
    expect(toastError).not.toHaveBeenCalled();
  });

  it('shows no refusal notice, because nothing is refused', async () => {
    const w = await mountView();
    expect(w.find(NOTICE).exists()).toBe(false);
  });

  it('does not double-submit while a save is genuinely in flight', async () => {
    // The mark call is held PENDING on purpose. With an instantly
    // resolving mock the first click would finish before the second
    // arrives, and this would assert nothing about concurrency at all.
    let release!: () => void;
    const pending = new Promise<void>((r) => {
      release = r;
    });
    vi.mocked(TutoringBimbelService.markSessionAttendance).mockImplementation(
      async (...args: unknown[]) => {
        calls.push({ fn: 'mark', args });
        await pending;
        return [] as never;
      },
    );

    const w = await mountView();
    const btn = w.get(SAVE_BUTTON);

    await btn.trigger('click');
    // First save is now parked inside markSessionAttendance.
    expect(calls.filter((c) => c.fn === 'mark')).toHaveLength(1);
    expect(btn.attributes('disabled')).toBeDefined();

    await btn.trigger('click');
    expect(calls.filter((c) => c.fn === 'mark')).toHaveLength(1);

    release();
    await flushPromises();

    expect(calls.filter((c) => c.fn === 'mark')).toHaveLength(1);
    expect(calls.filter((c) => c.fn === 'complete')).toHaveLength(1);
  });
});

describe('the partial-failure path: marks saved, session not closed', () => {
  beforeEach(() => {
    grantedAbilities = [...TUTOR_DEFAULTS, MANAGE];
    vi.mocked(TutoringBimbelService.completeSession).mockImplementation(
      async (...args: unknown[]) => {
        calls.push({ fn: 'complete', args });
        throw new Error('Sesi dibatalkan tidak bisa ditandai selesai.');
      },
    );
  });

  it('tells the tutor the marks ARE saved and the session is NOT closed', async () => {
    const w = await mountView();
    await w.get(SAVE_BUTTON).trigger('click');
    await flushPromises();

    // The save really did run and really did succeed.
    expect(calls.map((c) => c.fn)).toEqual(['mark', 'complete']);

    // A blanket "gagal" here would read as "your marks are gone".
    expect(toastError).toHaveBeenCalledWith(SAVED_NOT_COMPLETED);
    expect(toastError.mock.calls[0][0]).toContain('Presensi tersimpan');
    expect(toastError.mock.calls[0][0]).toContain('belum bisa ditandai selesai');

    // And it must NOT also claim success.
    expect(toastSuccess).not.toHaveBeenCalled();
  });
});

describe('when the save itself fails', () => {
  beforeEach(() => {
    grantedAbilities = [...TUTOR_DEFAULTS, MANAGE];
    vi.mocked(TutoringBimbelService.markSessionAttendance).mockImplementation(
      async (...args: unknown[]) => {
        calls.push({ fn: 'mark', args });
        throw new Error('Network down');
      },
    );
  });

  it('never closes a session whose attendance was not written', async () => {
    const w = await mountView();
    await w.get(SAVE_BUTTON).trigger('click');
    await flushPromises();

    expect(calls.map((c) => c.fn)).toEqual(['mark']);
    expect(TutoringBimbelService.completeSession).not.toHaveBeenCalled();
    expect(toastError).toHaveBeenCalledWith(SAVE_FAILED);
    expect(toastSuccess).not.toHaveBeenCalled();
  });
});

describe('a DEFAULT tutor, who does not hold tutoring.session.manage', () => {
  it('does not post a guaranteed 403 to /complete', async () => {
    const w = await mountView();
    await w.get(SAVE_BUTTON).trigger('click');
    await flushPromises();

    expect(calls.map((c) => c.fn)).toEqual(['mark']);
    expect(TutoringBimbelService.completeSession).not.toHaveBeenCalled();
  });

  it('drops the label back to plain "Simpan" rather than promising a close', async () => {
    const w = await mountView();
    expect(w.get(SAVE_BUTTON).text()).toBe('Simpan');
  });

  it('explains in Indonesian why the session stays open', async () => {
    const w = await mountView();

    const notice = w.get(NOTICE);
    expect(notice.text()).toBe(NO_MANAGE_ABILITY);
    // Wired for screen readers too, not just sighted users.
    expect(w.get(SAVE_BUTTON).attributes('aria-describedby')).toBe('roster-complete-notice');
  });

  it('still claims only what happened: the marks were saved', async () => {
    const w = await mountView();
    await w.get(SAVE_BUTTON).trigger('click');
    await flushPromises();

    expect(toastSuccess).toHaveBeenCalledWith(SAVED_ONLY);
    expect(toastError).not.toHaveBeenCalled();
  });
});

describe('the copy this screen depends on actually ships', () => {
  // vue-i18n echoes the key back for a missing message, so every toast
  // assertion above would pass against a deleted key without this.
  // Read straight off the typed JSON import: a DELETED key then fails
  // to compile under `vue-tsc --build`, which is a louder signal than a
  // runtime `undefined`.
  const att = idMessages.tutoring2.tutor.attendance;
  const detail = idMessages.tutoring2.tutor.sessionDetail;

  it('id.json carries the two new attendance messages', () => {
    expect(att.savedAndCompleted).toBe(
      'Presensi tersimpan ({count} siswa) dan sesi ditandai selesai',
    );
    expect(att.savedNotCompleted).toBe(
      'Presensi tersimpan ({count} siswa), tetapi sesi belum bisa ditandai selesai: {msg}',
    );
  });

  it('reuses the existing refusal copy rather than inventing a second wording', () => {
    expect(detail.noManageAbility).toBe(NO_MANAGE_ABILITY);
  });
});

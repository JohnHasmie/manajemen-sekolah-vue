/**
 * readiness-nav — destination + ACCESS table.
 *
 * The table is half of a cross-platform pair: the other half is
 * `kReadinessTargetAccess` in
 * `lib/features/readiness/presentation/readiness_todo_router.dart`.
 * A divergence between them is invisible at runtime — one platform
 * quietly shows a row the other correctly hides — so the expected
 * values are spelled out literally here rather than derived from the
 * map. Copy any change into the Dart table too.
 */
import { describe, expect, it } from 'vitest';
import {
  READINESS_ROUTE_MAP,
  canReachReadinessTarget,
  readinessQuery,
  resolveReadinessTarget,
  type ReadinessAccess,
} from './readiness-nav';

/** Hint → the ability set that admits its destination. Any-of. */
const EXPECTED_ABILITIES: Record<string, string[]> = {
  admin_teacher_management: ['school.teacher.view', 'school.teacher.manage'],
  admin_class_management: [],
  admin_student_management: ['school.student.view', 'school.student.manage'],
  admin_subject_management: [],
  admin_schedule_management: ['academic.schedule.view'],
  admin_academic_year: ['school.settings.view', 'school.settings.manage'],
  admin_attendance: ['attendance.student.view', 'attendance.student.export'],
  admin_mobile_app_broadcast: ['readiness.view'],
  admin_announcement_drafts: ['communication.announcement.view'],
  admin_overdue_bills: ['finance.bill.view'],
  admin_payment_verification: ['finance.payment.view'],
  admin_report_card_hub: ['academic.report_card.view'],
  admin_rpp_review: ['academic.lesson_plan.view'],
  admin_schedule_conflicts: ['academic.schedule.view'],
  admin_staff_attendance_report: ['attendance.staff.report.view'],
};

const EXPECTED_CONTEXT: Record<string, string | undefined> = {
  admin_class_management: 'student-context',
  admin_student_management: 'student-context',
  admin_subject_management: 'academic-context',
};

/** A user holding everything. */
const superUser: ReadinessAccess = {
  canAny: () => true,
  hasStudentContext: true,
  hasAcademicContext: true,
};

/** A user holding nothing and owning no modules. */
const nobody: ReadinessAccess = {
  canAny: () => false,
  hasStudentContext: false,
  hasAcademicContext: false,
};

/** A user holding exactly `granted`, with both module contexts. */
function userWith(granted: string[]): ReadinessAccess {
  return {
    canAny: (abilities) => {
      for (const a of abilities) if (granted.includes(a)) return true;
      return false;
    },
    hasStudentContext: true,
    hasAcademicContext: true,
  };
}

describe('READINESS_ROUTE_MAP access table', () => {
  it('covers exactly the hints the backend emits — no more, no less', () => {
    expect(Object.keys(READINESS_ROUTE_MAP).sort()).toEqual(
      Object.keys(EXPECTED_ABILITIES).sort(),
    );
  });

  it('declares the expected abilities for every hint', () => {
    for (const [hint, abilities] of Object.entries(EXPECTED_ABILITIES)) {
      expect(
        [...READINESS_ROUTE_MAP[hint].requiredAbilities],
        `${hint} ability gate drifted — update the Dart mirror too`,
      ).toEqual(abilities);
    }
  });

  it('declares the expected module contexts', () => {
    for (const hint of Object.keys(EXPECTED_ABILITIES)) {
      expect(READINESS_ROUTE_MAP[hint].requiredContext, hint).toBe(
        EXPECTED_CONTEXT[hint],
      );
    }
  });

  it('does not gate payment verification on the bills ability', () => {
    // The Pembayaran route carries its own key; a bills-only admin is
    // bounced by the router guard, so the row has to drop for them.
    const billsOnly = userWith(['finance.bill.view']);
    expect(canReachReadinessTarget('admin_overdue_bills', billsOnly)).toBe(true);
    expect(canReachReadinessTarget('admin_payment_verification', billsOnly)).toBe(
      false,
    );
  });
});

describe('canReachReadinessTarget', () => {
  it('admits every destination for a fully-privileged user', () => {
    for (const hint of Object.keys(READINESS_ROUTE_MAP)) {
      expect(canReachReadinessTarget(hint, superUser), hint).toBe(true);
    }
  });

  it('denies every gated destination for a user holding nothing', () => {
    for (const hint of Object.keys(READINESS_ROUTE_MAP)) {
      expect(canReachReadinessTarget(hint, nobody), hint).toBe(false);
    }
  });

  it('honours any-of semantics — either key is enough', () => {
    for (const key of ['school.teacher.view', 'school.teacher.manage']) {
      expect(
        canReachReadinessTarget('admin_teacher_management', userWith([key])),
        key,
      ).toBe(true);
    }
  });

  it('still applies the context gate to an ability-less destination', () => {
    // Kelas/Mapel carry no ability in the nav, so `needs:` is the only
    // thing standing between the user and a dead screen.
    const noModules: ReadinessAccess = {
      canAny: () => true,
      hasStudentContext: false,
      hasAcademicContext: false,
    };
    expect(canReachReadinessTarget('admin_class_management', noModules)).toBe(
      false,
    );
    expect(canReachReadinessTarget('admin_subject_management', noModules)).toBe(
      false,
    );
  });

  it('lets an unmapped hint through so schema drift stays visible', () => {
    // Those callers fall back to the readiness hub, which the viewer
    // already holds readiness.view for. Blanking the lane instead would
    // hide a backend/frontend version skew.
    expect(resolveReadinessTarget('admin_something_new_2027')).toBeNull();
    expect(canReachReadinessTarget('admin_something_new_2027', nobody)).toBe(
      true,
    );
  });
});

describe('destination paths', () => {
  it('points academic-year at the real router path', () => {
    // Was `/admin/settings/academic-years`, which matches no route — the
    // alerts grid pushes by PATH, so the row navigated into a 404.
    expect(READINESS_ROUTE_MAP.admin_academic_year.path).toBe(
      '/admin/settings/manage-academic-years',
    );
  });

  it('gives every hint a non-empty name, path, label and icon', () => {
    for (const [hint, target] of Object.entries(READINESS_ROUTE_MAP)) {
      expect(target.name, hint).toBeTruthy();
      expect(target.path.startsWith('/admin'), hint).toBe(true);
      expect(target.labelKey, hint).toBeTruthy();
      expect(target.icon, hint).toBeTruthy();
    }
  });
});

describe('readinessQuery', () => {
  it('forwards a lane item filter', () => {
    // The reported case: "15 siswa belum masuk kelas" ships
    // {filter: 'no_class'} and the panel dropped it, so PERBAIKI opened
    // the unfiltered roster where the fifteen were invisible among the
    // students who DO have a class.
    expect(readinessQuery({ filter: 'no_class' })).toEqual({ filter: 'no_class' });
  });

  it('stringifies numbers so they survive a URL', () => {
    expect(readinessQuery({ grade: 7 })).toEqual({ grade: '7' });
  });

  it('drops values a destination cannot honour', () => {
    // A query is a promise the receiving screen can keep. Putting an
    // object or an array in the URL would promise a filter that does
    // nothing — which is exactly the failure being fixed, restated.
    expect(
      readinessQuery({ filter: 'no_class', extra: { a: 1 }, list: [1, 2], flag: true }),
    ).toEqual({ filter: 'no_class' });
  });

  it('is empty rather than undefined when there is nothing to carry', () => {
    // router.push({name, query}) must always get an object; an
    // undefined query silently keeps the CURRENT url's query on some
    // navigations, which would leak one item's filter onto the next.
    expect(readinessQuery(undefined)).toEqual({});
    expect(readinessQuery(null)).toEqual({});
    expect(readinessQuery({})).toEqual({});
  });
});

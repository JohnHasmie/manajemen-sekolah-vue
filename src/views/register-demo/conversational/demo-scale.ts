/**
 * How many students a demo school will actually be given.
 *
 * The wizard asks "Rata-rata siswa per kelas?" — per class, not in
 * total. A school owner typed 30 and found 450 students afterwards
 * (2026-08-17): the pattern they picked produces 5 classes per grade,
 * and an SMP has 3 grades, so 30 × 15 = 450. Nothing was wrong; the
 * consequence was simply never shown before they pressed on.
 *
 * These tables mirror `EducationLevelTemplate` in the backend, which is
 * what provisioning actually uses. Mirroring is a real risk — the
 * backend carries a comment about unmapped levels once falling through
 * to JUNIOR_HIGH and handing an SD school grades 7–9 — so the rule here
 * is: when the level is not one we can map with confidence, return
 * null and say NOTHING. A silent wizard is recoverable; a confident
 * wrong number is the very surprise this exists to prevent.
 */

/** Backend `EducationLevelTemplate::ALIAS` — tier aliases. */
const ALIAS: Record<string, string> = {
  MI: 'ELEMENTARY',
  MTs: 'JUNIOR_HIGH',
  MTS: 'JUNIOR_HIGH',
  MA: 'SENIOR_HIGH',
  TK: 'KINDERGARTEN',
  KB: 'KINDERGARTEN',
  RA: 'KINDERGARTEN',
  PAUD: 'KINDERGARTEN',
  SPS: 'KINDERGARTEN',
  SD: 'ELEMENTARY',
  SMP: 'JUNIOR_HIGH',
  SMA: 'SENIOR_HIGH',
  SMK: 'VOCATIONAL_HIGH',
};

/** Backend `EducationLevelTemplate::GRADES` — grade count per tier. */
const GRADE_COUNT: Record<string, number> = {
  KINDERGARTEN: 2,
  ELEMENTARY: 6,
  JUNIOR_HIGH: 3,
  SENIOR_HIGH: 3,
  VOCATIONAL_HIGH: 3,
  Pesantren: 6,
};

/** Backend `classCountMap()` — rombel per grade for each pattern. */
const CLASSES_PER_GRADE: Record<string, number> = {
  small: 1,
  medium: 3,
  large: 5,
};

export interface ScaleProjection {
  /** Classes the provisioner will create. */
  classes: number;
  /** Students it will create — classes × perClass. */
  students: number;
  /** Grades in this tier, so the copy can explain the multiplication. */
  grades: number;
}

/**
 * Project the roster size, or null when we cannot be sure.
 *
 * Null — never a guess — for an unknown tier, an unknown pattern
 * (including 'custom', where the admin picks counts later), or a
 * per-class number outside what the form accepts.
 */
export function projectDemoScale(input: {
  educationLevel?: string | null;
  pattern?: string | null;
  perClass?: number | null;
}): ScaleProjection | null {
  const { educationLevel, pattern, perClass } = input;
  if (!educationLevel || !pattern || !perClass || perClass < 1) return null;

  const tier = ALIAS[educationLevel] ?? educationLevel;
  const grades = GRADE_COUNT[tier];
  const perGrade = CLASSES_PER_GRADE[pattern];
  if (!grades || !perGrade) return null;

  const classes = grades * perGrade;

  return { classes, students: classes * perClass, grades };
}

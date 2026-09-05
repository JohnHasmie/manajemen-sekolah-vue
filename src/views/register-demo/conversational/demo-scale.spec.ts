import { describe, expect, it } from 'vitest';
import { projectDemoScale } from './demo-scale';

describe('projectDemoScale', () => {
  it('reproduces the reported surprise exactly', () => {
    // 2026-08-17: "aku hanya mendaftarkan 30 siswa, tpi yang terdata
    // 450". SMP has 3 grades, `large` is 5 classes per grade, so the
    // wizard was always going to build 15 classes of 30.
    expect(projectDemoScale({ educationLevel: 'JUNIOR_HIGH', pattern: 'large', perClass: 30 }))
      .toEqual({ classes: 15, students: 450, grades: 3 });
  });

  it('follows tier aliases the way provisioning does', () => {
    // MTs is an SMP; MI is an SD. Getting this wrong would show a
    // number the provisioner then contradicts.
    expect(projectDemoScale({ educationLevel: 'MTs', pattern: 'medium', perClass: 20 }))
      .toEqual({ classes: 9, students: 180, grades: 3 });
    expect(projectDemoScale({ educationLevel: 'MI', pattern: 'small', perClass: 25 }))
      .toEqual({ classes: 6, students: 150, grades: 6 });
  });

  it('counts SD as six grades, not three', () => {
    expect(projectDemoScale({ educationLevel: 'ELEMENTARY', pattern: 'large', perClass: 30 }))
      .toEqual({ classes: 30, students: 900, grades: 6 });
  });

  it('says nothing for a tier it cannot map', () => {
    // The load-bearing case. The backend carries a comment about an
    // unmapped level once falling through to JUNIOR_HIGH and handing an
    // SD school grades 7-9. A wrong number here is worse than none,
    // because the whole point is to stop a surprise.
    expect(projectDemoScale({ educationLevel: 'PKBM', pattern: 'large', perClass: 30 })).toBeNull();
  });

  it('says nothing for custom, where the count is decided later', () => {
    expect(projectDemoScale({ educationLevel: 'JUNIOR_HIGH', pattern: 'custom', perClass: 30 })).toBeNull();
  });

  it('says nothing while the answers are still incomplete', () => {
    // The line must not flash a number mid-typing.
    expect(projectDemoScale({ educationLevel: 'JUNIOR_HIGH', pattern: 'large', perClass: 0 })).toBeNull();
    expect(projectDemoScale({ educationLevel: null, pattern: 'large', perClass: 30 })).toBeNull();
    expect(projectDemoScale({ educationLevel: 'JUNIOR_HIGH', pattern: null, perClass: 30 })).toBeNull();
  });
});

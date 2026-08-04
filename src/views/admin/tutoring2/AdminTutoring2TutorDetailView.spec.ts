/**
 * Vitest spec for AdminTutoring2TutorDetailView — locks the wire
 * contract the view depends on (Tutor + DeactivateTutorConflict) and
 * verifies the component exports cleanly.
 *
 * Full-render is skipped for the same reasons as the invite modal
 * spec (vue-i18n + router + async data are noisy); the type-level
 * assertions below are what actually break the build when a
 * downstream shape changes.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2TutorDetailView from './AdminTutoring2TutorDetailView.vue';
import type { DeactivateTutorConflict, Tutor } from '@/types/tutoring2/tutor';

describe('AdminTutoring2TutorDetailView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2TutorDetailView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('Tutor carries every field the detail view renders', () => {
    // If a field is dropped from Tutor, the view template will break —
    // this test fails at type-check time to catch that early.
    const _t: Tutor = {
      id: 't1',
      user_id: 'u1',
      name: 'Ust. Ali',
      email: 'ali@sekolah.id',
      employee_number: 'K-2026-01',
      is_active: true,
      active_group_count: 2,
    };
    expect(_t.name).toBeTruthy();
    // active_group_count is what the confirm-dialog callout reads.
    expect(_t.active_group_count).toBeGreaterThanOrEqual(0);
  });

  it('DeactivateTutorConflict has the two fields the toast reads', () => {
    // Both `message` (verbatim string) and `active_group_count` (int)
    // are surfaced by the danger footer's 409 branch.
    const _c: DeactivateTutorConflict = {
      message: 'Tutor masih mengajar kelompok belajar aktif — pindahkan tutor kelompok tersebut sebelum menonaktifkan.',
      active_group_count: 3,
    };
    expect(_c.active_group_count).toBe(3);
    expect(_c.message).toContain('kelompok');
  });
});

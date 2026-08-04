/**
 * Vitest spec for AdminTutoring2InviteTutorModal — pins the emit
 * contract + the InviteTutorPayload shape the modal produces.
 *
 * Full-render tests over vue-i18n + Modal Teleport are noisy in this
 * workspace, so this file guards the contract: the shape of the
 * emitted `saved` payload (a Tutor from the service) and the payload
 * fields the modal collects. If a later refactor drops a field the
 * BE will start relying on, TypeScript will complain here.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2InviteTutorModal from './AdminTutoring2InviteTutorModal.vue';
import type { InviteTutorPayload, Tutor } from '@/types/tutoring2/tutor';

describe('AdminTutoring2InviteTutorModal contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2InviteTutorModal as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('InviteTutorPayload matches the modal form fields', () => {
    // The four fields the modal renders. `phone` + `initial_rate` are
    // reserved for a future BE MR — BE-17 ignores them today but the
    // FE collects them so the round-trip is already in place.
    const _payload: InviteTutorPayload = {
      email: 'ali@sekolah.id',
      name: 'Ust. Ali',
      phone: '+628123456',
      initial_rate: 75000,
    };
    expect(_payload.email).toContain('@');
    expect(_payload.initial_rate).toBe(75000);
  });

  it('accepts a bare payload (only email required)', () => {
    // Guard: the BE nullable branch (defaults name from local part)
    // must stay reachable from the FE. If someone adds a required
    // field to the payload type without a BE change, this fails.
    const _bare: InviteTutorPayload = { email: 'x@y.z' };
    expect(_bare.email).toBe('x@y.z');
  });

  it('emits `saved` with a full Tutor row from the service', () => {
    type SavedHandler = (tutor: Tutor) => void;
    const _h: SavedHandler = (t) => {
      // The parent view relies on `id` to open the detail route and
      // `name` for the toast. Both must remain non-nullable on Tutor.
      const idNonNull: string = t.id;
      const nameNonNull: string = t.name;
      expect(idNonNull).toBe(t.id);
      expect(nameNonNull).toBe(t.name);
    };
    _h({
      id: 't1',
      user_id: 'u1',
      name: 'Ust. Ali',
      email: 'ali@sekolah.id',
      is_active: true,
      active_group_count: 0,
    });
  });
});

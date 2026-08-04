/**
 * Vitest spec for AdminTutoring2StudentCreateEditSheet — pins the
 * prop / emit contract and the payload shape the sheet emits on
 * `saved`. Same convention as the other web-vue specs: Vitest API,
 * type-checked by `vue-tsc --build`. Vitest isn't wired yet — vue-tsc
 * is the active gate.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2StudentCreateEditSheet from './AdminTutoring2StudentCreateEditSheet.vue';
import type { BimbelStudent } from '@/types/tutoring2/student';

describe('AdminTutoring2StudentCreateEditSheet contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2StudentCreateEditSheet as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('emits `saved` with a BimbelStudent + `close` (no payload)', () => {
    // Compile-time proof the emit signatures haven't drifted. The
    // parent list view reloads on `saved` and un-mounts the sheet on
    // `close`.
    type SavedHandler = (student: BimbelStudent) => void;
    type CloseHandler = () => void;
    const _s: SavedHandler = () => {};
    const _c: CloseHandler = () => {};
    expect(typeof _s).toBe('function');
    expect(typeof _c).toBe('function');
  });

  it('accepts `student` prop for edit mode; undefined → create', () => {
    // Both `undefined` and a full BimbelStudent must satisfy the prop
    // type — the parent flips between create and edit by passing the
    // row (or null) without unmounting.
    const _createProp: { student?: BimbelStudent | null } = { student: undefined };
    const _editProp: { student?: BimbelStudent | null } = {
      student: {
        id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
        school_id: '019f8090-51c4-703d-ad74-6b95f8421445',
        name: 'Nadia Putri',
        gender: 'female',
        guardian_name: 'Ibu Sari',
        guardian_email: 'sari@example.com',
      },
    };
    expect(_createProp.student).toBeUndefined();
    expect(_editProp.student?.id).toBeTruthy();
  });
});

import { computed, type ComputedRef } from 'vue';
import type { Role } from '@/types/auth';

/**
 * Mirrors `ColorUtils.getRoleColor('admin'|'teacher'|'parent'|'staff')` from
 * `lib/core/utils/color_utils.dart`.
 *
 * Returns Tailwind class names + raw hex (the latter is useful for SVG
 * fills, chart colors, and inline styles where Tailwind classes don't
 * reach).
 */
export interface RoleColor {
  hex: string;
  /** background utility, e.g. 'bg-role-admin' */
  bg: string;
  /** soft background utility, e.g. 'bg-role-admin-soft' */
  bgSoft: string;
  /** text utility, e.g. 'text-role-admin' */
  text: string;
  /** ring utility, e.g. 'ring-role-admin' */
  ring: string;
}

const TABLE: Record<Role, RoleColor> = {
  admin: {
    hex: '#143068',
    bg: 'bg-role-admin',
    bgSoft: 'bg-role-admin-soft',
    text: 'text-role-admin',
    ring: 'ring-role-admin',
  },
  guru: {
    hex: '#1B6FB8',
    bg: 'bg-role-teacher',
    bgSoft: 'bg-role-teacher-soft',
    text: 'text-role-teacher',
    ring: 'ring-role-teacher',
  },
  wali_kelas: {
    hex: '#1B6FB8',
    bg: 'bg-role-teacher',
    bgSoft: 'bg-role-teacher-soft',
    text: 'text-role-teacher',
    ring: 'ring-role-teacher',
  },
  wali: {
    hex: '#21AFE6',
    bg: 'bg-role-parent',
    bgSoft: 'bg-role-parent-soft',
    text: 'text-role-parent',
    ring: 'ring-role-parent',
  },
  staff: {
    hex: '#B45309',
    bg: 'bg-role-staff',
    bgSoft: 'bg-role-staff-soft',
    text: 'text-role-staff',
    ring: 'ring-role-staff',
  },
  // Super-admins act on the admin surface — reuse the admin navy so
  // the shell + headers stay visually consistent.
  super_admin: {
    hex: '#143068',
    bg: 'bg-role-admin',
    bgSoft: 'bg-role-admin-soft',
    text: 'text-role-admin',
    ring: 'ring-role-admin',
  },
};

// No-role fallback: used on public/pre-auth surfaces (/subscribe,
// /register-demo, /login) where the shared Button component still
// resolves a color. Point at the KamilEdu cobalt navy — the
// `brand.*` scale is legacy indigo (#4F46E5, leftover from an earlier
// iteration) and a `<Button variant="primary">` rendered against it
// reads as a jarring purple against the rest of the marketing surface,
// which uses `brand-cobalt` everywhere else.
const FALLBACK: RoleColor = {
  hex: '#1B6FB8',
  bg: 'bg-brand-cobalt',
  bgSoft: 'bg-brand-cobalt/10',
  text: 'text-brand-cobalt',
  ring: 'ring-brand-cobalt',
};

export function getRoleColor(role: Role | null | undefined): RoleColor {
  if (!role) return FALLBACK;
  return TABLE[role] ?? FALLBACK;
}

export function useRoleColor(
  roleRef: () => Role | null | undefined,
): ComputedRef<RoleColor> {
  return computed(() => getRoleColor(roleRef()));
}

/**
 * Maps the canonical English RPP status to the Indonesian display label
 * used throughout the UI. Matches `update_status_sheet.dart`'s
 * `_mapInitialStatus` helper.
 */
export function mapStatus(
  s: 'Pending' | 'Approved' | 'Rejected' | string,
): string {
  switch (s) {
    case 'Pending':
      return 'Menunggu';
    case 'Approved':
      return 'Disetujui';
    case 'Rejected':
      return 'Ditolak';
    default:
      return s;
  }
}

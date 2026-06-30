/**
 * Centralised role_type → swatch (icon name + tone colors).
 *
 * Lives next to the RBAC components rather than in `dashboard_modules.ts`
 * because it's RBAC-specific — tweaking the "Bendahara is amber" call
 * stays scoped to this feature.
 */

import type { RbacRoleType } from '@/types/rbac';

export interface RoleSwatch {
  /** Lucide icon name — the consumer renders via <Icon :name=... /> or
   *  the existing inline SVG components. */
  icon: string;
  /** Hex used for the left accent rail. */
  accent: string;
  /** Soft tint for the icon square background (light mode). */
  background: string;
  /** Hex used for the icon stroke/fill inside the soft tile. */
  iconColor: string;
}

const SWATCHES: Record<RbacRoleType, RoleSwatch> = {
  admin: {
    icon: 'shield',
    accent: '#143068',
    background: '#E8EEF7',
    iconColor: '#143068',
  },
  teacher: {
    icon: 'graduation-cap',
    accent: '#1B6FB8',
    background: '#E1EEFA',
    iconColor: '#1B6FB8',
  },
  parent: {
    icon: 'users',
    accent: '#21AFE6',
    background: '#E2F4FD',
    iconColor: '#0E7CB5',
  },
  student: {
    icon: 'user',
    accent: '#16A34A',
    background: '#D1FAE5',
    iconColor: '#15803D',
  },
  staff: {
    icon: 'briefcase',
    accent: '#E89C2A',
    background: '#FBEEDA',
    iconColor: '#A2660D',
  },
};

export function swatchFor(roleType: RbacRoleType | string): RoleSwatch {
  return SWATCHES[roleType as RbacRoleType] ?? SWATCHES.staff;
}

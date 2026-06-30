/**
 * Type definitions for the RBAC (Role-Based Access Control) feature.
 *
 * Mirrors the Flutter `lib/features/rbac/domain/models/*.dart` shapes
 * so the same backend response speaks to both clients. Field names
 * stay snake_case at the wire boundary; we surface them as camelCase
 * here to match the Vue codebase convention.
 *
 * See the Phase A/B backend MRs (!227, !228) and the mobile MR !391
 * for context.
 */

/** Single permission key from the catalog. Server-defined. */
export interface RbacPermission {
  id: number;
  key: string; // e.g. "finance.bill.view"
  label: string; // human label
  module: string; // grouping for the accordion UI
  description?: string | null;
}

/** A role row from `GET /api/schools/{id}/roles`. */
export interface RbacRole {
  id: number;
  school_id: string;
  key: string; // e.g. "bendahara"
  label: string; // e.g. "Bendahara"
  role_type: RbacRoleType;
  is_system: boolean;
  /** Only present when the endpoint eager-loaded permissions. */
  permission_keys?: string[];
  created_at?: string | null;
  updated_at?: string | null;
}

export type RbacRoleType =
  | 'admin'
  | 'teacher'
  | 'student'
  | 'parent'
  | 'staff';

/** A member of a role, as returned by `GET .../roles/{rid}/members`. */
export interface RbacRoleMember {
  user_id: string;
  name: string;
  email: string;
  photo_url?: string | null;
  is_active: boolean;
  joined_at?: string | null;
  /**
   * Every OTHER role the user holds in the same school. Lets the
   * members list render "+ Wali Murid (7B)" badges without an extra
   * round-trip.
   */
  other_roles: RbacRoleMemberOtherRole[];
}

export interface RbacRoleMemberOtherRole {
  id: number;
  key: string;
  label: string;
  role_type: string;
}

/** A search-result row from `GET /api/schools/{id}/members`. */
export interface RbacMemberSummary {
  user_id: string;
  name: string;
  email: string;
  photo_url?: string | null;
  roles: RbacRoleMemberOtherRole[];
  /** True when the picker was called with `exclude_role_id` and this
   *  user already holds that role. UI disables the row. */
  already_in_excluded_role: boolean;
}

export interface RbacMemberPickerPage {
  data: RbacMemberSummary[];
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
}

/** Server payload from `POST .../roles/{rid}/members`. */
export interface RbacAssignResult {
  assigned: string[];
  already_member: string[];
  not_in_school: string[];
  role?: { id: number; key: string; label: string };
}

/**
 * Derived UI-only state — what the "Salin dari role lain" quick action
 * passes to the controller. NOT a wire type.
 */
export type RoleTypeFilter = 'all' | 'system' | 'custom';

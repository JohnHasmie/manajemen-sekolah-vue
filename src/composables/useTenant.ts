/**
 * useTenant — derives the active tenant kind (formal school vs tutoring
 * center) from the auth store.
 *
 * The backend stamps `tenant_type` onto the user payload (switch-school)
 * and each /user/schools row (both since Phase 0). We read it off the
 * persisted user first, then fall back to matching the active schoolId
 * against the schools list, then default to SCHOOL for older payloads.
 *
 * Mirrors the Flutter `TenantContext` + `TenantKind` helpers.
 */
import { computed, type ComputedRef } from 'vue';
import { useAuthStore } from '@/stores/auth';

export type TenantKind = 'SCHOOL' | 'TUTORING_CENTER';

export interface TenantInfo {
  /** Raw kind, defaulting to 'SCHOOL'. */
  kind: ComputedRef<TenantKind>;
  /** True when the active tenant is a tutoring center. */
  isTutoringCenter: ComputedRef<boolean>;
  /**
   * English label: 'School' | 'Tutoring' — canonical English per the
   * 2026-06-26 enum-value cutover. Callers that need the Indonesian
   * display word (Sekolah / Bimbel) should pick the literal at the
   * usage site since the actual wording is context-dependent (e.g.
   * "Bimbel formal" vs "Lembaga bimbel").
   */
  label: ComputedRef<string>;
}

/** Parse a raw tenant_type string, defaulting to SCHOOL. */
export function tenantKindFromRaw(raw: unknown): TenantKind {
  const v = String(raw).toLowerCase();
  if (v === 'tutoring_center' || v === 'tutoring' || v === 'bimbel') {
    return 'TUTORING_CENTER';
  }
  return 'SCHOOL';
}

export function tenantLabel(kind: TenantKind): string {
  return kind === 'TUTORING_CENTER' ? 'Tutoring' : 'School';
}

export function useTenant(): TenantInfo {
  const auth = useAuthStore();

  const kind = computed<TenantKind>(() => {
    // 1. Stamped on the user (switch-school / login response).
    const fromUser = auth.user?.tenant_type;
    if (fromUser) return tenantKindFromRaw(fromUser);

    const matchActive = (
      rows:
        | { id?: string; school_id?: string; tenant_type?: string }[]
        | undefined,
    ) => rows?.find((s) => (s.id ?? s.school_id) === auth.schoolId);

    // 2. The active row in the user's OWN schools list — this is what
    //    fetchSchoolsAndRoles populates (with tenant_type) after login,
    //    even for a single-school admin who never hit switch-school.
    const fromUserSchools = matchActive(auth.user?.schools);
    if (fromUserSchools?.tenant_type) {
      return tenantKindFromRaw(fromUserSchools.tenant_type);
    }

    // 3. The store-level schools list (populated on multi-school login).
    const fromStore = matchActive(auth.schools);
    if (fromStore?.tenant_type) {
      return tenantKindFromRaw(fromStore.tenant_type);
    }

    // 4. Single school in either list (no ambiguity).
    const only =
      (auth.user?.schools?.length === 1 ? auth.user.schools[0] : null) ??
      (auth.schools.length === 1 ? auth.schools[0] : null);
    if (only?.tenant_type) return tenantKindFromRaw(only.tenant_type);

    // 5. Last-resort name heuristic. A user whose localStorage payload
    //    predates the `tenant_type` field (older session, or any user
    //    who hasn't called switchSchool since the field was added)
    //    falls through 1-4 with no signal and silently gets the school
    //    sidebar even when their school is obviously a bimbel. Sniff
    //    the active school's display name for the canonical brand
    //    words. Lossy, but biased the right way (`Yahya Bimbel` →
    //    TUTORING_CENTER) and only fires after every authoritative
    //    source comes up empty.
    const activeFromStore =
      auth.schools.find((s) => s.id === auth.schoolId)?.name;
    const name = (
      auth.user?.school_name ??
      activeFromStore ??
      ''
    ).toLowerCase();
    if (name.includes('bimbel') || name.includes('tutoring')) {
      return 'TUTORING_CENTER';
    }
    return 'SCHOOL';
  });

  const isTutoringCenter = computed(() => kind.value === 'TUTORING_CENTER');
  const label = computed(() => tenantLabel(kind.value));

  return { kind, isTutoringCenter, label };
}

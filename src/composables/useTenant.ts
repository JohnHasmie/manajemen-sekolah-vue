/**
 * useTenant — derives the active tenant kind (formal school vs tutoring
 * center / bimbel) from the auth store.
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
  /** Indonesian label: 'Sekolah' | 'Bimbel'. */
  label: ComputedRef<string>;
}

/** Parse a raw tenant_type string, defaulting to SCHOOL. */
export function tenantKindFromRaw(raw: unknown): TenantKind {
  return String(raw).toUpperCase() === 'TUTORING_CENTER'
    ? 'TUTORING_CENTER'
    : 'SCHOOL';
}

export function tenantLabel(kind: TenantKind): string {
  return kind === 'TUTORING_CENTER' ? 'Bimbel' : 'Sekolah';
}

export function useTenant(): TenantInfo {
  const auth = useAuthStore();

  const kind = computed<TenantKind>(() => {
    const fromUser = auth.user?.tenant_type;
    if (fromUser) return tenantKindFromRaw(fromUser);

    // Fall back to the active school row.
    const active = auth.schools.find(
      (s) => (s.id ?? s.school_id) === auth.schoolId,
    );
    return tenantKindFromRaw(active?.tenant_type);
  });

  const isTutoringCenter = computed(() => kind.value === 'TUTORING_CENTER');
  const label = computed(() => tenantLabel(kind.value));

  return { kind, isTutoringCenter, label };
}

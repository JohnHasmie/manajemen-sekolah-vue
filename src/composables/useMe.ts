/**
 * useMe — ergonomic wrapper over the Me store.
 *
 * Views that only need to gate rendering can import this composable
 * and get `can` / `canAny` directly, instead of pulling the whole
 * store. The returned functions are reactive — they'll re-evaluate
 * on every render because they read the ref inside their bodies.
 *
 * Example:
 *   const { can } = useMe();
 *   <button v-if="can('rbac.role.create')">Tambah Role</button>
 */
import { storeToRefs } from 'pinia';
import { useMeStore } from '@/stores/me';

export function useMe() {
  const store = useMeStore();
  const { snapshot, loading, error, hasSnapshot, isInitialLoading } =
    storeToRefs(store);

  return {
    snapshot,
    loading,
    error,
    hasSnapshot,
    isInitialLoading,
    can: (ability: string) => store.can(ability),
    canAny: (abilities: Iterable<string>) => store.canAny(abilities),
    refresh: () => store.refresh(),
  };
}

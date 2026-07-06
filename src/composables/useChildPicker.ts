/**
 * useChildPicker - shared composable for parent screens that pivot per anak.
 *
 * Loads children on first call, exposes a reactive `activeChild`, and
 * a `setActive` setter. Single-child parents auto-select the only one.
 *
 * Source order:
 *   1. `dashboard.stats.slices` (primary — matches mobile bimbel parent,
 *      where the school-side /student endpoint returns nothing because
 *      bimbel guardian link goes via enrollment, not the legacy
 *      guardian columns)
 *   2. top-level `child_name` synthesis (single-anak parents)
 *   3. `ParentService.listChildren` (last-resort school-side fallback)
 */
import { onMounted, ref } from 'vue';
import { ParentService } from '@/services/parent.service';
import { DashboardService } from '@/services/dashboard.service';
import { useAuthStore } from '@/stores/auth';
import { storage, StorageKeys } from '@/lib/storage';
import type { Child } from '@/types/parent';

const children = ref<Child[]>([]);
// Hydrate the last-viewed child from storage at module init so the
// FIRST paint after a hard refresh already shows the right rapor /
// bill / grade — no flash of "child A" before we swap to "child B".
const activeChildId = ref<string>(
  storage.get<string>(StorageKeys.parentActiveChild) ?? '',
);
const loaded = ref(false);
/**
 * Overdue-billing signal for the sidebar badge (Wave 7). Set from the
 * SAME `getStats('wali')` response `load()` already fetches for the
 * child slices — no extra round-trip. True when any bill amount is
 * outstanding/overdue. The parent stats expose a rupiah TOTAL
 * (`outstanding_bills` / `overdue_total`), not a count, so this is a
 * boolean "has overdue" flag rendered as a red dot, not a number.
 */
const hasOverdueBills = ref(false);

function readOverdue(stats: Record<string, unknown> | null | undefined): boolean {
  if (!stats || typeof stats !== 'object') return false;
  const m = stats as Record<string, unknown>;
  // Prefer a per-child sum across slices (multi-anak parents); fall
  // back to the top-level total (single-anak synthesis). Either field
  // name may be present depending on the backend stats shape.
  const slices = Array.isArray(m.slices) ? (m.slices as Record<string, unknown>[]) : [];
  const sliceOverdue = slices.some((s) => toNum(s.overdue_total) > 0 || toNum(s.outstanding_bills) > 0);
  return sliceOverdue || toNum(m.outstanding_bills) > 0 || toNum(m.overdue_total) > 0;
}

function toNum(v: unknown): number {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return Number.parseFloat(v) || 0;
  return 0;
}

function persistActive(id: string): void {
  if (id) storage.set(StorageKeys.parentActiveChild, id);
  else storage.remove(StorageKeys.parentActiveChild);
}

function fromSlices(slices: unknown): Child[] {
  if (!Array.isArray(slices)) return [];
  return slices
    .map((raw) => {
      if (!raw || typeof raw !== 'object') return null;
      const m = raw as Record<string, unknown>;
      const id = m.student_id ?? m.id;
      const name = m.name ?? m.student_name;
      if (!id || !name) return null;
      return {
        student_id: String(id),
        name: String(name),
        class_name: String(m.class_name ?? m.classLabel ?? m.class_label ?? ''),
        avatar: (m.avatar as string | null | undefined) ?? null,
      } satisfies Child;
    })
    .filter((c): c is Child => c != null);
}

export function useChildPicker() {
  const auth = useAuthStore();

  async function load() {
    if (loaded.value) return;
    loaded.value = true;

    // Primary: dashboard slices (tenant-aware, includes bimbel parent).
    try {
      const stats = await DashboardService.getStats('wali');
      hasOverdueBills.value = readOverdue(stats);
      const fromDash = fromSlices(stats?.slices);
      if (fromDash.length > 0) {
        children.value = fromDash;
      } else if (stats?.child_name) {
        // Single-anak top-level synthesis (matches ParentDashboardView).
        children.value = [
          {
            student_id: String(stats.student_id ?? stats.child_id ?? 'me'),
            name: String(stats.child_name),
            class_name: String(stats.child_class ?? ''),
            avatar: null,
          },
        ];
      }
    } catch { /* non-fatal — fall through to listChildren */ }

    // Last-resort fallback: school-side /student endpoint.
    if (children.value.length === 0) {
      children.value = await ParentService.listChildren({
        user_id: auth.user?.id ?? null,
        guardian_email: auth.user?.email ?? null,
      });
    }

    // Reconcile the hydrated selection with what actually came back
    // from the server. If the stored ID is stale (child removed, or a
    // different parent signed in), fall back to the first available
    // child rather than leaving the picker pointing at nothing.
    const stored = activeChildId.value;
    const stillExists =
      stored && children.value.some((c) => c.student_id === stored);
    if (!stillExists) {
      activeChildId.value = children.value[0]?.student_id ?? '';
      persistActive(activeChildId.value);
    }
  }

  onMounted(load);

  function activeChild() {
    return children.value.find((c) => c.student_id === activeChildId.value) ?? null;
  }

  return {
    children,
    activeChildId,
    hasOverdueBills,
    activeChild,
    setActive(id: string) {
      activeChildId.value = id;
      persistActive(id);
    },
    refresh: async () => {
      loaded.value = false;
      await load();
    },
  };
}

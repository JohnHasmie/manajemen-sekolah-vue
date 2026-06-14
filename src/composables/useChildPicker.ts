/**
 * useChildPicker - shared composable for parent screens that pivot per anak.
 *
 * Loads children on first call, exposes a reactive `activeChild`, and
 * a `setActive` setter. Single-child parents auto-select the only one.
 *
 * Source order:
 *   1. `dashboard.stats.slices` (primary — matches mobile bimbel wali,
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
import type { Child } from '@/types/parent';

const children = ref<Child[]>([]);
const activeChildId = ref<string>('');
const loaded = ref(false);

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

    // Primary: dashboard slices (tenant-aware, includes bimbel wali).
    try {
      const stats = await DashboardService.getStats('wali');
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

    if (!activeChildId.value && children.value[0]) {
      activeChildId.value = children.value[0].student_id;
    }
  }

  onMounted(load);

  function activeChild() {
    return children.value.find((c) => c.student_id === activeChildId.value) ?? null;
  }

  return {
    children,
    activeChildId,
    activeChild,
    setActive(id: string) {
      activeChildId.value = id;
    },
    refresh: async () => {
      loaded.value = false;
      await load();
    },
  };
}

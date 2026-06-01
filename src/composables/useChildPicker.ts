/**
 * useChildPicker - shared composable for parent screens that pivot per anak.
 *
 * Loads children on first call, exposes a reactive `activeChild`, and
 * a `setActive` setter. Single-child parents auto-select the only one.
 */
import { onMounted, ref } from 'vue';
import { ParentService } from '@/services/parent.service';
import { useAuthStore } from '@/stores/auth';
import type { Child } from '@/types/parent';

const children = ref<Child[]>([]);
const activeChildId = ref<string>('');
const loaded = ref(false);

export function useChildPicker() {
  const auth = useAuthStore();

  async function load() {
    if (loaded.value) return;
    loaded.value = true;
    children.value = await ParentService.listChildren({
      user_id: auth.user?.id ?? null,
      guardian_email: auth.user?.email ?? null,
    });
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

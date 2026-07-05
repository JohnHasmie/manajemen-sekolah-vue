<!--
  TeacherSelectionSheet.vue — admin teacher picker.

  Used by the admin Kehadiran FAB when starting a new attendance
  session "as" a specific teacher. Lists all school teachers with
  search. On select, emits the chosen teacher's full row so the host
  can read teacher_id + display name.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { TeacherService } from '@/services/teachers.service';
import type { Teacher } from '@/types/entities';
import Modal from '@/components/ui/Modal.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  title?: string;
  subtitle?: string;
}>();

const emit = defineEmits<{
  close: [];
  select: [Teacher];
}>();

const teachers = ref<Teacher[]>([]);
const search = ref('');
const isLoading = ref(true);

async function load() {
  try {
    const res = await TeacherService.list({ per_page: 200 });
    teachers.value = res.items;
  } catch {
    teachers.value = [];
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return teachers.value;
  return teachers.value.filter(
    (t) =>
      t.name.toLowerCase().includes(q) ||
      (t.employee_number ?? '').toLowerCase().includes(q),
  );
});
</script>

<template>
  <Modal
    :title="title ?? 'Pilih Guru'"
    :subtitle="subtitle ?? 'Pilih guru untuk memulai presensi atas namanya'"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <div class="inline-flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 w-full">
        <NavIcon name="search" :size="13" class="text-slate-400" />
        <input
          v-model="search"
          type="search"
          placeholder="Cari nama guru atau NIP..."
          class="bg-transparent border-0 outline-none flex-1 text-[12px] font-medium text-slate-900 placeholder:text-slate-400"
        />
      </div>

      <div
        v-if="isLoading"
        class="text-center text-[12px] text-slate-500 py-8"
      >
        Memuat guru...
      </div>
      <div
        v-else-if="filtered.length === 0"
        class="text-center text-[12px] text-slate-500 py-8"
      >
        Tidak ada guru yang cocok.
      </div>
      <ul v-else class="max-h-[60vh] overflow-y-auto bg-slate-50 rounded-xl divide-y divide-slate-100">
        <li v-for="t in filtered" :key="t.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 flex items-center gap-3 hover:bg-white transition-colors"
            @click="emit('select', t); emit('close')"
          >
            <InitialsAvatar
              :name="t.name || '?'"
              :size="36"
              color="#143068"
              :border-radius="10"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">{{ t.name }}</p>
              <p class="text-3xs text-slate-500 truncate">
                <template v-if="t.employee_number">NIP {{ t.employee_number }}</template>
                <template v-else>Tanpa NIP</template>
                <span v-if="t.subject_names?.length"> · {{ t.subject_names.join(', ') }}</span>
              </p>
            </div>
            <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
          </button>
        </li>
      </ul>
    </div>
  </Modal>
</template>

<!--
  SleepyStaffCard.vue — staff variant of SleepyTeachersCard. Emits
  `send` with the selected user_ids array (staff rows carry user_id,
  not teacher_id). Otherwise contract-identical.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Rows from AdminStaffIndexPayload.data filtered to status === 'silent'. */
  silentStaff: Array<{
    user_id: string;
    name: string;
    last_active_at: string | null;
  }>;
  sending?: boolean;
}>();

const emit = defineEmits<{
  (e: 'send', userIds: string[]): void;
}>();

const selected = ref<string[]>([]);

watch(
  () => props.silentStaff.map((s) => s.user_id).join('|'),
  () => {
    selected.value = props.silentStaff.map((s) => s.user_id);
  },
  { immediate: true },
);

function toggle(id: string) {
  const idx = selected.value.indexOf(id);
  if (idx >= 0) selected.value.splice(idx, 1);
  else selected.value.push(id);
}

const daysAgo = (dateStr: string | null): string => {
  if (!dateStr) return 'Belum pernah aktif';
  const d = new Date(dateStr);
  const diff = Math.max(0, Math.floor((Date.now() - d.getTime()) / (1000 * 60 * 60 * 24)));
  if (diff === 0) return 'Hari ini';
  if (diff === 1) return '1 hari lalu';
  return `${diff} hari lalu`;
};

const allSelected = computed(() =>
  props.silentStaff.length > 0 && selected.value.length === props.silentStaff.length,
);

function toggleAll() {
  selected.value = allSelected.value
    ? []
    : props.silentStaff.map((s) => s.user_id);
}
</script>

<template>
  <div
    v-if="silentStaff.length === 0"
    class="rounded-2xl bg-emerald-50 border border-emerald-200 p-4"
  >
    <header class="flex items-start gap-3">
      <div class="w-10 h-10 rounded-xl bg-emerald-500/20 text-emerald-700 grid place-items-center flex-shrink-0">
        <NavIcon name="check-circle" :size="20" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-3xs font-bold text-emerald-700 uppercase tracking-widest">Semua aktif</p>
        <p class="text-sm font-black text-emerald-900 leading-tight mt-1">
          Semua staf aktif minggu ini
        </p>
        <p class="text-2xs text-emerald-800 mt-1">
          Tidak ada staf yang perlu disapa lewat pengingat saat ini.
        </p>
      </div>
    </header>
  </div>

  <div v-else class="rounded-2xl bg-amber-50 border border-amber-200 p-4">
    <header class="flex items-start gap-3 mb-3">
      <div class="w-10 h-10 rounded-xl bg-amber-500/20 text-amber-700 grid place-items-center flex-shrink-0">
        <NavIcon name="bell" :size="20" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-3xs font-bold text-amber-700 uppercase tracking-widest">Perlu sapaan</p>
        <p class="text-sm font-black text-amber-900 leading-tight mt-1">
          {{ silentStaff.length }} staf belum aktif 7+ hari
        </p>
        <p class="text-2xs text-amber-800 mt-1">
          Kirim pengingat lembut lewat bell agar mereka kembali membuka aplikasi.
        </p>
      </div>
    </header>

    <div class="space-y-2">
      <label class="flex items-center gap-2 text-2xs font-bold text-amber-900 cursor-pointer">
        <input
          type="checkbox"
          class="rounded border-amber-300 text-amber-600 focus:ring-amber-500"
          :checked="allSelected"
          @change="toggleAll"
        />
        Pilih semua
      </label>
      <div class="max-h-56 overflow-y-auto space-y-1">
        <label
          v-for="s in silentStaff"
          :key="s.user_id"
          class="flex items-center gap-2 bg-white/70 rounded-lg px-2 py-1.5 cursor-pointer"
        >
          <input
            type="checkbox"
            class="rounded border-amber-300 text-amber-600 focus:ring-amber-500"
            :checked="selected.includes(s.user_id)"
            @change="toggle(s.user_id)"
          />
          <div class="min-w-0 flex-1">
            <p class="text-2xs font-bold text-slate-800 truncate">{{ s.name }}</p>
            <p class="text-3xs text-slate-500">{{ daysAgo(s.last_active_at) }}</p>
          </div>
        </label>
      </div>
      <button
        type="button"
        class="w-full mt-3 rounded-xl bg-amber-600 hover:bg-amber-700 disabled:bg-amber-300 text-white text-xs font-bold py-2 transition"
        :disabled="sending || selected.length === 0"
        @click="emit('send', [...selected])"
      >
        {{ sending ? 'Mengirim…' : `Kirim pengingat ke ${selected.length} staf` }}
      </button>
    </div>
  </div>
</template>

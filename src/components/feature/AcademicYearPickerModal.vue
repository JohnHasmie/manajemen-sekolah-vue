<!--
  AcademicYearPickerModal.vue — list picker for switching the active
  academic year. Web port of Flutter's
  `academic_year_picker_sheet.dart`.

  Selected year renders as an "expanded" role-tinted card with the
  full label + Ganjil/Genap semester chips (checkmark on active).
  Other years render as compact rows tagged "Sebelumnya" /
  "Selanjutnya" so the user understands their place in the timeline.

  On pick:
    1. Store.setSelected(id) is called → reactivity propagates everywhere
    2. The parent's watcher on selectedYearId triggers their reload
    3. Modal closes
-->
<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useAcademicYearStore } from '@/stores/academic-year';
import type { AcademicYear } from '@/types/academic-year';
import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    /** Role for tinting the expanded card. */
    role?: 'admin' | 'guru' | 'wali' | 'staff';
  }>(),
  { role: 'admin' },
);

const emit = defineEmits<{ close: [] }>();

const store = useAcademicYearStore();

onMounted(() => {
  if (store.years.length === 0) store.fetchAll();
});

const sortedYears = computed<AcademicYear[]>(() =>
  [...store.years].sort((a, b) => a.year.localeCompare(b.year)),
);

const selectedIndex = computed(() =>
  sortedYears.value.findIndex((y) => y.id === store.selectedYearId),
);

const roleColorClass = computed(() => {
  switch (props.role) {
    case 'guru':
      return {
        bg: 'bg-brand-cobalt/8',
        border: 'border-brand-cobalt/35',
        text: 'text-brand-cobalt',
        chipActiveBg: 'bg-brand-cobalt',
        chipActiveText: 'text-white',
      };
    case 'wali':
      return {
        bg: 'bg-sky-50',
        border: 'border-sky-300',
        text: 'text-sky-700',
        chipActiveBg: 'bg-sky-600',
        chipActiveText: 'text-white',
      };
    case 'staff':
      return {
        bg: 'bg-amber-50',
        border: 'border-amber-300',
        text: 'text-amber-700',
        chipActiveBg: 'bg-amber-600',
        chipActiveText: 'text-white',
      };
    case 'admin':
    default:
      return {
        bg: 'bg-slate-50',
        border: 'border-slate-300',
        text: 'text-slate-900',
        chipActiveBg: 'bg-slate-900',
        chipActiveText: 'text-white',
      };
  }
});

function onPick(year: AcademicYear) {
  store.setSelected(year.id);
  emit('close');
}

function isNext(i: number) {
  return selectedIndex.value !== -1 && i > selectedIndex.value;
}
</script>

<template>
  <Modal
    title="Pilih Tahun Ajaran"
    subtitle="Tahun ajaran aktif memengaruhi data di semua halaman."
    @close="$emit('close')"
  >
    <div v-if="store.isLoading && sortedYears.length === 0" class="py-8 text-center text-sm text-slate-400">
      Memuat daftar tahun ajaran…
    </div>

    <div
      v-else-if="sortedYears.length === 0"
      class="py-8 text-center text-sm text-slate-500"
    >
      Belum ada data tahun ajaran.
    </div>

    <ul v-else class="space-y-2 max-h-[60vh] overflow-y-auto pr-1">
      <li v-for="(y, i) in sortedYears" :key="y.id">
        <!-- Selected year — expanded role-tinted card -->
        <div
          v-if="y.id === store.selectedYearId"
          class="rounded-2xl p-4 border"
          :class="[roleColorClass.bg, roleColorClass.border]"
        >
          <div class="flex items-center justify-between">
            <div>
              <p
                class="text-[9.5px] font-bold uppercase tracking-widest mb-1"
                :class="roleColorClass.text"
              >
                Aktif sekarang
              </p>
              <p class="text-lg font-black" :class="roleColorClass.text">
                {{ y.year }}
              </p>
            </div>
            <span
              v-if="y.current"
              class="text-3xs font-bold px-2 py-1 rounded-full bg-emerald-100 text-emerald-700 inline-flex items-center gap-1"
            >
              <NavIcon name="check-circle" :size="11" />
              Current
            </span>
            <span
              v-else-if="y.status === 'archived'"
              class="text-3xs font-bold px-2 py-1 rounded-full bg-slate-200 text-slate-600"
            >
              Arsip
            </span>
            <span
              v-else-if="y.status === 'inactive'"
              class="text-3xs font-bold px-2 py-1 rounded-full bg-amber-100 text-amber-700"
            >
              Read-only
            </span>
          </div>

          <!-- Semester chips -->
          <div class="flex items-center gap-2 mt-3">
            <span
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-2xs font-bold border transition-colors"
              :class="
                y.semester === 'ganjil'
                  ? `${roleColorClass.chipActiveBg} ${roleColorClass.chipActiveText} border-transparent`
                  : 'bg-white text-slate-500 border-slate-200'
              "
            >
              <NavIcon
                v-if="y.semester === 'ganjil'"
                name="check"
                :size="11"
              />
              Sem. Ganjil
            </span>
            <span
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-2xs font-bold border transition-colors"
              :class="
                y.semester === 'genap'
                  ? `${roleColorClass.chipActiveBg} ${roleColorClass.chipActiveText} border-transparent`
                  : 'bg-white text-slate-500 border-slate-200'
              "
            >
              <NavIcon
                v-if="y.semester === 'genap'"
                name="check"
                :size="11"
              />
              Sem. Genap
            </span>
          </div>
        </div>

        <!-- Other years — collapsed -->
        <button
          v-else
          type="button"
          class="w-full text-left rounded-xl border border-slate-200 bg-white p-3 hover:border-slate-300 hover:bg-slate-50 flex items-center gap-3 transition-colors"
          @click="onPick(y)"
        >
          <span
            class="w-9 h-9 rounded-lg bg-slate-100 text-slate-500 grid place-items-center flex-shrink-0"
          >
            <NavIcon name="calendar" :size="14" />
          </span>
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ y.year }}
            </p>
            <p class="text-[10.5px] text-slate-500">
              {{ isNext(i) ? 'Selanjutnya' : 'Sebelumnya' }}
              <span v-if="y.semester"> · Sem. {{ y.semester === 'ganjil' ? 'Ganjil' : 'Genap' }}</span>
              <span v-if="y.status === 'archived'"> · arsip</span>
            </p>
          </div>
          <NavIcon
            name="chevron-right"
            :size="14"
            class="text-slate-300 flex-shrink-0"
          />
        </button>
      </li>
    </ul>

    <footer class="mt-4 pt-3 border-t border-slate-100 flex items-center gap-2">
      <p class="text-[10.5px] text-slate-400 flex-1">
        Menambah tahun ajaran baru hanya bisa dilakukan admin di
        <em>Kelola Tahun Ajaran</em>.
      </p>
      <button
        type="button"
        class="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-[12px] font-bold"
        @click="$emit('close')"
      >
        Tutup
      </button>
    </footer>
  </Modal>
</template>

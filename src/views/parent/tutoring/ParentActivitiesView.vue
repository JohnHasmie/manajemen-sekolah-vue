<!--
  ParentActivitiesView — wali kegiatan/tugas list. Mockup parent_web_pages_browse
  frame 3: hero + type filter + table.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringActivitySubmission } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const submissions = ref<TutoringActivitySubmission[]>([]);
const typeFilter = ref<'all' | 'HOMEWORK' | 'QUIZ' | 'EXAM' | 'PROJECT'>('all');
const query = ref('');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try {
    submissions.value = await TutoringService.getStudentActivitySubmissions(sid);
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

const filtered = computed(() => {
  let list = submissions.value;
  if (typeFilter.value !== 'all') {
    list = list.filter((s) => {
      const t = (s as TutoringActivitySubmission & { activity_type?: string }).activity_type;
      return (t ?? '').toUpperCase() === typeFilter.value;
    });
  }
  const q = query.value.trim().toLowerCase();
  if (q) {
    list = list.filter((s) => {
      const title = (s as TutoringActivitySubmission & { activity_title?: string }).activity_title;
      return (title ?? '').toLowerCase().includes(q);
    });
  }
  return list;
});

function statusChip(s: TutoringActivitySubmission) {
  if (s.status === 'GRADED') return { cls: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300', label: 'Selesai' };
  if (s.status === 'SUBMITTED') return { cls: 'bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]', label: 'Dikumpul' };
  if (s.status === 'LATE') return { cls: 'bg-rose-500/15 text-rose-700 dark:text-rose-300', label: 'Telat' };
  if (s.status === 'MISSED') return { cls: 'bg-rose-500/15 text-rose-700 dark:text-rose-300', label: 'Lewat' };
  return { cls: 'bg-amber-500/15 text-amber-800 dark:text-amber-300', label: 'Belum' };
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · KEGIATAN"
      title="PR, Quiz & Try-out"
      :subtitle="`${activeChild()?.name ?? 'Anak'} · ${submissions.length} kegiatan`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[180px] flex-1">
        <NavIcon name="search" :size="13" class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-bimbel-text-lo" />
        <input
          v-model="query"
          type="text"
          placeholder="Cari tugas…"
          class="w-full rounded-lg border border-bimbel-border bg-bimbel-bg pl-8 pr-3 py-1.5 text-[12px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-[#21afe6] focus:outline-none"
        />
      </div>
      <div class="flex flex-wrap gap-1">
        <button
          v-for="opt in [
            { id: 'all', label: 'Semua' },
            { id: 'HOMEWORK', label: 'PR' },
            { id: 'QUIZ', label: 'Quiz' },
            { id: 'EXAM', label: 'Try-out' },
            { id: 'PROJECT', label: 'Proyek' },
          ] as const"
          :key="opt.id"
          type="button"
          class="rounded-full border px-3 py-1.5 text-[12px] font-semibold"
          :class="
            typeFilter === opt.id
              ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
              : 'border-bimbel-border text-bimbel-text-mid'
          "
          @click="typeFilter = opt.id"
        >{{ opt.label }}</button>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="filtered.length" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel overflow-hidden">
      <table class="w-full text-[12px]">
        <thead class="bg-bimbel-bg/40">
          <tr class="text-left text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">
            <th class="px-3 py-2">Tugas</th>
            <th class="px-3 py-2 w-[100px]">Jenis</th>
            <th class="px-3 py-2 w-[140px]">Kelas</th>
            <th class="px-3 py-2 w-[140px]">Dikumpul</th>
            <th class="px-3 py-2 w-[80px]">Nilai</th>
            <th class="px-3 py-2 w-[100px]">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="s in filtered"
            :key="s.id"
            class="border-t border-bimbel-border-soft hover:bg-bimbel-border-soft/30"
          >
            <td class="px-3 py-2.5">
              <p class="font-bold text-bimbel-text-hi">{{ (s as any).activity_title ?? 'Tugas' }}</p>
              <p v-if="s.note" class="text-[12px] text-bimbel-text-mid line-clamp-1">{{ s.note }}</p>
            </td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">{{ (s as any).activity_type ?? '—' }}</td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">{{ (s as any).group_name ?? '—' }}</td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">
              {{
                s.submitted_at
                  ? new Date(s.submitted_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })
                  : '—'
              }}
            </td>
            <td class="px-3 py-2.5 font-bold" :class="s.score != null ? 'text-emerald-700 dark:text-emerald-300' : 'text-bimbel-text-mid'">
              {{ s.score ?? '—' }}
            </td>
            <td class="px-3 py-2.5">
              <span class="inline-flex rounded-full px-2 py-0.5 text-[12px] font-bold" :class="statusChip(s).cls">{{ statusChip(s).label }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Belum ada kegiatan.
    </div>
  </div>
</template>

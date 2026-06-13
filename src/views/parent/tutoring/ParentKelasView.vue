<!--
  ParentKelasView — wali Kelas list. Mirrors the mockup at
  parent_web_pages_main frame 2 (responsive grid of gradient cards
  with search + status filter). Backed by getWaliClassMeta(studentId).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringWaliClassMeta } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import ParentClassCard from '@/components/feature/tutoring/ParentClassCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const classes = ref<TutoringWaliClassMeta[]>([]);
const query = ref('');
const status = ref<'all' | 'active' | 'completed'>('all');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try {
    classes.value = await TutoringService.getWaliClassMeta(sid);
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

const filtered = computed(() => {
  let list = classes.value;
  if (status.value === 'active') {
    list = list.filter((c) => /active|aktif|open/i.test(c.status));
  } else if (status.value === 'completed') {
    list = list.filter((c) => /completed|selesai|closed/i.test(c.status));
  }
  const q = query.value.trim().toLowerCase();
  if (q) list = list.filter((c) => c.group_name.toLowerCase().includes(q));
  return list;
});

function goToClass(c: TutoringWaliClassMeta) {
  router.push({
    name: 'parent.tutoring.kelas-detail',
    params: { studentId: studentId.value, groupId: c.group_id },
  });
}

function classFooter(c: TutoringWaliClassMeta): string {
  const parts: string[] = [];
  if (c.next_session?.scheduled_at) {
    const d = new Date(c.next_session.scheduled_at);
    if (!Number.isNaN(d.valueOf())) {
      parts.push(
        d.toLocaleString('id-ID', { weekday: 'short', hour: '2-digit', minute: '2-digit' }),
      );
    }
  }
  if (c.attendance.rate != null) {
    parts.push(`hadir ${c.attendance.rate}%`);
  }
  return parts.join(' · ') || 'belum ada sesi';
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · KELAS"
      title="Kelas anak"
      :subtitle="`${activeChild()?.name ?? 'Anak'} · ${classes.length} kelas aktif`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div class="flex flex-wrap items-center gap-2">
      <div class="relative min-w-0 flex-1">
        <NavIcon
          name="search"
          :size="14"
          class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-bimbel-text-lo"
        />
        <input
          v-model="query"
          type="text"
          placeholder="Cari kelas…"
          class="w-full rounded-xl border border-bimbel-border bg-bimbel-panel pl-9 pr-3 py-2 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-[#21afe6] focus:outline-none"
        />
      </div>
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'all', label: 'Semua' },
            { id: 'active', label: 'Aktif' },
            { id: 'completed', label: 'Selesai' },
          ] as const"
          :key="opt.id"
          type="button"
          class="rounded-full border px-3 py-1.5 text-[12px] font-semibold transition"
          :class="
            status === opt.id
              ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
              : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid hover:text-bimbel-text-hi'
          "
          @click="status = opt.id"
        >
          {{ opt.label }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div
      v-else-if="filtered.length"
      class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3"
    >
      <ParentClassCard
        v-for="c in filtered"
        :key="c.group_id"
        :identity-key="c.group_id"
        :name="c.group_name"
        :subject="c.program_name"
        :tutor-name="c.tutor_name ? `Tutor: ${c.tutor_name}` : undefined"
        :footer="classFooter(c)"
        :new-count="c.new_announcements_count_7d"
        @click="goToClass(c)"
      />
    </div>

    <div
      v-else
      class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
    >
      <template v-if="query">Tidak ada kelas yang cocok dengan "{{ query }}".</template>
      <template v-else>Belum ada kelas — daftarkan anak ke program dulu.</template>
    </div>
  </div>
</template>

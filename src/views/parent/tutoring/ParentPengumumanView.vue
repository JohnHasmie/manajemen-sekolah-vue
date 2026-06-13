<!--
  ParentPengumumanView — wali Pengumuman list. Mockup parent_web_pages_extra
  frame 4: hero + Semua/Tutor/Admin pills + announcement cards.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringGroupAnnouncement } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import ParentAnnouncementCard from '@/components/feature/tutoring/ParentAnnouncementCard.vue';

const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const announcements = ref<TutoringGroupAnnouncement[]>([]);
const filter = ref<'all' | 'tutor' | 'admin'>('all');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try {
    announcements.value = await TutoringService.getGroupAnnouncements({ student_id: sid });
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

function sourceKind(a: TutoringGroupAnnouncement): 'tutor' | 'admin' {
  const name = (a.author_name ?? '').toLowerCase();
  if (name.includes('admin') || name.includes('bimbel')) return 'admin';
  return 'tutor';
}

const filtered = computed(() => {
  if (filter.value === 'all') return announcements.value;
  return announcements.value.filter((a) => sourceKind(a) === filter.value);
});

const tutorCount = computed(() => announcements.value.filter((a) => sourceKind(a) === 'tutor').length);
const adminCount = computed(() => announcements.value.filter((a) => sourceKind(a) === 'admin').length);
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · PENGUMUMAN"
      title="Pengumuman"
      :subtitle="`Dari tutor & admin · ${announcements.length} pesan`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div class="flex flex-wrap gap-1.5">
      <button
        v-for="opt in [
          { id: 'all' as const, label: `Semua (${announcements.length})` },
          { id: 'tutor' as const, label: `Tutor (${tutorCount})` },
          { id: 'admin' as const, label: `Admin (${adminCount})` },
        ]"
        :key="opt.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[11.5px] font-semibold"
        :class="
          filter === opt.id
            ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
            : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'
        "
        @click="filter = opt.id"
      >{{ opt.label }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="filtered.length" class="space-y-3">
      <ParentAnnouncementCard
        v-for="a in filtered"
        :key="a.id"
        :title="a.title"
        :body="a.body"
        :source-name="a.author_name ?? 'Bimbel'"
        :source-kind="sourceKind(a)"
        :context="a.group_name"
        :occurred-at="a.created_at"
      />
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Belum ada pengumuman.
    </div>
  </div>
</template>

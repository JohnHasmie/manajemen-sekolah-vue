<!--
  ParentAnnouncementsView — wali pengumuman list. Redesign: hero +
  group filter chips ("Semua kelompok" + per-group) + announcement
  cards (NEW pill for <48h, rel-time otherwise).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringGroupAnnouncement } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';

const route = useRoute();
const { activeChildId } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const announcements = ref<TutoringGroupAnnouncement[]>([]);
const groupFilter = ref<string>('all');

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

const groupChips = computed(() => {
  const seen = new Set<string>();
  const out: { id: string; label: string }[] = [{ id: 'all', label: 'Semua kelompok' }];
  for (const a of announcements.value) {
    const id = a.tutoring_group_id;
    if (id && !seen.has(id)) {
      seen.add(id);
      out.push({ id, label: a.group_name ?? id });
    }
  }
  return out;
});

function isNew(a: TutoringGroupAnnouncement): boolean {
  if (!a.created_at) return false;
  return Date.now() - new Date(a.created_at).valueOf() < 48 * 3_600_000;
}

const newCount = computed(() => announcements.value.filter(isNew).length);

const visible = computed(() => {
  if (groupFilter.value === 'all') return announcements.value;
  return announcements.value.filter((a) => a.tutoring_group_id === groupFilter.value);
});

function relTime(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diffMin = (Date.now() - d.valueOf()) / 60_000;
  if (diffMin < 60) return `${Math.max(1, Math.floor(diffMin))} menit lalu`;
  const h = Math.floor(diffMin / 60);
  if (h < 24) return `${h} jam lalu`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days} hari lalu`;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

function snippet(body?: string | null, n = 150): string {
  if (!body) return '';
  const trimmed = body.trim();
  return trimmed.length > n ? `${trimmed.slice(0, n).trimEnd()}…` : trimmed;
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · PENGUMUMAN"
      title="Pengumuman semua kelompok"
      :subtitle="`${newCount} baru · ${announcements.length} total · semua anak`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <!-- Group filter chips -->
    <div class="flex gap-1.5 flex-wrap">
      <button
        v-for="g in groupChips"
        :key="g.id"
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] transition-colors"
        :class="
          groupFilter === g.id
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid'
        "
        @click="groupFilter = g.id"
      >{{ g.label }}</button>
    </div>

    <div class="space-y-2">
      <div
        v-for="a in visible"
        :key="a.id"
        class="rounded-lg bg-bimbel-bg p-2.5"
        :class="isNew(a) ? 'border-l-2 border-bimbel-hero pl-3' : ''"
      >
        <div class="flex justify-between items-start gap-2">
          <div class="min-w-0 flex-1">
            <p class="text-[10px] text-bimbel-text-lo tracking-wider font-bold uppercase">
              {{ a.author_name }} · {{ a.group_name }}
            </p>
            <p class="text-[13px] font-bold text-bimbel-text-hi mt-0.5">{{ a.title }}</p>
          </div>
          <span
            v-if="isNew(a)"
            class="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide bg-red-900 text-white flex-shrink-0"
          >BARU</span>
          <span
            v-else
            class="text-[11px] text-bimbel-text-lo flex-shrink-0"
          >{{ relTime(a.created_at) }}</span>
        </div>
        <p class="text-[11px] text-bimbel-text-mid leading-relaxed mt-1">{{ snippet(a.body) }}</p>
      </div>
      <p v-if="!visible.length && !loading" class="text-center text-[12px] text-bimbel-text-mid py-6">
        Belum ada pengumuman di kelompok ini.
      </p>
      <p v-if="loading" class="text-center text-[12px] text-bimbel-text-mid py-6">Memuat…</p>
    </div>
  </div>
</template>

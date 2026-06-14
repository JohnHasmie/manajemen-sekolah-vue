<!--
  ParentAnnouncementsView — wali Pengumuman list. Mockup parent_web_pages_extra
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

const route = useRoute();
const { activeChildId } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const announcements = ref<TutoringGroupAnnouncement[]>([]);
const groupFilter = ref<string>('');

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

// ── Redesigned template helpers ──────────────────────────────────
const groups = computed(() => {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const a of announcements.value) {
    const g = a.group_name;
    if (g && !seen.has(g)) { seen.add(g); out.push(g); }
  }
  return out;
});

function isNew(a: TutoringGroupAnnouncement): boolean {
  if (!a.created_at) return false;
  const ageMs = Date.now() - new Date(a.created_at).valueOf();
  return ageMs < 48 * 3_600_000; // < 48h
}

const newCount = computed(() => announcements.value.filter(isNew).length);

const visible = computed(() => {
  if (!groupFilter.value) return announcements.value;
  return announcements.value.filter((a) => a.group_name === groupFilter.value);
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

function snippet(body?: string | null, max = 150): string {
  if (!body) return '';
  const trimmed = body.trim();
  return trimmed.length > max ? `${trimmed.slice(0, max).trimEnd()}…` : trimmed;
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
    <div class="flex gap-1.5 mb-2.5 flex-wrap">
      <button
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] transition-colors"
        :class="
          groupFilter === ''
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="groupFilter = ''"
      >Semua kelompok</button>
      <button
        v-for="g in groups"
        :key="g"
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] transition-colors"
        :class="
          groupFilter === g
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="groupFilter = g"
      >{{ g }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-[12px] text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="visible.length">
      <article
        v-for="a in visible"
        :key="a.id"
        class="rounded-lg bg-bimbel-bg p-2.5 mb-2"
        :class="isNew(a) ? 'border-l-2 border-bimbel-hero pl-3' : ''"
      >
        <div class="flex justify-between items-start gap-2">
          <div class="min-w-0 flex-1">
            <p class="text-[10px] text-bimbel-text-lo tracking-wider font-bold uppercase truncate">
              {{ (a.author_name ?? 'TUTOR').toUpperCase() }}<template v-if="a.group_name"> · {{ a.group_name.toUpperCase() }}</template>
            </p>
            <h3 class="text-[13px] font-bold text-bimbel-text-hi mt-0.5 mb-1">{{ a.title }}</h3>
          </div>
          <span
            v-if="isNew(a)"
            class="flex-shrink-0 rounded-full bg-red-900 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white"
          >Baru</span>
          <span
            v-else
            class="flex-shrink-0 text-[11px] text-bimbel-text-lo whitespace-nowrap"
          >{{ relTime(a.created_at) }}</span>
        </div>
        <p class="text-[11px] text-bimbel-text-mid leading-relaxed">{{ snippet(a.body) }}</p>
      </article>
    </div>

    <div
      v-else
      class="rounded-lg border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-[12px] text-bimbel-text-mid"
    >Belum ada pengumuman.</div>
  </div>
</template>

<!--
  ParentSesiView — wali Jadwal sesi list. Mockup parent_web_pages_browse
  frame 1: hero + range pill + table of sessions.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringSession } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const sessions = ref<TutoringSession[]>([]);
const range = ref<'all' | 'today' | 'upcoming' | 'past'>('upcoming');
const query = ref('');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  const now = new Date();
  const from = new Date(now.getTime() - 30 * 86_400_000);
  const to = new Date(now.getTime() + 60 * 86_400_000);
  try {
    sessions.value = await TutoringService.getSchedule(sid, from, to);
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

const filtered = computed(() => {
  const now = Date.now();
  let list = [...sessions.value];
  if (range.value === 'today') {
    list = list.filter((s) => s.scheduled_at && new Date(s.scheduled_at).toDateString() === new Date().toDateString());
  } else if (range.value === 'upcoming') {
    list = list.filter((s) => s.scheduled_at && new Date(s.scheduled_at).valueOf() >= now);
  } else if (range.value === 'past') {
    list = list.filter((s) => s.scheduled_at && new Date(s.scheduled_at).valueOf() < now);
  }
  const q = query.value.trim().toLowerCase();
  if (q) {
    list = list.filter((s) =>
      [s.topic, s.group?.name, s.tutor?.name].filter(Boolean).join(' ').toLowerCase().includes(q),
    );
  }
  return list.sort((a, b) => {
    const ta = a.scheduled_at ? new Date(a.scheduled_at).valueOf() : 0;
    const tb = b.scheduled_at ? new Date(b.scheduled_at).valueOf() : 0;
    return range.value === 'past' ? tb - ta : ta - tb;
  });
});

function whenParts(iso?: string | null) {
  if (!iso) return { main: '—', sub: '' };
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return { main: '—', sub: '' };
  const today = new Date();
  const isToday = d.toDateString() === today.toDateString();
  const tomorrow = new Date(today.getTime() + 86_400_000);
  const isTomorrow = d.toDateString() === tomorrow.toDateString();
  const main = isToday
    ? 'Hari ini'
    : isTomorrow
    ? 'Besok'
    : d.toLocaleDateString('id-ID', { weekday: 'short', day: 'numeric', month: 'short' });
  return {
    main,
    sub: d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
  };
}

function statusChip(s: TutoringSession) {
  if (s.status === 'DONE') {
    return { cls: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300', label: s.status_label ?? 'Hadir' };
  }
  if (s.status === 'CANCELLED') {
    return { cls: 'bg-rose-500/15 text-rose-700 dark:text-rose-300', label: s.status_label ?? 'Batal' };
  }
  return { cls: 'bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]', label: s.status_label ?? 'Terjadwal' };
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · SESI"
      title="Jadwal sesi"
      :subtitle="`${activeChild()?.name ?? 'Anak'} · ${sessions.length} sesi dalam 90 hari`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3">
      <div class="flex flex-wrap items-center gap-2">
        <div class="relative min-w-[180px] flex-1">
          <NavIcon name="search" :size="13" class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-bimbel-text-lo" />
          <input
            v-model="query"
            type="text"
            placeholder="Cari topik / kelas…"
            class="w-full rounded-lg border border-bimbel-border bg-bimbel-bg pl-8 pr-3 py-1.5 text-[12px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-[#21afe6] focus:outline-none"
          />
        </div>
        <div class="flex gap-1">
          <button
            v-for="r in [
              { id: 'upcoming', label: 'Mendatang' },
              { id: 'today', label: 'Hari ini' },
              { id: 'past', label: 'Lalu' },
              { id: 'all', label: 'Semua' },
            ] as const"
            :key="r.id"
            type="button"
            class="rounded-full border px-3 py-1.5 text-[12px] font-semibold"
            :class="
              range === r.id
                ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
                : 'border-bimbel-border text-bimbel-text-mid'
            "
            @click="range = r.id"
          >{{ r.label }}</button>
        </div>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="filtered.length" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel overflow-hidden">
      <table class="w-full text-[12px]">
        <thead class="bg-bimbel-bg/40">
          <tr class="text-left text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">
            <th class="px-3 py-2 w-[120px]">Waktu</th>
            <th class="px-3 py-2">Topik</th>
            <th class="px-3 py-2 w-[160px]">Kelas</th>
            <th class="px-3 py-2 w-[120px]">Tutor</th>
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
              <p class="font-bold text-bimbel-text-hi">{{ whenParts(s.scheduled_at).main }}</p>
              <p class="text-[12px] text-bimbel-text-mid">{{ whenParts(s.scheduled_at).sub }} · {{ s.duration_minutes }}m</p>
            </td>
            <td class="px-3 py-2.5">
              <p class="font-bold text-bimbel-text-hi">{{ s.topic || 'Sesi terjadwal' }}</p>
              <p v-if="s.room" class="text-[12px] text-bimbel-text-mid">ruang {{ s.room }}</p>
            </td>
            <td class="px-3 py-2.5">
              <p class="text-bimbel-text-hi">{{ s.group?.name ?? '—' }}</p>
              <p v-if="s.group?.program?.name" class="text-[12px] text-bimbel-text-mid">{{ s.group.program.name }}</p>
            </td>
            <td class="px-3 py-2.5 text-bimbel-text-hi">{{ s.tutor?.name ?? '—' }}</td>
            <td class="px-3 py-2.5">
              <span
                class="inline-flex rounded-full px-2 py-0.5 text-[12px] font-bold"
                :class="statusChip(s).cls"
              >{{ statusChip(s).label }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div
      v-else
      class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
    >Tidak ada sesi sesuai filter.</div>
  </div>
</template>

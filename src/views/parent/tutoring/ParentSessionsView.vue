<!--
  ParentSessionsView — wali Jadwal sesi list. Mockup parent_web_pages_browse
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
const { activeChildId } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const sessions = ref<TutoringSession[]>([]);
const range = ref<'all' | 'today' | 'upcoming' | 'past'>('upcoming');
const query = ref('');
const subjectFilter = ref<string>('');

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

// ── Redesigned template helpers ──────────────────────────────────
function statusLabel(s: TutoringSession): string {
  if (s.status === 'DONE') return s.status_label ?? 'Selesai';
  if (s.status === 'CANCELLED') return s.status_label ?? 'Batal';
  return s.status_label ?? 'Akan datang';
}

function timeOnly(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
}

const weekCount = computed(() => {
  const now = new Date();
  const start = new Date(now);
  start.setDate(now.getDate() - now.getDay());
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(start.getDate() + 7);
  return sessions.value.filter((s) => {
    if (!s.scheduled_at) return false;
    const d = new Date(s.scheduled_at);
    return d >= start && d < end;
  }).length;
});

const monthCount = computed(() => {
  const now = new Date();
  return sessions.value.filter((s) => {
    if (!s.scheduled_at) return false;
    const d = new Date(s.scheduled_at);
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }).length;
});

const subjects = computed(() => {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const s of sessions.value) {
    const name = s.group?.name;
    if (name && !seen.has(name)) {
      seen.add(name);
      out.push(name);
    }
  }
  return out;
});

const visible = computed(() => {
  let list = filtered.value;
  if (subjectFilter.value) {
    list = list.filter((s) => s.group?.name === subjectFilter.value);
  }
  return list;
});

function dateGroupLabel(d: Date): string {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  const dayStart = new Date(d);
  dayStart.setHours(0, 0, 0, 0);
  const dateLabel = d.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
  }).toUpperCase();
  if (dayStart.valueOf() === today.valueOf()) return `HARI INI · ${dateLabel}`;
  if (dayStart.valueOf() === tomorrow.valueOf()) return `BESOK · ${dateLabel}`;
  return dateLabel;
}

const groupedByDate = computed(() => {
  const groups = new Map<string, { key: string; label: string; items: TutoringSession[] }>();
  for (const s of visible.value) {
    if (!s.scheduled_at) continue;
    const d = new Date(s.scheduled_at);
    const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    let g = groups.get(key);
    if (!g) {
      g = { key, label: dateGroupLabel(d), items: [] };
      groups.set(key, g);
    }
    g.items.push(s);
  }
  return Array.from(groups.values());
});
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · JADWAL"
      title="Sesi mendatang"
      :subtitle="`${weekCount} sesi minggu ini · ${monthCount} bulan ini`"
      :stats="[]"
    >
      <template #actions>
        <ParentChildPickerChip />
        <span
          class="inline-flex items-center gap-1 rounded-full bg-white px-2.5 py-1 text-[12px] font-bold text-bimbel-hero shadow-sm"
        >
          <i class="ti ti-calendar text-[14px]"></i>
          Kalender
        </span>
      </template>
    </ParentBerandaHero>

    <!-- Subject filter chips -->
    <div class="flex gap-1.5 mb-2.5 flex-wrap">
      <button
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] transition-colors"
        :class="
          subjectFilter === ''
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="subjectFilter = ''"
      >Semua</button>
      <button
        v-for="s in subjects"
        :key="s"
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] transition-colors"
        :class="
          subjectFilter === s
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="subjectFilter = s"
      >{{ s }}</button>
    </div>

    <!-- Search -->
    <div class="relative">
      <NavIcon
        name="search"
        :size="13"
        class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-bimbel-text-lo"
      />
      <input
        v-model="query"
        type="text"
        placeholder="Cari topik atau tutor…"
        class="w-full rounded-lg border border-bimbel-border-soft bg-bimbel-panel pl-8 pr-3 py-1.5 text-[12px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-bimbel-hero focus:outline-none"
      />
    </div>

    <div v-if="loading" class="py-12 text-center text-[12px] text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="visible.length" class="rounded-lg border border-bimbel-border-soft bg-bimbel-panel p-3">
      <template v-for="(group, gIdx) in groupedByDate" :key="group.key">
        <p
          class="text-[10px] tracking-wider text-bimbel-text-lo font-bold uppercase py-2 pt-3"
          :class="gIdx === 0 ? 'first-of-type:pt-0' : ''"
        >
          {{ group.label }}
        </p>
        <div
          v-for="s in group.items"
          :key="s.id"
          class="rounded-lg bg-bimbel-bg p-2.5 mb-1.5 flex items-center gap-2.5"
        >
          <div class="w-16 flex-shrink-0">
            <p class="text-[13px] font-bold text-bimbel-text-hi">{{ timeOnly(s.scheduled_at) }}</p>
            <p class="text-[11px] text-bimbel-text-mid">{{ s.duration_minutes }} menit</p>
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-[12px] font-bold text-bimbel-text-hi truncate">
              {{ s.group?.name ?? s.topic ?? 'Sesi' }}<template v-if="s.group?.program?.name"> · {{ s.group.program.name }}</template>
            </p>
            <p class="text-[11px] text-bimbel-text-mid truncate">
              {{ [s.tutor?.name, s.room ? `ruang ${s.room}` : null, s.topic].filter(Boolean).join(' · ') }}
            </p>
          </div>
          <span
            class="flex-shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide"
            :class="
              s.status === 'DONE'
                ? 'bg-bimbel-green-dim text-green-700'
                : s.status === 'CANCELLED'
                ? 'bg-bimbel-red-dim text-red-700'
                : 'bg-bimbel-accent-dim text-bimbel-hero'
            "
          >
            {{ statusLabel(s) }}
          </span>
        </div>
      </template>
    </div>

    <div
      v-else
      class="rounded-lg border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-[12px] text-bimbel-text-mid"
    >Tidak ada sesi sesuai filter.</div>
  </div>
</template>

<!--
  ParentClassesView — wali Kelas list.

  Mockup-exact: hero + search/filter row + 2-col grid of class cards
  with tutor initials chip, subject, meta (tutor + schedule), and
  attendance footer bar. Trailing dashed "Daftarkan ke program baru"
  CTA tile. Data via TutoringService.getWaliClassMeta.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringWaliClassMeta } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const classes = ref<TutoringWaliClassMeta[]>([]);

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try { classes.value = await TutoringService.getWaliClassMeta(sid); }
  catch { /* non-fatal */ }
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

// ── Search + status filter (chip row with counts) ────────────────
// Previously a cycle button "Semester ini → Aktif → Selesai" — lost the
// at-a-glance count and required 3 clicks to land on a specific filter.
// Mobile shows three chips with badge counts; mirror that.
const q = ref('');
type StatusKey = 'semua' | 'aktif' | 'selesai';
const status = ref<StatusKey>('semua');

function matchAktif(s: string): boolean {
  return /active|aktif|open/i.test(s);
}
function matchSelesai(s: string): boolean {
  return /completed|selesai|closed/i.test(s);
}

const statusChips = computed<{ id: StatusKey; label: string; count: number }[]>(() => {
  const total = decorated.value.length;
  const aktif = decorated.value.filter((c) => matchAktif(c.status)).length;
  const selesai = decorated.value.filter((c) => matchSelesai(c.status)).length;
  return [
    { id: 'semua', label: 'Semua', count: total },
    { id: 'aktif', label: 'Aktif', count: aktif },
    { id: 'selesai', label: 'Selesai', count: selesai },
  ];
});

type ClassRow = TutoringWaliClassMeta & {
  subject?: string;
  schedule_label?: string;
  attendance_rate?: number | null;
};

const decorated = computed<ClassRow[]>(() =>
  classes.value.map((c) => ({
    ...c,
    subject: c.program_name || c.group_name,
    schedule_label: scheduleLabel(c),
    attendance_rate: c.attendance?.rate ?? null,
  })),
);

const filteredClasses = computed<ClassRow[]>(() => {
  let list = decorated.value;
  if (status.value === 'aktif') list = list.filter((c) => matchAktif(c.status));
  else if (status.value === 'selesai') list = list.filter((c) => matchSelesai(c.status));
  const needle = q.value.trim().toLowerCase();
  if (needle) {
    list = list.filter((c) => {
      const hay = `${c.subject ?? ''} ${c.group_name ?? ''} ${c.tutor_name ?? ''}`.toLowerCase();
      return hay.includes(needle);
    });
  }
  return list;
});

// ── Display helpers ──────────────────────────────────────────────
const childFirstName = computed(() => {
  const n = activeChild()?.name ?? 'Anak';
  return n.split(/\s+/)[0];
});

function initials(name?: string | null): string {
  if (!name) return '?';
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase() ?? '')
    .join('');
}

// Cycle through bimbel-palette chip styles so siblings/tutors get
// distinct hues without raw slate/sky tokens.
const TUTOR_CHIPS = [
  'bg-bimbel-accent-dim text-bimbel-hero',
  'bg-bimbel-green-dim text-green-700',
  'bg-bimbel-amber-dim text-amber-700',
  'bg-purple-200 text-purple-800',
];
function tutorChipClass(i: number): string {
  return TUTOR_CHIPS[i % TUTOR_CHIPS.length];
}

function scheduleLabel(c: TutoringWaliClassMeta): string {
  const ns = c.next_session;
  if (!ns?.scheduled_at) return 'belum ada sesi';
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return 'belum ada sesi';
  return d.toLocaleString('id-ID', {
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function attBarClass(rate: number | null | undefined): string {
  if (rate == null) return 'bg-bimbel-text-lo';
  if (rate >= 85) return 'bg-green-600';
  if (rate >= 70) return 'bg-amber-500';
  return 'bg-red-600';
}

function openClass(c: TutoringWaliClassMeta) {
  router.push({
    name: 'parent.tutoring.class-detail',
    params: { studentId: studentId.value, groupId: c.group_id },
  });
}
function goEnroll() {
  router.push({ name: 'parent.tutoring.enroll-new' });
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · WALI"
      :title="`Kelas ${childFirstName}`"
      :subtitle="`${classes.length} kelompok aktif semester ini`"
      :stats="[]"
    >
      <template #actions>
        <ParentChildPickerChip />
      </template>
    </ParentBerandaHero>

    <!-- Search row -->
    <div class="rounded-lg bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-mid flex items-center gap-2">
      <NavIcon name="search" :size="14" />
      <input
        v-model="q"
        placeholder="Cari mata pelajaran atau tutor"
        class="bg-transparent flex-1 focus:outline-none text-bimbel-text-hi placeholder:text-bimbel-text-mid"
      />
    </div>

    <!-- Status chips with counts -->
    <div class="flex gap-1.5 flex-wrap">
      <button
        v-for="s in statusChips"
        :key="s.id"
        type="button"
        class="rounded-full px-2.5 py-1 text-[12px] transition-colors"
        :class="
          status === s.id
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid'
        "
        @click="status = s.id"
      >{{ s.label }} ({{ s.count }})</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <!-- Class grid 2-col -->
    <div v-else class="grid sm:grid-cols-2 gap-2.5">
      <button
        v-for="(c, i) in filteredClasses"
        :key="c.group_id"
        type="button"
        class="rounded-xl bg-bimbel-panel border border-bimbel-border-soft p-3 flex flex-col gap-1.5 text-left hover:border-bimbel-border"
        @click="openClass(c)"
      >
        <div class="flex items-center gap-2">
          <span
            class="w-7 h-7 rounded-full grid place-items-center text-[12px] font-bold"
            :class="tutorChipClass(i)"
          >
            {{ initials(c.tutor_name) }}
          </span>
          <span class="text-[14px] font-bold text-bimbel-text-hi truncate">
            {{ c.subject || c.group_name }}
          </span>
        </div>
        <div class="text-[12px] text-bimbel-text-mid flex gap-2.5">
          <span class="inline-flex items-center gap-1">
            <NavIcon name="user" :size="12" />{{ c.tutor_name || '—' }}
          </span>
          <span class="inline-flex items-center gap-1">
            <NavIcon name="calendar" :size="12" />{{ c.schedule_label || '—' }}
          </span>
        </div>
        <div class="text-[12px] flex justify-between items-center mt-1 pt-2 border-t border-bimbel-border-soft">
          <span class="text-bimbel-text-mid">Kehadiran</span>
          <span class="flex-1 mx-2 h-1 bg-bimbel-bg rounded-full overflow-hidden max-w-[80px]">
            <span
              class="block h-full"
              :class="attBarClass(c.attendance_rate)"
              :style="{ width: `${Math.max(0, Math.min(100, c.attendance_rate ?? 0))}%` }"
            />
          </span>
          <span class="font-bold text-bimbel-text-hi">{{ c.attendance_rate ?? 0 }}%</span>
        </div>
      </button>

      <!-- Daftarkan tile -->
      <button
        type="button"
        class="rounded-xl border border-dashed border-bimbel-border bg-bimbel-bg p-3 flex flex-col items-center justify-center text-center min-h-[110px]"
        @click="goEnroll"
      >
        <NavIcon name="plus" :size="22" />
        <p class="text-[13px] text-bimbel-text-mid mt-1">Daftarkan ke program baru</p>
      </button>
    </div>
  </div>
</template>

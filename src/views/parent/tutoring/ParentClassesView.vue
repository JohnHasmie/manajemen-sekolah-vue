<!--
  ParentClassesView — wali Kelas list.

  Redesigned per approved mockup: hero + search row + 2-col class grid
  with tutor initials, subject, meta (tutor + schedule), and a
  "kehadiran" footer bar. Final cell is a dashed "Daftarkan ke program
  baru" CTA. Data shape unchanged (TutoringWaliClassMeta).
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
    name: 'parent.tutoring.class-detail',
    params: { studentId: studentId.value, groupId: c.group_id },
  });
}

function goToEnroll() {
  router.push({ name: 'parent.tutoring.enroll-new' });
}

const childFirstName = computed(() => {
  const n = activeChild()?.name ?? 'Anak';
  return n.split(/\s+/)[0];
});

function tutorInitials(name?: string | null): string {
  if (!name) return '?';
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase() ?? '')
    .join('');
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

function attendanceColor(rate: number | null | undefined): string {
  if (rate == null) return 'bg-bimbel-text-lo';
  if (rate >= 85) return 'bg-bimbel-green';
  if (rate >= 70) return 'bg-bimbel-amber';
  return 'bg-bimbel-red';
}
</script>

<template>
  <div class="space-y-4 pb-12">
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

    <!-- Search + filter row -->
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
          class="w-full rounded-lg bg-bimbel-bg pl-9 pr-3 py-2 text-[12px] text-bimbel-text-mid placeholder:text-bimbel-text-lo focus:outline-none"
        />
      </div>
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-lg bg-bimbel-bg px-3 py-2 text-[12px] text-bimbel-text-mid"
        @click="status = status === 'all' ? 'active' : status === 'active' ? 'completed' : 'all'"
      >
        {{
          status === 'all'
            ? 'Semester ini'
            : status === 'active'
              ? 'Aktif saja'
              : 'Selesai saja'
        }}
        <NavIcon name="chevron-down" :size="12" />
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <!-- Class grid: 2-col -->
    <div v-else class="grid gap-2.5 sm:grid-cols-2">
      <template v-if="filtered.length">
        <div
          v-for="c in filtered"
          :key="c.group_id"
          role="button"
          tabindex="0"
          class="flex cursor-pointer flex-col gap-1.5 rounded-xl border border-bimbel-border-soft bg-bimbel-panel p-3 hover:border-bimbel-accent/40"
          @click="goToClass(c)"
          @keydown.enter="goToClass(c)"
        >
          <!-- Header: tutor initials circle + subject -->
          <div class="flex items-center gap-2">
            <span
              class="grid h-7 w-7 flex-shrink-0 place-items-center rounded-full bg-bimbel-accent-dim text-[11px] font-bold text-bimbel-hero"
            >
              {{ tutorInitials(c.tutor_name) }}
            </span>
            <p class="truncate text-[13px] font-bold text-bimbel-text-hi">
              {{ c.program_name || c.group_name }}
            </p>
          </div>

          <!-- Meta row: tutor + schedule -->
          <div class="flex flex-wrap items-center gap-2.5 text-[11px] text-bimbel-text-mid">
            <span class="inline-flex items-center gap-1">
              <NavIcon name="user" :size="11" />
              {{ c.tutor_name ?? '—' }}
            </span>
            <span class="inline-flex items-center gap-1">
              <NavIcon name="calendar" :size="11" />
              {{ scheduleLabel(c) }}
            </span>
          </div>

          <!-- Footer: attendance bar -->
          <div
            class="mt-1 flex items-center justify-between gap-2 border-t border-bimbel-border-soft pt-2"
          >
            <span class="text-[11px] text-bimbel-text-mid">Kehadiran</span>
            <div class="flex items-center gap-2">
              <span class="block h-1 w-20 overflow-hidden rounded-full bg-bimbel-bg">
                <span
                  class="block h-full rounded-full"
                  :class="attendanceColor(c.attendance.rate)"
                  :style="{ width: `${Math.max(0, Math.min(100, c.attendance.rate ?? 0))}%` }"
                />
              </span>
              <span class="text-[11px] font-bold text-bimbel-text-hi">
                {{ c.attendance.rate == null ? '—' : `${c.attendance.rate}%` }}
              </span>
            </div>
          </div>
        </div>
      </template>

      <!-- Empty-state cell when nothing filtered (still show CTA) -->
      <div
        v-if="!filtered.length && query"
        class="rounded-xl border border-bimbel-border-soft bg-bimbel-panel p-3 text-center text-[12px] text-bimbel-text-mid sm:col-span-2"
      >
        Tidak ada kelas yang cocok dengan "{{ query }}".
      </div>

      <!-- Always-present dashed CTA cell -->
      <div
        role="button"
        tabindex="0"
        class="flex cursor-pointer flex-col items-center justify-center gap-1 rounded-xl border border-dashed border-bimbel-border bg-bimbel-bg p-4 text-center hover:border-bimbel-accent/40"
        @click="goToEnroll"
        @keydown.enter="goToEnroll"
      >
        <NavIcon name="plus" :size="22" class="text-bimbel-text-lo" />
        <span class="text-[12px] text-bimbel-text-mid">Daftarkan ke program baru</span>
      </div>
    </div>
  </div>
</template>

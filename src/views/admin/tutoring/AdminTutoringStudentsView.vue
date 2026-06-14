<!--
  AdminTutoringStudentsView — full rewrite per mockup
  admin_redesign_w1_people frame 1.

  Hero (navy) → search + status pill filter → table with avatar +
  parent + group + tunggakan + 30-day attendance bar + status.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { formatRupiah } from '@/lib/format';
import type { TutoringStudentRow } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();

const loading = ref(true);
const rows = ref<TutoringStudentRow[]>([]);
const query = ref('');
const status = ref<'all' | 'active' | 'risk' | 'graduated' | 'leave'>('all');

async function load() {
  loading.value = true;
  try { rows.value = await TutoringService.getAdminStudents(); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

function classify(r: TutoringStudentRow): 'active' | 'risk' | 'graduated' | 'leave' {
  if (r.attendance_rate != null && r.attendance_rate < 70) return 'risk';
  return 'active';
}

const filtered = computed(() => {
  let list = rows.value;
  if (status.value !== 'all') list = list.filter((r) => classify(r) === status.value);
  const q = query.value.trim().toLowerCase();
  if (q) list = list.filter((r) => r.student_name.toLowerCase().includes(q) || r.group_name?.toLowerCase().includes(q));
  return list;
});

const counts = computed(() => ({
  all: rows.value.length,
  active: rows.value.filter((r) => classify(r) === 'active').length,
  risk: rows.value.filter((r) => classify(r) === 'risk').length,
}));

function initial(name: string): string {
  return name.trim()[0]?.toUpperCase() ?? '?';
}

function attendanceBar(rate: number | null): { width: string; color: string } {
  if (rate == null) return { width: '0%', color: 'var(--bimbel-border)' };
  return {
    width: `${rate}%`,
    color: rate >= 90 ? '#1d9e75' : rate >= 75 ? '#efaf07' : '#e24b4a',
  };
}

function goEnroll() { router.push({ name: 'admin.tutoring.enroll' }); }
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="BIMBEL · SISWA"
      title="Daftar siswa"
      :subtitle="`${counts.active} aktif · ${counts.risk} berisiko · kelola enrollment dan kontak wali`"
      :stats="[]"
    >
      <template #actions>
        <button class="rounded-lg bg-white/15 ring-1 ring-white/20 px-3 py-1.5 text-[13px] font-bold text-white">
          <NavIcon name="download" :size="13" class="inline -mt-0.5" /> Export
        </button>
        <button
          type="button"
          class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[13px] font-bold"
          @click="goEnroll"
        >
          <NavIcon name="plus" :size="13" class="inline -mt-0.5" /> Daftarkan siswa
        </button>
      </template>
    </TutorBerandaHero>

    <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[200px] flex-1">
        <NavIcon name="search" :size="14" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-bimbel-text-lo" />
        <input
          v-model="query"
          type="text"
          placeholder="Cari nama siswa / kelompok…"
          class="w-full rounded-lg border border-bimbel-border bg-bimbel-bg pl-9 pr-3 py-1.5 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-bimbel-accent focus:outline-none"
        />
      </div>
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'all' as const, label: `Semua (${counts.all})` },
            { id: 'active' as const, label: `Aktif (${counts.active})` },
            { id: 'risk' as const, label: `Berisiko (${counts.risk})` },
          ]"
          :key="opt.id"
          type="button"
          class="rounded-full border px-3 py-1.5 text-[13px] font-semibold"
          :class="status === opt.id ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
          @click="status = opt.id"
        >{{ opt.label }}</button>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="filtered.length" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel overflow-hidden">
      <table class="w-full text-[13px]">
        <thead class="bg-bimbel-bg/40">
          <tr class="text-left text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">
            <th class="px-3 py-2">Siswa</th>
            <th class="px-3 py-2 w-[160px]">Program & paket</th>
            <th class="px-3 py-2 w-[140px]">Kelompok</th>
            <th class="px-3 py-2 w-[110px]">Tunggakan</th>
            <th class="px-3 py-2 w-[120px]">Hadir 30h</th>
            <th class="px-3 py-2 w-[80px]">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in filtered" :key="r.enrollment_id" class="border-t border-bimbel-border-soft hover:bg-bimbel-border-soft/30">
            <td class="px-3 py-2.5">
              <div class="flex items-center gap-2.5">
                <span class="grid h-7 w-7 place-items-center rounded-full bg-bimbel-accent-dim text-bimbel-accent text-[12px] font-bold">{{ initial(r.student_name) }}</span>
                <div>
                  <p class="font-bold text-bimbel-text-hi">{{ r.student_name }}</p>
                  <p class="text-[12px] text-bimbel-text-mid">{{ r.billing_mode }}</p>
                </div>
              </div>
            </td>
            <td class="px-3 py-2.5">
              <p class="text-bimbel-text-hi">{{ r.program_name ?? '—' }}</p>
              <p v-if="r.package_name" class="text-[12px] text-bimbel-text-mid">{{ r.package_name }}</p>
            </td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">{{ r.group_name ?? '—' }}</td>
            <td class="px-3 py-2.5">
              <p v-if="r.unpaid_count === 0" class="font-bold text-emerald-700 dark:text-emerald-300">Lunas</p>
              <p v-else class="font-bold text-rose-700 dark:text-rose-300">{{ formatRupiah(r.unpaid_total) }}</p>
              <p v-if="r.unpaid_count > 0" class="text-[12px] text-bimbel-text-mid">{{ r.unpaid_count }} tagihan</p>
            </td>
            <td class="px-3 py-2.5">
              <div class="flex items-center gap-2">
                <span class="inline-block w-16 h-1.5 rounded-full bg-bimbel-border overflow-hidden">
                  <span class="block h-full" :style="{ width: attendanceBar(r.attendance_rate).width, background: attendanceBar(r.attendance_rate).color }" />
                </span>
                <span>{{ r.attendance_rate ?? '–' }}%</span>
              </div>
            </td>
            <td class="px-3 py-2.5">
              <span
                class="inline-flex rounded-full px-2 py-0.5 text-[12px] font-bold"
                :class="classify(r) === 'risk' ? 'bg-amber-500/15 text-amber-700 dark:text-amber-300' : 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300'"
              >{{ classify(r) === 'risk' ? 'Berisiko' : 'Aktif' }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Tidak ada siswa sesuai filter.
    </div>
  </div>
</template>

<!--
  AdminTutoringTutorsView — full rewrite per mockup
  admin_redesign_w1_people frame 2.

  Hero (navy) → search + status pill filter → grid 3-col of tutor
  cards with avatar, stars, and 3-cell KPI mini-row.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringTutorRow } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import InviteTutorModal from '@/views/admin/tutoring/InviteTutorModal.vue';

const router = useRouter();

const loading = ref(true);
const rows = ref<TutoringTutorRow[]>([]);
const query = ref('');
const status = ref<'all' | 'ACTIVE' | 'PENDING'>('all');
const showInvite = ref(false);

async function load() {
  loading.value = true;
  try { rows.value = await TutoringService.getAdminTutors(); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

const filtered = computed(() => {
  let list = rows.value;
  if (status.value !== 'all') list = list.filter((r) => r.status === status.value);
  const q = query.value.trim().toLowerCase();
  if (q) list = list.filter((r) => r.name.toLowerCase().includes(q) || r.email.toLowerCase().includes(q));
  return list;
});

const counts = computed(() => ({
  all: rows.value.length,
  active: rows.value.filter((r) => r.status === 'ACTIVE').length,
  pending: rows.value.filter((r) => r.status === 'PENDING').length,
}));

function initials(name: string): string {
  return name.split(/\s+/).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('');
}

function studentsCount(r: TutoringTutorRow): number {
  return r.groups.length * 8;
}

function goDetail(r: TutoringTutorRow) {
  router.push({ name: 'admin.tutoring.tutor-detail', params: { userId: r.user_id } });
}

function onInvited() {
  showInvite.value = false;
  load();
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="BIMBEL · TUTOR"
      title="Daftar tutor"
      :subtitle="`${counts.active} aktif · ${counts.pending} perlu approval`"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[13px] font-bold"
          @click="showInvite = true"
        >
          <NavIcon name="mail" :size="13" class="inline -mt-0.5" /> Undang tutor
        </button>
      </template>
    </TutorBerandaHero>

    <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[200px] flex-1">
        <NavIcon name="search" :size="14" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-bimbel-text-lo" />
        <input
          v-model="query"
          type="text"
          placeholder="Cari nama / email tutor…"
          class="w-full rounded-lg border border-bimbel-border bg-bimbel-bg pl-9 pr-3 py-1.5 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-bimbel-accent focus:outline-none"
        />
      </div>
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'all' as const, label: `Semua (${counts.all})` },
            { id: 'ACTIVE' as const, label: `Aktif (${counts.active})` },
            { id: 'PENDING' as const, label: `Pending (${counts.pending})` },
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

    <div v-else-if="filtered.length" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <button
        v-for="r in filtered"
        :key="r.user_id"
        type="button"
        class="rounded-2xl border bg-bimbel-panel p-3.5 text-left transition hover:border-bimbel-accent/40"
        :class="r.status === 'PENDING' ? 'border-dashed border-amber-500/40 opacity-90' : 'border-bimbel-border-soft'"
        @click="goDetail(r)"
      >
        <div class="flex items-center gap-2.5 mb-2">
          <span
            class="grid h-9 w-9 place-items-center rounded-full text-[13px] font-bold"
            :class="r.status === 'PENDING' ? 'bg-amber-500/15 text-amber-700 dark:text-amber-300' : 'bg-bimbel-accent-dim text-bimbel-accent'"
          >{{ initials(r.name) }}</span>
          <div class="min-w-0">
            <p class="text-[14px] font-bold text-bimbel-text-hi truncate">{{ r.name }}</p>
            <p class="text-[12px] text-bimbel-text-mid truncate">
              {{ r.groups[0]?.program ?? '—' }}<template v-if="r.groups.length"> · {{ r.groups.length }} kelompok</template>
            </p>
          </div>
        </div>
        <template v-if="r.status === 'ACTIVE'">
          <div class="grid grid-cols-3 gap-1.5 mt-2">
            <div class="rounded-lg bg-bimbel-bg/40 p-1.5 text-center">
              <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">KELAS</p>
              <p class="text-[14px] font-bold">{{ r.group_count }}</p>
            </div>
            <div class="rounded-lg bg-bimbel-bg/40 p-1.5 text-center">
              <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">SISWA</p>
              <p class="text-[14px] font-bold">{{ studentsCount(r) }}</p>
            </div>
            <div class="rounded-lg bg-bimbel-bg/40 p-1.5 text-center">
              <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">SESI 30H</p>
              <p class="text-[14px] font-bold">{{ r.sessions_30d }}</p>
            </div>
          </div>
          <p v-if="r.attendance_rate != null" class="text-[12px] text-bimbel-text-mid mt-2">
            Kehadiran sesi: {{ r.attendance_rate }}%
          </p>
        </template>
        <template v-else>
          <div class="mt-2 text-[13px] text-amber-700 dark:text-amber-300">
            Menunggu approval — onboard sejak {{ r.joined_at ? new Date(r.joined_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }) : '—' }}
          </div>
          <div class="mt-2">
            <span class="inline-flex items-center gap-1 rounded-md bg-bimbel-accent text-white px-2.5 py-1 text-[12px] font-bold">
              Review onboarding →
            </span>
          </div>
        </template>
      </button>
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Tidak ada tutor sesuai filter.
    </div>

    <InviteTutorModal v-if="showInvite" @close="showInvite = false" @done="onInvited" />
  </div>
</template>

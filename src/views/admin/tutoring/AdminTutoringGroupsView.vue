<!--
  AdminTutoringGroupsView — list of all kelompok in this tenant.
  Mockup admin_web_pages_beranda_groups frame 2.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringGroup } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import TutorClassCard from '@/components/feature/tutoring/TutorClassCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();

const loading = ref(true);
const groups = ref<TutoringGroup[]>([]);
const query = ref('');
const status = ref<'all' | 'active' | 'full' | 'closed'>('all');

async function load() {
  loading.value = true;
  try { groups.value = await TutoringService.getAllGroups(); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

const filtered = computed(() => {
  let list = groups.value;
  if (status.value === 'active') list = list.filter((g) => /active|aktif|open/i.test(g.status));
  if (status.value === 'full') list = list.filter((g) => (g.enrollments_count ?? 0) >= g.capacity);
  if (status.value === 'closed') list = list.filter((g) => /closed|selesai/i.test(g.status));
  const q = query.value.trim().toLowerCase();
  if (q) list = list.filter((g) => g.name.toLowerCase().includes(q));
  return list;
});

const needsAttention = computed(() => groups.value.filter((g) => !g.tutor_user_id).length);

function goToDetail(g: TutoringGroup) {
  router.push({ name: 'admin.tutoring.group-detail', params: { groupId: g.id } });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="BIMBEL · KELOMPOK"
      title="Daftar kelompok"
      :subtitle="`${groups.length} aktif · ${needsAttention} perlu perhatian`"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[13px] font-bold hover:opacity-90"
        >
          <NavIcon name="plus" :size="13" class="inline -mt-0.5" /> Buat kelompok
        </button>
      </template>
    </TutorBerandaHero>

    <div class="flex flex-wrap items-center gap-2">
      <div class="relative min-w-0 flex-1">
        <NavIcon name="search" :size="14" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-bimbel-text-lo" />
        <input
          v-model="query"
          type="text"
          placeholder="Cari kelompok…"
          class="w-full rounded-xl border border-bimbel-border bg-bimbel-panel pl-9 pr-3 py-2 text-[14px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-bimbel-accent focus:outline-none"
        />
      </div>
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'all' as const, label: 'Semua' },
            { id: 'active' as const, label: 'Aktif' },
            { id: 'full' as const, label: 'Penuh' },
            { id: 'closed' as const, label: 'Selesai' },
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
      <TutorClassCard
        v-for="g in filtered"
        :key="g.id"
        :identity-key="g.id"
        :name="g.name"
        :program="g.tutor?.name ? `Tutor: ${g.tutor.name}` : 'Belum ada tutor'"
        :meta="`${g.enrollments_count ?? 0} / ${g.capacity} siswa · ${g.status}`"
        @click="goToDetail(g)"
      />
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Tidak ada kelompok sesuai filter.
    </div>
  </div>
</template>

<!--
  ParentMoreView — wali "Lainnya" hub. Mockup parent_web_pages_account
  frame 2: grouped tiles (Pembelajaran / Keuangan / Komunitas & Akun).
-->
<script setup lang="ts">
import { useRouter } from 'vue-router';
import { computed } from 'vue';
import { useChildPicker } from '@/composables/useChildPicker';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const { activeChildId } = useChildPicker();

const childId = computed(() => activeChildId.value);

function go(name: string) {
  const params = childId.value ? { studentId: childId.value } : undefined;
  router.push({ name, params });
}

const sections = computed(() => [
  {
    title: 'Pembelajaran',
    tiles: [
      { icon: 'book', label: 'Kegiatan', sub: 'PR, quiz & try-out', to: 'parent.tutoring.kegiatan' },
      { icon: 'star', label: 'Nilai & progress', sub: 'Per mapel & riwayat', to: 'parent.tutoring.nilai' },
      { icon: 'check-circle', label: 'Peringkat', sub: 'Posisi anak di kelas', to: 'parent.tutoring.peringkat' },
    ],
  },
  {
    title: 'Keuangan',
    tiles: [
      { icon: 'wallet', label: 'Riwayat tagihan', sub: 'Lunas + belum bayar', to: 'parent.tutoring.tagihan' },
      { icon: 'sparkles', label: 'Voucher saya', sub: 'Promo & kode diskon', to: 'parent.tutoring.voucher' },
    ],
  },
  {
    title: 'Komunitas & akun',
    tiles: [
      { icon: 'megaphone', label: 'Pengumuman', sub: 'Dari tutor & admin', to: 'parent.tutoring.pengumuman' },
      { icon: 'user', label: 'Profil & sandi', sub: 'Identitas wali', to: 'parent.tutoring.profil' },
      { icon: 'sun', label: 'Tampilan & bahasa', sub: 'Mode terang/gelap', to: 'parent.tutoring.tampilan' },
    ],
  },
]);
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · LAINNYA"
      title="Akses cepat"
      subtitle="Semua menu dalam satu tempat"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div v-for="s in sections" :key="s.title" class="space-y-2">
      <h3 class="text-[12px] font-bold uppercase tracking-widest text-bimbel-text-mid">{{ s.title }}</h3>
      <div class="grid gap-2.5 sm:grid-cols-2 lg:grid-cols-3">
        <button
          v-for="t in s.tiles"
          :key="t.label"
          type="button"
          class="flex flex-col items-start gap-2 rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 text-left transition hover:border-[#21afe6]/50"
          @click="go(t.to)"
        >
          <span class="grid h-9 w-9 place-items-center rounded-xl bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]">
            <NavIcon :name="t.icon" :size="16" />
          </span>
          <div>
            <p class="text-[13px] font-bold text-bimbel-text-hi">{{ t.label }}</p>
            <p class="text-[12px] text-bimbel-text-mid">{{ t.sub }}</p>
          </div>
        </button>
      </div>
    </div>
  </div>
</template>

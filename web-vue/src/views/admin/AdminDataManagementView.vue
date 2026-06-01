<!--
  AdminDataManagementView.vue — admin Manajemen Data hub.

  Mirrors Flutter's `AdminDataManagementScreen` — a tile-card menu that
  links to the four existing master-data CRUD screens (Siswa, Guru,
  Kelas, Mapel). Each tile carries an icon, a one-line subtitle, and
  a chevron — same chrome as the parent Akademik hub and the admin
  People + Academic hubs so cross-role list menus render identically.

  Reached from the admin Sistem hub ("Manajemen Data" tile).
-->
<script setup lang="ts">
import { useRouter } from 'vue-router';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();

interface DataTile {
  icon: string;
  iconBg: string;
  iconFg: string;
  title: string;
  subtitle: string;
  routeName: string;
}

const tiles: DataTile[] = [
  {
    icon: 'users',
    iconBg: 'bg-emerald-100',
    iconFg: 'text-emerald-700',
    title: 'Siswa',
    subtitle: 'Daftar siswa · NIS · kelas aktif',
    routeName: 'admin.students',
  },
  {
    icon: 'user',
    iconBg: 'bg-amber-100',
    iconFg: 'text-amber-700',
    title: 'Guru',
    subtitle: 'Profil guru · mapel diampu · kontak',
    routeName: 'admin.teachers',
  },
  {
    icon: 'layers',
    iconBg: 'bg-indigo-100',
    iconFg: 'text-indigo-700',
    title: 'Kelas',
    subtitle: 'Rombel · wali kelas · tingkat',
    routeName: 'admin.classes',
  },
  {
    icon: 'book',
    iconBg: 'bg-violet-100',
    iconFg: 'text-violet-700',
    title: 'Mata Pelajaran',
    subtitle: 'Mapel · KKM · kelas penerima',
    routeName: 'admin.subjects',
  },
];

function goBack() {
  router.push({ name: 'admin.settings' });
}

function open(t: DataTile) {
  router.push({ name: t.routeName });
}
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      Pengaturan
    </button>

    <BrandPageHeader
      role="admin"
      kicker="Sistem · Data"
      title="Kelola Data"
      meta="Siswa · Guru · Kelas · Mapel"
      :live-dot="false"
    />

    <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
      <button
        v-for="(t, idx) in tiles"
        :key="t.routeName"
        type="button"
        class="w-full text-left px-4 py-3.5 flex items-center gap-3 hover:bg-slate-50 transition-colors"
        :class="[idx > 0 ? 'border-t border-slate-100' : '']"
        @click="open(t)"
      >
        <div
          class="w-10 h-10 rounded-xl grid place-items-center flex-shrink-0"
          :class="[t.iconBg, t.iconFg]"
        >
          <NavIcon :name="t.icon" :size="18" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[14px] font-bold text-slate-900">{{ t.title }}</p>
          <p class="text-[11.5px] text-slate-500 truncate">{{ t.subtitle }}</p>
        </div>
        <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
      </button>
    </section>
  </div>
</template>

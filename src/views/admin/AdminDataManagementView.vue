<!--
  AdminDataManagementView.vue — admin Manajemen Data hub.

  Mirrors Flutter's `AdminDataManagementScreen` — a tile-card menu that
  links to the four existing master-data CRUD screens (Student, Teacher,
  Kelas, Mapel). Each tile carries an icon, a one-line subtitle, and
  a chevron — same chrome as the parent Academic hub and the admin
  People + Academic hubs so cross-role list menus render identically.

  Reached from the admin Sistem hub ("Manajemen Data" tile).
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const { t } = useI18n();

interface DataTile {
  icon: string;
  iconBg: string;
  iconFg: string;
  title: string;
  subtitle: string;
  routeName: string;
}

const tiles = computed<DataTile[]>(() => [
  {
    icon: 'users',
    iconBg: 'bg-emerald-100',
    iconFg: 'text-emerald-700',
    title: t('admin.sekolah.data_management.tile_students_title'),
    subtitle: t('admin.sekolah.data_management.tile_students_subtitle'),
    routeName: 'admin.students',
  },
  {
    icon: 'user',
    iconBg: 'bg-amber-100',
    iconFg: 'text-amber-700',
    title: t('admin.sekolah.data_management.tile_teachers_title'),
    subtitle: t('admin.sekolah.data_management.tile_teachers_subtitle'),
    routeName: 'admin.teachers',
  },
  {
    icon: 'layers',
    iconBg: 'bg-indigo-100',
    iconFg: 'text-indigo-700',
    title: t('admin.sekolah.data_management.tile_classes_title'),
    subtitle: t('admin.sekolah.data_management.tile_classes_subtitle'),
    routeName: 'admin.classes',
  },
  {
    icon: 'book',
    iconBg: 'bg-violet-100',
    iconFg: 'text-violet-700',
    title: t('admin.sekolah.data_management.tile_subjects_title'),
    subtitle: t('admin.sekolah.data_management.tile_subjects_subtitle'),
    routeName: 'admin.subjects',
  },
]);

function goBack() {
  router.push({ name: 'admin.settings' });
}

function open(tile: DataTile) {
  router.push({ name: tile.routeName });
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
      {{ t('admin.sekolah.data_management.back_to_settings') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.data_management.header_kicker')"
      :title="t('admin.sekolah.data_management.header_title')"
      :meta="t('admin.sekolah.data_management.header_meta')"
      :live-dot="false"
    />

    <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
      <button
        v-for="(tile, idx) in tiles"
        :key="tile.routeName"
        type="button"
        class="w-full text-left px-4 py-3.5 flex items-center gap-3 hover:bg-slate-50 transition-colors"
        :class="[idx > 0 ? 'border-t border-slate-100' : '']"
        @click="open(tile)"
      >
        <div
          class="w-10 h-10 rounded-xl grid place-items-center flex-shrink-0"
          :class="[tile.iconBg, tile.iconFg]"
        >
          <NavIcon :name="tile.icon" :size="18" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[14px] font-bold text-slate-900">{{ tile.title }}</p>
          <p class="text-[11.5px] text-slate-500 truncate">{{ tile.subtitle }}</p>
        </div>
        <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
      </button>
    </section>
  </div>
</template>

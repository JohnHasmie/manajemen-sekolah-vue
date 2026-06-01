<!--
  RoleHomeStub.vue — placeholder dashboard inside AppShell.
  Replaced by the real role dashboards as tasks #18 (admin), #32 (teacher),
  #43 (parent) land. Kept intentionally minimal: just enough to confirm
  the routing pipeline end-to-end and demo the layout primitives.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import HeroStatsCard from '@/components/feature/HeroStatsCard.vue';
import StatSummaryCard from '@/components/feature/StatSummaryCard.vue';
import Card from '@/components/ui/Card.vue';
import type { Role } from '@/types/auth';

const auth = useAuthStore();
const { t } = useI18n();

const roleLabel = computed(() => {
  const r = auth.activeRole as Role | null;
  return r ? t(`role.${r}`) : '';
});
</script>

<template>
  <div class="space-y-md">
    <header>
      <h1 class="text-2xl font-bold text-slate-900">
        Selamat datang, {{ auth.user?.name }}
      </h1>
      <p class="text-sm text-slate-500">Masuk sebagai {{ roleLabel }}</p>
    </header>

    <HeroStatsCard
      label="Dashboard sementara"
      value="—"
      sublabel="Implementasi penuh menyusul (lihat task tracker)."
    />

    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-md">
      <StatSummaryCard
        label="Status sesi"
        value="Aktif"
        tone="success"
        :sublabel="auth.user?.email ?? ''"
      />
      <StatSummaryCard
        label="Peran aktif"
        :value="roleLabel"
        tone="brand"
      />
      <StatSummaryCard
        label="ID Sekolah"
        :value="auth.schoolId ?? '—'"
        tone="info"
      />
    </div>

    <Card title="Catatan untuk pengembang" subtitle="Halaman ini adalah placeholder.">
      <p class="text-sm text-slate-600 leading-relaxed">
        Dashboard {{ roleLabel }} akan menggantikan layar ini sesuai daftar tugas
        di <code>web-vue/CLAUDE.md</code>. Topbar, sidebar, notifikasi, dan
        profil di header sudah aktif — buka menu profil untuk mencoba toggle
        bahasa dan logout.
      </p>
    </Card>
  </div>
</template>

<!--
  AdminTutoring2PengaturanView.vue — greenfield "Pengaturan" hub.

  Not a list view: renders a 6-card grid of setting entrypoints (mode
  tagihan, struktur akademik, RBAC, fitur AI, profil bimbel, tampilan).
  No API call — each card is a placeholder for its own drill-in that
  a later agent wires up.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';

const { t } = useI18n();

interface SettingCard {
  short: string;
  title: string;
  subtitle: string;
}

// TODO i18n key: per-card subtitle strings (Prabayar · SPP bulanan · Per sesi, Program/Paket + Kelompok,
// Admin · Tutor · Wali · Siswa, Generate soal & tryout aktif, Nama, logo, alamat, kontak).
const cards = computed<SettingCard[]>(() => [
  { short: 'BIL', title: t('tutoring2.admin.settings.billingModes'), subtitle: 'Prabayar · SPP bulanan · Per sesi' },
  { short: 'AKA', title: t('tutoring2.admin.settings.academic'), subtitle: 'Program/Paket + Kelompok' },
  { short: 'RBA', title: t('tutoring2.admin.settings.rbac'), subtitle: 'Admin · Tutor · Wali · Siswa' },
  { short: 'AI', title: t('tutoring2.admin.settings.ai'), subtitle: 'Generate soal & tryout aktif' },
  { short: 'PRO', title: t('tutoring2.admin.settings.profile'), subtitle: 'Nama, logo, alamat, kontak' },
  { short: 'TEM', title: t('tutoring2.admin.settings.appearance'), subtitle: t('tutoring2.tutor.profile.appearanceDesc') },
]);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.settings.title')"
      :meta="t('tutoring2.admin.settings.meta')"
    />

    <div class="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
      <button
        v-for="c in cards"
        :key="c.short"
        type="button"
        class="flex items-center gap-3 rounded-3xl border border-slate-100 bg-white p-4 text-left shadow-sm transition hover:border-brand-cobalt hover:shadow-md"
      >
        <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-cobalt/10 text-brand-cobalt text-xs font-bold uppercase">
          {{ c.short }}
        </span>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-bold text-slate-900">{{ c.title }}</p>
          <p class="truncate text-2xs text-slate-500">{{ c.subtitle }}</p>
        </div>
        <span class="text-slate-300" aria-hidden="true">›</span>
      </button>
    </div>

    <!-- TODO i18n key: tenantConfigNote contains inline <code> tags; tutoring2.admin.settings.tenantConfigNote is plain text -->
    <p class="text-2xs text-slate-400">
      Disimpan di <code>tenant_config</code>. <code>module:tutoring</code> + ModuleCatalog scope=bimbel menentukan modul terbuka.
    </p>
  </div>
</template>

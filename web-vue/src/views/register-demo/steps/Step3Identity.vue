<!--
  Step 3 — Identity. Pilih semua-3-role atau hanya 1 role.
  Saat single_role, dropdown tambahan untuk pilih peran utama.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import type { DemoRole } from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';

const wizard = useDemoWizardStore();
const auth = useAuthStore();

const mode = computed({
  get: () => wizard.payload.identity.mode,
  set: (v: 'all_roles' | 'single_role') => wizard.patchPayload('identity', { mode: v }),
});

const primaryRole = computed({
  get: () => wizard.payload.identity.primary_role,
  set: (v: DemoRole) => wizard.patchPayload('identity', { primary_role: v }),
});

const userEmail = computed(() => auth.user?.email ?? 'akun.anda@gmail.com');

const ROLE_LABELS: Record<DemoRole, string> = {
  admin: 'Admin',
  teacher: 'Guru',
  parent: 'Wali murid',
};
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Langkah 3 dari 12 · Identitas Anda
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      Anda ingin coba berapa role?
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">
      Akun Google Anda jadi admin. Bisa juga sekaligus jadi guru & wali, atau pakai akun terpisah.
    </p>

    <div class="grid grid-cols-2 gap-3 mb-5">
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="
          mode === 'all_roles'
            ? 'border-2 border-role-admin bg-role-admin/10'
            : 'border-slate-300 bg-white hover:border-slate-400'
        "
        @click="mode = 'all_roles'"
      >
        <NavIcon
          name="users"
          :size="22"
          :class="mode === 'all_roles' ? 'text-role-admin' : 'text-slate-500'"
          class="mx-auto mb-1.5"
        />
        <div class="text-[13px] font-bold">Semua 3 role</div>
        <div class="text-[11px]" :class="mode === 'all_roles' ? 'text-role-admin' : 'text-slate-500'">
          Switch role dari menu profil
        </div>
      </button>

      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="
          mode === 'single_role'
            ? 'border-2 border-role-admin bg-role-admin/10'
            : 'border-slate-300 bg-white hover:border-slate-400'
        "
        @click="mode = 'single_role'"
      >
        <NavIcon
          name="user"
          :size="22"
          :class="mode === 'single_role' ? 'text-role-admin' : 'text-slate-500'"
          class="mx-auto mb-1.5"
        />
        <div class="text-[13px] font-bold">Hanya 1 role</div>
        <div class="text-[11px]" :class="mode === 'single_role' ? 'text-role-admin' : 'text-slate-500'">
          + 2 akun demo untuk role lain
        </div>
      </button>
    </div>

    <div v-if="mode === 'single_role'" class="mb-5">
      <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
        Pilih peran utama Anda
      </p>
      <div class="grid grid-cols-3 gap-1.5">
        <button
          v-for="role in (['admin', 'teacher', 'parent'] as DemoRole[])"
          :key="role"
          type="button"
          class="px-3 py-2 rounded-lg text-[12px] font-bold border transition"
          :class="
            primaryRole === role
              ? 'border-role-admin bg-role-admin text-white'
              : 'border-slate-300 bg-white text-slate-700 hover:border-slate-400'
          "
          @click="primaryRole = role"
        >
          {{ ROLE_LABELS[role] }}
        </button>
      </div>
    </div>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Akun yang akan Anda dapatkan
    </p>
    <div class="space-y-1.5">
      <div class="bg-slate-50 rounded-lg p-2.5 flex items-center gap-3">
        <div class="w-12 flex-shrink-0">
          <NavIcon name="shield" :size="18" class="text-role-admin" />
          <div class="text-[9px] font-bold tracking-wider text-slate-500 uppercase mt-0.5">Admin</div>
        </div>
        <div class="flex-1 min-w-0">
          <div class="font-mono text-[11px] text-slate-900 truncate">{{ userEmail }}</div>
          <div class="font-mono text-[11px] text-slate-500">Login Google · akun Anda</div>
        </div>
      </div>
      <div class="bg-slate-50 rounded-lg p-2.5 flex items-center gap-3">
        <div class="w-12 flex-shrink-0">
          <NavIcon name="user-check" :size="18" class="text-role-admin" />
          <div class="text-[9px] font-bold tracking-wider text-slate-500 uppercase mt-0.5">Guru</div>
        </div>
        <div class="flex-1 min-w-0">
          <div class="font-mono text-[11px] text-slate-900">guru.demo@kamiledu.id</div>
          <div class="font-mono text-[11px] text-slate-500">password dirilis di langkah akhir</div>
        </div>
      </div>
      <div class="bg-slate-50 rounded-lg p-2.5 flex items-center gap-3">
        <div class="w-12 flex-shrink-0">
          <NavIcon name="heart" :size="18" class="text-role-admin" />
          <div class="text-[9px] font-bold tracking-wider text-slate-500 uppercase mt-0.5">Wali</div>
        </div>
        <div class="flex-1 min-w-0">
          <div class="font-mono text-[11px] text-slate-900">wali.demo@kamiledu.id</div>
          <div class="font-mono text-[11px] text-slate-500">password dirilis di langkah akhir</div>
        </div>
      </div>
    </div>
  </div>
</template>

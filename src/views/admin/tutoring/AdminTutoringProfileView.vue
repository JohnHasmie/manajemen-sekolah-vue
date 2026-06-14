<!--
  AdminTutoringProfileView — admin profile + bimbel info + security.
  Mockup admin_web_pages_account frame 1.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const auth = useAuthStore();
const user = computed(() => auth.user);

function initials(name?: string | null): string {
  if (!name) return '?';
  return name.split(/\s+/).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('');
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="AKUN · PROFIL"
      title="Profil admin"
      subtitle="Identitas operator + profil bimbel + keamanan"
      :stats="[]"
    >
      <template #actions>
        <button class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[14px] font-bold">Simpan</button>
      </template>
    </TutorBerandaHero>

    <div class="grid gap-4 lg:grid-cols-5">
      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 text-center lg:col-span-2 h-fit">
        <div class="mx-auto grid h-20 w-20 place-items-center rounded-full bg-bimbel-accent-dim text-bimbel-accent text-2xl font-extrabold">{{ initials(user?.name) }}</div>
        <p class="mt-3 text-[15px] font-extrabold text-bimbel-text-hi">{{ user?.name ?? '—' }}</p>
        <p class="text-[13px] text-bimbel-text-mid">Admin · {{ user?.school_name ?? 'Bimbel' }}</p>
        <dl class="mt-4 space-y-1 text-left text-[14px]">
          <div class="flex justify-between border-t border-bimbel-border-soft pt-2"><dt class="text-bimbel-text-mid">Email</dt><dd class="font-bold truncate">{{ user?.email ?? '—' }}</dd></div>
          <div class="flex justify-between border-t border-bimbel-border-soft pt-2"><dt class="text-bimbel-text-mid">Bergabung</dt><dd class="font-bold">—</dd></div>
        </dl>
        <button class="mt-3 w-full rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[14px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft">Ganti foto</button>
      </aside>

      <div class="space-y-3 lg:col-span-3">
        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-2.5">
          <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">Identitas operator</h4>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-bimbel-text-mid">Nama</span>
            <input type="text" :value="user?.name ?? ''" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-bimbel-text-mid">Email</span>
            <input type="email" :value="user?.email ?? ''" disabled class="rounded-lg border border-bimbel-border-soft bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-mid" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-bimbel-text-mid">No HP / WA</span>
            <input type="tel" placeholder="08xx-xxxx-xxxx" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-2.5">
          <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">Profil bimbel</h4>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-bimbel-text-mid">Nama bimbel</span>
            <input type="text" :value="user?.school_name ?? ''" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-start gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="pt-1 text-[14px] text-bimbel-text-mid">Alamat</span>
            <textarea rows="2" placeholder="Alamat lengkap" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"></textarea>
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-bimbel-text-mid">No telp kantor</span>
            <input type="tel" placeholder="021-xxx-xxxx" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
          <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Keamanan</h4>
          <div class="grid items-center gap-3" style="grid-template-columns: 140px 1fr auto;">
            <span class="text-[14px] text-bimbel-text-mid">Kata sandi</span>
            <span class="text-[14px] text-bimbel-text-mid">Diperbarui beberapa waktu lalu</span>
            <button type="button" class="inline-flex items-center gap-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[14px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="router.push({ name: 'admin.tutoring.change-password' })">
              <NavIcon name="lock" :size="13" /> Ubah sandi
            </button>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

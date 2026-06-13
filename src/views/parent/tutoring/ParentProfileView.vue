<!--
  ParentProfileView — wali profile. Mockup parent_web_pages_account
  frame 3: 2-col layout (avatar card on left, identitas form +
  anak terdaftar + keamanan on right).
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useChildPicker } from '@/composables/useChildPicker';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const auth = useAuthStore();
const { children } = useChildPicker();

const user = computed(() => auth.user);

function initial(name?: string | null): string {
  if (!name) return '?';
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase() ?? '')
    .join('');
}

function goToUbahSandi() {
  router.push({ name: 'parent.tutoring.change-password' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · PROFIL"
      title="Profil wali"
      subtitle="Identitas, anak, dan keamanan akun"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-[#0c447c] px-3 py-1.5 text-[12px] font-bold hover:bg-white/95"
        >Simpan perubahan</button>
      </template>
    </ParentBerandaHero>

    <div class="grid gap-4 lg:grid-cols-5">
      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 text-center lg:col-span-2 h-fit">
        <div class="mx-auto grid h-20 w-20 place-items-center rounded-full bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4] text-2xl font-extrabold">
          {{ initial(user?.name) }}
        </div>
        <p class="mt-3 text-[14px] font-extrabold text-bimbel-text-hi">{{ user?.name ?? '—' }}</p>
        <p class="text-[12px] text-bimbel-text-mid">Wali · {{ children.length }} anak terdaftar</p>
        <dl class="mt-4 space-y-1 text-left text-[12px]">
          <div class="flex items-center gap-2 border-t border-bimbel-border-soft pt-2 text-bimbel-text-mid">
            <NavIcon name="mail" :size="13" />
            <span class="truncate">{{ user?.email ?? '—' }}</span>
          </div>
          <div class="flex items-center gap-2 border-t border-bimbel-border-soft pt-2 text-bimbel-text-mid">
            <NavIcon name="school" :size="13" />
            <span class="truncate">{{ user?.school_name ?? 'Bimbel' }}</span>
          </div>
        </dl>
        <button
          type="button"
          class="mt-3 w-full rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[12px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
        >Ganti foto</button>
      </aside>

      <div class="space-y-3 lg:col-span-3">
        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
          <h4 class="mb-3 text-[13px] font-bold tracking-tight text-bimbel-text-hi">Identitas wali</h4>
          <div class="space-y-2.5">
            <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
              <span class="text-[12px] text-bimbel-text-mid">Nama lengkap</span>
              <input
                type="text"
                :value="user?.name ?? ''"
                class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-1.5 text-[12px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
              />
            </label>
            <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
              <span class="text-[12px] text-bimbel-text-mid">Email</span>
              <input
                type="email"
                :value="user?.email ?? ''"
                disabled
                class="rounded-lg border border-bimbel-border-soft bg-bimbel-bg px-3 py-1.5 text-[12px] text-bimbel-text-mid"
              />
            </label>
            <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
              <span class="text-[12px] text-bimbel-text-mid">No HP / WA</span>
              <input
                type="tel"
                placeholder="08xx-xxxx-xxxx"
                class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-1.5 text-[12px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
              />
            </label>
            <label class="grid items-start gap-3" style="grid-template-columns: 140px 1fr;">
              <span class="pt-1 text-[12px] text-bimbel-text-mid">Alamat</span>
              <textarea
                rows="2"
                placeholder="Alamat lengkap"
                class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-1.5 text-[12px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
              ></textarea>
            </label>
          </div>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
          <h4 class="mb-3 text-[13px] font-bold tracking-tight text-bimbel-text-hi">Anak terdaftar</h4>
          <div v-if="children.length === 0" class="py-4 text-center text-[12px] text-bimbel-text-mid">
            Belum ada anak terdaftar.
          </div>
          <ul class="space-y-1.5">
            <li
              v-for="c in children"
              :key="c.student_id"
              class="flex items-center gap-3 rounded-lg border border-bimbel-border-soft p-2"
            >
              <span class="grid h-8 w-8 place-items-center rounded-full bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4] text-[12px] font-bold">
                {{ initial(c.name) }}
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-[13px] font-bold text-bimbel-text-hi">{{ c.name }}</p>
                <p class="truncate text-[12px] text-bimbel-text-mid">{{ c.class_name }}</p>
              </div>
            </li>
          </ul>
          <button
            type="button"
            class="mt-3 inline-flex items-center gap-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[12px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
            @click="router.push({ name: 'parent.tutoring.enroll-new' })"
          >
            <NavIcon name="plus" :size="12" /> Daftarkan anak baru
          </button>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
          <h4 class="mb-3 text-[13px] font-bold tracking-tight text-bimbel-text-hi">Keamanan</h4>
          <div class="grid items-center gap-3" style="grid-template-columns: 140px 1fr auto;">
            <span class="text-[12px] text-bimbel-text-mid">Kata sandi</span>
            <span class="text-[12px] text-bimbel-text-mid">Diperbarui beberapa waktu lalu</span>
            <button
              type="button"
              class="inline-flex items-center gap-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[12px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
              @click="goToUbahSandi"
            >
              <NavIcon name="lock" :size="12" /> Ubah sandi
            </button>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

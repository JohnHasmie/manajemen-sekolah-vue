<!--
  ParentProfileView — wali profile.

  Mockup-exact: hero + 2/5 + 3/5 grid. Left col = avatar card + Anak
  saya list. Right col = Identitas form + Keamanan section. Reads
  auth.user + useChildPicker().children — no data writes wired yet
  (save() is a placeholder).
-->
<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useChildPicker } from '@/composables/useChildPicker';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const router = useRouter();
const auth = useAuthStore();
const { children } = useChildPicker();

const user = computed(() => auth.user);

// Local-only form state — `save()` is a stub until a wali-profile
// update endpoint exists. Initialize from user when it loads.
const form = reactive({ name: '', phone: '', address: '' });
watch(
  user,
  (u) => {
    if (!u) return;
    if (!form.name) form.name = u.name ?? '';
  },
  { immediate: true },
);

function initials(name?: string | null): string {
  if (!name) return '?';
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase() ?? '')
    .join('');
}

// Cycle through bimbel-palette chip styles for sibling avatars so
// they're visually distinct without raw slate/sky tokens.
const CHILD_RAMP = [
  'bg-bimbel-accent-dim text-bimbel-hero',
  'bg-bimbel-green-dim text-green-700',
  'bg-bimbel-amber-dim text-amber-700',
  'bg-bimbel-red-dim text-red-700',
];
function childChipClass(i: number): string {
  return CHILD_RAMP[i % CHILD_RAMP.length];
}

function save() {
  // Placeholder — wali-profile update endpoint not wired yet.
}
function goPwd() {
  router.push({ name: 'parent.tutoring.change-password' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · WALI"
      title="Profil wali"
      subtitle="Identitas, anak, dan keamanan akun"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-bimbel-hero px-3 py-1.5 text-[13px] font-bold hover:bg-white/95"
          @click="save"
        >
          Simpan perubahan
        </button>
      </template>
    </ParentBerandaHero>

    <div class="grid gap-3.5 lg:grid-cols-5">
      <!-- LEFT: avatar + Anak saya -->
      <aside class="rounded-2xl bg-bimbel-bg p-3.5 text-center lg:col-span-2 h-fit">
        <div class="mx-auto w-16 h-16 rounded-full bg-bimbel-hero text-white text-[22px] font-extrabold grid place-items-center">
          {{ initials(user?.name) }}
        </div>
        <p class="mt-2 text-[14px] font-bold text-bimbel-text-hi">{{ user?.name ?? '—' }}</p>
        <p class="text-[11px] text-bimbel-text-mid">{{ user?.email ?? '—' }}</p>
        <button type="button" class="mt-2.5 text-[11px] font-bold text-bimbel-hero hover:underline">
          Ubah foto
        </button>
        <div class="my-3.5 border-t border-bimbel-border-soft" />
        <p class="text-left text-[11px] font-bold uppercase tracking-wider text-bimbel-text-lo">Anak saya</p>
        <p v-if="!children.length" class="mt-2 text-left text-[12px] text-bimbel-text-mid">
          Belum ada anak terdaftar.
        </p>
        <div
          v-for="(c, i) in children"
          :key="c.student_id"
          class="mt-2 flex items-center gap-2.5 rounded-lg bg-bimbel-panel p-2.5 text-left"
        >
          <span
            class="w-[30px] h-[30px] rounded-full grid place-items-center text-[11px] font-bold flex-shrink-0"
            :class="childChipClass(i)"
          >
            {{ initials(c.name) }}
          </span>
          <div class="min-w-0">
            <p class="text-[12px] font-bold text-bimbel-text-hi truncate">{{ c.name }}</p>
            <p class="text-[11px] text-bimbel-text-mid truncate">{{ c.class_name || 'Kelas —' }}</p>
          </div>
        </div>
      </aside>

      <!-- RIGHT: Identitas + Keamanan -->
      <div class="lg:col-span-3 space-y-3.5">
        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <h4 class="mb-2 text-[13px] font-bold text-bimbel-text-hi">Identitas</h4>
          <label class="grid items-center gap-3 border-b border-bimbel-border-soft py-2" style="grid-template-columns: 110px 1fr;">
            <span class="text-[12px] text-bimbel-text-mid">Nama lengkap</span>
            <input
              v-model="form.name"
              type="text"
              class="rounded-lg bg-bimbel-bg px-2.5 py-1.5 text-[12px] text-bimbel-text-hi focus:outline-none"
            />
          </label>
          <label class="grid items-center gap-3 border-b border-bimbel-border-soft py-2" style="grid-template-columns: 110px 1fr;">
            <span class="text-[12px] text-bimbel-text-mid">Email</span>
            <input
              :value="user?.email ?? ''"
              type="email"
              disabled
              class="rounded-lg bg-bimbel-bg px-2.5 py-1.5 text-[12px] text-bimbel-text-mid"
            />
          </label>
          <label class="grid items-center gap-3 border-b border-bimbel-border-soft py-2" style="grid-template-columns: 110px 1fr;">
            <span class="text-[12px] text-bimbel-text-mid">No. telepon</span>
            <input
              v-model="form.phone"
              type="tel"
              placeholder="08xx-xxxx-xxxx"
              class="rounded-lg bg-bimbel-bg px-2.5 py-1.5 text-[12px] text-bimbel-text-hi focus:outline-none"
            />
          </label>
          <label class="grid items-start gap-3 py-2" style="grid-template-columns: 110px 1fr;">
            <span class="pt-1 text-[12px] text-bimbel-text-mid">Alamat</span>
            <textarea
              v-model="form.address"
              rows="2"
              placeholder="Alamat lengkap"
              class="min-h-12 rounded-lg bg-bimbel-bg px-2.5 py-1.5 text-[12px] text-bimbel-text-hi focus:outline-none"
            />
          </label>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <h4 class="mb-2 text-[13px] font-bold text-bimbel-text-hi">Keamanan</h4>
          <div class="grid items-center gap-3 border-b border-bimbel-border-soft py-2" style="grid-template-columns: 110px 1fr auto;">
            <span class="text-[12px] text-bimbel-text-mid">Kata sandi</span>
            <span class="text-[12px] text-bimbel-text-hi tracking-widest">••••••••</span>
            <button type="button" class="text-[12px] font-bold text-bimbel-hero hover:underline" @click="goPwd">
              Ubah
            </button>
          </div>
          <div class="grid items-center gap-3 py-2" style="grid-template-columns: 110px 1fr auto;">
            <span class="text-[12px] text-bimbel-text-mid">Sesi aktif</span>
            <span class="text-[12px] text-bimbel-text-mid">2 perangkat</span>
            <button type="button" class="text-[12px] font-bold text-bimbel-hero hover:underline">
              Kelola
            </button>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

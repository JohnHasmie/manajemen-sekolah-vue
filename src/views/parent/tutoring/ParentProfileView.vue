<!--
  ParentProfileView — wali profile.

  Redesigned per mockup: hero + 2-col grid. Left col (col-span-2): avatar
  card + "Anak saya" list. Right col (col-span-3): Identitas form +
  Keamanan section. No data-flow changes — still reads auth.user +
  useChildPicker().children.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useChildPicker } from '@/composables/useChildPicker';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

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

// Stable per-child color ramp for the initials chips. Cycles through
// the bimbel palette so siblings get distinct hues without raw
// hardcoded slate/sky/etc.
const CHILD_RAMP = [
  'bg-bimbel-accent-dim text-bimbel-hero',
  'bg-bimbel-green-dim text-green-700',
  'bg-bimbel-amber-dim text-amber-700',
  'bg-bimbel-red-dim text-red-700',
];

function childChipColor(idx: number): string {
  return CHILD_RAMP[idx % CHILD_RAMP.length];
}

function childMeta(c: { class_name?: string }): string {
  const parts: string[] = [];
  if (c.class_name) parts.push(c.class_name);
  // class_name already encodes the school class label — for bimbel the
  // count of kelompok isn't on the Child shape here, so we keep it
  // simple ("Kelas X") and let the wali drill in for details.
  return parts.join(' · ') || 'Belum ada kelas';
}

function goToUbahSandi() {
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
        >
          Simpan perubahan
        </button>
      </template>
    </ParentBerandaHero>

    <div class="grid gap-3.5 lg:grid-cols-5">
      <!-- LEFT col: avatar card + Anak saya list -->
      <aside class="rounded-2xl bg-bimbel-bg p-3.5 text-center lg:col-span-2 h-fit">
        <div
          class="mx-auto grid h-16 w-16 place-items-center rounded-full bg-bimbel-hero text-[22px] font-extrabold text-white"
        >
          {{ initial(user?.name) }}
        </div>
        <p class="mt-2 text-[14px] font-bold text-bimbel-text-hi">
          {{ user?.name ?? '—' }}
        </p>
        <p class="text-[11px] text-bimbel-text-mid">{{ user?.email ?? '—' }}</p>
        <button
          type="button"
          class="mt-2.5 text-[11px] font-bold text-bimbel-hero hover:underline"
        >
          Ubah foto
        </button>

        <div class="my-3.5 border-t border-bimbel-border-soft" />

        <p
          class="text-left text-[11px] font-bold uppercase tracking-wider text-bimbel-text-lo"
        >
          Anak saya
        </p>

        <p
          v-if="children.length === 0"
          class="mt-2 text-left text-[12px] text-bimbel-text-mid"
        >
          Belum ada anak terdaftar.
        </p>

        <div
          v-for="(c, idx) in children"
          :key="c.student_id"
          class="mt-2 flex items-center gap-2.5 rounded-lg bg-bimbel-panel p-2.5 text-left"
        >
          <span
            class="grid h-[30px] w-[30px] flex-shrink-0 place-items-center rounded-full text-[11px] font-bold"
            :class="childChipColor(idx)"
          >
            {{ initial(c.name) }}
          </span>
          <div class="min-w-0">
            <p class="truncate text-[12px] font-bold text-bimbel-text-hi">
              {{ c.name }}
            </p>
            <p class="truncate text-[11px] text-bimbel-text-mid">
              {{ childMeta(c) }}
            </p>
          </div>
        </div>
      </aside>

      <!-- RIGHT col: Identitas + Keamanan -->
      <div class="lg:col-span-3 space-y-3.5">
        <section
          class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5"
        >
          <h4 class="mb-2 text-[13px] font-bold text-bimbel-text-hi">Identitas</h4>

          <label
            class="grid items-center gap-3 border-b border-bimbel-border-soft py-2"
            style="grid-template-columns: 110px 1fr;"
          >
            <span class="text-[12px] text-bimbel-text-mid">Nama lengkap</span>
            <input
              type="text"
              :value="user?.name ?? ''"
              class="rounded-lg bg-bimbel-bg px-2.5 py-1.5 text-[12px] text-bimbel-text-hi focus:outline-none"
            />
          </label>

          <label
            class="grid items-center gap-3 border-b border-bimbel-border-soft py-2"
            style="grid-template-columns: 110px 1fr;"
          >
            <span class="text-[12px] text-bimbel-text-mid">Email</span>
            <input
              type="email"
              :value="user?.email ?? ''"
              disabled
              class="rounded-lg bg-bimbel-bg px-2.5 py-1.5 text-[12px] text-bimbel-text-mid"
            />
          </label>

          <label
            class="grid items-center gap-3 border-b border-bimbel-border-soft py-2"
            style="grid-template-columns: 110px 1fr;"
          >
            <span class="text-[12px] text-bimbel-text-mid">No. telepon</span>
            <input
              type="tel"
              placeholder="08xx-xxxx-xxxx"
              class="rounded-lg bg-bimbel-bg px-2.5 py-1.5 text-[12px] text-bimbel-text-hi focus:outline-none"
            />
          </label>

          <label
            class="grid items-start gap-3 py-2"
            style="grid-template-columns: 110px 1fr;"
          >
            <span class="pt-1 text-[12px] text-bimbel-text-mid">Alamat</span>
            <textarea
              rows="2"
              placeholder="Alamat lengkap"
              class="min-h-12 rounded-lg bg-bimbel-bg px-2.5 py-1.5 text-[12px] text-bimbel-text-hi focus:outline-none"
            />
          </label>
        </section>

        <section
          class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5"
        >
          <h4 class="mb-2 text-[13px] font-bold text-bimbel-text-hi">Keamanan</h4>

          <div
            class="grid items-center gap-3 border-b border-bimbel-border-soft py-2"
            style="grid-template-columns: 110px 1fr auto;"
          >
            <span class="text-[12px] text-bimbel-text-mid">Kata sandi</span>
            <span class="text-[12px] text-bimbel-text-hi tracking-widest">••••••••</span>
            <button
              type="button"
              class="text-[12px] font-bold text-bimbel-hero hover:underline"
              @click="goToUbahSandi"
            >
              Ubah
            </button>
          </div>

          <div
            class="grid items-center gap-3 py-2"
            style="grid-template-columns: 110px 1fr auto;"
          >
            <span class="text-[12px] text-bimbel-text-mid">Sesi aktif</span>
            <span class="text-[12px] text-bimbel-text-hi">1 perangkat</span>
            <button
              type="button"
              class="text-[12px] font-bold text-bimbel-hero hover:underline"
            >
              Kelola
            </button>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

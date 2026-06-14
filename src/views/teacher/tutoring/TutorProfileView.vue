<!--
  TutorProfileView — tutor's own profile + qualifications + security
  shortcut. Mockup tutor_web_pages_profile_rating frame 1.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringTutorStats } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const auth = useAuthStore();

const stats = ref<TutoringTutorStats | null>(null);
const loading = ref(true);

async function load() {
  loading.value = true;
  try { stats.value = await TutoringService.getTutorStats(); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

const user = computed(() => auth.user);

function initials(name?: string | null): string {
  if (!name) return '?';
  return name.split(/\s+/).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('');
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="AKUN · PROFIL TUTOR"
      title="Profil tutor"
      subtitle="Identitas, kontak, dan keamanan akun"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[14px] font-bold hover:opacity-90"
        >Simpan perubahan</button>
      </template>
    </TutorBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else class="grid gap-4 lg:grid-cols-5">
      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 text-center lg:col-span-2 h-fit">
        <div class="mx-auto grid h-20 w-20 place-items-center rounded-full bg-bimbel-accent-dim text-bimbel-accent text-2xl font-extrabold">
          {{ initials(user?.name) }}
        </div>
        <p class="mt-3 text-[15px] font-extrabold text-bimbel-text-hi">{{ user?.name ?? '—' }}</p>
        <p class="text-[12px] text-bimbel-text-mid">Tutor · {{ stats?.groups ?? 0 }} kelas</p>
        <dl class="mt-4 space-y-1 text-left text-[13px]">
          <div class="flex justify-between border-t border-bimbel-border-soft pt-2"><dt class="text-bimbel-text-mid">Email</dt><dd class="font-bold truncate">{{ user?.email ?? '—' }}</dd></div>
          <div class="flex justify-between border-t border-bimbel-border-soft pt-2"><dt class="text-bimbel-text-mid">Pengalaman</dt><dd class="font-bold">—</dd></div>
          <div class="flex justify-between border-t border-bimbel-border-soft pt-2"><dt class="text-bimbel-text-mid">Rating rata</dt>
            <dd class="font-bold">{{ stats?.rating_avg?.toFixed(1) ?? '–' }} <span class="text-bimbel-text-mid font-normal text-[12px]">· {{ stats?.rating_count ?? 0 }} ulasan</span></dd>
          </div>
        </dl>
        <button class="mt-3 w-full rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft">Ganti foto</button>
      </aside>

      <div class="space-y-3 lg:col-span-3">
        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-2.5">
          <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">Identitas</h4>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[13px] text-bimbel-text-mid">Nama lengkap</span>
            <input type="text" :value="user?.name ?? ''" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[13px] text-bimbel-text-mid">Email</span>
            <input type="email" :value="user?.email ?? ''" disabled class="rounded-lg border border-bimbel-border-soft bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-mid" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[13px] text-bimbel-text-mid">No HP / WA</span>
            <input type="tel" placeholder="08xx-xxxx-xxxx" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-start gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="pt-1 text-[13px] text-bimbel-text-mid">Alamat</span>
            <textarea rows="2" placeholder="Alamat lengkap" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"></textarea>
          </label>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-2.5">
          <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">Kualifikasi</h4>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[13px] text-bimbel-text-mid">Mata pelajaran</span>
            <input type="text" placeholder="Matematika SMP" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-start gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="pt-1 text-[13px] text-bimbel-text-mid">Bio singkat</span>
            <textarea rows="2" placeholder="Latar belakang singkat untuk wali / siswa" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"></textarea>
          </label>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
          <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Keamanan</h4>
          <div class="grid items-center gap-3" style="grid-template-columns: 140px 1fr auto;">
            <span class="text-[13px] text-bimbel-text-mid">Kata sandi</span>
            <span class="text-[13px] text-bimbel-text-mid">Diperbarui beberapa waktu lalu</span>
            <button
              type="button"
              class="inline-flex items-center gap-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
              @click="router.push({ name: 'teacher.tutoring.change-password' })"
            >
              <NavIcon name="lock" :size="13" /> Ubah sandi
            </button>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

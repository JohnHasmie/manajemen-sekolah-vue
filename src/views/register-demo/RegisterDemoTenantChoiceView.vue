<!--
  RegisterDemoTenantChoiceView — the new front door for the demo
  wizard. Lives at /register-demo. Two big choices, then routes
  into the conversational wizard at /register-demo/wizard with the
  tenant flag set.

  Replaces the legacy welcome step. The old wizard remains at
  /register-demo/legacy as a temporary fallback (cleaned up later).
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import { DemoService } from '@/services/demo.service';
import type { DemoRegistrationItem, ActiveSchoolItem } from '@/types/demo';
import ExistingRegistrationsBanner from '@/components/demo/ExistingRegistrationsBanner.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import PublicLanguageSwitcher from '@/components/feature/PublicLanguageSwitcher.vue';

const router = useRouter();
const wizard = useDemoWizardStore();

const demoRequests = ref<DemoRegistrationItem[]>([]);
const activeSchools = ref<ActiveSchoolItem[]>([]);
const isLoadingReg = ref(false);
const showExistingBanner = ref(true);

onMounted(async () => {
  await wizard.hydrate();
  
  isLoadingReg.value = true;
  try {
    const res = await DemoService.getMyRegistrations();
    demoRequests.value = res.demo_requests || [];
    activeSchools.value = res.active_schools || [];
    if (demoRequests.value.length === 0 && activeSchools.value.length === 0) {
      showExistingBanner.value = false;
    }
  } catch (err) {
    console.error('Failed to load registrations:', err);
    showExistingBanner.value = false;
  } finally {
    isLoadingReg.value = false;
  }
});

function pick(t: 'sekolah' | 'bimbel') {
  wizard.setTenantType(t);
  router.push('/register-demo/wizard');
}
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-50">
    <!-- Topbar -->
    <header class="bg-white border-b border-slate-200">
      <div class="max-w-5xl mx-auto px-6 h-16 flex items-center justify-between">
        <router-link to="/" class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-brand-dark-blue text-white text-sm font-black grid place-items-center">
            K
          </div>
          <div>
            <div class="text-sm font-bold text-slate-900 leading-tight">KamilEdu</div>
            <div class="text-[10px] text-slate-500 font-medium">Daftar demo gratis</div>
          </div>
        </router-link>
        <div class="flex items-center gap-4">
          <PublicLanguageSwitcher />
          <router-link
            to="/login?intent=demo"
            class="text-xs font-semibold text-slate-500 hover:text-brand-cobalt"
          >
            Sudah punya akun? <span class="text-brand-cobalt">Masuk</span>
          </router-link>
        </div>
      </div>
    </header>

    <!-- Body -->
    <main class="flex-1 flex items-center justify-center px-6 py-10">
      <div class="w-full max-w-4xl">
        <div class="text-center mb-10">
          <p class="text-[11px] font-black tracking-[0.3em] uppercase text-brand-cobalt mb-3">
            Langkah 1 dari 2 — pilih jenis lembaga
          </p>
          <h1 class="text-3xl sm:text-4xl font-bold text-slate-900 tracking-tight mb-3">
            Apa yang ingin Anda kelola?
          </h1>
          <p class="text-sm sm:text-base text-slate-500 max-w-xl mx-auto leading-relaxed">
            Kami siapkan demo dengan data dummy yang relevan sesuai jenis lembaga Anda — agar bisa langsung
            diuji tanpa setup manual.
          </p>
        </div>

        <template v-if="isLoadingReg">
          <div class="flex justify-center py-10">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-brand-cobalt"></div>
          </div>
        </template>
        <template v-else>
          <!-- Existing Registrations Banner -->
          <ExistingRegistrationsBanner
            v-if="showExistingBanner"
            :demo-requests="demoRequests"
            :active-schools="activeSchools"
            @daftar-baru="showExistingBanner = false"
          />

          <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <!-- Sekolah -->
            <button
              type="button"
              class="group bg-white border border-slate-200 hover:border-brand-cobalt hover:shadow-card rounded-2xl p-7 text-left transition"
              @click="pick('sekolah')"
            >
              <div class="w-12 h-12 rounded-xl bg-blue-50 text-blue-700 grid place-items-center mb-4">
                <NavIcon name="building" :size="22" />
              </div>
              <h2 class="text-lg font-bold text-slate-900 mb-1.5">Sekolah formal</h2>
              <p class="text-[13px] text-slate-500 leading-relaxed mb-4">
                SD, SMP, SMA, atau SMK. Kelola siswa, guru, kelas, jadwal, raport, presensi.
              </p>
              <div class="flex flex-wrap gap-1.5 mb-5">
                <span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-50 text-slate-600 font-medium">
                  Kelas & wali kelas
                </span>
                <span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-50 text-slate-600 font-medium">
                  Mapel & nilai
                </span>
                <span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-50 text-slate-600 font-medium">
                  Raport
                </span>
                <span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-50 text-slate-600 font-medium">
                  Presensi
                </span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-xs font-semibold text-brand-cobalt inline-flex items-center gap-1.5 group-hover:gap-2 transition-all">
                  Pilih sekolah
                  <NavIcon name="arrow-right" :size="14" />
                </span>
                <span class="text-[10.5px] text-slate-400 font-medium">~2 menit setup</span>
              </div>
            </button>

            <!-- Bimbel -->
            <button
              type="button"
              class="group bg-white border-2 border-brand-cobalt rounded-2xl p-7 text-left transition hover:shadow-card relative"
              @click="pick('bimbel')"
            >
              <span class="absolute top-3 right-3 text-[10px] font-black uppercase tracking-widest bg-brand-cobalt text-white px-2 py-0.5 rounded-md">
                Baru
              </span>
              <div class="w-12 h-12 rounded-xl bg-indigo-50 text-indigo-700 grid place-items-center mb-4">
                <NavIcon name="book" :size="22" />
              </div>
              <h2 class="text-lg font-bold text-slate-900 mb-1.5">Bimbel / lembaga</h2>
              <p class="text-[13px] text-slate-500 leading-relaxed mb-4">
                Bimbel, kursus, atau private tutoring. Kelola tutor, program, sesi, honor, tagihan.
              </p>
              <div class="flex flex-wrap gap-1.5 mb-5">
                <span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-50 text-slate-600 font-medium">
                  Program & paket
                </span>
                <span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-50 text-slate-600 font-medium">
                  Sesi & tutor
                </span>
                <span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-50 text-slate-600 font-medium">
                  Honor & tagihan
                </span>
                <span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-50 text-slate-600 font-medium">
                  Voucher & leads
                </span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-xs font-semibold text-brand-cobalt inline-flex items-center gap-1.5 group-hover:gap-2 transition-all">
                  Pilih bimbel
                  <NavIcon name="arrow-right" :size="14" />
                </span>
                <span class="text-[10.5px] text-slate-400 font-medium">~2 menit setup</span>
              </div>
            </button>
          </div>
        </template>

      </div>
    </main>
  </div>
</template>

<!--
  Step 1 — Welcome.
  No form binding; pure intro. Footer's "Mulai" advances to step 2.
  Intentionally does NOT mention the 30-day expiry — that's a
  dashboard surprise.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';
</script>

<template>
  <div class="text-center max-w-md mx-auto py-4">
    <div class="w-16 h-16 rounded-2xl bg-role-admin/10 mx-auto mb-5 flex items-center justify-center">
      <NavIcon name="school" :size="32" class="text-role-admin" />
    </div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      Selamat datang
    </p>
    <h2 class="text-[22px] font-black text-slate-900 mb-2 leading-tight">
      Bangun sekolah demo Anda
    </h2>
    <p class="text-[13.5px] text-slate-600 leading-relaxed">
      11 pertanyaan singkat. Sekitar 2 menit. Semua bisa diubah nanti.
    </p>

    <ul class="text-left mt-6 space-y-3 max-w-sm mx-auto">
      <li
        v-for="bullet in [
          'Data realistis dengan nama Indonesia',
          'Cek dulu sekolah Anda — jangan sampai dobel',
          'Akun untuk admin, guru, dan wali — bisa coba semua',
          'Bisa lanjut nanti — progress tersimpan',
        ]"
        :key="bullet"
        class="flex items-start gap-2.5 text-[13px] text-slate-700"
      >
        <span class="w-5 h-5 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center flex-shrink-0 mt-0.5">
          <NavIcon name="check" :size="11" />
        </span>
        {{ bullet }}
      </li>
    </ul>
  </div>
</template>

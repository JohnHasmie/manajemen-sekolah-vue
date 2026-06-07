<!--
  Step 1 — Welcome.
  No form binding; pure intro. Footer's "Mulai" advances to step 2.
  Intentionally does NOT mention the 30-day expiry — that's a
  dashboard surprise.
-->
<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
</script>

<template>
  <div class="text-center max-w-md mx-auto py-4">
    <div class="w-16 h-16 rounded-2xl bg-role-admin/10 mx-auto mb-5 flex items-center justify-center">
      <NavIcon name="school" :size="32" class="text-role-admin" />
    </div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.step1Label') }}
    </p>
    <h2 class="text-[22px] font-black text-slate-900 mb-2 leading-tight">
      {{ t('registerDemo.step1Title') }}
    </h2>
    <p class="text-[13.5px] text-slate-600 leading-relaxed">
      {{ t('registerDemo.step1Subtitle') }}
    </p>

    <ul class="text-left mt-6 space-y-3 max-w-sm mx-auto">
      <li
        v-for="bullet in [
          t('registerDemo.step1Bullet1'),
          t('registerDemo.step1Bullet2'),
          t('registerDemo.step1Bullet3'),
          t('registerDemo.step1Bullet4'),
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

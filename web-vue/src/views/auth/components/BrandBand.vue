<!--
  BrandBand.vue — the gradient hero on the login screen.
  `compact` mode shrinks the band when on the OTP / school / role steps
  so the picker / OTP body has more vertical room (matches Flutter's
  Frame B/C/D behaviour from `auth_login_school_role_redesign.html`).
-->
<script setup lang="ts">
defineProps<{ compact?: boolean }>();
</script>

<template>
  <div
    class="brand-band w-full transition-all duration-200"
    :class="compact ? 'pt-md pb-xl' : 'pt-xl pb-12 sm:pb-16'"
  >
    <div
      class="mx-auto max-w-md px-md text-center"
      :class="compact ? 'space-y-1' : 'space-y-3.5'"
    >
      <!-- Logo Mark -->
      <div
        class="inline-flex items-center justify-center bg-white"
        :class="compact 
          ? 'w-7 h-7 rounded-md' 
          : 'w-[76px] h-[76px] rounded-logo-card shadow-lifted-logo mb-3.5'"
      >
        <!-- KamilEdu logo — assets/icon/KamilEdu.png from the Flutter app. -->
        <img
          src="/icon/KamilEdu.png"
          alt="KamilEdu"
          class="object-contain"
          :class="compact ? 'w-[17px] h-[17px]' : 'w-[47px] h-[47px]'"
        />
      </div>

      <!-- Wordmark -->
      <div 
        class="flex items-center justify-center leading-none"
        :class="compact ? 'inline-flex align-middle ml-2' : 'flex-col'"
      >
        <h1
          class="tracking-tight text-white"
          :class="compact ? 'text-[18px]' : 'text-[24px]'"
        >
          <span class="font-black">Kamil</span>
          <span class="font-medium opacity-85">Edu</span>
        </h1>
      </div>

      <!-- Tagline (Desktop/Full only) -->
      <p
        v-if="!compact"
        class="text-white/85 text-[11.5px] font-semibold tracking-[0.2px] max-w-xs mx-auto"
      >
        Platform Manajemen Sekolah Terpadu
      </p>
    </div>
  </div>
</template>

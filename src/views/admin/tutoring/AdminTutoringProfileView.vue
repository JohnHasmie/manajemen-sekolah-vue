<!--
  AdminTutoringProfileView — admin profile + bimbel info + security.
  Mockup admin_web_pages_account frame 1.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
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
    <TutorHomeHero
      :greeting="t('admin.bimbel.profile.hero_kicker')"
      :title="t('admin.bimbel.profile.hero_title')"
      :subtitle="t('admin.bimbel.profile.hero_subtitle')"
      :stats="[]"
    >
      <template #actions>
        <button class="rounded-lg bg-white text-tutoring-accent px-3 py-1.5 text-[14px] font-bold">{{ t('admin.bimbel.profile.save') }}</button>
      </template>
    </TutorHomeHero>

    <div class="grid gap-4 lg:grid-cols-5">
      <aside class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-4 text-center lg:col-span-2 h-fit">
        <div class="mx-auto grid h-20 w-20 place-items-center rounded-full bg-tutoring-accent-dim text-tutoring-accent text-2xl font-extrabold">{{ initials(user?.name) }}</div>
        <p class="mt-3 text-[15px] font-extrabold text-tutoring-text-hi">{{ user?.name ?? '—' }}</p>
        <p class="text-[13px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.role_admin', { school: user?.school_name ?? 'Bimbel' }) }}</p>
        <dl class="mt-4 space-y-1 text-left text-[14px]">
          <div class="flex justify-between border-t border-tutoring-border-soft pt-2"><dt class="text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_email') }}</dt><dd class="font-bold truncate">{{ user?.email ?? '—' }}</dd></div>
          <div class="flex justify-between border-t border-tutoring-border-soft pt-2"><dt class="text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_joined') }}</dt><dd class="font-bold">—</dd></div>
        </dl>
        <button class="mt-3 w-full rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-1.5 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft">{{ t('admin.bimbel.profile.change_photo') }}</button>
      </aside>

      <div class="space-y-3 lg:col-span-3">
        <section class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-4 space-y-2.5">
          <h4 class="text-[15px] font-bold tracking-tight text-tutoring-text-hi">{{ t('admin.bimbel.profile.section_operator') }}</h4>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_name') }}</span>
            <input type="text" :value="user?.name ?? ''" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_email') }}</span>
            <input type="email" :value="user?.email ?? ''" disabled class="rounded-lg border border-tutoring-border-soft bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-mid" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_phone') }}</span>
            <input type="tel" :placeholder="t('admin.bimbel.profile.phone_ph')" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
          </label>
        </section>

        <section class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-4 space-y-2.5">
          <h4 class="text-[15px] font-bold tracking-tight text-tutoring-text-hi">{{ t('admin.bimbel.profile.section_center') }}</h4>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_center_name') }}</span>
            <input type="text" :value="user?.school_name ?? ''" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
          </label>
          <label class="grid items-start gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="pt-1 text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_address') }}</span>
            <textarea rows="2" :placeholder="t('admin.bimbel.profile.address_ph')" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none"></textarea>
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_office_phone') }}</span>
            <input type="tel" :placeholder="t('admin.bimbel.profile.office_phone_ph')" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
          </label>
        </section>

        <section class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-4">
          <h4 class="mb-2 text-[15px] font-bold tracking-tight text-tutoring-text-hi">{{ t('admin.bimbel.profile.section_security') }}</h4>
          <div class="grid items-center gap-3" style="grid-template-columns: 140px 1fr auto;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.field_password') }}</span>
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.profile.password_updated_hint') }}</span>
            <button type="button" class="inline-flex items-center gap-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-1.5 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft" @click="router.push({ name: 'admin.tutoring.change-password' })">
              <NavIcon name="lock" :size="13" /> {{ t('admin.bimbel.profile.change_password') }}
            </button>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

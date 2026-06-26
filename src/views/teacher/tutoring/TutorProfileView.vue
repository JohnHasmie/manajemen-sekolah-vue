<!--
  TutorProfileView — tutor's own profile + qualifications + security
  shortcut. Mockup tutor_web_pages_profile_rating frame 1.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringTutorStats } from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
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
    <TutorHomeHero
      :greeting="t('tutor.bimbel.profile.greeting')"
      :title="t('tutor.bimbel.profile.title')"
      :subtitle="t('tutor.bimbel.profile.subtitle')"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[14px] font-bold hover:opacity-90"
        >{{ t('tutor.bimbel.profile.save_changes_btn') }}</button>
      </template>
    </TutorHomeHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">{{ t('tutor.bimbel.profile.loading') }}</div>

    <div v-else class="grid gap-4 lg:grid-cols-5">
      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 text-center lg:col-span-2 h-fit">
        <div class="mx-auto grid h-20 w-20 place-items-center rounded-full bg-bimbel-accent-dim text-bimbel-accent text-2xl font-extrabold">
          {{ initials(user?.name) }}
        </div>
        <p class="mt-3 text-[15px] font-extrabold text-bimbel-text-hi">{{ user?.name ?? '—' }}</p>
        <p class="text-[12px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.role_meta', { count: stats?.groups ?? 0 }) }}</p>
        <dl class="mt-4 space-y-1 text-left text-[13px]">
          <div class="flex justify-between border-t border-bimbel-border-soft pt-2"><dt class="text-bimbel-text-mid">{{ t('tutor.bimbel.profile.dl_email') }}</dt><dd class="font-bold truncate">{{ user?.email ?? '—' }}</dd></div>
          <div class="flex justify-between border-t border-bimbel-border-soft pt-2"><dt class="text-bimbel-text-mid">{{ t('tutor.bimbel.profile.dl_experience') }}</dt><dd class="font-bold">—</dd></div>
          <div class="flex justify-between border-t border-bimbel-border-soft pt-2"><dt class="text-bimbel-text-mid">{{ t('tutor.bimbel.profile.dl_rating') }}</dt>
            <dd class="font-bold">{{ stats?.rating_avg?.toFixed(1) ?? '–' }} <span class="text-bimbel-text-mid font-normal text-[12px]">· {{ stats?.rating_count ?? 0 }} {{ t('tutor.bimbel.profile.rating_reviews_suffix') }}</span></dd>
          </div>
        </dl>
        <button class="mt-3 w-full rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft">{{ t('tutor.bimbel.profile.change_photo') }}</button>
      </aside>

      <div class="space-y-3 lg:col-span-3">
        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-2.5">
          <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('tutor.bimbel.profile.section_identity') }}</h4>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[13px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.field_full_name') }}</span>
            <input type="text" :value="user?.name ?? ''" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[13px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.field_email') }}</span>
            <input type="email" :value="user?.email ?? ''" disabled class="rounded-lg border border-bimbel-border-soft bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-mid" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[13px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.field_phone') }}</span>
            <input type="tel" :placeholder="t('tutor.bimbel.profile.field_phone_placeholder')" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-start gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="pt-1 text-[13px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.field_address') }}</span>
            <textarea rows="2" :placeholder="t('tutor.bimbel.profile.field_address_placeholder')" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"></textarea>
          </label>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-2.5">
          <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('tutor.bimbel.profile.section_qualifications') }}</h4>
          <label class="grid items-center gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="text-[13px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.field_subject') }}</span>
            <input type="text" :placeholder="t('tutor.bimbel.profile.field_subject_placeholder')" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-start gap-3" style="grid-template-columns: 140px 1fr;">
            <span class="pt-1 text-[13px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.field_bio') }}</span>
            <textarea rows="2" :placeholder="t('tutor.bimbel.profile.field_bio_placeholder')" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"></textarea>
          </label>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
          <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('tutor.bimbel.profile.section_security') }}</h4>
          <div class="grid items-center gap-3" style="grid-template-columns: 140px 1fr auto;">
            <span class="text-[13px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.field_password') }}</span>
            <span class="text-[13px] text-bimbel-text-mid">{{ t('tutor.bimbel.profile.password_updated') }}</span>
            <button
              type="button"
              class="inline-flex items-center gap-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
              @click="router.push({ name: 'teacher.tutoring.change-password' })"
            >
              <NavIcon name="lock" :size="13" /> {{ t('tutor.bimbel.profile.change_password_btn') }}
            </button>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

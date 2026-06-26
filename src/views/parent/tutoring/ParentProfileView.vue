<!--
  ParentProfileView — parent profile.

  Mockup-exact: hero + 2/5 + 3/5 grid. Left col = avatar card + Anak
  saya list. Right col = Identitas form + Keamanan section. Reads
  auth.user + useChildPicker().children — no data writes wired yet
  (save() is a placeholder).
-->
<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { useChildPicker } from '@/composables/useChildPicker';

import ParentHomeHero from '@/components/feature/tutoring/ParentHomeHero.vue';

const { t } = useI18n();
const router = useRouter();
const auth = useAuthStore();
const { children } = useChildPicker();

const user = computed(() => auth.user);

// Local-only form state — `save()` is a stub until a parent-profile
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
  'bg-tutoring-accent-dim text-tutoring-hero',
  'bg-tutoring-green-dim text-green-700',
  'bg-tutoring-amber-dim text-amber-700',
  'bg-tutoring-red-dim text-red-700',
];
function childChipClass(i: number): string {
  return CHILD_RAMP[i % CHILD_RAMP.length];
}

function save() {
  // Placeholder — parent-profile update endpoint not wired yet.
}
function goPwd() {
  router.push({ name: 'parent.tutoring.change-password' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentHomeHero
      :kicker="t('wali.bimbel.profile.kicker')"
      :title="t('wali.bimbel.profile.title')"
      :subtitle="t('wali.bimbel.profile.subtitle')"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-tutoring-hero px-3 py-1.5 text-[14px] font-bold hover:bg-white/95"
          @click="save"
        >
          {{ t('wali.bimbel.profile.save_changes') }}
        </button>
      </template>
    </ParentHomeHero>

    <div class="grid gap-3.5 lg:grid-cols-5">
      <!-- LEFT: avatar + Anak saya -->
      <aside class="rounded-2xl bg-tutoring-bg p-3.5 text-center lg:col-span-2 h-fit">
        <div class="mx-auto w-16 h-16 rounded-full bg-tutoring-hero text-white text-[22px] font-extrabold grid place-items-center">
          {{ initials(user?.name) }}
        </div>
        <p class="mt-2 text-[14px] font-bold text-tutoring-text-hi">{{ user?.name ?? '—' }}</p>
        <p class="text-[12px] text-tutoring-text-mid">{{ user?.email ?? '—' }}</p>
        <button type="button" class="mt-2.5 text-[12px] font-bold text-tutoring-hero hover:underline">
          {{ t('wali.bimbel.profile.change_photo') }}
        </button>
        <div class="my-3.5 border-t border-tutoring-border-soft" />
        <p class="text-left text-[12px] font-bold uppercase tracking-wider text-tutoring-text-lo">{{ t('wali.bimbel.profile.my_children_heading') }}</p>
        <p v-if="!children.length" class="mt-2 text-left text-[13px] text-tutoring-text-mid">
          {{ t('wali.bimbel.profile.no_children') }}
        </p>
        <div
          v-for="(c, i) in children"
          :key="c.student_id"
          class="mt-2 flex items-center gap-2.5 rounded-lg bg-tutoring-panel p-2.5 text-left"
        >
          <span
            class="w-[30px] h-[30px] rounded-full grid place-items-center text-[12px] font-bold flex-shrink-0"
            :class="childChipClass(i)"
          >
            {{ initials(c.name) }}
          </span>
          <div class="min-w-0">
            <p class="text-[13px] font-bold text-tutoring-text-hi truncate">{{ c.name }}</p>
            <p class="text-[12px] text-tutoring-text-mid truncate">{{ c.class_name || t('wali.bimbel.profile.default_class_name') }}</p>
          </div>
        </div>
      </aside>

      <!-- RIGHT: Identitas + Keamanan -->
      <div class="lg:col-span-3 space-y-3.5">
        <section class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
          <h4 class="mb-2 text-[14px] font-bold text-tutoring-text-hi">{{ t('wali.bimbel.profile.identity_heading') }}</h4>
          <label class="grid items-center gap-3 border-b border-tutoring-border-soft py-2" style="grid-template-columns: 110px 1fr;">
            <span class="text-[13px] text-tutoring-text-mid">{{ t('wali.bimbel.profile.name_label') }}</span>
            <input
              v-model="form.name"
              type="text"
              class="rounded-lg bg-tutoring-bg px-2.5 py-1.5 text-[13px] text-tutoring-text-hi focus:outline-none"
            />
          </label>
          <label class="grid items-center gap-3 border-b border-tutoring-border-soft py-2" style="grid-template-columns: 110px 1fr;">
            <span class="text-[13px] text-tutoring-text-mid">{{ t('wali.bimbel.profile.email_label') }}</span>
            <input
              :value="user?.email ?? ''"
              type="email"
              disabled
              class="rounded-lg bg-tutoring-bg px-2.5 py-1.5 text-[13px] text-tutoring-text-mid"
            />
          </label>
          <label class="grid items-center gap-3 border-b border-tutoring-border-soft py-2" style="grid-template-columns: 110px 1fr;">
            <span class="text-[13px] text-tutoring-text-mid">{{ t('wali.bimbel.profile.phone_label') }}</span>
            <input
              v-model="form.phone"
              type="tel"
              :placeholder="t('wali.bimbel.profile.phone_placeholder')"
              class="rounded-lg bg-tutoring-bg px-2.5 py-1.5 text-[13px] text-tutoring-text-hi focus:outline-none"
            />
          </label>
          <label class="grid items-start gap-3 py-2" style="grid-template-columns: 110px 1fr;">
            <span class="pt-1 text-[13px] text-tutoring-text-mid">{{ t('wali.bimbel.profile.address_label') }}</span>
            <textarea
              v-model="form.address"
              rows="2"
              :placeholder="t('wali.bimbel.profile.address_placeholder')"
              class="min-h-12 rounded-lg bg-tutoring-bg px-2.5 py-1.5 text-[13px] text-tutoring-text-hi focus:outline-none"
            />
          </label>
        </section>

        <section class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
          <h4 class="mb-2 text-[14px] font-bold text-tutoring-text-hi">{{ t('wali.bimbel.profile.security_heading') }}</h4>
          <div class="grid items-center gap-3 border-b border-tutoring-border-soft py-2" style="grid-template-columns: 110px 1fr auto;">
            <span class="text-[13px] text-tutoring-text-mid">{{ t('wali.bimbel.profile.password_label') }}</span>
            <span class="text-[13px] text-tutoring-text-hi tracking-widest">••••••••</span>
            <button type="button" class="text-[13px] font-bold text-tutoring-hero hover:underline" @click="goPwd">
              {{ t('wali.bimbel.profile.change_password') }}
            </button>
          </div>
          <div class="grid items-center gap-3 py-2" style="grid-template-columns: 110px 1fr auto;">
            <span class="text-[13px] text-tutoring-text-mid">{{ t('wali.bimbel.profile.sessions_label') }}</span>
            <span class="text-[13px] text-tutoring-text-mid">{{ t('wali.bimbel.profile.sessions_count', { count: 2 }) }}</span>
            <button type="button" class="text-[13px] font-bold text-tutoring-hero hover:underline">
              {{ t('wali.bimbel.profile.manage_sessions') }}
            </button>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

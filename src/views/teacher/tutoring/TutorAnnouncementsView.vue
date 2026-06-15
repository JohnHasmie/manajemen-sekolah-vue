<!--
  TutorAnnouncementsView — group announcements list + compose form.
  Mockup tutor_web_pages_notif_announce_rank frame 2.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import type {
  TutoringGroup,
  TutoringGroupAnnouncement,
} from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const auth = useAuthStore();

const loading = ref(true);
const groups = ref<TutoringGroup[]>([]);
const announcements = ref<TutoringGroupAnnouncement[]>([]);
const groupFilter = ref<string>('');

const form = ref({ group_id: '', title: '', body: '' });
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

async function load() {
  loading.value = true;
  try {
    const [g, a] = await Promise.all([
      TutoringService.getAllGroups().catch(() => []),
      TutoringService.getGroupAnnouncements({}).catch(() => []),
    ]);
    groups.value = (g as TutoringGroup[]).filter((x) => x.tutor_user_id === auth.user?.id);
    announcements.value = a as TutoringGroupAnnouncement[];
  } finally { loading.value = false; }
}
onMounted(load);

const filtered = computed(() => {
  if (!groupFilter.value) return announcements.value;
  return announcements.value.filter((a) => a.tutoring_group_id === groupFilter.value);
});

const canPost = computed(() =>
  form.value.group_id && form.value.title.trim().length >= 2 && form.value.body.trim().length >= 4 && !saving.value,
);

async function post() {
  if (!canPost.value) return;
  saving.value = true; message.value = null;
  try {
    await TutoringService.createGroupAnnouncement({
      tutoring_group_id: form.value.group_id,
      title: form.value.title,
      body: form.value.body,
    });
    message.value = { kind: 'ok', text: t('tutor.bimbel.announcements.sent_ok') };
    form.value = { group_id: '', title: '', body: '' };
    await load();
  } catch (e) {
    message.value = { kind: 'err', text: e instanceof Error ? e.message : t('tutor.bimbel.announcements.post_failed') };
  } finally { saving.value = false; }
}

function rel(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diff = (Date.now() - d.valueOf()) / 60_000;
  if (diff < 60) return t('tutor.bimbel.announcements.rel_min_ago', { n: Math.max(1, Math.floor(diff)) });
  const h = Math.floor(diff / 60);
  if (h < 24) return t('tutor.bimbel.announcements.rel_hour_ago', { n: h });
  const days = Math.floor(h / 24);
  if (days < 7) return t('tutor.bimbel.announcements.rel_day_ago', { n: days });
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

function groupName(id: string): string {
  return groups.value.find((g) => g.id === id)?.name ?? t('tutor.bimbel.announcements.no_group_dash');
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      :greeting="t('tutor.bimbel.announcements.greeting')"
      :title="t('tutor.bimbel.announcements.title')"
      :subtitle="t('tutor.bimbel.announcements.subtitle')"
      :stats="[]"
    />

    <div class="flex gap-1.5 flex-wrap">
      <button
        type="button"
        class="rounded-full border px-3 py-1.5 text-[13px] font-semibold"
        :class="groupFilter === '' ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
        @click="groupFilter = ''"
      >{{ t('tutor.bimbel.announcements.filter_all') }}</button>
      <button
        v-for="g in groups"
        :key="g.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[13px] font-semibold"
        :class="groupFilter === g.id ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
        @click="groupFilter = g.id"
      >{{ g.name }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">{{ t('tutor.bimbel.announcements.loading') }}</div>

    <div v-else class="grid gap-4 lg:grid-cols-5">
      <div class="space-y-3 lg:col-span-3">
        <div v-if="filtered.length === 0" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
          {{ t('tutor.bimbel.announcements.empty') }}
        </div>
        <article
          v-for="a in filtered"
          :key="a.id"
          class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5"
        >
          <div class="flex items-center gap-2 mb-1 text-[13px] text-bimbel-text-mid">
            <span>{{ t('tutor.bimbel.announcements.author_self') }} · {{ rel(a.created_at) }}</span>
            <span class="ml-auto rounded-full bg-bimbel-accent-dim text-bimbel-accent px-2 py-0.5 text-[12px]">
              {{ groupName(a.tutoring_group_id) }}
            </span>
          </div>
          <h3 class="text-[14px] font-extrabold tracking-tight text-bimbel-text-hi">{{ a.title }}</h3>
          <p class="mt-1 text-[13px] text-bimbel-text-mid leading-relaxed">{{ a.body }}</p>
        </article>
      </div>

      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-2 h-fit space-y-2.5">
        <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('tutor.bimbel.announcements.compose_title') }}</h4>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('tutor.bimbel.announcements.field_group') }} <span class="text-rose-500">*</span></span>
          <select v-model="form.group_id" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none">
            <option value="">{{ t('tutor.bimbel.announcements.field_group_placeholder') }}</option>
            <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
          </select>
        </label>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('tutor.bimbel.announcements.field_title') }} <span class="text-rose-500">*</span></span>
          <input v-model="form.title" type="text" :placeholder="t('tutor.bimbel.announcements.field_title_placeholder')" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('tutor.bimbel.announcements.field_body') }} <span class="text-rose-500">*</span></span>
          <textarea v-model="form.body" rows="4" :placeholder="t('tutor.bimbel.announcements.field_body_placeholder')" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"></textarea>
        </label>
        <div v-if="message" class="rounded-lg px-3 py-2 text-[13px]" :class="message.kind === 'ok' ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300' : 'bg-rose-500/10 text-rose-700 dark:text-rose-300'">{{ message.text }}</div>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[14px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="form = { group_id: '', title: '', body: '' }">{{ t('tutor.bimbel.announcements.cancel') }}</button>
          <button type="button" :disabled="!canPost" class="flex-1 rounded-lg bg-bimbel-accent px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="post">
            <NavIcon name="megaphone" :size="13" class="inline -mt-0.5" /> {{ saving ? t('tutor.bimbel.announcements.posting') : t('tutor.bimbel.announcements.post_btn') }}
          </button>
        </div>
      </aside>
    </div>
  </div>
</template>

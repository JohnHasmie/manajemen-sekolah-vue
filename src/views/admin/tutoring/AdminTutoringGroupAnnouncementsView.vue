<!--
  AdminTutoringGroupAnnouncementsView — bimbel announcement per
  group. Audience filter (semua / per group) + tulis CTA →
  list of broadcast cards with delivery footer.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { formatDateShort } from '@/lib/format';
import type {
  TutoringGroup,
  TutoringGroupAnnouncement,
} from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const toast = useToast();
const { confirm } = useConfirm();
const { t } = useI18n();

const groupId = ref(String(route.query.groupId ?? ''));
const groups = ref<TutoringGroup[]>([]);
const rows = ref<TutoringGroupAnnouncement[]>([]);
const loading = ref(true);

const showCompose = ref(false);
const fGroupId = ref('');
const fTitle = ref('');
const fBody = ref('');
const saving = ref(false);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getGroupAnnouncements(
      groupId.value ? { group_id: groupId.value } : {},
    );
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.group_announcements.load_fail'));
  } finally { loading.value = false; }
}

onMounted(async () => {
  try { groups.value = await TutoringService.getAllGroups(); } catch {/* non-fatal */}
  await load();
});

const totalRecipients = computed(() =>
  groups.value.reduce((s, g) => s + (g.enrollments_count ?? 0), 0),
);

const heroStats = computed(() => [
  { label: t('admin.bimbel.group_announcements.stat_announcements'), value: String(rows.value.length), hint: t('admin.bimbel.group_announcements.stat_last_30') },
  { label: t('admin.bimbel.group_announcements.stat_groups'), value: String(groups.value.length) },
  { label: t('admin.bimbel.group_announcements.stat_recipients'), value: String(totalRecipients.value) },
]);

function openCompose() {
  fGroupId.value = groupId.value || groups.value[0]?.id || '';
  fTitle.value = '';
  fBody.value = '';
  showCompose.value = true;
}

async function submitCompose() {
  if (!fGroupId.value) { toast.error(t('admin.bimbel.group_announcements.pick_group_first')); return; }
  if (fTitle.value.trim().length < 3 || fBody.value.trim().length < 3) {
    toast.error(t('admin.bimbel.group_announcements.too_short')); return;
  }
  saving.value = true;
  try {
    await TutoringService.createGroupAnnouncement({
      tutoring_group_id: fGroupId.value,
      title: fTitle.value.trim(),
      body: fBody.value.trim(),
    });
    toast.success(t('admin.bimbel.group_announcements.published'));
    showCompose.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.group_announcements.publish_fail'));
  } finally { saving.value = false; }
}

async function remove(a: TutoringGroupAnnouncement) {
  if (
    !(await confirm({
      message: t('admin.bimbel.group_announcements.delete_confirm', {
        title: a.title,
      }),
      danger: true,
      confirmLabel: t('common.delete'),
    }))
  )
    return;
  const snapshot = {
    tutoring_group_id: a.tutoring_group_id,
    title: a.title,
    body: a.body,
  };
  try {
    await TutoringService.deleteGroupAnnouncement(a.id);
    await load();
    toast.undoable(t('admin.bimbel.group_announcements.deleted'), async () => {
      try {
        await TutoringService.createGroupAnnouncement(snapshot);
        await load();
        toast.success(t('admin.bimbel.group_announcements.restored'));
      } catch (e) {
        toast.error(
          e instanceof Error
            ? `${t('admin.bimbel.group_announcements.restore_fail')}: ${e.message}`
            : t('admin.bimbel.group_announcements.restore_fail'),
        );
      }
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.group_announcements.delete_fail'));
  }
}

function recipientsFor(a: TutoringGroupAnnouncement): number {
  return groups.value.find((g) => g.id === a.tutoring_group_id)?.enrollments_count ?? 0;
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="t('admin.bimbel.group_announcements.hero_kicker')"
      :title="t('admin.bimbel.group_announcements.hero_title')"
      :subtitle="groupId ? t('admin.bimbel.group_announcements.hero_subtitle_filtered', { count: rows.length }) : t('admin.bimbel.group_announcements.hero_subtitle', { count: rows.length })"
      :stats="heroStats"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-tutoring-accent px-3 py-1.5 text-[14px] font-bold"
          @click="openCompose"
        >
          <NavIcon name="plus" :size="13" class="inline -mt-0.5" /> {{ t('admin.bimbel.group_announcements.compose') }}
        </button>
      </template>
    </TutorHomeHero>

    <div class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3 flex flex-wrap items-center gap-2">
      <span class="text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.group_announcements.audience_label') }}</span>
      <button
        type="button"
        class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
        :class="groupId === '' ? 'border-tutoring-accent bg-tutoring-accent-dim text-tutoring-accent' : 'border-tutoring-border bg-tutoring-panel text-tutoring-text-mid'"
        @click="groupId = ''; load()"
      >{{ t('admin.bimbel.group_announcements.audience_all') }}</button>
      <button
        v-for="g in groups"
        :key="g.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
        :class="groupId === g.id ? 'border-tutoring-accent bg-tutoring-accent-dim text-tutoring-accent' : 'border-tutoring-border bg-tutoring-panel text-tutoring-text-mid'"
        @click="groupId = g.id; load()"
      >{{ g.name }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('admin.bimbel.group_announcements.loading') }}</div>

    <div v-else-if="rows.length" class="space-y-2">
      <article v-for="a in rows" :key="a.id" class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-4">
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <h3 class="text-[15px] font-bold tracking-tight text-tutoring-text-hi">{{ a.title }}</h3>
            <p class="text-[13px] text-tutoring-text-mid mt-0.5">
              {{ a.group_name ?? '—' }}
              <template v-if="a.author_name"> · {{ t('admin.bimbel.group_announcements.author_prefix', { name: a.author_name }) }}</template>
              <template v-if="a.created_at"> · {{ formatDateShort(a.created_at) }}</template>
            </p>
          </div>
          <button
            type="button"
            class="rounded-md border border-tutoring-border bg-tutoring-panel p-1.5 text-tutoring-text-lo hover:bg-tutoring-border-soft hover:text-rose-500"
            :title="t('admin.bimbel.group_announcements.delete_title')"
            @click="remove(a)"
          >
            <NavIcon name="trash-2" :size="13" />
          </button>
        </div>
        <p class="text-[14px] text-tutoring-text-mid mt-2 whitespace-pre-wrap">{{ a.body }}</p>
        <div class="mt-2.5 flex items-center gap-3 border-t border-tutoring-border-soft pt-2 text-[13px] text-tutoring-text-mid">
          <span class="inline-flex items-center gap-1">
            <NavIcon name="users" :size="12" /> {{ t('admin.bimbel.group_announcements.recipients_count', { count: recipientsFor(a) }) }}
          </span>
          <span class="inline-flex items-center gap-1">
            <NavIcon name="check" :size="12" /> {{ t('admin.bimbel.group_announcements.delivered_app') }}
          </span>
          <span class="ml-auto inline-flex items-center gap-1">
            <NavIcon name="megaphone" :size="12" /> {{ a.group_name ?? '—' }}
          </span>
        </div>
      </article>
    </div>

    <div v-else class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid">
      {{ t('admin.bimbel.group_announcements.empty') }}
    </div>

    <div
      v-if="showCompose"
      class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6"
      @click.self="showCompose = false"
    >
      <div class="w-full max-w-lg rounded-2xl bg-tutoring-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-tutoring-text-hi">{{ t('admin.bimbel.group_announcements.modal_new') }}</h3>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">
            {{ t('admin.bimbel.group_announcements.field_group') }} <span class="text-rose-500">*</span>
          </span>
          <select
            v-model="fGroupId"
            class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none"
          >
            <option value="" disabled>{{ t('admin.bimbel.group_announcements.group_pick') }}</option>
            <option v-for="g in groups" :key="g.id" :value="g.id">
              {{ t('admin.bimbel.group_announcements.group_option', { name: g.name, count: g.enrollments_count ?? 0 }) }}
            </option>
          </select>
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.group_announcements.field_title') }}</span>
          <input
            v-model="fTitle"
            type="text"
            class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none"
          />
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.group_announcements.field_body') }}</span>
          <textarea
            v-model="fBody"
            rows="6"
            class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none resize-none"
          ></textarea>
        </label>
        <div class="flex gap-2 pt-1">
          <button
            type="button"
            class="flex-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-2 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft"
            @click="showCompose = false"
          >{{ t('admin.bimbel.group_announcements.cancel') }}</button>
          <button
            type="button"
            :disabled="saving"
            class="flex-1 rounded-lg bg-tutoring-accent px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50"
            @click="submitCompose"
          >{{ saving ? t('admin.bimbel.group_announcements.sending') : t('admin.bimbel.group_announcements.publish') }}</button>
        </div>
      </div>
    </div>
  </div>
</template>

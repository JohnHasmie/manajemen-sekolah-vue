<!--
  TutorCreateSessionView — schedule a single bimbel session. Rebuilt on
  the tutoring shared components with the teacher (cobalt) accent.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringGroup } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const saving = ref(false);
const groups = ref<TutoringGroup[]>([]);

const groupId = ref<string | null>(null);
const date = ref<string>(''); // yyyy-mm-dd
const time = ref<string>('15:00');
const duration = ref<number>(90);
const room = ref('');
const topic = ref('');

async function load() {
  loading.value = true;
  try {
    groups.value = await TutoringService.getAllGroups();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.createSession.loadFailed'),
    );
  } finally {
    loading.value = false;
  }
}

async function submit() {
  if (!groupId.value) {
    toast.error(t('tutoring.createSession.pickGroupFirst'));
    return;
  }
  if (!date.value) {
    toast.error(t('tutoring.createSession.pickDate'));
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createSession({
      group_id: groupId.value,
      scheduled_at: new Date(`${date.value}T${time.value}:00`).toISOString(),
      duration_minutes: duration.value,
      room: room.value.trim() || undefined,
      topic: topic.value.trim() || undefined,
    });
    toast.success(t('tutoring.createSession.created'));
    router.back();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.createSession.createFailed'),
    );
  } finally {
    saving.value = false;
  }
}

onMounted(load);

const fieldLabel =
  'text-[10.5px] font-bold text-slate-500 uppercase tracking-wider';
const inputCls =
  'mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher';
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="guru"
      kicker="Bimbel · Sesi · Buat"
      :title="t('tutoring.createSession.title')"
      meta="Pilih kelompok → tanggal/jam → durasi → simpan"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <TutoringEmpty
      v-else-if="groups.length === 0"
      :text="t('tutoring.createSession.noGroups')"
      icon="users"
    />

    <div
      v-else
      class="space-y-3 bg-white border border-slate-100 rounded-2xl p-4 sm:p-5"
    >
      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.createSession.group') }}</span>
        <select v-model="groupId" :class="inputCls">
          <option :value="null" disabled>{{ t('tutoring.createSession.pickGroup') }}</option>
          <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
        </select>
      </label>

      <div class="flex gap-2">
        <label class="block flex-1">
          <span :class="fieldLabel">{{ t('tutoring.createSession.date') }}</span>
          <input v-model="date" type="date" :class="inputCls" />
        </label>
        <label class="block w-32">
          <span :class="fieldLabel">{{ t('tutoring.createSession.time') }}</span>
          <input v-model="time" type="time" :class="inputCls" />
        </label>
      </div>

      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.createSession.duration') }}</span>
        <select v-model.number="duration" :class="inputCls">
          <option :value="60">60 menit</option>
          <option :value="90">90 menit</option>
          <option :value="120">120 menit</option>
          <option :value="150">150 menit</option>
        </select>
      </label>

      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.createSession.room') }}</span>
        <input v-model="room" :class="inputCls" />
      </label>

      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.createSession.topic') }}</span>
        <input v-model="topic" :class="inputCls" />
      </label>

      <button
        :disabled="saving"
        class="w-full rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="submit"
      >
        {{ saving ? t('tutoring.common.saving') : t('tutoring.createSession.save') }}
      </button>
    </div>
  </div>
</template>

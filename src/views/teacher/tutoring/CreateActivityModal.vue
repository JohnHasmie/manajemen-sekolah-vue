<!--
  CreateActivityModal — bottom-sheet-style form for POST /tutoring/
  activities. Group + type + title + optional description + optional
  tenggat. On success, emits `done` so the parent reloads.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringGroup } from '@/types/tutoring';

const { t } = useI18n();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'done'): void;
}>();

const groups = ref<TutoringGroup[]>([]);
const groupId = ref('');
// Backend ActivityType enum: ASSIGNMENT (Tugas) / EXAM (Ujian) /
// MATERIAL (Materi). HOMEWORK/QUIZ/PROJECT never existed — those
// payloads previously got rejected at the validator.
const type = ref<'ASSIGNMENT' | 'EXAM' | 'MATERIAL'>('ASSIGNMENT');
const title = ref('');
const description = ref('');
const dueDate = ref(''); // yyyy-mm-dd
const dueTime = ref('17:00');
const saving = ref(false);
const errMsg = ref<string | null>(null);

onMounted(async () => {
  try {
    groups.value = await TutoringService.getAllGroups();
    if (groups.value[0]) groupId.value = groups.value[0].id;
  } catch {/* non-fatal */}
});

async function submit() {
  if (!groupId.value) {
    errMsg.value = t('tutor.bimbel.create_activity_modal.err_pick_group');
    return;
  }
  if (title.value.trim().length < 3) {
    errMsg.value = t('tutor.bimbel.create_activity_modal.err_title_short');
    return;
  }
  saving.value = true;
  errMsg.value = null;
  try {
    const dueIso = dueDate.value
      ? new Date(`${dueDate.value}T${dueTime.value}:00`).toISOString()
      : null;
    await TutoringService.createActivity({
      tutoring_group_id: groupId.value,
      type: type.value,
      title: title.value.trim(),
      description: description.value.trim() || undefined,
      due_at: dueIso,
    });
    emit('done');
  } catch (e) {
    errMsg.value = e instanceof Error ? e.message : String(e);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-md bg-tutoring-panel rounded-2xl p-5 sm:p-6">
      <h2 class="text-base font-bold text-tutoring-text-hi tracking-tight">
        {{ t('tutor.bimbel.create_activity_modal.title') }}
      </h2>
      <p class="text-xs text-tutoring-text-mid mt-1">
        {{ t('tutor.bimbel.create_activity_modal.subtitle') }}
      </p>

      <div class="mt-4 space-y-3">
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.create_activity_modal.field_group') }}
          </span>
          <select
            v-model="groupId"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option value="" disabled>{{ t('tutor.bimbel.create_activity_modal.field_group_placeholder') }}</option>
            <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.create_activity_modal.field_type') }}
          </span>
          <select
            v-model="type"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option value="ASSIGNMENT">{{ t('tutor.bimbel.create_activity_modal.type_assignment') }}</option>
            <option value="EXAM">{{ t('tutor.bimbel.create_activity_modal.type_exam') }}</option>
            <option value="MATERIAL">{{ t('tutor.bimbel.create_activity_modal.type_material') }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.create_activity_modal.field_title') }}
          </span>
          <input
            v-model="title"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            :placeholder="t('tutor.bimbel.create_activity_modal.field_title_placeholder')"
          />
        </label>
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.create_activity_modal.field_description') }}
          </span>
          <textarea
            v-model="description"
            rows="3"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher resize-none"
          />
        </label>
        <div class="flex gap-2">
          <label class="block flex-1">
            <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
              {{ t('tutor.bimbel.create_activity_modal.field_due_date') }}
            </span>
            <input
              v-model="dueDate"
              type="date"
              class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            />
          </label>
          <label class="block w-32">
            <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
              {{ t('tutor.bimbel.create_activity_modal.field_due_time') }}
            </span>
            <input
              v-model="dueTime"
              type="time"
              class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            />
          </label>
        </div>
        <p v-if="errMsg" class="text-xs text-tutoring-red">{{ errMsg }}</p>
      </div>

      <div class="mt-5 flex items-center gap-2 justify-end">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
          @click="emit('close')"
        >
          {{ t('tutoring.common.close') }}
        </button>
        <button
          type="button"
          :disabled="saving"
          class="rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submit"
        >
          {{ saving ? t('tutoring.common.saving') : t('tutor.bimbel.create_activity_modal.submit') }}
        </button>
      </div>
    </div>
  </div>
</template>

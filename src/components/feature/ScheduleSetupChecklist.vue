<!--
  ScheduleSetupChecklist.vue — Sprint 2 (MR C) setup-first gate.

  Rendered inside <ScheduleFormModal> when GET /schedule/prereq-check
  reports `ready === false`. Each row is (icon + title + subtitle +
  optional CTA). The three hard prerequisites (teachers, classes,
  lesson_hours) gate the form's "Lanjut ke form →" button; the rooms
  row is informational only so a school that never books rooms per
  session isn't blocked by it.

  The lesson-hours row owns the one CTA that fires inline: a preset
  seed ("Buat 8 jam standar SMP", with a small toggle for SMA). The
  teachers + classes rows route to their respective admin management
  pages — those flows are too fat to inline here.

  Contract: emits `seed(preset)`, `open-teachers`, `open-classes`,
  `continue`, `close`. The parent form re-fetches prereq-check after
  each seed so the checklist can re-render "done" rows in place.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import type {
  LessonHourSeedPreset,
  SchedulePrereqCheck,
} from '@/services/schedule.service';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  prereq: SchedulePrereqCheck;
  /** Fresh prereq-check in flight (initial load or post-seed refetch). */
  isChecking?: boolean;
  /** POST /lesson-hours/seed in flight. */
  isSeeding?: boolean;
  /** Server-returned error banner text — parent owns the error state. */
  error?: string | null;
}>();

const emit = defineEmits<{
  /** Fire the lesson-hour seed with the selected preset. */
  seed: [LessonHourSeedPreset];
  /** Bail out to /admin/teachers so the admin can seed the roster. */
  'open-teachers': [];
  /** Bail out to /admin/classes so the admin can create classrooms. */
  'open-classes': [];
  /** Enter the actual form (only enabled when `ready === true`). */
  continue: [];
  /** Close the whole modal — parent owns the modal shell. */
  close: [];
}>();

const { t } = useI18n();

// Preset toggle — SMP is the default (KamilEdu's launch cohort is
// mostly MTs/SMP), SMA sits behind a one-tap segmented switch.
const preset = ref<LessonHourSeedPreset>('smp');

const ready = computed(() => props.prereq.ready);

function seed() {
  emit('seed', preset.value);
}
</script>

<template>
  <div class="space-y-4">
    <!-- Explainer strip. Explains WHY we're gating instead of showing
         a form the admin will only bounce off of. -->
    <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
      <p class="text-3xs font-bold uppercase tracking-widest text-slate-500 flex items-center gap-1.5">
        <NavIcon name="clipboard-list" :size="12" />
        {{ t('admin.schedule.setup.badge') }}
      </p>
      <p class="text-[13px] font-bold text-slate-900 mt-1 leading-relaxed">
        {{ t('admin.schedule.setup.headline') }}
      </p>
      <p class="text-2xs text-slate-600 mt-1 leading-relaxed">
        {{ t('admin.schedule.setup.subhead') }}
      </p>
    </div>

    <!-- The four rows. Order = the order an admin would tackle them:
         hours first (that's the one we can seed), then classes (needed
         to route students), then teachers, and rooms last (soft). -->
    <ul class="space-y-2">
      <!-- 1. Lesson hours — has the inline seed CTA. -->
      <li
        class="rounded-2xl border p-3.5"
        :class="prereq.lesson_hours.has_any
          ? 'border-emerald-200 bg-emerald-50/60'
          : 'border-amber-200 bg-amber-50/60'"
      >
        <div class="flex items-start gap-3">
          <NavIcon
            :name="prereq.lesson_hours.has_any ? 'check-circle' : 'alert-circle'"
            :size="18"
            :class="prereq.lesson_hours.has_any ? 'text-emerald-600' : 'text-amber-600'"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900">
              {{ t('admin.schedule.setup.lessonHoursTitle') }}
            </p>
            <p class="text-2xs text-slate-600 leading-relaxed mt-0.5">
              <span v-if="prereq.lesson_hours.has_any">
                {{ t('admin.schedule.setup.lessonHoursDone', { count: prereq.lesson_hours.count }) }}
              </span>
              <span v-else>
                {{ t('admin.schedule.setup.lessonHoursPending') }}
              </span>
            </p>

            <!-- Preset toggle + primary CTA — only when pending. Once
                 hours exist we hide the seeder so a subsequent visit
                 doesn't tempt the admin into re-seeding on top. -->
            <div v-if="!prereq.lesson_hours.has_any" class="mt-3 space-y-2">
              <div class="inline-flex rounded-lg bg-white border border-amber-200 p-0.5 text-2xs font-bold">
                <button
                  type="button"
                  class="px-3 py-1 rounded-md transition-colors"
                  :class="preset === 'smp'
                    ? 'bg-amber-500 text-white'
                    : 'text-slate-600 hover:text-slate-900'"
                  @click="preset = 'smp'"
                >
                  {{ t('admin.schedule.setup.presetSmp') }}
                </button>
                <button
                  type="button"
                  class="px-3 py-1 rounded-md transition-colors"
                  :class="preset === 'sma'
                    ? 'bg-amber-500 text-white'
                    : 'text-slate-600 hover:text-slate-900'"
                  @click="preset = 'sma'"
                >
                  {{ t('admin.schedule.setup.presetSma') }}
                </button>
              </div>
              <Button
                variant="primary"
                size="sm"
                :loading="isSeeding"
                :disabled="isSeeding"
                @click="seed"
              >
                <NavIcon name="zap" :size="12" />
                {{ preset === 'smp'
                  ? t('admin.schedule.setup.seedSmpCta')
                  : t('admin.schedule.setup.seedSmaCta') }}
              </Button>
            </div>
          </div>
        </div>
      </li>

      <!-- 2. Classes -->
      <li
        class="rounded-2xl border p-3.5"
        :class="prereq.classes.has_any
          ? 'border-emerald-200 bg-emerald-50/60'
          : 'border-amber-200 bg-amber-50/60'"
      >
        <div class="flex items-start gap-3">
          <NavIcon
            :name="prereq.classes.has_any ? 'check-circle' : 'alert-circle'"
            :size="18"
            :class="prereq.classes.has_any ? 'text-emerald-600' : 'text-amber-600'"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900">
              {{ t('admin.schedule.setup.classesTitle') }}
            </p>
            <p class="text-2xs text-slate-600 leading-relaxed mt-0.5">
              <span v-if="prereq.classes.has_any">
                {{ t('admin.schedule.setup.classesDone', { count: prereq.classes.count }) }}
              </span>
              <span v-else>
                {{ t('admin.schedule.setup.classesPending') }}
              </span>
            </p>
            <div v-if="!prereq.classes.has_any" class="mt-2">
              <Button variant="secondary" size="sm" @click="emit('open-classes')">
                <NavIcon name="external-link" :size="11" />
                {{ t('admin.schedule.setup.openClasses') }}
              </Button>
            </div>
          </div>
        </div>
      </li>

      <!-- 3. Teachers -->
      <li
        class="rounded-2xl border p-3.5"
        :class="prereq.teachers.has_any
          ? 'border-emerald-200 bg-emerald-50/60'
          : 'border-amber-200 bg-amber-50/60'"
      >
        <div class="flex items-start gap-3">
          <NavIcon
            :name="prereq.teachers.has_any ? 'check-circle' : 'alert-circle'"
            :size="18"
            :class="prereq.teachers.has_any ? 'text-emerald-600' : 'text-amber-600'"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900">
              {{ t('admin.schedule.setup.teachersTitle') }}
            </p>
            <p class="text-2xs text-slate-600 leading-relaxed mt-0.5">
              <span v-if="prereq.teachers.has_any">
                {{ t('admin.schedule.setup.teachersDone', { count: prereq.teachers.count }) }}
              </span>
              <span v-else>
                {{ t('admin.schedule.setup.teachersPending') }}
              </span>
            </p>
            <div v-if="!prereq.teachers.has_any" class="mt-2">
              <Button variant="secondary" size="sm" @click="emit('open-teachers')">
                <NavIcon name="external-link" :size="11" />
                {{ t('admin.schedule.setup.openTeachers') }}
              </Button>
            </div>
          </div>
        </div>
      </li>

      <!-- 4. Rooms — informational only. Empty = neutral slate, not
           amber, so it doesn't visually gate the "Lanjut" button. -->
      <li class="rounded-2xl border border-slate-200 bg-white p-3.5">
        <div class="flex items-start gap-3">
          <NavIcon
            :name="prereq.rooms.has_any ? 'check-circle' : 'info'"
            :size="18"
            :class="prereq.rooms.has_any ? 'text-emerald-600' : 'text-slate-400'"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900">
              {{ t('admin.schedule.setup.roomsTitle') }}
            </p>
            <p class="text-2xs text-slate-500 leading-relaxed mt-0.5">
              <span v-if="prereq.rooms.has_any">
                {{ t('admin.schedule.setup.roomsDone', { count: prereq.rooms.count }) }}
              </span>
              <span v-else>
                {{ t('admin.schedule.setup.roomsInfo') }}
              </span>
            </p>
          </div>
        </div>
      </li>
    </ul>

    <p v-if="error" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
      {{ error }}
    </p>

    <div class="grid grid-cols-2 gap-2 pt-2">
      <Button variant="secondary" block @click="emit('close')">
        {{ t('common.cancel') }}
      </Button>
      <Button
        variant="primary"
        block
        :loading="isChecking"
        :disabled="!ready || isChecking"
        @click="emit('continue')"
      >
        {{ t('admin.schedule.setup.continueCta') }}
      </Button>
    </div>
  </div>
</template>

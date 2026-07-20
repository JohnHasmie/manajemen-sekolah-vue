<!--
  EngagementToggleCard.vue — the merged Prestasi/Engagement card for the
  admin dashboard (Opsi A, "Engagement · gamifikasi" band).

  Consolidates what USED to be FOUR separate cards (Guru "Bulan Ini",
  Staf "Bulan Ini", Engagement Guru, Engagement Staf) into ONE card with
  a Guru ↔ Staf segmented toggle. Inside, for the active side:

    · monthly winner as a hero row  ("Guru Bulan Ini · Mar'atus · 85 XP")
    · 4 retention stats             (Total / Aktif / Streak / Sepi)
    · "Top minggu ini" list         (top 3, padded to 3 slots)

  Gating lives in the PARENT — this card only renders inside the
  `canSeePrestasi` branch. When the tenant has zero staff the toggle
  hides and only the Guru side shows. Payloads may be null while the
  fetch is in flight; the card shows a lightweight loading shell.

  Palette: the engagement module reads as "violet" (header icon + toggle
  + XP), matching the approved mockup. Winner medal stays amber; avatars
  keep the role tint (teacher cobalt / staff amber) via InitialsAvatar.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import NavIcon from '@/components/feature/NavIcon.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import type {
  AdminHighlightPayload,
  AdminSummaryPayload,
  AdminStaffHighlightPayload,
  AdminStaffSummaryPayload,
} from '@/services/teacher-progress.service';

const props = defineProps<{
  teacherHighlight: AdminHighlightPayload | null;
  teacherSummary: AdminSummaryPayload | null;
  staffHighlight: AdminStaffHighlightPayload | null;
  staffSummary: AdminStaffSummaryPayload | null;
}>();

const { t } = useI18n();
const router = useRouter();

type Role = 'teacher' | 'staff';
const activeRole = ref<Role>('teacher');

// Staff side only offered when the tenant actually has staff rows —
// single-guru bimbel keeps the card Guru-only (no toggle).
const hasStaff = computed(
  () => !!props.staffSummary && props.staffSummary.total_staff > 0,
);
const effectiveRole = computed<Role>(() =>
  activeRole.value === 'staff' && hasStaff.value ? 'staff' : 'teacher',
);

const AVATAR_COLOR: Record<Role, string> = {
  teacher: '#1B6FB8', // brand cobalt
  staff: '#B45309', // role-staff amber
};

// ─── Winner hero ─────────────────────────────────────────────────────
interface Winner {
  eyebrow: string;
  title: string;
  sub: string;
  points: number | null;
}
const winner = computed<Winner | null>(() => {
  if (effectiveRole.value === 'staff') {
    const w = props.staffHighlight?.staff_of_month;
    if (!w) return null;
    return {
      eyebrow: w.eyebrow ?? t('admin.dashboard.engagement.winnerStaffEyebrow'),
      title: w.title,
      sub: w.sub ?? '',
      points: w.meta?.points ?? null,
    };
  }
  const w = props.teacherHighlight?.teacher_of_month;
  if (!w) return null;
  return {
    eyebrow: w.eyebrow ?? t('admin.dashboard.engagement.winnerTeacherEyebrow'),
    title: w.title,
    sub: w.sub ?? '',
    points: w.meta?.points ?? null,
  };
});

// ─── Retention stats ─────────────────────────────────────────────────
interface Stats {
  total: number;
  active: number;
  streak: number;
  quiet: number;
}
const stats = computed<Stats | null>(() => {
  if (effectiveRole.value === 'staff') {
    const s = props.staffSummary;
    if (!s) return null;
    return {
      total: s.total_staff,
      active: s.active_this_week,
      streak: s.average_streak,
      quiet: s.needs_attention_count,
    };
  }
  const s = props.teacherSummary;
  if (!s) return null;
  return {
    total: s.total_teachers,
    active: s.active_this_week,
    streak: s.average_streak,
    quiet: s.needs_attention_count,
  };
});

// ─── Top three (normalised across teacher/staff shapes) ──────────────
interface TopRow {
  id: string;
  name: string;
  photoUrl: string | null;
  points: number;
  streakDays: number | null;
  roleTag: string | null;
}
const topThree = computed<TopRow[]>(() => {
  if (effectiveRole.value === 'staff') {
    return (props.staffSummary?.top_three ?? []).map((e) => ({
      id: e.user_id,
      name: e.name,
      photoUrl: e.photo_url,
      points: e.points,
      streakDays: e.streak_days ?? null,
      roleTag: e.ability_role_tag ?? null,
    }));
  }
  return (props.teacherSummary?.top_three ?? []).map((e) => ({
    id: e.teacher_id,
    name: e.name,
    photoUrl: e.photo_url,
    points: e.points,
    streakDays: e.streak_days ?? null,
    roleTag: null,
  }));
});
const placeholderCount = computed(() => Math.max(0, 3 - topThree.value.length));

const hasData = computed(() => stats.value != null || winner.value != null);

function gotoDetail() {
  router.push(
    effectiveRole.value === 'staff'
      ? '/admin/staff-engagement'
      : '/admin/teacher-engagement',
  );
}
</script>

<template>
  <section class="bg-white border border-slate-200 rounded-2xl p-4 flex flex-col h-full min-w-0">
    <!-- Header -->
    <header class="flex items-center justify-between mb-3">
      <div class="flex items-center gap-2.5">
        <div class="w-8 h-8 rounded-xl bg-violet-100 text-violet-700 grid place-items-center">
          <NavIcon name="trophy" :size="16" />
        </div>
        <div>
          <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
            {{ t('admin.dashboard.engagement.eyebrow') }}
          </p>
          <h3 class="text-sm font-black text-slate-900">
            {{ t('admin.dashboard.engagement.title') }}
          </h3>
        </div>
      </div>
      <button
        type="button"
        class="text-2xs font-bold text-violet-700 hover:underline flex-shrink-0"
        @click="gotoDetail"
      >
        {{ t('admin.dashboard.engagement.seeDetail') }}
      </button>
    </header>

    <!-- Guru ↔ Staf toggle (hidden when the tenant has no staff) -->
    <div
      v-if="hasStaff"
      role="tablist"
      class="inline-flex self-start gap-1 bg-slate-100 rounded-xl p-1 mb-3"
    >
      <button
        type="button"
        role="tab"
        :aria-selected="effectiveRole === 'teacher'"
        class="inline-flex items-center gap-1.5 rounded-lg px-3.5 py-1.5 text-2xs font-bold transition"
        :class="effectiveRole === 'teacher' ? 'bg-white shadow-sm text-violet-700' : 'text-slate-500 hover:text-slate-700'"
        @click="activeRole = 'teacher'"
      >
        <NavIcon name="user" :size="13" />
        {{ t('admin.dashboard.engagement.toggleTeacher') }}
      </button>
      <button
        type="button"
        role="tab"
        :aria-selected="effectiveRole === 'staff'"
        class="inline-flex items-center gap-1.5 rounded-lg px-3.5 py-1.5 text-2xs font-bold transition"
        :class="effectiveRole === 'staff' ? 'bg-white shadow-sm text-violet-700' : 'text-slate-500 hover:text-slate-700'"
        @click="activeRole = 'staff'"
      >
        <NavIcon name="briefcase" :size="13" />
        {{ t('admin.dashboard.engagement.toggleStaff') }}
      </button>
    </div>

    <!-- Loading shell while payloads resolve -->
    <div v-if="!hasData" class="flex-1 flex flex-col gap-3">
      <div class="h-16 rounded-xl bg-slate-50 animate-pulse"></div>
      <div class="h-14 rounded-xl bg-slate-50 animate-pulse"></div>
    </div>

    <template v-else>
      <!-- Winner hero row -->
      <div
        v-if="winner"
        class="flex items-center gap-3 rounded-xl px-3.5 py-3 bg-amber-50 border border-amber-200 mb-3"
      >
        <div class="w-9 h-9 rounded-xl bg-amber-500 text-white grid place-items-center flex-shrink-0">
          <NavIcon name="trophy" :size="18" />
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-3xs font-bold text-amber-700 uppercase tracking-widest">{{ winner.eyebrow }}</p>
          <p class="text-sm font-black text-slate-900 truncate leading-tight">{{ winner.title }}</p>
          <p v-if="winner.sub" class="text-3xs text-slate-500 truncate">{{ winner.sub }}</p>
        </div>
        <div v-if="winner.points != null" class="text-right flex-shrink-0">
          <p class="text-lg font-black text-amber-600 tabular-nums leading-none">{{ winner.points }}</p>
          <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest mt-0.5">
            {{ t('admin.dashboard.engagement.xp') }}
          </p>
        </div>
      </div>

      <!-- Retention stats -->
      <div v-if="stats" class="grid grid-cols-2 md:grid-cols-4 gap-2 mb-3">
        <div class="rounded-xl bg-slate-50 px-3 py-2 text-center">
          <p class="text-base font-black text-slate-900 tabular-nums">{{ stats.total }}</p>
          <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest mt-0.5">
            {{ t('admin.dashboard.engagement.statTotal') }}
          </p>
        </div>
        <div class="rounded-xl bg-emerald-50 px-3 py-2 text-center">
          <p class="text-base font-black text-emerald-700 tabular-nums">{{ stats.active }}</p>
          <p class="text-3xs font-bold text-emerald-700 uppercase tracking-widest mt-0.5">
            {{ t('admin.dashboard.engagement.statActive') }}
          </p>
        </div>
        <div class="rounded-xl bg-amber-50 px-3 py-2 text-center">
          <p class="text-base font-black text-amber-700 tabular-nums">
            {{ stats.streak }}<span class="text-3xs font-bold ml-0.5">{{ t('admin.dashboard.engagement.streakUnit') }}</span>
          </p>
          <p class="text-3xs font-bold text-amber-700 uppercase tracking-widest mt-0.5">
            {{ t('admin.dashboard.engagement.statStreak') }}
          </p>
        </div>
        <div class="rounded-xl bg-slate-50 px-3 py-2 text-center">
          <p class="text-base font-black text-slate-700 tabular-nums">{{ stats.quiet }}</p>
          <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest mt-0.5">
            {{ t('admin.dashboard.engagement.statQuiet') }}
          </p>
        </div>
      </div>

      <!-- Top minggu ini -->
      <div class="pt-3 border-t border-slate-100 mt-auto">
        <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest mb-2">
          {{ t('admin.dashboard.engagement.topWeek') }}
        </p>
        <ol class="space-y-2">
          <li
            v-for="(row, i) in topThree"
            :key="row.id"
            class="flex items-center gap-2.5"
          >
            <span
              class="w-5 h-5 rounded-full text-3xs font-black text-white grid place-items-center flex-shrink-0"
              :class="i === 0 ? 'bg-amber-500' : i === 1 ? 'bg-slate-400' : 'bg-orange-400'"
            >{{ i + 1 }}</span>
            <InitialsAvatar
              :name="row.name"
              :image-url="row.photoUrl"
              :size="28"
              :color="AVATAR_COLOR[effectiveRole]"
              :border-radius="8"
            />
            <div class="flex-1 min-w-0">
              <p class="text-2xs font-bold text-slate-800 truncate leading-tight">{{ row.name }}</p>
              <p
                v-if="row.roleTag || (row.streakDays != null && row.streakDays > 0)"
                class="text-3xs text-slate-500 leading-tight mt-0.5 truncate"
              >
                <template v-if="row.roleTag">{{ row.roleTag }}</template>
                <template v-if="row.roleTag && row.streakDays != null && row.streakDays > 0"> · </template>
                <template v-if="row.streakDays != null && row.streakDays > 0">
                  {{ t('admin.dashboard.engagement.streakDays', { n: row.streakDays }) }}
                </template>
              </p>
            </div>
            <p class="text-2xs font-black text-violet-700 flex-shrink-0 tabular-nums">
              {{ row.points }}<span class="text-3xs text-slate-500 font-bold ml-1">{{ t('admin.dashboard.engagement.xp') }}</span>
            </p>
          </li>
          <!-- Pad to 3 slots so the card height is stable. -->
          <li
            v-for="ph in placeholderCount"
            :key="`ph-${ph}`"
            class="flex items-center gap-2.5 min-h-[28px]"
          >
            <span class="w-5 h-5 rounded-full bg-slate-300 text-3xs font-black text-white grid place-items-center flex-shrink-0">
              {{ topThree.length + ph }}
            </span>
            <div class="flex-1 border-t border-dashed border-slate-300"></div>
            <span class="text-xs italic text-slate-400 flex-shrink-0">
              {{ t('admin.dashboard.engagement.noRankYet', { n: topThree.length + ph }) }}
            </span>
          </li>
        </ol>
      </div>
    </template>
  </section>
</template>

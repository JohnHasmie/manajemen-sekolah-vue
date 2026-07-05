<!--
  AnnouncementCard.vue — single-row card used across the
  admin / teacher / parent Announcement lists.

  Mirrors Flutter's `AnnouncementCard` + `TeacherAnnouncementCard`
  + parent inbox row in `lib/features/announcements/presentation/widgets/`.

  Visual layout:
    ┌──────────────────────────────────────────────────────┐
    │ ●  [Penting] [→ 9A]                       2 jam lalu │  ← meta strip
    │    Libur Idul Adha (Jumat)                            │  ← title
    │    Sekolah akan libur pada hari Jumat …               │  ← body clamp 2
    │    Dibaca 12 / 28 parent                          │  ← read footer
    └──────────────────────────────────────────────────────┘

  Props per role:
    - admin   → shows priority + audience + read counter + delete
    - teacher → shows audience + read counter
    - parent    → shows unread dot + source label + tinted bg when unread
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatRelative, formatDateLong } from '@/lib/format';
import type { Announcement } from '@/types/announcements';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();

const props = withDefaults(
  defineProps<{
    announcement: Announcement;
    viewerRole?: 'admin' | 'guru' | 'wali';
    isSelected?: boolean;
    showDelete?: boolean;
  }>(),
  { viewerRole: 'wali', isSelected: false, showDelete: false },
);

defineEmits<{
  tap: [Announcement];
  longPress: [Announcement];
  delete: [Announcement];
}>();

// Category colour map — same palette across all three role views.
// The `label` is a translation KEY now so the badge text re-renders when
// the locale switches.
const CATEGORY_PALETTE: Record<
  string,
  { bg: string; text: string; labelKey: string }
> = {
  penting: { bg: 'bg-red-50', text: 'text-red-700', labelKey: 'announcement.categoryImportant' },
  pengumuman: { bg: 'bg-slate-100', text: 'text-slate-600', labelKey: 'announcement.categoryGeneral' },
  umum: { bg: 'bg-slate-100', text: 'text-slate-600', labelKey: 'announcement.categoryGeneral' },
  acara: { bg: 'bg-violet-50', text: 'text-violet-700', labelKey: 'announcement.categoryEvent' },
  libur: { bg: 'bg-amber-50', text: 'text-amber-700', labelKey: 'announcement.categoryHoliday' },
};

const categoryStyle = computed(() => {
  const entry =
    CATEGORY_PALETTE[props.announcement.category] ??
    CATEGORY_PALETTE.pengumuman;
  return { ...entry, label: t(entry.labelKey) };
});

const isUnread = computed(() => props.announcement.is_read === false);

/** Show the brand-tinted background only for the parent inbox view. */
const showUnreadTint = computed(
  () => props.viewerRole === 'wali' && isUnread.value,
);

const audienceLabel = computed(() => {
  const a = props.announcement;
  if (a.audience_label) return a.audience_label;
  if (a.audience === 'all') return t('announcement.audienceAll');
  if (a.audience === 'role') return t('announcement.audienceRole');
  if (a.audience === 'class') return t('announcement.audienceClass');
  if (a.audience === 'student') return t('announcement.audienceStudent');
  return null;
});

const sourceLabel = computed(() => props.announcement.source ?? null);

const timeLabel = computed(() => {
  const a = props.announcement;
  const ts = a.published_at ?? a.created_at;
  return formatRelative(ts) || formatDateLong(ts);
});

const showReadCounter = computed(() => {
  const a = props.announcement;
  return (
    (props.viewerRole === 'admin' || props.viewerRole === 'guru') &&
    typeof a.total_recipients === 'number' &&
    (a.total_recipients ?? 0) > 0
  );
});

const isScheduled = computed(() => {
  const a = props.announcement;
  if (a.status === 'scheduled') return true;
  if (!a.scheduled_at) return false;
  return Date.parse(a.scheduled_at) > Date.now();
});

const isExpired = computed(() => {
  const a = props.announcement;
  if (a.status === 'expired') return true;
  if (!a.expires_at) return false;
  return Date.parse(a.expires_at) < Date.now();
});
</script>

<template>
  <button
    type="button"
    class="w-full text-left rounded-2xl border transition-all p-3.5 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
    :class="[
      isSelected
        ? 'border-brand-cobalt bg-brand-cobalt/5'
        : showUnreadTint
          ? 'border-role-parent/30 bg-role-parent/5 hover:bg-role-parent/10'
          : 'border-slate-200 bg-white hover:border-slate-300 hover:shadow-sm',
    ]"
    @click="$emit('tap', announcement)"
    @contextmenu.prevent="$emit('longPress', announcement)"
  >
    <div class="flex items-start gap-3">
      <!-- Unread dot (parent only) / pin marker (admin) -->
      <div class="flex flex-col items-center gap-2 pt-1 flex-shrink-0">
        <span
          v-if="viewerRole === 'wali'"
          class="w-2.5 h-2.5 rounded-full"
          :class="
            isUnread ? 'bg-role-parent' : 'border border-slate-200'
          "
          :aria-label="isUnread ? 'Belum dibaca' : 'Sudah dibaca'"
        />
        <NavIcon
          v-if="announcement.is_pinned"
          name="star"
          :size="13"
          class="text-amber-600"
          aria-label="Disematkan"
        />
      </div>

      <div class="flex-1 min-w-0">
        <!-- Meta strip -->
        <div class="flex items-center gap-1.5 flex-wrap mb-1.5">
          <span
            class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full"
            :class="[categoryStyle.bg, categoryStyle.text]"
          >
            {{ categoryStyle.label }}
          </span>
          <span
            v-if="audienceLabel"
            class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-slate-100 text-slate-600"
          >
            → {{ audienceLabel }}
          </span>
          <span
            v-if="sourceLabel && viewerRole === 'wali'"
            class="text-[10.5px] text-slate-500 truncate"
          >
            {{ sourceLabel }}
          </span>
          <span
            v-if="isScheduled"
            class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-amber-50 text-amber-700"
          >
            Terjadwal
          </span>
          <span
            v-else-if="isExpired"
            class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-slate-100 text-slate-500"
          >
            Kedaluwarsa
          </span>
          <span
            v-else-if="announcement.status === 'draft'"
            class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-slate-100 text-slate-500"
          >
            Draft
          </span>
          <span class="flex-1"></span>
          <span class="text-2xs text-slate-400 flex-shrink-0">{{ timeLabel }}</span>
        </div>

        <!-- Title -->
        <p
          class="text-[14px] leading-snug text-slate-900 truncate"
          :class="
            isUnread && viewerRole === 'wali'
              ? 'font-black'
              : 'font-bold'
          "
        >
          {{ announcement.title || '(Tanpa judul)' }}
        </p>

        <!-- Body preview — clamp 2 lines -->
        <p
          v-if="announcement.body"
          class="text-[12px] text-slate-600 mt-1 line-clamp-2 leading-relaxed"
        >
          {{ announcement.body }}
        </p>

        <!-- Read counter (admin / teacher) -->
        <p
          v-if="showReadCounter"
          class="text-[10.5px] text-slate-400 mt-2 inline-flex items-center gap-1"
        >
          <NavIcon name="eye" :size="11" />
          Dibaca {{ announcement.read_count ?? 0 }} / {{ announcement.total_recipients }} wali murid
        </p>
      </div>

      <!-- Delete (admin / teacher own posts) -->
      <button
        v-if="showDelete"
        type="button"
        class="text-slate-300 hover:text-red-600 p-1 -m-1 flex-shrink-0"
        aria-label="Hapus pengumuman"
        @click.stop="$emit('delete', announcement)"
      >
        <NavIcon name="trash" :size="14" />
      </button>
    </div>
  </button>
</template>

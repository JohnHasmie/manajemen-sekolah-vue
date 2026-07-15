<!--
  AnnouncementDetailModal.vue — full read view for an announcement.

  Mirrors Flutter's `AnnouncementDetailSheet`. Priority-coloured reading hero
  (PENTING red / ACARA violet / UMUM navy) bleeds to the modal edges; body
  renders the full text; an event block adds a live countdown + "add to
  calendar"; attachments are downloadable; footer exposes role-specific
  actions (admin → Hapus · Edit). Icons are inline SVG.
-->
<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatDateLong, formatDateShort, formatRelative } from '@/lib/format';
import { AnnouncementService } from '@/services/announcements.service';
import type { Announcement } from '@/types/announcements';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { canonicalRole, ROLE_ADMIN, ROLE_TEACHER } from '@/utils/role';
import { renderAnnouncementHtml } from '@/lib/sanitize-html';

const props = withDefaults(
  defineProps<{
    announcement: Announcement;
    viewerRole?: 'admin' | 'teacher' | 'parent';
    canEdit?: boolean;
    canDelete?: boolean;
    autoMarkRead?: boolean;
  }>(),
  {
    viewerRole: 'parent',
    canEdit: false,
    canDelete: false,
    autoMarkRead: true,
  },
);

const emit = defineEmits<{
  close: [];
  edit: [Announcement];
  delete: [Announcement];
}>();

const { t } = useI18n();

type Tier = 'penting' | 'acara' | 'umum';

const tier = computed<Tier>(() => {
  const a = props.announcement;
  if (a.priority === 'high' || a.priority === 'urgent') return 'penting';
  if (a.type === 'event' || a.event_at || a.category === 'acara') return 'acara';
  return 'umum';
});

// Hero gradient + the light accent used for chips/blocks, per tier.
const heroClass = computed(
  () =>
    ({
      penting: 'from-red-600 to-rose-800',
      acara: 'from-violet-600 to-purple-800',
      umum: 'from-[#1b4b8f] to-[#0e2553]',
    })[tier.value],
);
const accentText = computed(
  () =>
    ({
      penting: 'text-red-700',
      acara: 'text-violet-700',
      umum: 'text-[#1b4b8f]',
    })[tier.value],
);
const accentBg = computed(
  () =>
    ({ penting: 'bg-red-50', acara: 'bg-violet-50', umum: 'bg-sky-50' })[
      tier.value
    ],
);

const tierLabel = computed(() => {
  switch (tier.value) {
    case 'penting':
      return t('announcement.categoryImportant');
    case 'acara':
      return t('announcement.categoryEvent');
    default:
      return t('announcement.categoryGeneral');
  }
});

const dateLabel = computed(() => {
  const ts = props.announcement.published_at ?? props.announcement.created_at;
  return formatDateLong(ts);
});
const relativeLabel = computed(() => {
  const ts = props.announcement.published_at ?? props.announcement.created_at;
  return formatRelative(ts);
});

const audienceLabel = computed(() => {
  const a = props.announcement;
  if (a.audience_label) return a.audience_label;
  if (a.audience === 'all') return 'Semua';
  if (a.audience === 'role') return 'Per peran';
  if (a.audience === 'class') return 'Per kelas';
  if (a.audience === 'student') return 'Per siswa';
  return null;
});

// ── Event block ──
const eventWhen = computed(() =>
  props.announcement.event_at ? formatDateLong(props.announcement.event_at) : '',
);
const countdown = computed(() => {
  const iso = props.announcement.event_at;
  if (!iso) return '';
  const ev = new Date(iso);
  if (Number.isNaN(ev.getTime())) return '';
  const day = (d: Date) =>
    new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const days = Math.round((day(ev) - day(new Date())) / 86400000);
  if (days < 0) return t('announcements.eventOngoing');
  if (days === 0) return t('announcements.eventToday');
  if (days === 1) return t('announcements.eventTomorrow');
  return t('announcements.eventInDays', { n: days });
});
const calendarUrl = computed(() => {
  const a = props.announcement;
  if (!a.event_at) return '';
  const stamp = (iso: string) =>
    new Date(iso).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const start = stamp(a.event_at);
  const end = stamp(new Date(new Date(a.event_at).getTime() + 3600000).toISOString());
  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: a.title || '',
    dates: `${start}/${end}`,
    details: a.body || '',
    location: a.event_location || '',
  });
  return `https://calendar.google.com/calendar/render?${params.toString()}`;
});

const validUntil = computed(() =>
  props.announcement.pinned_until
    ? formatDateShort(props.announcement.pinned_until)
    : '',
);

const showReadMetrics = computed(
  () =>
    [ROLE_ADMIN, ROLE_TEACHER].includes(canonicalRole(props.viewerRole)) &&
    typeof props.announcement.total_recipients === 'number' &&
    props.announcement.total_recipients > 0,
);

// Rich body → sanitized HTML (new Quill content) or upgraded legacy plain text.
const renderedBody = computed(() =>
  renderAnnouncementHtml(props.announcement.body),
);

onMounted(() => {
  if (props.autoMarkRead && props.announcement.is_read === false) {
    AnnouncementService.markAsRead(props.announcement.id);
  }
});
</script>

<template>
  <Modal title="" @close="emit('close')">
    <!-- Priority-coloured reading hero (bleeds to modal edges) -->
    <header
      class="-mx-lg -mt-lg sm:-mx-xl sm:-mt-xl px-lg sm:px-xl pt-6 pb-5 rounded-t-2xl bg-gradient-to-br text-white relative overflow-hidden"
      :class="heroClass"
    >
      <div class="flex items-center gap-1.5 flex-wrap mb-3">
        <span
          class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-white/20 inline-flex items-center gap-1"
        >
          <!-- tier icon -->
          <svg v-if="tier === 'penting'" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
          <svg v-else-if="tier === 'acara'" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
          <svg v-else width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m3 11 18-5v12L3 14v-3z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/></svg>
          {{ tierLabel }}
        </span>
        <span
          v-if="announcement.is_pinned"
          class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-white/20 inline-flex items-center gap-1"
        >
          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/></svg>
          {{ t('announcements.pinnedLabel') }}
        </span>
        <span
          v-if="audienceLabel"
          class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-white/20"
        >
          {{ audienceLabel }}
        </span>
      </div>

      <h2 class="text-xl font-black leading-snug text-balance">
        {{ announcement.title || t('announcements.untitled') }}
      </h2>
      <p class="text-[12px] text-white/85 mt-2.5">
        <span v-if="announcement.source">{{ announcement.source }} · </span>
        {{ dateLabel }}
        <span v-if="relativeLabel"> · {{ relativeLabel }}</span>
        <template v-if="validUntil">
          · {{ t('announcements.validUntil', { date: validUntil }) }}
        </template>
      </p>
    </header>

    <!-- Event block: date + countdown + add to calendar -->
    <div
      v-if="announcement.event_at"
      class="mt-4 rounded-xl border border-slate-200 overflow-hidden"
    >
      <div class="flex items-center gap-3 p-3" :class="accentBg">
        <span class="inline-flex" :class="accentText">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
        </span>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-extrabold text-slate-800">{{ eventWhen }}</p>
          <p v-if="announcement.event_location" class="text-[11.5px] text-slate-500">
            {{ announcement.event_location }}
          </p>
        </div>
        <span
          v-if="countdown"
          class="text-2xs font-black px-2.5 py-1 rounded-full bg-white"
          :class="accentText"
        >
          {{ countdown }}
        </span>
      </div>
      <a
        :href="calendarUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center justify-center gap-1.5 py-2.5 text-[12px] font-extrabold border-t border-slate-100"
        :class="accentText"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        {{ t('announcements.addToCalendar') }}
      </a>
    </div>

    <!-- Body — rich HTML (Quill), sanitized. Legacy plain-text bodies keep
         their line breaks + WhatsApp *bold* via renderAnnouncementHtml. -->
    <article
      v-if="renderedBody"
      class="rpp-prose mt-4 text-[14.5px] text-slate-700 leading-relaxed"
      v-html="renderedBody"
    ></article>
    <p v-else class="mt-4 text-[13px] italic text-slate-400">(Tanpa isi)</p>

    <!-- Attachment -->
    <a
      v-if="announcement.attachment_url"
      :href="announcement.attachment_url"
      target="_blank"
      rel="noopener noreferrer"
      class="mt-4 flex items-center gap-3 rounded-xl border border-slate-200 px-3 py-2.5 hover:bg-slate-50"
    >
      <span
        class="w-8 h-8 rounded-lg grid place-items-center text-2xs font-black"
        :class="[accentBg, accentText]"
      >
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
      </span>
      <span class="flex-1 min-w-0 text-[12.5px] font-bold text-slate-700 truncate">
        {{ announcement.attachment_name || t('announcements.attachment') }}
      </span>
      <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-slate-400"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
    </a>

    <!-- Read metrics (admin / teacher) -->
    <p
      v-if="showReadMetrics"
      class="mt-4 text-2xs text-slate-500 inline-flex items-center gap-1.5 bg-slate-50 rounded-lg px-3 py-2"
    >
      <NavIcon name="eye" :size="13" />
      Dibaca {{ announcement.read_count ?? 0 }} dari
      {{ announcement.total_recipients }} penerima
    </p>

    <!-- Footer actions -->
    <footer class="mt-5 flex items-center gap-2 flex-wrap">
      <Button variant="secondary" size="sm" @click="emit('close')"
        >Tutup</Button
      >
      <span class="flex-1"></span>
      <Button
        v-if="canDelete"
        variant="ghost"
        size="sm"
        class="!text-red-600 hover:!bg-red-50"
        @click="emit('delete', announcement)"
      >
        <NavIcon name="trash" :size="13" />
        Hapus
      </Button>
      <Button
        v-if="canEdit"
        variant="primary"
        size="sm"
        @click="emit('edit', announcement)"
      >
        <NavIcon name="edit" :size="13" />
        Edit
      </Button>
    </footer>
  </Modal>
</template>

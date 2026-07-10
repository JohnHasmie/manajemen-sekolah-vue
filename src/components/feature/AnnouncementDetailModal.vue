<!--
  AnnouncementDetailModal.vue — full read view for an announcement.

  Mirrors Flutter's `AnnouncementDetailSheet`. Header carries title +
  meta strip (date, category, source); body renders the full text
  with `whitespace-pre-wrap`; footer exposes role-specific actions:

    - admin → Tutup · Hapus · Edit
    - teacher  → Tutup · (Hapus when ownPost)
    - parent  → Tutup
-->
<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { formatDateLong, formatRelative } from '@/lib/format';
import { AnnouncementService } from '@/services/announcements.service';
import type { Announcement } from '@/types/announcements';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { canonicalRole, ROLE_ADMIN, ROLE_TEACHER } from '@/utils/role';

const props = withDefaults(
  defineProps<{
    announcement: Announcement;
    viewerRole?: 'admin' | 'teacher' | 'parent';
    canEdit?: boolean;
    canDelete?: boolean;
    /**
     * Auto-mark as read on mount. Default true for the parent inbox.
     * Pass false from admin/teacher detail where reads are already
     * tracked or where the action would skew metrics.
     */
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

const CATEGORY_PALETTE: Record<
  string,
  { bg: string; text: string; label: string }
> = {
  penting: { bg: 'bg-red-50', text: 'text-red-700', label: 'Penting' },
  pengumuman: { bg: 'bg-slate-100', text: 'text-slate-600', label: 'Umum' },
  umum: { bg: 'bg-slate-100', text: 'text-slate-600', label: 'Umum' },
  acara: { bg: 'bg-violet-50', text: 'text-violet-700', label: 'Acara' },
  libur: { bg: 'bg-amber-50', text: 'text-amber-700', label: 'Libur' },
};

const categoryStyle = computed(
  () =>
    CATEGORY_PALETTE[props.announcement.category] ??
    CATEGORY_PALETTE.pengumuman,
);

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
  if (a.audience === 'all') return 'Semua wali';
  if (a.audience === 'role') return 'Per peran';
  if (a.audience === 'class') return 'Per kelas';
  if (a.audience === 'student') return 'Per siswa';
  return null;
});

onMounted(() => {
  if (props.autoMarkRead && props.announcement.is_read === false) {
    AnnouncementService.markAsRead(props.announcement.id);
  }
});
</script>

<template>
  <Modal title="" @close="emit('close')">
    <!-- Header block -->
    <header class="-mt-md">
      <div class="flex items-center gap-1.5 flex-wrap mb-2">
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
          v-if="announcement.is_pinned"
          class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-amber-50 text-amber-700 inline-flex items-center gap-1"
        >
          <NavIcon name="star" :size="11" /> Disematkan
        </span>
      </div>

      <h2 class="text-lg font-black text-slate-900 leading-snug">
        {{ announcement.title || '(Tanpa judul)' }}
      </h2>
      <p class="text-[12px] text-slate-500 mt-1.5">
        {{ dateLabel }}
        <span v-if="relativeLabel"> · {{ relativeLabel }}</span>
        <span v-if="announcement.source"> · {{ announcement.source }}</span>
      </p>
    </header>

    <!-- Body -->
    <article
      class="mt-4 text-[13px] text-slate-700 leading-relaxed whitespace-pre-wrap"
    >
      {{ announcement.body || '(Tanpa isi)' }}
    </article>

    <!-- Read metrics (admin / teacher) -->
    <p
      v-if="
        [ROLE_ADMIN, ROLE_TEACHER].includes(canonicalRole(viewerRole)) &&
        typeof announcement.total_recipients === 'number' &&
        announcement.total_recipients > 0
      "
      class="mt-4 text-2xs text-slate-500 inline-flex items-center gap-1.5"
    >
      <NavIcon name="eye" :size="13" />
      Dibaca {{ announcement.read_count ?? 0 }} dari
      {{ announcement.total_recipients }} wali murid
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

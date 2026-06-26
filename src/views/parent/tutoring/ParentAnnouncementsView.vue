<!--
  ParentAnnouncementsView — parent announcement list.

  Fetches announcements for EVERY child the parent has (Promise.all +
  dedupe), so a multi-child family sees the full picture. Mirrors the
  mobile `parent_announcements_screen.dart:74` implementation.

  Two filter axes:
    - Anak chip (Semua anak / per-anak)        — drives the fetch scope
    - Group chip (Semua group / per-group) — client-side filter
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringGroupAnnouncement } from '@/types/tutoring';

import ParentHomeHero from '@/components/feature/tutoring/ParentHomeHero.vue';

const { t } = useI18n();
const { children, activeChildId } = useChildPicker();

// Row carries the child it belongs to so the chip filter + subtitle
// can show "milik anak X" without an extra lookup.
type Row = {
  a: TutoringGroupAnnouncement;
  child_id: string;
  child_name: string;
};

const loading = ref(true);
const rows = ref<Row[]>([]);
// Two-axis filter: which child, which group.
const childFilter = ref<string>('all');
const groupFilter = ref<string>('all');

async function load() {
  loading.value = true;
  try {
    const kids = children.value;
    if (kids.length === 0) {
      rows.value = [];
      return;
    }
    const fetched = await Promise.all(
      kids.map(async (c) => {
        try {
          const list = await TutoringService.getGroupAnnouncements({
            student_id: c.student_id,
          });
          return list.map<Row>((a) => ({
            a,
            child_id: c.student_id,
            child_name: c.name,
          }));
        } catch {
          return [] as Row[];
        }
      }),
    );
    // Flatten + dedupe by announcement id (siblings sometimes share a
    // group and would otherwise create double rows).
    const seen = new Set<string>();
    const out: Row[] = [];
    for (const group of fetched) {
      for (const r of group) {
        if (r.a.id && !seen.has(r.a.id)) {
          seen.add(r.a.id);
          out.push(r);
        }
      }
    }
    // Newest first.
    out.sort((x, y) => {
      const ax = x.a.created_at ? new Date(x.a.created_at).valueOf() : 0;
      const by = y.a.created_at ? new Date(y.a.created_at).valueOf() : 0;
      return by - ax;
    });
    rows.value = out;
  } finally {
    loading.value = false;
  }
}
onMounted(load);
// Re-fetch when the children list itself changes (login flow, etc.).
// activeChildId doesn't trigger because filtering is now in-page.
watch(() => children.value.map((c) => c.student_id).join(','), load);

const childChips = computed(() => {
  const out: { id: string; label: string }[] = [{ id: 'all', label: t('wali.bimbel.announcements.child_filter_all') }];
  for (const c of children.value) {
    out.push({ id: c.student_id, label: c.name.split(' ')[0] });
  }
  return out;
});

const groupChips = computed(() => {
  // Group chips reflect only the group present in the currently-
  // visible-by-child rows. Switching to "Anak A" should narrow the
  // group chips to A's group only.
  const pool = childFilter.value === 'all'
    ? rows.value
    : rows.value.filter((r) => r.child_id === childFilter.value);
  const seen = new Set<string>();
  const out: { id: string; label: string }[] = [{ id: 'all', label: t('wali.bimbel.announcements.group_filter_all') }];
  for (const r of pool) {
    const id = r.a.tutoring_group_id;
    if (id && !seen.has(id)) {
      seen.add(id);
      out.push({ id, label: r.a.group_name ?? id });
    }
  }
  return out;
});

function isNew(a: TutoringGroupAnnouncement): boolean {
  if (!a.created_at) return false;
  return Date.now() - new Date(a.created_at).valueOf() < 48 * 3_600_000;
}

const newCount = computed(() => rows.value.filter((r) => isNew(r.a)).length);

const visible = computed(() => {
  let list = rows.value;
  if (childFilter.value !== 'all') {
    list = list.filter((r) => r.child_id === childFilter.value);
  }
  if (groupFilter.value !== 'all') {
    list = list.filter((r) => r.a.tutoring_group_id === groupFilter.value);
  }
  return list;
});

function relTime(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diffMin = (Date.now() - d.valueOf()) / 60_000;
  if (diffMin < 60) return t('wali.bimbel.announcements.minute_ago', { minutes: Math.max(1, Math.floor(diffMin)) });
  const h = Math.floor(diffMin / 60);
  if (h < 24) return t('wali.bimbel.announcements.hour_ago', { hours: h });
  const days = Math.floor(h / 24);
  if (days < 7) return t('wali.bimbel.announcements.day_ago', { days });
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

function snippet(body?: string | null, n = 150): string {
  if (!body) return '';
  const trimmed = body.trim();
  return trimmed.length > n ? `${trimmed.slice(0, n).trimEnd()}…` : trimmed;
}

const subtitle = computed(() => {
  const parts: string[] = [
    t('wali.bimbel.announcements.subtitle_new_count', { count: newCount.value }),
    t('wali.bimbel.announcements.subtitle_total_count', { count: rows.value.length }),
  ];
  if (children.value.length > 1) parts.push(t('wali.bimbel.announcements.subtitle_child_count', { count: children.value.length }));
  return parts.join(' · ');
});
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentHomeHero
      :kicker="t('wali.bimbel.announcements.kicker')"
      :title="t('wali.bimbel.announcements.title')"
      :subtitle="subtitle"
      :stats="[]"
    />

    <!-- Anak filter chips (only when parent has >1 child) -->
    <div v-if="children.length > 1" class="flex gap-1.5 flex-wrap">
      <button
        v-for="c in childChips"
        :key="c.id"
        type="button"
        class="rounded-full px-2.5 py-1 text-[12px] transition-colors"
        :class="
          childFilter === c.id
            ? 'bg-bimbel-hero text-white font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid'
        "
        @click="
          childFilter = c.id;
          // Reset kelompok filter — chips change when child changes.
          groupFilter = 'all';
        "
      >{{ c.label }}</button>
    </div>

    <!-- Group filter chips -->
    <div class="flex gap-1.5 flex-wrap">
      <button
        v-for="g in groupChips"
        :key="g.id"
        type="button"
        class="rounded-full px-2.5 py-1 text-[12px] transition-colors"
        :class="
          groupFilter === g.id
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid'
        "
        @click="groupFilter = g.id"
      >{{ g.label }}</button>
    </div>

    <div class="space-y-2">
      <div
        v-for="r in visible"
        :key="r.a.id"
        class="rounded-lg bg-bimbel-bg p-2.5"
        :class="isNew(r.a) ? 'border-l-2 border-bimbel-hero pl-3' : ''"
      >
        <div class="flex justify-between items-start gap-2">
          <div class="min-w-0 flex-1">
            <p class="text-[10px] text-bimbel-text-lo tracking-wider font-bold uppercase">
              {{ r.a.author_name }} · {{ r.a.group_name }}
              <span v-if="children.length > 1" class="text-bimbel-hero">· {{ r.child_name }}</span>
            </p>
            <p class="text-[14px] font-bold text-bimbel-text-hi mt-0.5">{{ r.a.title }}</p>
          </div>
          <span
            v-if="isNew(r.a)"
            class="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide bg-red-900 text-white flex-shrink-0"
          >{{ t('wali.bimbel.announcements.badge_new') }}</span>
          <span
            v-else
            class="text-[12px] text-bimbel-text-lo flex-shrink-0"
          >{{ relTime(r.a.created_at) }}</span>
        </div>
        <p class="text-[12px] text-bimbel-text-mid leading-relaxed mt-1">{{ snippet(r.a.body) }}</p>
      </div>
      <p v-if="!visible.length && !loading" class="text-center text-[13px] text-bimbel-text-mid py-6">
        {{ t('wali.bimbel.announcements.empty_filter') }}
      </p>
      <p v-if="loading" class="text-center text-[13px] text-bimbel-text-mid py-6">{{ t('wali.bimbel.announcements.loading') }}</p>
    </div>
  </div>
</template>

<!--
  ParentActivityDetailModal.vue — read-only sheet shown after the
  parent taps an activity card. Mirrors Flutter's `_ActivityDetailContent`
  (parent_activity_ui_builder_mixin.dart). Rows shown:

    • Guru Pengajar (always)
    • Mata Pelajaran (always)
    • Tanggal — "Day · dd/MM/yyyy"
    • Batas Waktu — only for assignments with a deadline
    • Deskripsi — only when non-empty
    • Materi — only when chapter_title is set; sub_chapter on second line
    • Sub-Bab tambahan — one row per additional_material entry

  Wali-tinted header (azure) to match the rest of the parent role.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { ClassActivity } from '@/types/class-activity';
import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{ activity: ClassActivity }>();
defineEmits<{ close: [] }>();

const isAssignment = computed(() => {
  const raw = (props.activity.raw_type ?? '').toLowerCase().trim();
  if (raw === 'materi' || raw === 'material' || raw === 'info') return false;
  return (
    props.activity.type === 'tugas' ||
    props.activity.type === 'pr' ||
    props.activity.type === 'ulangan'
  );
});

function fmtDate(iso?: string | null): string {
  if (!iso) return '-';
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) return iso;
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yy = d.getFullYear();
  return `${dd}/${mm}/${yy}`;
}

const dayLabel = computed(() => {
  if (!props.activity.date) return '-';
  const d = new Date(props.activity.date);
  if (!Number.isFinite(d.getTime())) return '-';
  return d.toLocaleDateString('id-ID', { weekday: 'long' });
});

const chapterValue = computed(() => {
  const bab = props.activity.chapter_title ?? props.activity.chapter_label ?? '';
  const sub = props.activity.sub_chapter_title ?? '';
  if (bab && sub) return `${bab}\n• ${sub}`;
  return bab || sub || '';
});

const hasDescription = computed(() => {
  const d = (props.activity.description ?? '').trim();
  return d.length > 0 && d !== 'null';
});
</script>

<template>
  <Modal :title="activity.title" size="lg" @close="$emit('close')">
    <!-- Sub-header pill -->
    <div class="flex items-center gap-2 mb-4">
      <span
        class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold tracking-wide"
        :class="
          isAssignment
            ? 'bg-amber-100 text-amber-700'
            : 'bg-emerald-100 text-emerald-700'
        "
      >
        <NavIcon :name="isAssignment ? 'check-square' : 'book'" :size="12" />
        {{ isAssignment ? 'Tugas' : 'Materi' }}
      </span>
      <span
        v-if="activity.is_specific_target"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-sky-100 text-sky-700"
      >
        <NavIcon name="shield" :size="12" />
        Khusus
      </span>
      <span
        v-if="activity.for_this_student"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-blue-100 text-blue-700"
      >
        <NavIcon name="star" :size="12" />
        Untuk anak ini
      </span>
    </div>

    <!-- Detail rows -->
    <dl class="divide-y divide-slate-100">
      <div class="py-2.5 grid grid-cols-[28px_1fr] gap-3">
        <NavIcon name="user" :size="16" class="text-role-wali mt-0.5" />
        <div>
          <dt class="text-[11px] font-bold text-slate-500 uppercase tracking-wide">
            Guru Pengajar
          </dt>
          <dd class="text-[13px] font-medium text-slate-800 mt-0.5">
            {{ activity.teacher_name || '-' }}
          </dd>
        </div>
      </div>

      <div class="py-2.5 grid grid-cols-[28px_1fr] gap-3">
        <NavIcon name="book" :size="16" class="text-role-wali mt-0.5" />
        <div>
          <dt class="text-[11px] font-bold text-slate-500 uppercase tracking-wide">
            Mata Pelajaran
          </dt>
          <dd class="text-[13px] font-medium text-slate-800 mt-0.5">
            {{ activity.subject_name || '-' }}
          </dd>
        </div>
      </div>

      <div class="py-2.5 grid grid-cols-[28px_1fr] gap-3">
        <NavIcon name="calendar" :size="16" class="text-role-wali mt-0.5" />
        <div>
          <dt class="text-[11px] font-bold text-slate-500 uppercase tracking-wide">
            Tanggal
          </dt>
          <dd class="text-[13px] font-medium text-slate-800 mt-0.5">
            {{ dayLabel }} · {{ fmtDate(activity.date) }}
          </dd>
        </div>
      </div>

      <div
        v-if="isAssignment && activity.deadline"
        class="py-2.5 grid grid-cols-[28px_1fr] gap-3"
      >
        <NavIcon name="clock" :size="16" class="text-red-600 mt-0.5" />
        <div>
          <dt class="text-[11px] font-bold text-slate-500 uppercase tracking-wide">
            Batas Waktu
          </dt>
          <dd class="text-[13px] font-medium text-slate-800 mt-0.5">
            {{ fmtDate(activity.deadline) }}
          </dd>
        </div>
      </div>

      <div
        v-if="hasDescription"
        class="py-2.5 grid grid-cols-[28px_1fr] gap-3"
      >
        <NavIcon name="file" :size="16" class="text-role-wali mt-0.5" />
        <div>
          <dt class="text-[11px] font-bold text-slate-500 uppercase tracking-wide">
            Deskripsi
          </dt>
          <dd class="text-[13px] text-slate-700 mt-0.5 whitespace-pre-line">
            {{ activity.description }}
          </dd>
        </div>
      </div>

      <div
        v-if="chapterValue"
        class="py-2.5 grid grid-cols-[28px_1fr] gap-3"
      >
        <NavIcon name="book" :size="16" class="text-role-wali mt-0.5" />
        <div>
          <dt class="text-[11px] font-bold text-slate-500 uppercase tracking-wide">
            Materi
          </dt>
          <dd class="text-[13px] font-medium text-slate-800 mt-0.5 whitespace-pre-line">
            {{ chapterValue }}
          </dd>
        </div>
      </div>

      <div
        v-for="(m, idx) in activity.additional_material ?? []"
        :key="idx"
        class="py-2.5 grid grid-cols-[28px_1fr] gap-3"
      >
        <NavIcon name="bookmark" :size="16" class="text-role-wali mt-0.5" />
        <div>
          <dt class="text-[11px] font-bold text-slate-500 uppercase tracking-wide">
            Sub-Bab Tambahan
          </dt>
          <dd class="text-[13px] font-medium text-slate-800 mt-0.5">
            {{ m.sub_chapter_title }}
          </dd>
        </div>
      </div>
    </dl>
  </Modal>
</template>

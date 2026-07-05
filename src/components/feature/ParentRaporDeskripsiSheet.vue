<!--
  ParentRaporDeskripsiSheet.vue — per-subject deskripsi capaian sheet.

  Web port of Flutter's `showParentRaporDeskripsiSheet`
  (parent_report_card_detail_widgets.dart). Two stacked blocks:
    • KI 3 · Pengetahuan — predicate + score + long description
    • KI 4 · Keterampilan — predicate + score + long description

  Empty descriptions fall back to a friendly italic placeholder.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { RaportSubject } from '@/types/report-card';
import Modal from '@/components/ui/Modal.vue';

const props = defineProps<{ subject: RaportSubject }>();
const emit = defineEmits<{ close: [] }>();

const kkm = computed<number>(() => props.subject.kkm ?? 75);

function toNum(v: unknown): number | null {
  if (v == null) return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v === 'string' && v.trim()) {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

const knowledgeNum = computed(() => toNum(props.subject.knowledge_score));
const skillNum = computed(() => toNum(props.subject.skill_score));

function scoreTone(score: number | null): string {
  if (score == null) return 'text-slate-400';
  if (score >= kkm.value) return 'text-emerald-700';
  return 'text-red-700';
}
function chipTone(score: number | null): string {
  if (score == null) return 'bg-slate-100 text-slate-500';
  if (score >= kkm.value + 10) return 'bg-emerald-100 text-emerald-700';
  if (score >= kkm.value) return 'bg-blue-100 text-blue-700';
  return 'bg-red-100 text-red-700';
}
</script>

<template>
  <Modal
    :title="subject.subject_name"
    :subtitle="
      subject.teacher_name
        ? `${subject.teacher_name} · Deskripsi capaian`
        : 'Deskripsi capaian'
    "
    size="xl"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- KI 3 Pengetahuan -->
      <section class="rounded-2xl border border-slate-200 bg-white p-4">
        <header class="flex items-center justify-between gap-2 mb-2">
          <div>
            <p
              class="text-3xs font-bold uppercase tracking-widest text-slate-500"
            >
              KI 3
            </p>
            <h4 class="text-[13px] font-bold text-slate-900 mt-0.5">
              Pengetahuan
            </h4>
          </div>
          <div class="flex items-center gap-1.5">
            <span
              v-if="subject.knowledge_predicate"
              class="text-3xs font-bold px-2 py-0.5 rounded-full"
              :class="chipTone(knowledgeNum)"
            >
              {{ subject.knowledge_predicate }}
            </span>
            <span
              class="text-[20px] font-black tabular-nums"
              :class="scoreTone(knowledgeNum)"
            >
              {{ knowledgeNum ?? '—' }}
            </span>
          </div>
        </header>
        <p
          v-if="subject.knowledge_description?.trim()"
          class="text-[12.5px] text-slate-700 leading-relaxed whitespace-pre-wrap"
        >
          {{ subject.knowledge_description }}
        </p>
        <p v-else class="text-[12px] text-slate-400 italic">
          Wali kelas belum menulis deskripsi pengetahuan untuk mata pelajaran ini.
        </p>
      </section>

      <!-- KI 4 Keterampilan -->
      <section class="rounded-2xl border border-slate-200 bg-white p-4">
        <header class="flex items-center justify-between gap-2 mb-2">
          <div>
            <p
              class="text-3xs font-bold uppercase tracking-widest text-slate-500"
            >
              KI 4
            </p>
            <h4 class="text-[13px] font-bold text-slate-900 mt-0.5">
              Keterampilan
            </h4>
          </div>
          <div class="flex items-center gap-1.5">
            <span
              v-if="subject.skill_predicate"
              class="text-3xs font-bold px-2 py-0.5 rounded-full"
              :class="chipTone(skillNum)"
            >
              {{ subject.skill_predicate }}
            </span>
            <span
              class="text-[20px] font-black tabular-nums"
              :class="scoreTone(skillNum)"
            >
              {{ skillNum ?? '—' }}
            </span>
          </div>
        </header>
        <p
          v-if="subject.skill_description?.trim()"
          class="text-[12.5px] text-slate-700 leading-relaxed whitespace-pre-wrap"
        >
          {{ subject.skill_description }}
        </p>
        <p v-else class="text-[12px] text-slate-400 italic">
          Wali kelas belum menulis deskripsi keterampilan untuk mata pelajaran ini.
        </p>
      </section>

      <p
        class="text-2xs text-slate-500 italic px-1 leading-relaxed"
      >
        KKM {{ kkm }} · Deskripsi ini ditulis oleh wali kelas berdasarkan
        capaian harian.
      </p>
    </div>
  </Modal>
</template>

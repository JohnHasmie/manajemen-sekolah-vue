<!--
  ParentRaporSubjectCard.vue — single mata pelajaran row on the
  parent rapor detail screen. Web port of Flutter's
  `ParentRaporSubjectCard` (parent_report_card_detail_widgets.dart).

  Layout:
    ┌──────────────────────────────────────────────────┐
    │  Matematika                          Bu Sari      │  ← subject + teacher
    │  ┌──────────────────┬──────────────────────┐      │
    │  │ KI 3  Pengetahuan│ KI 4  Keterampilan   │      │  ← score cells
    │  │ 85          [B]  │ 82          [B]      │      │
    │  └──────────────────┴──────────────────────┘      │
    │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Tuntas ✓     │  ← verdict bar (vs KKM)
    │  Tap untuk lihat deskripsi capaian →             │
    └──────────────────────────────────────────────────┘

  Tap → emits `open` which the host opens as a Deskripsi sheet.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { RaportSubject } from '@/types/report-card';
import NavIcon from '@/components/feature/NavIcon.vue';
import InfoHint from '@/components/ui/InfoHint.vue';

const props = defineProps<{ subject: RaportSubject }>();
defineEmits<{ open: [RaportSubject] }>();

function toNum(v: unknown): number | null {
  if (v == null) return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v === 'string' && v.trim()) {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

// The KKM is optional on the wire. When the school never set one for this
// subject there is no threshold to judge against, so every verdict below goes
// tri-state (`null` = cannot be said) rather than falling back to an invented
// 75 and telling a guardian their child fell short of a standard nobody set.
const kkm = computed<number | null>(() => props.subject.kkm ?? null);

const knowledgeNum = computed<number | null>(() =>
  toNum(props.subject.knowledge_score),
);
const skillNum = computed<number | null>(() => toNum(props.subject.skill_score));

const hasKnowledge = computed(() => knowledgeNum.value != null);
const hasSkill = computed(() => skillNum.value != null);

/** `null` when the score or the KKM is unknown — no verdict either way. */
function okAgainstKkm(score: number | null): boolean | null {
  const k = kkm.value;
  if (score == null || k == null) return null;
  return score >= k;
}

const knowledgeOk = computed(() => okAgainstKkm(knowledgeNum.value));
const skillOk = computed(() => okAgainstKkm(skillNum.value));

const hasAnyScore = computed(() => hasKnowledge.value || hasSkill.value);

// Overall verdict — Tuntas only when BOTH KI3 & KI4 are at/above KKM
// (mirrors Flutter `_ParentRaporVerdictBar` which checks both). `null` means
// unjudgeable: nothing graded yet, or the school set no KKM for this subject.
const allTuntas = computed<boolean | null>(() => {
  if (!hasAnyScore.value || kkm.value == null) return null;
  if (hasKnowledge.value && !knowledgeOk.value) return false;
  if (hasSkill.value && !skillOk.value) return false;
  return true;
});

const verdictPct = computed(() => {
  const scores: number[] = [];
  if (knowledgeNum.value != null) scores.push(knowledgeNum.value);
  if (skillNum.value != null) scores.push(skillNum.value);
  if (scores.length === 0) return 0;
  const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
  return Math.max(0, Math.min(100, avg));
});

function predicateTone(score: number | null): string {
  const k = kkm.value;
  if (score == null) return 'bg-slate-100 text-slate-500';
  if (k == null) return 'bg-slate-100 text-slate-700';
  if (score >= k + 10) return 'bg-emerald-100 text-emerald-700';
  if (score >= k) return 'bg-blue-100 text-blue-700';
  return 'bg-red-100 text-red-700';
}
</script>

<template>
  <button
    type="button"
    class="w-full text-left bg-white border border-slate-200 rounded-2xl p-4 hover:border-role-wali/30 hover:shadow-sm transition-all"
    @click="$emit('open', subject)"
  >
    <!-- Header row -->
    <div class="flex items-center gap-2">
      <p class="text-[13px] font-bold text-slate-900 flex-1 min-w-0 truncate">
        {{ subject.subject_name }}
      </p>
      <p
        v-if="subject.teacher_name"
        class="text-[10.5px] font-medium text-slate-500 truncate flex-shrink-0 max-w-[40%]"
      >
        {{ subject.teacher_name }}
      </p>
    </div>

    <!-- KI3 + KI4 score cells -->
    <div class="grid grid-cols-2 gap-2 mt-2.5">
      <!-- KI 3 Pengetahuan -->
      <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
        <p class="text-4xs font-bold uppercase tracking-widest text-slate-500">
          KI 3 · Pengetahuan
        </p>
        <div class="flex items-baseline gap-1.5 mt-1">
          <span
            class="text-[18px] font-black tabular-nums"
            :class="{
              'text-emerald-700': knowledgeOk === true,
              'text-red-700': knowledgeOk === false,
              'text-slate-700': knowledgeOk === null && hasKnowledge,
              'text-slate-400': !hasKnowledge,
            }"
          >
            {{ knowledgeNum ?? '—' }}
          </span>
          <span
            v-if="subject.knowledge_predicate"
            class="text-3xs font-bold px-1.5 py-0.5 rounded-full"
            :class="predicateTone(knowledgeNum)"
          >
            {{ subject.knowledge_predicate }}
          </span>
        </div>
      </div>

      <!-- KI 4 Keterampilan -->
      <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
        <p class="text-4xs font-bold uppercase tracking-widest text-slate-500">
          KI 4 · Keterampilan
        </p>
        <div class="flex items-baseline gap-1.5 mt-1">
          <span
            class="text-[18px] font-black tabular-nums"
            :class="{
              'text-emerald-700': skillOk === true,
              'text-red-700': skillOk === false,
              'text-slate-700': skillOk === null && hasSkill,
              'text-slate-400': !hasSkill,
            }"
          >
            {{ skillNum ?? '—' }}
          </span>
          <span
            v-if="subject.skill_predicate"
            class="text-3xs font-bold px-1.5 py-0.5 rounded-full"
            :class="predicateTone(skillNum)"
          >
            {{ subject.skill_predicate }}
          </span>
        </div>
      </div>
    </div>

    <!-- Verdict bar -->
    <div class="flex items-center gap-2 mt-3">
      <div class="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden">
        <div
          class="h-full transition-all"
          :class="{
            'bg-emerald-500': allTuntas === true,
            'bg-amber-500': allTuntas === false,
            'bg-slate-400': allTuntas === null,
          }"
          :style="{ width: `${verdictPct}%` }"
        ></div>
      </div>
      <span
        class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full flex-shrink-0"
        :class="{
          'bg-emerald-100 text-emerald-700': allTuntas === true,
          'bg-amber-100 text-amber-700': allTuntas === false,
          'bg-slate-100 text-slate-500': allTuntas === null,
        }"
      >
        {{
          allTuntas === true
            ? 'Tuntas'
            : allTuntas === false
              ? 'Perlu perbaikan'
              : hasAnyScore
                ? 'Sudah dinilai'
                : 'Belum dinilai'
        }}
      </span>
      <span
        v-if="kkm != null"
        class="inline-flex items-center gap-1 text-3xs font-bold text-slate-400 tabular-nums"
      >
        KKM {{ kkm }}
        <InfoHint
          :text="`KKM = Kriteria Ketuntasan Minimal — nilai minimum agar sebuah pelajaran dianggap tuntas. Di sini ${kkm}.`"
          aria-label="Apa itu KKM?"
        />
      </span>
    </div>

    <!-- Tap hint -->
    <div class="flex items-center gap-1 mt-2.5 text-[10.5px] font-bold text-role-wali">
      Lihat deskripsi capaian
      <NavIcon name="chevron-right" :size="11" />
    </div>
  </button>
</template>

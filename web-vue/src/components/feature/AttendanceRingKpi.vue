<!--
  AttendanceRingKpi.vue — parent attendance hero card.

  Mirrors Flutter's `AttendanceRingKpi`. Shows a brand-tinted ring
  chart of the present-rate with a 4-up breakdown (Hadir / Izin /
  Sakit / Alpa) + period label + `vs Bulan lalu` delta chip.

  The host computes counts + rate + deltaPct (vs previous month) and
  hands them in as props.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();

const props = withDefaults(
  defineProps<{
    /** Present rate 0..100. */
    rate: number;
    /** Period label e.g. "Bulan ini" / "Periode terpilih". */
    periodLabel: string;
    /** Counts breakdown — Flutter sums hadir + terlambat into "present". */
    present: number;
    izin: number;
    sakit: number;
    alpha: number;
    /** Total school days the window covered. */
    schoolDays: number;
    /** Optional delta vs previous period (percentage points). */
    deltaPct?: number | null;
  }>(),
  { deltaPct: null },
);

// Stroke-dasharray for the SVG circle (circumference ~326.7 for r=52).
const circumference = 326.7;

const ringDash = computed<string>(() => {
  const pct = Math.max(0, Math.min(100, props.rate));
  return `${(pct / 100) * circumference} ${circumference}`;
});

const deltaTone = computed<string>(() => {
  if (props.deltaPct == null) return 'bg-white/15 text-white/70';
  if (props.deltaPct >= 1) return 'bg-emerald-500/20 text-emerald-200';
  if (props.deltaPct <= -1) return 'bg-red-500/20 text-red-200';
  return 'bg-white/15 text-white/80';
});

const deltaLabel = computed<string>(() => {
  if (props.deltaPct == null) return t('parent.attendance.ringDeltaNone');
  if (props.deltaPct === 0) return t('parent.attendance.ringDeltaSame');
  const arrow = props.deltaPct > 0 ? '↑' : '↓';
  return `${arrow} ${Math.abs(props.deltaPct).toFixed(1)} ${t('parent.attendance.ringDeltaVsLastMonth')}`;
});
</script>

<template>
  <section
    class="rounded-3xl p-6 text-white shadow-xl shadow-role-wali/20 relative overflow-hidden"
    style="background: linear-gradient(135deg, #0B5677 0%, #6B4FB0 100%);"
  >
    <div class="absolute -top-12 -right-12 w-44 h-44 bg-white/10 rounded-full blur-3xl"></div>
    <div class="relative z-10 flex items-center gap-6 flex-wrap">
      <!-- Ring -->
      <div class="relative w-32 h-32 flex-shrink-0">
        <svg viewBox="0 0 120 120" class="w-full h-full -rotate-90">
          <circle
            cx="60"
            cy="60"
            r="52"
            fill="none"
            stroke="rgba(255,255,255,0.15)"
            stroke-width="10"
          />
          <circle
            cx="60"
            cy="60"
            r="52"
            fill="none"
            stroke="#A78BFA"
            stroke-width="10"
            stroke-linecap="round"
            :stroke-dasharray="ringDash"
          />
        </svg>
        <div class="absolute inset-0 grid place-items-center text-center">
          <div>
            <p class="text-[10px] font-bold text-white/70 uppercase tracking-widest">
              {{ t('parent.attendance.ringHadir') }}
            </p>
            <p class="text-2xl font-black">{{ rate.toFixed(1) }}%</p>
          </div>
        </div>
      </div>

      <!-- Right column -->
      <div class="flex-1 min-w-[200px] space-y-2">
        <div class="flex items-center gap-2 flex-wrap">
          <p class="text-[10px] font-bold tracking-widest uppercase text-white/70">
            {{ periodLabel }}
          </p>
          <span
            class="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full"
            :class="deltaTone"
          >
            <NavIcon
              :name="deltaPct != null && deltaPct >= 0 ? 'trending-up' : 'trending-down'"
              :size="10"
            />
            {{ deltaLabel }}
          </span>
        </div>
        <p class="text-[12px] text-white/80">
          {{ t('parent.attendance.ringSchoolDaysHadir', { days: schoolDays, present }) }}
        </p>
        <div class="grid grid-cols-4 gap-2 mt-3">
          <div class="bg-white/10 rounded-xl px-2 py-2">
            <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">{{ t('parent.attendance.ringHadir') }}</p>
            <p class="text-[14px] font-black mt-0.5">{{ present }}</p>
          </div>
          <div class="bg-white/10 rounded-xl px-2 py-2">
            <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">{{ t('parent.attendance.ringIzin') }}</p>
            <p class="text-[14px] font-black mt-0.5">{{ izin }}</p>
          </div>
          <div class="bg-white/10 rounded-xl px-2 py-2">
            <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">{{ t('parent.attendance.ringSakit') }}</p>
            <p class="text-[14px] font-black mt-0.5">{{ sakit }}</p>
          </div>
          <div class="bg-white/10 rounded-xl px-2 py-2">
            <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">{{ t('parent.attendance.ringAlpa') }}</p>
            <p class="text-[14px] font-black mt-0.5">{{ alpha }}</p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

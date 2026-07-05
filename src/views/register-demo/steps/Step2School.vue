<!--
  Step 2 — School. The most complex step.
  Jenjang chip row → live debounced search → match cards w/ 3 actions
  → "Buat baru" fallback. Selected school name + jenjang persist to
  the wizard payload so step 10 shows correct stats.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import { DemoService, type NpsnLookupResult } from '@/services/demo.service';
import type { EducationLevel, SchoolSearchHit } from '@/types/demo';
import { educationLevelDisplay, normalizeEducationLevel } from '@/lib/labels';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const wizard = useDemoWizardStore();
const toast = useToast();

// Wire-canonical English values per the 2026-06-26 enum cutover; UI
// shows the Indonesian abbreviation via `educationLevelDisplay()`.
const JENJANG_PRIMARY: EducationLevel[] = [
  'ELEMENTARY',         // SD
  'JUNIOR_HIGH',        // SMP
  'SENIOR_HIGH',        // SMA
  'VOCATIONAL_HIGH',    // SMK
];
const JENJANG_OTHERS: EducationLevel[] = ['TK', 'PAUD', 'MI', 'MTs', 'MA', 'Pesantren'];

const showOthers = ref(false);
// `?? ''` is defensive: a restored payload may carry a null school name,
// and onMounted/watch call `.length` / `.trim()` on this — null would throw
// and blank the step. (The store also coerces null → '' in mergeWithDefaults.)
const query = ref(wizard.payload.school.name ?? '');
const results = ref<SchoolSearchHit[]>([]);
const isSearching = ref(false);
const requestInflight = ref<string | null>(null);

// NPSN lookup state — separate from name search since the upstream
// Dapodik API only supports lookup-by-NPSN. User types an 8-12 digit
// NPSN and we hit /npsn-lookup to verify + auto-fill.
const npsnInput = ref(wizard.payload.school.npsn ?? '');
const isLookingUpNpsn = ref(false);
const npsnHit = ref<NpsnLookupResult | null>(null);
const npsnError = ref<string | null>(null);

let debounceTimer: ReturnType<typeof setTimeout> | null = null;

const selectedJenjang = computed({
  get: () => wizard.payload.school.education_level,
  set: (v: EducationLevel) => wizard.patchPayload('school', { education_level: v }),
});

onMounted(() => {
  if (query.value.length >= 2) runSearch();
});

watch(query, (q) => {
  // Mirror the typed name into wizard state so when the user picks
  // "Buat baru" we already have it. Empty string is fine — backend
  // validator catches < 3 chars at provision time.
  wizard.patchPayload('school', { name: q });
  if (debounceTimer) clearTimeout(debounceTimer);
  if (q.trim().length < 2) {
    results.value = [];
    return;
  }
  debounceTimer = setTimeout(runSearch, 350);
});

watch(selectedJenjang, () => {
  if (query.value.trim().length >= 2) runSearch();
});

async function runSearch() {
  isSearching.value = true;
  try {
    results.value = await DemoService.searchSchools({
      q: query.value.trim(),
      education_level: selectedJenjang.value,
    });
  } catch {
    results.value = [];
  } finally {
    isSearching.value = false;
  }
}

function setJenjang(j: EducationLevel) {
  selectedJenjang.value = j;
  showOthers.value = false;
}

function pickCreateNew() {
  wizard.patchPayload('school', {
    name: query.value.trim(),
    npsn: null,
  });
  wizard.next();
}

function pickRegistryHit(hit: SchoolSearchHit) {
  // User adopted an NPSN row that isn't on Kamiledu yet. Prefill
  // education_level / city / npsn from the registry hit. The Dapodik
  // registry still returns legacy Indonesian education_level values
  // (SD/SMP/SMA/SMK) — normalise to the canonical English wire form
  // before committing so the rest of the wizard sees one shape.
  const normalizedLevel = normalizeEducationLevel(hit.education_level);
  wizard.patchPayload('school', {
    name: hit.name,
    npsn: hit.npsn,
    city: hit.city ?? wizard.payload.school.city,
    education_level: (normalizedLevel as EducationLevel) ?? selectedJenjang.value,
  });
  toast.success('Sekolah diisi dari registri NPSN. Lanjut untuk klaim sebagai admin.');
  wizard.next();
}

async function requestAccess(hit: SchoolSearchHit) {
  if (!hit.id) return;
  requestInflight.value = hit.id;
  try {
    await DemoService.requestSchoolAccess({
      school_id: hit.id,
      school_type: hit.is_demo ? 'demo_school' : 'real_school',
      requested_role: 'admin',
      message: `Mohon akses untuk ${hit.name}.`,
    });
    toast.success(t('registerDemo.step2RequestSent'));
  } catch (e) {
    toast.error('Gagal kirim permintaan: ' + (e as Error).message);
  } finally {
    requestInflight.value = null;
  }
}

const showCreateNewCta = computed(
  () => query.value.trim().length >= 2 && !isSearching.value,
);

async function lookupNpsn() {
  const npsn = npsnInput.value.trim();
  if (!/^\d{6,12}$/.test(npsn)) {
    npsnError.value = t('registerDemo.step2NpsnInvalid');
    npsnHit.value = null;
    return;
  }
  npsnError.value = null;
  isLookingUpNpsn.value = true;
  try {
    const hit = await DemoService.lookupNpsn(npsn);
    if (!hit) {
      npsnError.value = t('registerDemo.step2NpsnNotFound');
      npsnHit.value = null;
      return;
    }
    npsnHit.value = hit;
  } finally {
    isLookingUpNpsn.value = false;
  }
}

function acceptNpsnHit() {
  if (!npsnHit.value) return;
  // If a Kamiledu tenant already exists for this NPSN, route the
  // user to "minta akun" instead of overwriting their wizard payload.
  if (npsnHit.value.kamiledu_school) {
    toast.info(t('registerDemo.step2AlreadyExists'));
    return;
  }
  // Same normalisation as pickRegistryHit — Dapodik returns SD/SMP/...
  const normalizedLevel = normalizeEducationLevel(npsnHit.value.education_level);
  wizard.patchPayload('school', {
    name: npsnHit.value.name,
    npsn: npsnHit.value.npsn,
    city: npsnHit.value.city,
    education_level: (normalizedLevel as EducationLevel) ?? selectedJenjang.value,
  });
  query.value = npsnHit.value.name;
  toast.success(t('registerDemo.step2DapodikSuccess'));
  npsnHit.value = null;
}

/**
 * Avatar style + secondary status pill derived from school name.
 * "NEGERI" / "SDN" / "SMPN" / "SMAN" → green gradient + "Negeri" pill.
 * "MI" / "MTs" / "MA" / "PESANTREN" → amber gradient + "Islami" pill.
 * Anything else → blue gradient + "Swasta" pill.
 */
type AvatarTier = 'negeri' | 'islami' | 'swasta';
function classifyHit(hit: SchoolSearchHit): { tier: AvatarTier; statusLabel: string; statusCls: string } {
  const u = hit.name.toUpperCase();
  if (/\b(NEGERI|SDN|SMPN|SMAN|SMKN|MIN|MTSN|MAN)\b/.test(u)) {
    return { tier: 'negeri', statusLabel: 'Negeri', statusCls: 'bg-emerald-100 text-emerald-700' };
  }
  if (/\b(MI|MTS|MA|PESANTREN|ISLAM|ISLAMI)\b/.test(u)) {
    return { tier: 'islami', statusLabel: 'Islami', statusCls: 'bg-amber-100 text-amber-800' };
  }
  return { tier: 'swasta', statusLabel: 'Swasta', statusCls: 'bg-blue-100 text-blue-700' };
}

function avatarCls(tier: AvatarTier): string {
  switch (tier) {
    case 'negeri':
      return 'bg-gradient-to-br from-emerald-500 to-emerald-700';
    case 'islami':
      return 'bg-gradient-to-br from-amber-500 to-amber-700';
    default:
      return 'bg-gradient-to-br from-sky-500 to-sky-700';
  }
}

function avatarInitials(name: string): string {
  return name
    .split(/\s+/)
    .filter((w) => /[A-Za-z]/.test(w))
    .slice(0, 2)
    .map((w) => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);
}

async function requestAccessForKamilEduMatch() {
  if (!npsnHit.value?.kamiledu_school) return;
  const k = npsnHit.value.kamiledu_school;
  requestInflight.value = k.id;
  try {
    await DemoService.requestSchoolAccess({
      school_id: k.id,
      school_type: k.is_demo ? 'demo_school' : 'real_school',
      requested_role: 'admin',
      message: `Mohon akses untuk ${k.name} (NPSN ${npsnHit.value.npsn}).`,
    });
    toast.success(t('registerDemo.step2RequestSentNpsn'));
  } catch (e) {
    toast.error('Gagal kirim permintaan: ' + (e as Error).message);
  } finally {
    requestInflight.value = null;
  }
}
</script>

<template>
  <div>
    <p class="text-2xs font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.stepCounter', { current: wizard.stepNumber, total: wizard.stepTotal }) }} · {{ t('registerDemo.step2Label') }}
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      {{ t('registerDemo.step2Title') }}
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">
      {{ t('registerDemo.step2Subtitle') }}
    </p>

    <!-- Accuracy note — keep data real so the demo request flows smoothly. -->
    <div
      class="mb-4 flex items-start gap-2 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2.5"
    >
      <NavIcon name="alert-circle" :size="15" class="mt-0.5 flex-shrink-0 text-amber-600" />
      <p class="text-[12px] leading-snug text-amber-900">
        {{ t('registerDemo.accuracyNote') }}
      </p>
    </div>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.step2JenjangLabel') }}
    </p>
    <div class="flex flex-wrap gap-1.5 mb-1">
      <button
        v-for="j in JENJANG_PRIMARY"
        :key="j"
        type="button"
        class="px-3 py-1.5 rounded-full text-[12px] font-bold transition border"
        :class="
          selectedJenjang === j
            ? 'bg-role-admin text-white border-role-admin'
            : 'bg-white text-slate-700 border-slate-300 hover:border-slate-400'
        "
        @click="setJenjang(j)"
      >
        {{ educationLevelDisplay(j) }}
      </button>
      <button
        type="button"
        class="px-3 py-1.5 rounded-full text-[12px] font-bold transition border inline-flex items-center gap-1"
        :class="
          showOthers || JENJANG_OTHERS.includes(selectedJenjang)
            ? 'bg-role-admin/10 text-role-admin border-role-admin/30'
            : 'bg-white text-role-admin border-role-admin/40 hover:bg-role-admin/5'
        "
        @click="showOthers = !showOthers"
      >
        {{ JENJANG_OTHERS.includes(selectedJenjang) ? educationLevelDisplay(selectedJenjang) : t('registerDemo.step2JenjangOthers') }}
        <NavIcon :name="showOthers ? 'chevron-up' : 'chevron-down'" :size="11" />
      </button>
    </div>
    <div v-if="showOthers" class="flex flex-wrap gap-1.5 mt-2 mb-1 pl-1">
      <button
        v-for="j in JENJANG_OTHERS"
        :key="j"
        type="button"
        class="px-2.5 py-1 rounded-full text-[11.5px] font-bold transition border"
        :class="
          selectedJenjang === j
            ? 'bg-role-admin text-white border-role-admin'
            : 'bg-white text-slate-600 border-slate-300 hover:border-slate-400'
        "
        @click="setJenjang(j)"
      >
        {{ educationLevelDisplay(j) }}
      </button>
    </div>

    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mt-5 mb-2">
      {{ t('registerDemo.step2NameLabel') }}
    </p>
    <div class="flex items-center gap-2 border border-role-admin rounded-lg px-3 py-2.5 bg-white">
      <NavIcon name="search" :size="16" class="text-role-admin flex-shrink-0" />
      <input
        v-model="query"
        type="text"
        :placeholder="t('registerDemo.step2NamePlaceholder', { selectedJenjang: educationLevelDisplay(selectedJenjang) })"
        class="flex-1 text-[14px] text-slate-900 placeholder-slate-400 outline-none bg-transparent"
        autocomplete="off"
      />
      <Spinner v-if="isSearching" size="sm" />
      <span v-else-if="results.length > 0" class="text-3xs text-slate-400">
        {{ results.length }} {{ t('registerDemo.step2SearchResults') }}
      </span>
    </div>

    <div v-if="results.length > 0" class="mt-4 grid gap-2.5 md:grid-cols-2">
      <article
        v-for="hit in results"
        :key="`${hit.kind}-${hit.id ?? hit.npsn ?? hit.name}`"
        class="border border-slate-200 rounded-xl bg-white overflow-hidden transition-shadow hover:shadow-md hover:border-slate-300"
      >
        <!-- Top: info-only. Avatar gradient by school tier (Negeri /
             Islami / Swasta), bigger name, single-line meta with
             icons, pills row showing both registry status and tier. -->
        <div class="p-3 flex items-start gap-3">
          <div
            class="w-10 h-10 rounded-[10px] flex items-center justify-center text-[13px] font-extrabold text-white flex-shrink-0 shadow-sm"
            :class="avatarCls(classifyHit(hit).tier)"
          >
            {{ avatarInitials(hit.name) }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[13.5px] font-extrabold text-slate-900 leading-tight truncate">
              {{ hit.name }}
            </p>
            <div class="text-2xs text-slate-500 mt-1 flex items-center gap-1.5 flex-wrap">
              <template v-if="hit.city">
                <NavIcon name="database" :size="10" class="text-slate-400" />
                <span>{{ hit.city }}</span>
              </template>
              <span v-if="hit.city && hit.npsn" class="text-slate-300">·</span>
              <template v-if="hit.npsn">
                <span class="font-mono text-[10.5px]">NPSN {{ hit.npsn }}</span>
              </template>
            </div>
            <div class="mt-1.5 flex items-center gap-1 flex-wrap">
              <span
                v-if="hit.kind === 'tenant'"
                class="inline-block px-2 py-0.5 rounded-full text-[9.5px] font-bold bg-emerald-100 text-emerald-700"
              >{{ t('registerDemo.step2BadgeTenant') }}</span>
              <span
                v-else-if="hit.kind === 'demo'"
                class="inline-block px-2 py-0.5 rounded-full text-[9.5px] font-bold bg-amber-100 text-amber-700"
              >{{ t('registerDemo.step2BadgeDemo') }}</span>
              <span
                v-else
                class="inline-block px-2 py-0.5 rounded-full text-[9.5px] font-bold bg-blue-100 text-blue-700"
              >{{ t('registerDemo.step2BadgeRegistry') }}</span>
              <span
                v-if="hit.kind === 'registry'"
                class="inline-block px-2 py-0.5 rounded-full text-[9.5px] font-bold"
                :class="classifyHit(hit).statusCls"
              >{{ classifyHit(hit).statusLabel }}</span>
            </div>
          </div>
        </div>

        <!-- Bottom: full-width action band, 1-tap. Color shifts
             between green (Pakai data) and amber (Minta akses/akun)
             so user instantly knows the next step from color alone. -->
        <button
          v-if="hit.kind === 'tenant'"
          type="button"
          class="w-full flex items-center justify-between px-3 py-2.5 bg-gradient-to-b from-amber-50 to-amber-100 hover:from-amber-100 hover:to-amber-200 border-t border-amber-200/60 text-amber-900 transition-colors disabled:opacity-50"
          :disabled="requestInflight === hit.id"
          @click="requestAccess(hit)"
        >
          <span class="inline-flex items-center gap-2 text-[12px] font-bold">
            <Spinner v-if="requestInflight === hit.id" size="sm" />
            <NavIcon v-else name="mail" :size="13" />
            {{ t('registerDemo.step2ActionRequestAccount') }}
          </span>
          <NavIcon name="arrow-right" :size="13" />
        </button>

        <button
          v-else-if="hit.kind === 'demo'"
          type="button"
          class="w-full flex items-center justify-between px-3 py-2.5 bg-gradient-to-b from-amber-50 to-amber-100 hover:from-amber-100 hover:to-amber-200 border-t border-amber-200/60 text-amber-900 transition-colors disabled:opacity-50"
          :disabled="requestInflight === hit.id"
          @click="requestAccess(hit)"
        >
          <span class="inline-flex items-center gap-2 text-[12px] font-bold">
            <Spinner v-if="requestInflight === hit.id" size="sm" />
            <NavIcon v-else name="user-plus" :size="13" />
            {{ t('registerDemo.step2ActionRequestAccess') }}
          </span>
          <NavIcon name="arrow-right" :size="13" />
        </button>

        <button
          v-else
          type="button"
          class="w-full flex items-center justify-between px-3 py-2.5 bg-gradient-to-b from-emerald-50 to-emerald-100 hover:from-emerald-100 hover:to-emerald-200 border-t border-emerald-200/60 text-emerald-900 transition-colors"
          @click="pickRegistryHit(hit)"
        >
          <span class="inline-flex items-center gap-2 text-[12px] font-bold">
            <NavIcon name="check" :size="13" />
            {{ t('registerDemo.step2ActionUseClaim') }}
          </span>
          <NavIcon name="arrow-right" :size="13" />
        </button>
      </article>
    </div>

    <div
      v-if="showCreateNewCta"
      class="mt-3 border border-dashed border-role-admin/40 rounded-lg p-3 bg-role-admin/5 text-center cursor-pointer hover:bg-role-admin/10 transition"
      @click="pickCreateNew"
    >
      <p class="text-[12.5px] font-bold text-role-admin">
        <NavIcon name="plus" :size="13" class="inline-block -mt-0.5 mr-1" />
        {{ t('registerDemo.step2CreateNew', { query: query.trim() }) }}
      </p>
    </div>

    <p
      v-if="!isSearching && query.trim().length >= 2 && results.length === 0"
      class="text-[12px] text-slate-500 mt-3"
    >
      {{ t('registerDemo.step2NoResults') }}
    </p>

    <!-- NPSN lookup — live Dapodik fetch via the backend proxy. Lebih
         akurat daripada fuzzy name search karena langsung match by ID. -->
    <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mt-5 mb-2">
      {{ t('registerDemo.step2NpsnLabel') }}
    </p>
    <div class="flex items-center gap-2">
      <input
        v-model="npsnInput"
        type="text"
        inputmode="numeric"
        maxlength="12"
        :placeholder="t('registerDemo.step2NpsnPlaceholder')"
        class="flex-1 border border-slate-300 rounded-lg px-3 py-2.5 text-[13.5px] font-mono outline-none focus:border-role-admin"
        @keydown.enter.prevent="lookupNpsn"
      />
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-lg bg-role-admin text-white text-[12.5px] font-bold hover:bg-role-admin/90 disabled:opacity-60"
        :disabled="isLookingUpNpsn || npsnInput.trim().length < 6"
        @click="lookupNpsn"
      >
        <Spinner v-if="isLookingUpNpsn" size="sm" class="!text-white" />
        <NavIcon v-else name="search" :size="13" />
        {{ t('common.search') }}
      </button>
    </div>
    <p v-if="npsnError" class="text-[11.5px] text-red-700 mt-1.5">{{ npsnError }}</p>

    <div
      v-if="npsnHit"
      class="mt-2 border-2 border-emerald-300 rounded-lg p-3 bg-emerald-50"
    >
      <div class="flex items-start gap-2">
        <NavIcon name="check-circle" :size="18" class="text-emerald-600 flex-shrink-0 mt-0.5" />
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-bold text-slate-900 leading-tight">{{ npsnHit.name }}</p>
          <p class="text-[10.5px] text-slate-600 mt-0.5">
            {{ [educationLevelDisplay(npsnHit.education_level), npsnHit.city, npsnHit.province].filter(Boolean).join(' · ') }}
            <span v-if="npsnHit.akreditasi" class="ml-1 px-1.5 py-0.5 bg-emerald-200 text-emerald-800 rounded text-4xs font-bold">
              Akreditasi {{ npsnHit.akreditasi }}
            </span>
          </p>
          <p class="text-3xs text-slate-500 mt-1">NPSN: {{ npsnHit.npsn }}</p>

          <template v-if="npsnHit.kamiledu_school">
            <div class="mt-2 p-2 bg-white rounded border border-amber-300">
              <p class="text-2xs text-amber-800 font-bold">
                <NavIcon name="alert-circle" :size="11" class="inline-block -mt-0.5 mr-1" />
                {{ t('registerDemo.step2NpsnExists') }}
                <span v-if="npsnHit.kamiledu_school.is_demo">(sebagai demo)</span>.
              </p>
              <button
                type="button"
                class="mt-1.5 text-2xs text-role-admin font-bold hover:underline disabled:opacity-50"
                :disabled="requestInflight === npsnHit.kamiledu_school.id"
                @click="requestAccessForKamilEduMatch"
              >
                <NavIcon name="mail" :size="11" class="inline-block -mt-0.5 mr-1" />
                Minta akun ke admin sekolah
              </button>
            </div>
          </template>
          <template v-else>
            <button
              type="button"
              class="mt-2 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-[12px] font-bold hover:bg-emerald-700"
              @click="acceptNpsnHit"
            >
              <NavIcon name="check" :size="12" />
              Pakai data ini · isi otomatis
            </button>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

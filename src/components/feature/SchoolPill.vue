<!--
  SchoolPill.vue — topbar pill showing the active school name.

  Click semantics:
    - When the user has more than one school the chevron + dropdown
      lets them switch in place. Single-school users get a static
      pill (no chevron, no click).
    - The dropdown always shows whatever schools are loaded; even
      the currently-active one is visible with an "Aktif" badge so
      the user can confirm where they are.

  Resilience:
    - `auth.user.school_name` is the canonical source for the visible
      label. Login response + `auth.hydrateSchoolsRoles()` both
      populate it.
    - Every list entry runs through `displayName()` so an entry whose
      `name` and `school_name` are both null still renders something
      legible instead of an invisible row.
-->
<script setup lang="ts">
import { computed, ref, onBeforeUnmount } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useRouter } from 'vue-router';
import type { School } from '@/types/auth';

const auth = useAuthStore();
const router = useRouter();
const open = ref(false);
const switching = ref(false);

function schoolKey(s: School): string {
  return String(s.id ?? s.school_id ?? '');
}

function displayName(s: School): string {
  const raw = s.name ?? s.school_name;
  const trimmed = typeof raw === 'string' ? raw.trim() : '';
  return trimmed.length > 0 ? trimmed : 'Sekolah';
}

const allSchools = computed<School[]>(() => auth.user?.schools ?? []);
const hasMultiple = computed(() => allSchools.value.length > 1);

const activeSchool = computed<School | null>(() => {
  const sid = auth.schoolId ?? auth.user?.school_id;
  if (!sid) return null;
  return allSchools.value.find((s) => schoolKey(s) === sid) ?? null;
});

const activeSchoolName = computed<string>(() => {
  if (activeSchool.value) return displayName(activeSchool.value);
  if (auth.user?.school_name) return auth.user.school_name;
  return auth.schoolId ? 'Sekolah Aktif' : 'Sekolah';
});

function close(e: MouseEvent) {
  const target = e.target as HTMLElement;
  if (!target.closest('[data-school-pill]')) open.value = false;
}

function toggle() {
  if (!hasMultiple.value) return;
  open.value = !open.value;
  if (open.value) {
    // Refresh in background in case the cached list went stale.
    auth.hydrateSchoolsRoles();
    setTimeout(() => document.addEventListener('click', close), 0);
  } else {
    document.removeEventListener('click', close);
  }
}

function roleHome(): string {
  switch (auth.activeRole) {
    case 'admin':
      return '/admin';
    case 'teacher':
    case 'wali_kelas':
      return '/teacher';
    case 'parent':
      return '/parent';
    case 'staff':
      return '/staff';
    default:
      return '/';
  }
}

async function pick(s: School) {
  const sid = schoolKey(s);
  if (!sid || sid === auth.schoolId) {
    open.value = false;
    return;
  }
  open.value = false;
  document.removeEventListener('click', close);
  switching.value = true;
  try {
    await auth.selectSchool(sid);
    if (auth.step === 'done') {
      router.replace(roleHome());
    }
  } catch {
    // ProfileMenu / global handler shows the toast — silent here.
  } finally {
    switching.value = false;
  }
}

onBeforeUnmount(() => document.removeEventListener('click', close));
</script>

<template>
  <div data-school-pill class="relative">
    <button
      type="button"
      class="inline-flex items-center gap-2 rounded-full bg-white/15 hover:bg-white/25 px-3 py-1.5 text-sm font-medium text-white max-w-[16rem]"
      :class="{ 'cursor-default hover:bg-white/15': !hasMultiple }"
      :aria-expanded="open"
      @click="toggle"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-4 h-4 flex-shrink-0"
      >
        <path d="M3 21h18M5 21V7l8-4v18M19 21V11l-6-4" />
      </svg>
      <span class="truncate font-semibold">{{ activeSchoolName }}</span>
      <svg
        v-if="hasMultiple"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-3.5 h-3.5 flex-shrink-0 opacity-80"
        :class="{ 'rotate-180': open }"
      >
        <polyline points="6 9 12 15 18 9" />
      </svg>
    </button>

    <Transition
      enter-active-class="transition duration-100 ease-out"
      enter-from-class="opacity-0 scale-95"
      enter-to-class="opacity-100 scale-100"
      leave-active-class="transition duration-75 ease-in"
      leave-from-class="opacity-100 scale-100"
      leave-to-class="opacity-0 scale-95"
    >
      <div
        v-if="open"
        class="absolute left-0 mt-2 w-80 form-card p-2 z-50 origin-top-left"
      >
        <p class="px-md py-sm text-3xs font-bold uppercase tracking-widest text-slate-400">
          Pilih sekolah · {{ allSchools.length }}
        </p>

        <ul v-if="allSchools.length > 0" class="space-y-0.5 max-h-[320px] overflow-y-auto">
          <li v-for="s in allSchools" :key="schoolKey(s) || displayName(s)">
            <button
              type="button"
              class="w-full text-left px-3 py-2.5 rounded-xl hover:bg-slate-50 flex items-center gap-3 disabled:opacity-50 transition-colors border border-transparent"
              :class="{
                'bg-brand-cobalt/5 border-brand-cobalt/20':
                  schoolKey(s) === auth.schoolId,
              }"
              :disabled="switching"
              @click="pick(s)"
            >
              <span
                class="w-9 h-9 rounded-lg bg-brand-cobalt/10 text-brand-cobalt grid place-items-center font-black text-sm flex-shrink-0"
              >
                {{ displayName(s).slice(0, 1).toUpperCase() }}
              </span>
              <div class="flex-1 min-w-0">
                <p class="text-[13px] font-bold text-slate-900 truncate">
                  {{ displayName(s) }}
                </p>
                <p v-if="s.city || s.address" class="text-2xs text-slate-500 truncate">
                  {{ s.city ?? s.address }}
                </p>
              </div>
              <span
                v-if="schoolKey(s) === auth.schoolId"
                class="text-4xs font-bold text-brand-cobalt bg-brand-cobalt/10 px-2 py-0.5 rounded-full uppercase tracking-wider flex-shrink-0"
              >
                Aktif
              </span>
              <svg
                v-else
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-3.5 h-3.5 text-slate-300 flex-shrink-0"
              >
                <polyline points="9 18 15 12 9 6" />
              </svg>
            </button>
          </li>
        </ul>

        <div v-else class="px-3 py-6 text-center text-[12px] text-slate-400">
          Tidak ada sekolah lain yang tertaut dengan akun Anda.
        </div>
      </div>
    </Transition>
  </div>
</template>

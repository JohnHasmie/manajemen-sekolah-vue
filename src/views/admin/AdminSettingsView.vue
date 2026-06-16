<!--
  AdminSettingsView.vue - school settings hub.
  Sections: school profile, levels, time periods, system, data backup.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import DemoResetForm from '@/components/demo/DemoResetForm.vue';
import DemoResetProgress from '@/components/demo/DemoResetProgress.vue';
import { DemoService } from '@/services/demo.service';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();
const { t } = useI18n();

const showResetModal = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const auth = useAuthStore();
const isResetting = ref(false);
const resetError = ref<string | null>(null);

/**
 * Original wizard payload from the user's DemoWizardState — the BASE
 * that <DemoResetForm> merges user overrides on top of when the
 * operator picks "Ubah konfigurasi". Hydrated lazily on first modal
 * open. Null while loading; if the fetch fails (or the user has no
 * wizard state cached), the form's "Ubah konfigurasi" tab stays
 * locked and only "Konfigurasi sama" is available — the safe
 * fallback, since the backend then reuses the demo_request's payload.
 */
const basePayload = ref<Record<string, unknown> | null>(null);

/**
 * Merged payload coming back from <DemoResetForm>. `null` means
 * "use the original wizard answers" — we call reset() with no body
 * and the backend reuses the payload captured on the demo_request.
 */
const resetOverride = ref<Record<string, unknown> | null>(null);

watch(showResetModal, async (open) => {
  if (!open) return;
  resetError.value = null;
  resetOverride.value = null;
  if (basePayload.value) return; // cached from a previous open
  try {
    const state = await DemoService.loadWizardState();
    if (state?.payload) {
      basePayload.value = state.payload as unknown as Record<string, unknown>;
    }
  } catch {
    // Non-fatal — tweak tab will stay locked, "Konfigurasi sama" still
    // works (server reuses the original payload).
  }
});

/**
 * Confirm "Reset Data Demo" — wipe the demo school back to a freshly-
 * provisioned state, then log out so the user re-enters with the new
 * school id. The backend re-provisions a brand-new school row, so the
 * current session's cached `current_school_id` no longer exists after
 * the call; forcing a clean re-login is the simplest reliable way to
 * land the user on the new demo with consistent auth state (vs trying
 * to swap active-school in place, which would race other tabs and
 * stale TanStack caches).
 */
async function confirmResetDemo() {
  if (isResetting.value) return;
  isResetting.value = true;
  resetError.value = null;
  // Hand off the screen to <DemoResetProgress>: close the confirmation
  // modal immediately so the takeover isn't visually layered on top of
  // it. The progress component mounts via v-if="isResetting" below.
  showResetModal.value = false;
  try {
    // The mini-wizard works with a generic Record (it merges fields
    // by name only); reset() typed its parameter as DemoWizardPayload
    // for the wizard's own call site. Cast at the boundary — the
    // backend validates the shape so a wrong-shape merged payload
    // surfaces as a 422 with a readable message, not a silent break.
    await DemoService.reset(
      (resetOverride.value ?? undefined) as never,
    );
    // Success: tear down session locally + server-side, route to
    // /login. The progress takeover stays mounted through the
    // navigation (it animates to 100% as the route changes), so the
    // user never sees a flash of the old dashboard chrome.
    await auth.logout();
    await router.push('/login');
  } catch (e) {
    // Failure: unmount the takeover, surface the error in the modal
    // again so the user can read it + retry.
    resetError.value = (e as Error).message;
    isResetting.value = false;
    showResetModal.value = true;
  }
}

interface SettingsGroup {
  title: string;
  items: { icon: string; label: string; desc: string; to?: string; action?: () => void; danger?: boolean }[];
}

const groups = computed<SettingsGroup[]>(() => [
  {
    title: t('admin.sekolah.settings.group_school_profile'),
    items: [
      { icon: 'home', label: t('admin.sekolah.settings.item_school_profile_label'), desc: t('admin.sekolah.settings.item_school_profile_desc'), to: '/admin/settings/school' },
      { icon: 'calendar', label: t('admin.sekolah.settings.item_academic_year_label'), desc: t('admin.sekolah.settings.item_academic_year_desc'), to: '/admin/settings/kelola-tahun-ajaran' },
    ],
  },
  {
    title: t('admin.sekolah.settings.group_operational'),
    items: [
      { icon: 'calendar', label: t('admin.sekolah.settings.item_lesson_hours_label'), desc: t('admin.sekolah.settings.item_lesson_hours_desc'), to: '/admin/schedule/lesson-hours' },
      { icon: 'wallet', label: t('admin.sekolah.settings.item_billing_label'), desc: t('admin.sekolah.settings.item_billing_desc'), to: '/admin/finance/jenis' },
    ],
  },
  {
    title: t('admin.sekolah.settings.group_data'),
    items: [
      { icon: 'layers', label: t('admin.sekolah.settings.item_data_management_label'), desc: t('admin.sekolah.settings.item_data_management_desc'), to: '/admin/settings/data' },
      { icon: 'file-text', label: t('admin.sekolah.settings.item_backup_label'), desc: t('admin.sekolah.settings.item_backup_desc') },
      { icon: 'edit', label: t('admin.sekolah.settings.item_reset_demo_label'), desc: t('admin.sekolah.settings.item_reset_demo_desc'), danger: true },
    ],
  },
  {
    title: t('admin.sekolah.settings.group_system'),
    items: [
      { icon: 'bell', label: t('admin.sekolah.settings.item_notifications_label'), desc: t('admin.sekolah.settings.item_notifications_desc') },
      { icon: 'sparkles', label: t('admin.sekolah.settings.item_ai_label'), desc: t('admin.sekolah.settings.item_ai_desc') },
    ],
  },
]);

function open(it: SettingsGroup['items'][number]) {
  if (it.to) router.push(it.to);
  else if (it.action) it.action();
  else if (it.danger) showResetModal.value = true;
  else toast.value = { message: t('admin.sekolah.settings.toast_under_construction'), tone: 'error' };
}
</script>

<template>
  <div class="space-y-md">
    <header>
      <h1 class="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
        {{ t('admin.sekolah.settings.page_title') }}
      </h1>
      <p class="text-xs text-slate-400 font-bold uppercase tracking-widest mt-1">
        {{ t('admin.sekolah.settings.page_subtitle') }}
      </p>
    </header>

    <div v-for="g in groups" :key="g.title" class="space-y-2">
      <h3 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest px-1">{{ g.title }}</h3>
      <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <button
          v-for="(it, idx) in g.items"
          :key="it.label"
          type="button"
          class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-slate-50 transition-colors"
          :class="[idx > 0 ? 'border-t border-slate-100' : '']"
          @click="open(it)"
        >
          <div
            class="w-9 h-9 rounded-lg grid place-items-center flex-shrink-0"
            :class="it.danger ? 'bg-red-100 text-red-700' : 'bg-role-admin/10 text-role-admin'"
          >
            <NavIcon :name="it.icon" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold" :class="it.danger ? 'text-red-700' : 'text-slate-900'">{{ it.label }}</p>
            <p class="text-[11px] text-slate-500 truncate">{{ it.desc }}</p>
          </div>
          <span class="text-slate-300">→</span>
        </button>
      </section>
    </div>

    <Modal
      v-if="showResetModal"
      size="xl"
      :title="t('admin.sekolah.settings.reset_modal_title')"
      :subtitle="t('admin.sekolah.settings.reset_modal_subtitle')"
      @close="!isResetting && (showResetModal = false)"
    >
      <div class="space-y-md">
        <div class="bg-red-50 border border-red-200 rounded-xl p-3 text-[12px] text-red-700 leading-relaxed">
          <strong>{{ t('admin.sekolah.settings.reset_modal_warning_label') }}</strong> {{ t('admin.sekolah.settings.reset_modal_warning_body') }}
        </div>

        <!-- Mini-wizard: pakai konfigurasi yang sama atau ubah sedikit. -->
        <DemoResetForm
          :base-payload="basePayload"
          @change="resetOverride = $event"
        />

        <div
          v-if="resetError"
          class="bg-red-100 border border-red-300 rounded-xl p-3 text-[12px] text-red-800 leading-relaxed"
        >
          {{ resetError }}
        </div>
        <div class="bg-amber-50 border border-amber-200 rounded-xl p-3 text-[11px] text-amber-800 leading-relaxed">
          Setelah reset selesai Anda akan diminta login kembali, lalu masuk lagi ke demo baru.
        </div>
        <div class="grid grid-cols-2 gap-2">
          <Button
            variant="secondary"
            block
            :disabled="isResetting"
            @click="showResetModal = false"
          >
            {{ t('admin.sekolah.settings.cancel') }}
          </Button>
          <Button
            variant="danger"
            block
            :disabled="isResetting"
            :loading="isResetting"
            @click="confirmResetDemo"
          >
            {{ t('admin.sekolah.settings.confirm_reset') }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- Full-viewport blocking screen mounted while the reset HTTP
         request is in flight. Teleported to <body> so it covers the
         AppShell chrome (sidebar, bottom nav on mobile) too. -->
    <DemoResetProgress :active="isResetting" />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>

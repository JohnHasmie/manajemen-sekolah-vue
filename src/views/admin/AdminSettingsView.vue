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
import { useMeStore } from '@/stores/me';
import { useSubscription } from '@/composables/useSubscription';

const router = useRouter();
const { t } = useI18n();
const me = useMeStore();

// Demo-tenant flag drives the "Reset data demo" tile (below). Shared
// module-level state — reuses the same fetch the topbar chip already
// makes, so gating the tile costs no extra round-trip.
const { isDemo, ensureLoaded: ensureSubscriptionLoaded } = useSubscription();
ensureSubscriptionLoaded();

const showResetModal = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const auth = useAuthStore();
const isResetting = ref(false);
const isResetSuccess = ref(false);
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
  isResetSuccess.value = false;
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
    // Success: trigger fast-forward animation in DemoResetProgress.
    // The actual routing happens in onResetCompleted once the UI finishes.
    isResetSuccess.value = true;
  } catch (e) {
    // Failure: unmount the takeover, surface the error in the modal
    // again so the user can read it + retry.
    resetError.value = (e as Error).message;
    isResetting.value = false;
    showResetModal.value = true;
  }
}

async function onResetCompleted() {
  await auth.logout();
  await router.push('/login');
}

interface SettingsGroup {
  title: string;
  items: {
    icon: string; label: string; desc: string; to?: string;
    action?: () => void; danger?: boolean;
    /**
     * RBAC/module gate — the tile hides when the active user doesn't
     * hold the ability. Mirrors the sidebar's `ability` field so a
     * tile absorbed FROM the sidebar (Wave 1 hub consolidation) keeps
     * the same visibility rule it had there.
     */
    ability?: string;
    /**
     * Demo-only gate — the tile renders ONLY while the active tenant is
     * still a demo school. Keeps "Reset data demo" out of a real,
     * paying tenant's settings hub (a real tenant has no demo data to
     * reset, and the action would re-provision their school).
     */
    demoOnly?: boolean;
  }[];
}

const groups = computed<SettingsGroup[]>(() => {
  const raw: SettingsGroup[] = [
    {
      title: t('admin.sekolah.settings.group_school_profile'),
      items: [
        { icon: 'home', label: t('admin.sekolah.settings.item_school_profile_label'), desc: t('admin.sekolah.settings.item_school_profile_desc'), to: '/admin/settings/school' },
        { icon: 'calendar', label: t('admin.sekolah.settings.item_academic_year_label'), desc: t('admin.sekolah.settings.item_academic_year_desc'), to: '/admin/settings/manage-academic-years' },
      ],
    },
    {
      title: t('admin.sekolah.settings.group_operational'),
      items: [
        { icon: 'calendar', label: t('admin.sekolah.settings.item_lesson_hours_label'), desc: t('admin.sekolah.settings.item_lesson_hours_desc'), to: '/admin/schedule/lesson-hours' },
        // Pengaturan Kehadiran — Wave 2 merged the two former tiles
        // (Presensi Guru settings + Metode & QR) into ONE unified
        // 3-tab screen; both wrote to the same
        // PUT /teacher-attendance/settings endpoint all along — the
        // split was historical, not semantic.
        {
          icon: 'camera',
          label: t('admin.sekolah.settings.item_attendance_config_label'),
          desc: t('admin.sekolah.settings.item_attendance_config_desc'),
          to: '/admin/settings/attendance',
          ability: 'attendance.staff.settings.manage',
        },
        { icon: 'wallet', label: t('admin.sekolah.settings.item_billing_label'), desc: t('admin.sekolah.settings.item_billing_desc'), to: '/admin/finance/types', ability: 'finance.bill_type.manage' },
      ],
    },
    {
      // Akses & Langganan — absorbed from the sidebar's former
      // PENGATURAN section (Wave 1). Roles keeps its RBAC gate;
      // Langganan & Modul is ungated (every admin has standing to
      // manage their tenant's plan).
      title: t('admin.sekolah.settings.group_access'),
      items: [
        {
          icon: 'shield',
          label: t('admin.sekolah.settings.item_roles_label'),
          desc: t('admin.sekolah.settings.item_roles_desc'),
          to: '/admin/roles',
          ability: 'rbac.role.view',
        },
        {
          icon: 'package',
          label: t('admin.sekolah.settings.item_modules_label'),
          desc: t('admin.sekolah.settings.item_modules_desc'),
          // Embedded route — keeps the admin shell chrome instead of
          // teleporting to the standalone /subscribe surface.
          to: '/admin/settings/modules',
        },
      ],
    },
    {
      // Keamanan — per-school security toggles (account-activation
      // Opsi B + login OTP 2FA). Gated on the same settings-view key
      // that admits the hub; the detail view enforces manage for writes.
      title: t('admin.sekolah.settings.group_security'),
      items: [
        {
          icon: 'shield',
          label: t('admin.sekolah.settings.item_security_label'),
          desc: t('admin.sekolah.settings.item_security_desc'),
          to: '/admin/settings/security',
          ability: 'school.settings.view',
        },
      ],
    },
    {
      title: t('admin.sekolah.settings.group_data'),
      items: [
        { icon: 'layers', label: t('admin.sekolah.settings.item_data_management_label'), desc: t('admin.sekolah.settings.item_data_management_desc'), to: '/admin/settings/data' },
        { icon: 'file-text', label: t('admin.sekolah.settings.item_backup_label'), desc: t('admin.sekolah.settings.item_backup_desc') },
        { icon: 'edit', label: t('admin.sekolah.settings.item_reset_demo_label'), desc: t('admin.sekolah.settings.item_reset_demo_desc'), danger: true, demoOnly: true },
      ],
    },
    {
      title: t('admin.sekolah.settings.group_system'),
      items: [
        { icon: 'bell', label: t('admin.sekolah.settings.item_notifications_label'), desc: t('admin.sekolah.settings.item_notifications_desc') },
        { icon: 'sparkles', label: t('admin.sekolah.settings.item_ai_label'), desc: t('admin.sekolah.settings.item_ai_desc') },
      ],
    },
  ];
  // Same filter contract as the sidebar's applyGates: drop tiles the
  // user can't act on, then drop groups that emptied out so the hub
  // never renders a bare section heading. Demo-only tiles additionally
  // require the tenant to still be a demo school.
  return raw
    .map((g) => ({
      ...g,
      items: g.items.filter(
        (it) =>
          (!it.ability || me.can(it.ability)) &&
          (!it.demoOnly || isDemo.value),
      ),
    }))
    .filter((g) => g.items.length > 0);
});

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
      <h3 class="text-3xs font-bold text-slate-400 uppercase tracking-widest px-1">{{ g.title }}</h3>
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
            <p class="text-2xs text-slate-500 truncate">{{ it.desc }}</p>
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
        <div class="bg-amber-50 border border-amber-200 rounded-xl p-3 text-2xs text-amber-800 leading-relaxed">
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
    <DemoResetProgress
      :active="isResetting"
      :success="isResetSuccess"
      @completed="onResetCompleted"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>

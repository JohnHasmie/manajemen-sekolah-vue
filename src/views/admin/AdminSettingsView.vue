<!--
  AdminSettingsView.vue - school settings hub.
  Sections: school profile, levels, time periods, system, data backup.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';

const router = useRouter();
const { t } = useI18n();

const showResetModal = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

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

    <Modal v-if="showResetModal" :title="t('admin.sekolah.settings.reset_modal_title')" :subtitle="t('admin.sekolah.settings.reset_modal_subtitle')" @close="showResetModal = false">
      <div class="space-y-md">
        <div class="bg-red-50 border border-red-200 rounded-xl p-3 text-[12px] text-red-700 leading-relaxed">
          <strong>{{ t('admin.sekolah.settings.reset_modal_warning_label') }}</strong> {{ t('admin.sekolah.settings.reset_modal_warning_body') }}
        </div>
        <div class="grid grid-cols-2 gap-2">
          <Button variant="secondary" block @click="showResetModal = false">{{ t('admin.sekolah.settings.cancel') }}</Button>
          <Button variant="danger" block @click="showResetModal = false">{{ t('admin.sekolah.settings.confirm_reset') }}</Button>
        </div>
      </div>
    </Modal>

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>

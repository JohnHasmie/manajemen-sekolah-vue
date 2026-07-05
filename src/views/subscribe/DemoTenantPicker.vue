<!--
  DemoTenantPicker.vue — modal for choosing which demo tenant to
  convert on the /subscribe page.

  Only mounts when the signed-in user owns 2+ tenants. Each row shows
  the tenant name, a tenant_type badge (Sekolah / Lembaga), current
  student + staff counts, and its subscription status pill.

  Clicking a row selects it; confirming closes the modal and emits the
  tenant to the parent, which pre-fills the calculator + hides the
  new-signup form fields.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import type { SubscriptionTenant } from '@/types/subscription-billing';

const props = defineProps<{
  open: boolean;
  tenants: SubscriptionTenant[];
  /** Currently selected tenant id (or null for the new-signup path). */
  selectedTenantId: string | null;
}>();

const emit = defineEmits<{
  close: [];
  confirm: [tenant: SubscriptionTenant];
  clear: [];
}>();

const { t } = useI18n();

// Local pick so canceling doesn't mutate the parent's state. Seeded
// from the current selection on open.
const localPick = ref<string | null>(props.selectedTenantId);
watch(
  () => [props.open, props.selectedTenantId] as const,
  ([open, id]) => {
    if (open) localPick.value = id;
  },
);

const chosen = computed<SubscriptionTenant | null>(() =>
  props.tenants.find((t) => t.id === localPick.value) ?? null,
);

function statusPill(status: SubscriptionTenant['subscription_status']) {
  const key = String(status).toLowerCase();
  if (key === 'active' || key === 'trialing') {
    return { label: t('subscribe.picker.statusActive'), cls: 'bg-emerald-100 text-emerald-700' };
  }
  if (key === 'expired' || key === 'unpaid') {
    return { label: t('subscribe.picker.statusExpired'), cls: 'bg-rose-100 text-rose-700' };
  }
  return { label: t('subscribe.picker.statusDemo'), cls: 'bg-amber-100 text-amber-700' };
}

function typeBadge(type: SubscriptionTenant['tenant_type']) {
  if (type === 'bimbel') {
    return { label: t('subscribe.picker.typeBimbel'), cls: 'bg-indigo-100 text-indigo-700' };
  }
  return { label: t('subscribe.picker.typeSekolah'), cls: 'bg-blue-100 text-blue-700' };
}

function pick(id: string) {
  localPick.value = id;
}

function confirm() {
  if (!chosen.value) return;
  emit('confirm', chosen.value);
}

function clearPick() {
  localPick.value = null;
  emit('clear');
}
</script>

<template>
  <Modal
    v-if="open"
    :title="t('subscribe.picker.title')"
    :subtitle="t('subscribe.picker.subtitle')"
    size="lg"
    @close="emit('close')"
  >
    <ul class="space-y-2 max-h-[60vh] overflow-y-auto pr-1">
      <li v-for="tenant in tenants" :key="tenant.id">
        <button
          type="button"
          class="w-full text-left rounded-xl border p-3.5 sm:p-4 transition-colors"
          :class="localPick === tenant.id
            ? 'border-brand-cobalt bg-brand-50/60 ring-2 ring-brand-cobalt/20'
            : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50'"
          @click="pick(tenant.id)"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-1.5 mb-1">
                <h3 class="text-sm font-bold text-slate-900 truncate">
                  {{ tenant.name }}
                </h3>
                <span
                  class="text-3xs font-semibold px-1.5 py-0.5 rounded"
                  :class="typeBadge(tenant.tenant_type).cls"
                >
                  {{ typeBadge(tenant.tenant_type).label }}
                </span>
                <span
                  v-if="tenant.is_demo"
                  class="text-3xs font-semibold px-1.5 py-0.5 rounded bg-slate-100 text-slate-600"
                >
                  Demo
                </span>
              </div>
              <div class="mt-1.5 flex flex-wrap items-center gap-3 text-xs text-slate-500">
                <span>
                  <span class="font-semibold text-slate-700">{{ tenant.student_count }}</span>
                  {{ t('subscribe.picker.students') }}
                </span>
                <span>
                  <span class="font-semibold text-slate-700">{{ tenant.staff_count }}</span>
                  {{ tenant.tenant_type === 'bimbel'
                      ? t('subscribe.picker.tutors')
                      : t('subscribe.picker.staff') }}
                </span>
              </div>
            </div>
            <span
              class="flex-shrink-0 text-3xs font-semibold px-1.5 py-0.5 rounded"
              :class="statusPill(tenant.subscription_status).cls"
            >
              {{ statusPill(tenant.subscription_status).label }}
            </span>
          </div>
        </button>
      </li>
    </ul>

    <footer class="mt-5 flex flex-col sm:flex-row-reverse gap-2">
      <Button variant="primary" :disabled="!chosen" block @click="confirm">
        {{ t('subscribe.picker.confirm') }}
      </Button>
      <Button variant="secondary" block @click="emit('close')">
        {{ t('subscribe.picker.cancel') }}
      </Button>
      <Button
        v-if="selectedTenantId"
        variant="ghost"
        block
        @click="clearPick"
      >
        {{ t('subscribe.picker.clear') }}
      </Button>
    </footer>
  </Modal>
</template>

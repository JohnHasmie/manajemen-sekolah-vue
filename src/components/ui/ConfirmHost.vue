<!--
  ConfirmHost.vue — single global mount point for useConfirm().

  Renders the styled ConfirmationDialog driven by the shared confirm
  state. Mount ONCE near the app root (App.vue). Feature code should
  never render this directly — it calls useConfirm() instead.
-->
<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import ConfirmationDialog from './ConfirmationDialog.vue';
import { useConfirmHost } from '@/composables/useConfirm';

const { state, onConfirm, onCancel } = useConfirmHost();
const { t } = useI18n();
</script>

<template>
  <ConfirmationDialog
    v-if="state.open"
    :title="state.title || t('common.confirm')"
    :message="state.message"
    :confirm-label="state.confirmLabel"
    :cancel-label="state.cancelLabel"
    :danger="state.danger"
    @confirm="onConfirm"
    @close="onCancel"
  />
</template>

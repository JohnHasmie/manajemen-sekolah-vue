/**
 * TutoringReminderSettingsService — greenfield reminder-offset client
 * (BE-9).
 *
 *   GET /tutoring-v2/settings/bill-reminders
 *   PUT /tutoring-v2/settings/bill-reminders
 *   GET /tutoring-v2/settings/session-reminders
 *   PUT /tutoring-v2/settings/session-reminders
 *
 * All four authorize on `tutoring.session_reminder.manage` — BE-9
 * deliberately reuses that one key for both kinds instead of growing
 * the PermissionCatalog for a settings screen the admin already owns.
 *
 * See `@/types/tutoring2/reminder-settings` for the unit/enabled
 * contract differences vs. the legacy endpoints.
 *
 * Every method returns the UNWRAPPED payload.
 */
import { api } from '@/lib/http';
import type {
  ReminderSettings,
  UpdateReminderSettingsPayload,
} from '@/types/tutoring2/reminder-settings';

interface OneEnvelope<T> {
  data: T;
}

export const TutoringReminderSettingsService = {
  async getBillReminders(): Promise<ReminderSettings> {
    const r = await api.get<OneEnvelope<ReminderSettings>>(
      '/tutoring-v2/settings/bill-reminders',
    );
    return r.data.data;
  },

  async updateBillReminders(
    payload: UpdateReminderSettingsPayload,
  ): Promise<ReminderSettings> {
    const r = await api.put<OneEnvelope<ReminderSettings>>(
      '/tutoring-v2/settings/bill-reminders',
      payload,
    );
    return r.data.data;
  },

  async getSessionReminders(): Promise<ReminderSettings> {
    const r = await api.get<OneEnvelope<ReminderSettings>>(
      '/tutoring-v2/settings/session-reminders',
    );
    return r.data.data;
  },

  async updateSessionReminders(
    payload: UpdateReminderSettingsPayload,
  ): Promise<ReminderSettings> {
    const r = await api.put<OneEnvelope<ReminderSettings>>(
      '/tutoring-v2/settings/session-reminders',
      payload,
    );
    return r.data.data;
  },
};

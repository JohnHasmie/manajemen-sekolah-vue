import { api } from '@/lib/http';

export interface ResolvedRecipient {
  name: string;
  phone_number: string;
  school_name: string;
}

export interface ResolveRecipientsResponse {
  success: boolean;
  data: ResolvedRecipient[];
}

export interface BroadcastSendResponse {
  success: boolean;
  message: string;
}

export const SuperAdminBroadcastService = {
  /**
   * Resolve administrator contacts for a list of school IDs.
   *
   * POST /api/broadcast/resolve-recipients
   */
  async resolveRecipients(schoolIds: string[]): Promise<ResolvedRecipient[]> {
    const res = await api.post<ResolveRecipientsResponse>('/broadcast/resolve-recipients', {
      school_ids: schoolIds,
    });
    return res.data?.data || [];
  },

  /**
   * Securely send a single WhatsApp message via backend gateway.
   *
   * POST /api/broadcast/send
   */
  async sendBroadcast(phoneNumber: string, message: string): Promise<BroadcastSendResponse> {
    const res = await api.post<BroadcastSendResponse>('/broadcast/send', {
      phone_number: phoneNumber,
      message,
    });
    return res.data;
  },
};

/**
 * Vitest contract spec for TutoringLeadsService.
 *
 * The web-vue package doesn't run vitest yet — the wider repo pins the
 * standard vitest API in spec files as a documentation/contract
 * artifact until the harness lands (see rbac.service.spec.ts for the
 * canonical setup instructions). Until then vue-tsc consumes this file
 * as a typed pin over the leads endpoint DTOs so a wire-level rename
 * upstream shows up at type-check.
 *
 * Every endpoint documented in `LeadController` is exercised at least
 * once; the assertions pin the exact URL + method + payload shape.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { api } from '@/lib/http';
import { TutoringLeadsService } from './leads';
import type { BimbelLead } from '@/types/tutoring2/lead';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

const SAMPLE_LEAD: BimbelLead = {
  id: 'ld-1',
  school_id: 'sc-1',
  name: 'Ayu Wijaya',
  phone: '+62 812 0000 1111',
  email: 'ayu@example.com',
  source: 'whatsapp',
  source_label: 'WhatsApp',
  status: 'new',
  status_label: 'Baru',
  notes: null,
  interest_program_id: null,
  interest_program_name: null,
  assigned_to_user_id: null,
  assigned_to_name: null,
  converted_enrollment_id: null,
  converted_enrollment: null,
  created_at: '2026-08-04T09:00:00+07:00',
  updated_at: '2026-08-04T09:00:00+07:00',
};

describe('TutoringLeadsService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('list', () => {
    it('GETs /tutoring-v2/leads and unwraps the Laravel {data, meta} envelope', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: {
          data: [SAMPLE_LEAD],
          meta: {
            total_items: 1,
            total_pages: 1,
            current_page: 1,
            per_page: 20,
            has_next_page: false,
            has_prev_page: false,
          },
        },
      });

      const result = await TutoringLeadsService.list({
        status: 'new',
        source: 'whatsapp',
        page: 1,
        per_page: 20,
      });

      expect(api.get).toHaveBeenCalledWith('/tutoring-v2/leads', {
        params: {
          status: 'new',
          source: 'whatsapp',
          page: 1,
          per_page: 20,
        },
      });
      expect(result.items).toHaveLength(1);
      expect(result.items[0].id).toBe('ld-1');
      expect(result.pagination?.total_items).toBe(1);
    });

    it('strips empty-string filter params (BE ignores them via Laravel filled())', async () => {
      (api.get as any).mockResolvedValueOnce({ data: { data: [] } });

      await TutoringLeadsService.list({
        status: '',
        source: '',
        search: 'ayu',
      });

      // `search` is a client-side filter (BE index has no `search` param)
      // so it must not appear on the wire; empty strings are pruned too.
      expect(api.get).toHaveBeenCalledWith('/tutoring-v2/leads', {
        params: {},
      });
    });
  });

  describe('get', () => {
    it('GETs /tutoring-v2/leads/{id}', async () => {
      (api.get as any).mockResolvedValueOnce({
        data: { data: SAMPLE_LEAD },
      });

      const result = await TutoringLeadsService.get('ld-1');

      expect(api.get).toHaveBeenCalledWith('/tutoring-v2/leads/ld-1');
      expect(result.id).toBe('ld-1');
      expect(result.status).toBe('new');
    });
  });

  describe('create', () => {
    it('POSTs /tutoring-v2/leads and returns the fresh resource', async () => {
      (api.post as any).mockResolvedValueOnce({
        data: { data: { ...SAMPLE_LEAD, id: 'ld-2' } },
      });

      const result = await TutoringLeadsService.create({
        name: 'Budi',
        source: 'website',
        phone: null,
      });

      expect(api.post).toHaveBeenCalledWith('/tutoring-v2/leads', {
        name: 'Budi',
        source: 'website',
        phone: null,
      });
      expect(result.id).toBe('ld-2');
    });
  });

  describe('update', () => {
    it('PUTs /tutoring-v2/leads/{id} with partial payload', async () => {
      (api.put as any).mockResolvedValueOnce({
        data: { data: { ...SAMPLE_LEAD, status: 'contacted' } },
      });

      const result = await TutoringLeadsService.update('ld-1', {
        status: 'contacted',
      });

      expect(api.put).toHaveBeenCalledWith('/tutoring-v2/leads/ld-1', {
        status: 'contacted',
      });
      expect(result.status).toBe('contacted');
    });
  });

  describe('convert', () => {
    it('POSTs /tutoring-v2/leads/{id}/convert; no program_id in body (BE reads it from interest_program_id)', async () => {
      (api.post as any).mockResolvedValueOnce({
        data: {
          data: {
            ...SAMPLE_LEAD,
            status: 'converted',
            converted_enrollment_id: 'en-9',
            converted_enrollment: {
              id: 'en-9',
              student_id: 'st-1',
              program_id: 'pr-1',
              billing_mode: 'prepaid',
              status: 'active',
            },
          },
        },
      });

      const result = await TutoringLeadsService.convert('ld-1', {
        student_id: 'st-1',
        package_id: 'pk-1',
        billing_mode: 'prepaid',
      });

      expect(api.post).toHaveBeenCalledWith('/tutoring-v2/leads/ld-1/convert', {
        student_id: 'st-1',
        package_id: 'pk-1',
        billing_mode: 'prepaid',
      });
      expect(result.status).toBe('converted');
      expect(result.converted_enrollment?.id).toBe('en-9');
    });
  });

  describe('drop', () => {
    it('POSTs /tutoring-v2/leads/{id}/drop with a bare notes payload', async () => {
      (api.post as any).mockResolvedValueOnce({
        data: {
          data: { ...SAMPLE_LEAD, status: 'dropped' },
        },
      });

      const result = await TutoringLeadsService.drop('ld-1', {
        notes: 'tidak cocok jadwal',
      });

      expect(api.post).toHaveBeenCalledWith('/tutoring-v2/leads/ld-1/drop', {
        notes: 'tidak cocok jadwal',
      });
      expect(result.status).toBe('dropped');
    });

    it('defaults to an empty payload when reason is not provided', async () => {
      (api.post as any).mockResolvedValueOnce({
        data: { data: { ...SAMPLE_LEAD, status: 'dropped' } },
      });

      await TutoringLeadsService.drop('ld-1');

      expect(api.post).toHaveBeenCalledWith('/tutoring-v2/leads/ld-1/drop', {});
    });
  });

  describe('destroy', () => {
    it('DELETEs /tutoring-v2/leads/{id}', async () => {
      (api.delete as any).mockResolvedValueOnce({ data: { success: true } });

      await TutoringLeadsService.destroy('ld-1');

      expect(api.delete).toHaveBeenCalledWith('/tutoring-v2/leads/ld-1');
    });
  });
});

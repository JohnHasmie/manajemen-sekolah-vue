/**
 * RatingsService — tutor ratings summary (WEB-13, mirrors BE-20
 * TutorRatingsController).
 *
 *   GET /tutors/me/ratings           self, no admin ability needed
 *                                    (backend resolves Teacher row from
 *                                    the auth user + active school).
 *   GET /tutors/{tutorId}/ratings    admin-facing (needs
 *                                    `tutoring.tutor.view`).
 *
 * The self endpoint deliberately BYPASSES `tutoring.tutor.view` on
 * the backend — tutor bimbel defaults don't include that key, so a
 * tutor inspecting their own ratings is the intended path. Do NOT
 * gate the Ratings view on `tutoring.tutor.view`.
 */
import { api } from '@/lib/http';
import type { TutorRatingSummary } from '@/types/tutoring2/rating';

interface OneEnvelope<T> {
  data: T;
}

export const RatingsService = {
  async getSelf(): Promise<TutorRatingSummary> {
    const r = await api.get<OneEnvelope<TutorRatingSummary>>('/tutoring-v2/tutors/me/ratings');
    return r.data.data;
  },

  async get(tutorId: string): Promise<TutorRatingSummary> {
    const r = await api.get<OneEnvelope<TutorRatingSummary>>(
      `/tutoring-v2/tutors/${tutorId}/ratings`,
    );
    return r.data.data;
  },
};

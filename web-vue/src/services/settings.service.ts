/**
 * SettingsService — `/school/settings`, `/semesters`, password CRUD.
 *
 * Mirrors Flutter's `ApiSettingsService` (school + profile branch).
 * Lesson-hour endpoints are handled by `LessonHourService` to avoid
 * duplication.
 */
import { api } from '@/lib/http';

export interface SchoolSettings {
  /** Canonical column: `schools.education_level` (was `jenjang`). */
  education_level: string; // SD | SMP | SMA | SMK
  /** Canonical column: `schools.name` (was `school_name`). */
  name: string;
  address: string;
}

export interface Semester {
  id: string;
  name: string | null;
  current: boolean;
  academic_year_id: string | null;
}

function humanError(e: unknown, fallback: string): string {
  const ax = e as any;
  if (ax?.response?.data) {
    const d = ax.response.data;
    if (typeof d === 'string') return d;
    if (d?.message) return String(d.message);
    if (d?.error) return String(d.error);
    if (d?.errors && typeof d.errors === 'object') {
      const first = Object.values(d.errors)[0];
      if (Array.isArray(first) && first.length > 0) return String(first[0]);
    }
  }
  if (e instanceof Error) return e.message;
  return fallback;
}

function schoolFromJson(raw: any): SchoolSettings {
  return {
    education_level: String(raw?.education_level ?? raw?.jenjang ?? ''),
    name: String(raw?.name ?? raw?.school_name ?? ''),
    address: String(raw?.address ?? ''),
  };
}

function semesterFromJson(raw: any): Semester {
  return {
    id: String(raw?.id ?? ''),
    name: raw?.name ?? raw?.semester ?? null,
    current: raw?.current === true || raw?.current === 1,
    academic_year_id: raw?.academic_year_id
      ? String(raw.academic_year_id)
      : null,
  };
}

export const SettingsService = {
  /** GET /school/settings. */
  async getSchool(): Promise<SchoolSettings> {
    try {
      const res = await api.get('/school/settings');
      return schoolFromJson(res.data ?? {});
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat pengaturan sekolah.'));
    }
  },

  /**
   * POST /school/settings — partial update (only sends keys that
   * differ from current values). The backend writes whatever it
   * receives.
   */
  async updateSchool(
    patch: Partial<SchoolSettings>,
  ): Promise<SchoolSettings> {
    try {
      const body: Record<string, unknown> = {};
      if (patch.education_level !== undefined) body.education_level = patch.education_level;
      if (patch.name !== undefined) body.name = patch.name;
      if (patch.address !== undefined) body.address = patch.address;
      const res = await api.post('/school/settings', body);
      return schoolFromJson(res.data ?? body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui pengaturan sekolah.'));
    }
  },

  /** GET /semesters — returns the list, current flag included. */
  async listSemesters(): Promise<Semester[]> {
    try {
      const res = await api.get('/semesters');
      const body = res.data;
      const list = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      return list.map(semesterFromJson);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat semester.'));
    }
  },

  /** Convenience — currently-flagged semester (null if none). */
  async getActiveSemester(): Promise<Semester | null> {
    const list = await this.listSemesters();
    return list.find((s) => s.current) ?? null;
  },

  /** PUT /profile/password. */
  async updatePassword(args: {
    old_password: string;
    new_password: string;
    confirm_password: string;
  }): Promise<void> {
    try {
      await api.put('/profile/password', args);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengubah password.'));
    }
  },
};

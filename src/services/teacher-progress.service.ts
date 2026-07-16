/**
 * TeacherProgressService — /teacher/prestasi/* endpoint wrapper.
 *
 * Mirrors the four endpoints backend MR 5 ships:
 *   GET   /teacher/prestasi/sorotan     one Sorotan Prestasi state
 *   GET   /teacher/prestasi/saya        personal panel (level ring,
 *                                       streak, chart, sumber_terbuka,
 *                                       opt-out state)
 *   GET   /teacher/prestasi/peringkat   cohort-scoped leaderboard
 *   PATCH /teacher/prestasi/setting     toggle hide-from-leaderboard
 *
 * All are gated by module:teacher_gamification + can:gamification.view
 * server-side, so a call from a school without the sub will 402 and
 * from a role without the ability will 403 — the FE catches and
 * hides the whole surface.
 */
import { api } from '@/lib/http';

export type SorotanState =
  | 'badge_baru'
  | 'naik_level'
  | 'streak_milestone'
  | 'top_rank'
  | 'delta_positif'
  | 'sapaan_awal';

export interface SorotanPayload {
  state: SorotanState;
  eyebrow?: string;
  title: string;
  sub?: string;
  mini_badge?: string | null;
  cta_label: string;
  cta_target: string;
  meta: {
    level: number;
    streak: number;
    badge_count: number;
  };
}

export type Cohort = 'guru_baru' | 'guru_mapel' | 'wali_kelas' | 'staf';

export interface SumberTerbukaEntry {
  unlocked: boolean;
  reason: string | null;
}

export interface PersonalPayload {
  total_xp: number;
  level: number;
  level_title: string;
  xp_in_level: number;
  xp_for_next_level: number;
  streak_current: number;
  streak_longest: number;
  last_active_date: string | null;
  xp_today: number;
  xp_this_week: number;
  sumber_terbuka: Record<string, SumberTerbukaEntry>;
  weekly_chart: { date: string; xp: number }[];
  sembunyi_dari_peringkat: boolean;
}

export interface LeaderboardEntry {
  posisi: number;
  teacher_id: string | null;
  user_id: string | null;
  nama: string;
  foto_url: string | null;
  poin: number;
  hari_beruntun: number;
  level: number;
  jumlah_badge: number;
  kamu: boolean;
}

export interface LeaderboardResponse {
  data: LeaderboardEntry[];
  meta: {
    periode: 'minggu' | 'bulan';
    kelompok: Cohort;
    you: LeaderboardEntry | null;
  };
}

export interface SettingUpdatePayload {
  sembunyi_dari_peringkat: boolean;
}

// ─── Admin ─────────────────────────────────────────────────

export interface AdminSorotanPayload {
  guru_bulan_ini: {
    state: 'guru_bulan_ini';
    eyebrow?: string;
    title: string;
    sub?: string;
    cta_label: string;
    cta_target: string;
    meta: null | { teacher_id: string; nama: string; poin: number };
  };
  perlu_sapaan: {
    state: 'perlu_sapaan';
    count: number;
    eyebrow?: string;
    title: string | null;
    sub?: string;
    cta_label?: string;
    cta_target?: string;
    meta: null | { teacher_ids: string[] };
  };
}

export interface AdminTopEntry {
  teacher_id: string;
  nama: string;
  foto_url: string | null;
  poin: number;
}

export interface AdminRingkasanPayload {
  total_guru: number;
  aktif_minggu_ini: number;
  rata_streak: number;
  perlu_perhatian: number;
  top_tiga: AdminTopEntry[];
}

export type TeacherRowStatus = 'aktif' | 'melambat' | 'sepi' | 'never';

export interface AdminTeacherEngagementRow {
  teacher_id: string;
  nama: string;
  foto_url: string | null;
  level: number;
  hari_beruntun: number;
  poin_7_hari: number;
  terakhir_aktif: string | null;
  status: TeacherRowStatus;
  /** 7-day XP sparkline; always length 7, oldest → newest. */
  sparkline: number[];
}

export interface AdminIndexPayload {
  data: AdminTeacherEngagementRow[];
  meta: {
    sorotan: AdminSorotanPayload;
    kpi: AdminRingkasanPayload;
  };
}

export interface KirimPengingatResponse {
  terkirim: number;
  total_target: number;
}

export const TeacherProgressService = {
  async getSorotan(): Promise<SorotanPayload> {
    const res = await api.get('/teacher/prestasi/sorotan');
    return (res.data?.data ?? res.data) as SorotanPayload;
  },

  async getPersonal(): Promise<PersonalPayload> {
    const res = await api.get('/teacher/prestasi/saya');
    return (res.data?.data ?? res.data) as PersonalPayload;
  },

  async getLeaderboard(params: {
    periode?: 'minggu' | 'bulan';
    kelompok?: Cohort;
  } = {}): Promise<LeaderboardResponse> {
    const res = await api.get('/teacher/prestasi/peringkat', { params });
    // Response envelope on backend controllers is { data: [...], meta: {...} }
    // — pass through as-is because callers want both.
    return res.data as LeaderboardResponse;
  },

  async updateSetting(payload: SettingUpdatePayload): Promise<SettingUpdatePayload> {
    const res = await api.patch('/teacher/prestasi/setting', payload);
    return (res.data?.data ?? res.data) as SettingUpdatePayload;
  },

  // ─── Admin ─────────────────────────────────────────────

  async getAdminSorotan(): Promise<AdminSorotanPayload> {
    const res = await api.get('/admin/prestasi-guru/sorotan');
    return (res.data?.data ?? res.data) as AdminSorotanPayload;
  },

  async getAdminRingkasan(): Promise<AdminRingkasanPayload> {
    const res = await api.get('/admin/prestasi-guru/ringkasan');
    return (res.data?.data ?? res.data) as AdminRingkasanPayload;
  },

  async getAdminIndex(): Promise<AdminIndexPayload> {
    const res = await api.get('/admin/prestasi-guru');
    return res.data as AdminIndexPayload;
  },

  async kirimPengingat(teacherIds: string[]): Promise<KirimPengingatResponse> {
    const res = await api.post('/admin/prestasi-guru/kirim-pengingat', {
      teacher_ids: teacherIds,
    });
    return (res.data?.data ?? res.data) as KirimPengingatResponse;
  },
};

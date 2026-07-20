/**
 * TeacherProgressService — /teacher/gamification/* endpoint wrapper.
 *
 * Mirrors the four endpoints backend MR 5 ships (renamed to English in
 * the Scope-B rename, backend MR !474):
 *   GET   /teacher/gamification/highlight    one Highlight state
 *   GET   /teacher/gamification/me           personal panel (level ring,
 *                                            streak, chart, unlocked_sources,
 *                                            opt-out state)
 *   GET   /teacher/gamification/leaderboard  cohort-scoped leaderboard
 *   PATCH /teacher/gamification/setting      toggle hide-from-leaderboard
 *
 * All are gated by module:teacher_gamification + can:gamification.view
 * server-side, so a call from a school without the sub will 402 and
 * from a role without the ability will 403 — the FE catches and
 * hides the whole surface.
 */
import { api } from '@/lib/http';

export type HighlightState =
  | 'new_badge'
  | 'level_up'
  | 'streak_milestone'
  | 'top_rank'
  | 'positive_delta'
  | 'welcome';

export interface HighlightPayload {
  state: HighlightState;
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
  /**
   * Teacher-fusion follow-on (backend MR !487): number of "Aksi hari ini"
   * quest tiles a teacher currently has waiting on the Prestasi Saya
   * Ringkasan tab. Powers the dashboard prestasi teaser subtitle
   * ("N aksi hari ini"). Older backends omit the key — treat as 0.
   */
  action_count?: number;
}

export type Cohort = 'general' | 'subject' | 'homeroom' | 'staff';

export interface UnlockedSourceEntry {
  unlocked: boolean;
  reason: string | null;
}

export interface EarnedBadge {
  code: string;
  awarded_at: string | null;
  is_new: boolean;
  meta: Record<string, unknown> | null;
}

/**
 * Teacher-fusion follow-on (backend MR !487): a single "Aksi hari ini"
 * quest tile on the Prestasi Saya Ringkasan tab. Structurally identical
 * to `PriorityInboxItem` — every item in the teacher priority inbox
 * that maps to an XP-earning activity source (attendance session, RPP
 * submit, grade input) is echoed here with its `xp_reward` filled in;
 * items that don't map to an activity source (recommendation reply,
 * report-card draft deadline) come through with `xp_reward: null` and
 * render as neutral, no XP pill.
 *
 * `nature` mirrors the two-lane taxonomy the admin readiness surface
 * uses: `operational` items are flow / "handle today" (matches most of
 * the teacher inbox) and `completeness` are structural / "fix-once"
 * (currently unused on the teacher side but declared for symmetry with
 * the admin contract).
 */
export interface TeacherAction {
  id: string;
  type: string;
  nature: 'operational' | 'completeness';
  severity: 'critical' | 'warning' | 'info';
  label: string;
  subtitle: string;
  count: number;
  occurred_at: string;
  target_route: string;
  target_params: Record<string, unknown>;
  activity_source: string | null;
  xp_reward: number | null;
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
  unlocked_sources: Record<string, UnlockedSourceEntry>;
  weekly_chart: { date: string; xp: number }[];
  hide_from_leaderboard: boolean;
  /** Backend MR 4b — absent = older backend, FE falls back to locked-only. */
  earned_badges?: EarnedBadge[];
  /**
   * Teacher-fusion follow-on (backend MR !487): quest tiles for the
   * "Aksi hari ini" lane on the Ringkasan tab. Absent on older
   * backends → FE falls back to the milestone hint card alone.
   */
  actions?: TeacherAction[];
}

export interface LeaderboardEntry {
  position: number;
  teacher_id: string | null;
  user_id: string | null;
  name: string;
  photo_url: string | null;
  points: number;
  streak_days: number;
  level: number;
  badge_count: number;
  you: boolean;
}

export interface LeaderboardResponse {
  data: LeaderboardEntry[];
  meta: {
    period: 'week' | 'month';
    cohort: Cohort;
    you: LeaderboardEntry | null;
  };
}

export interface SettingUpdatePayload {
  hide_from_leaderboard: boolean;
}

// ─── Admin ─────────────────────────────────────────────────

export interface AdminHighlightPayload {
  teacher_of_month: {
    state: 'teacher_of_month';
    eyebrow?: string;
    title: string;
    sub?: string;
    cta_label: string;
    cta_target: string;
    meta: null | { teacher_id: string; name: string; points: number };
  };
  needs_attention: {
    state: 'needs_attention';
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
  name: string;
  photo_url: string | null;
  points: number;
}

export interface AdminSummaryPayload {
  total_teachers: number;
  active_this_week: number;
  average_streak: number;
  needs_attention_count: number;
  top_three: AdminTopEntry[];
}

export type TeacherRowStatus = 'active' | 'slowing' | 'silent' | 'never';

export interface AdminTeacherEngagementRow {
  teacher_id: string;
  name: string;
  photo_url: string | null;
  level: number;
  streak_days: number;
  points_7d: number;
  last_active_at: string | null;
  status: TeacherRowStatus;
  /** 7-day XP sparkline; always length 7, oldest → newest. */
  sparkline: number[];
}

/** One day of school-wide XP for the admin weekly-activity bar chart. */
export interface WeeklyActivityPoint {
  /** ISO date (YYYY-MM-DD). */
  date: string;
  /** Total XP the whole school earned that day. */
  points: number;
}

export interface AdminIndexPayload {
  data: AdminTeacherEngagementRow[];
  meta: {
    highlight: AdminHighlightPayload;
    kpi: AdminSummaryPayload;
    /**
     * School-wide daily XP for the last 7 days (oldest → newest, 7
     * entries, zero days included) — backend MR (Part A). Feeds the
     * WeeklyActivityBars chart on the admin engagement page.
     */
    weekly_activity: WeeklyActivityPoint[];
  };
}

export interface SendRemindersResponse {
  sent: number;
  total_target: number;
}

// ─── Admin · Staff variant ─────────────────────────────────
// Mirror of the teacher admin shape but keyed on `user_id`
// instead of `teacher_id`. Staff rows in teacher_activity_points
// carry personnel_type='staff' + user_id; teacher_id is NULL.
// Backend: MR6 `/admin/staff-engagement/*`.

export interface AdminStaffHighlightPayload {
  staff_of_month: {
    state: 'staff_of_month';
    eyebrow?: string;
    title: string;
    sub?: string;
    cta_label: string;
    cta_target: string;
    meta: null | { user_id: string; name: string; points: number; current_month: boolean };
  };
  needs_attention: {
    state: 'staff_needs_attention';
    count: number;
    eyebrow?: string;
    title: string | null;
    sub?: string;
    cta_label?: string;
    cta_target?: string;
    meta: null | { user_ids: string[]; sample_names?: string[] };
  };
}

export interface AdminStaffTopEntry {
  user_id: string;
  name: string;
  photo_url: string | null;
  points: number;
}

export interface AdminStaffSummaryPayload {
  total_staff: number;
  active_this_week: number;
  average_streak: number;
  needs_attention_count: number;
  top_three: AdminStaffTopEntry[];
}

/**
 * Derived server-side from intersect(user_abilities, staff_quest_map.keys).
 * Values are Indonesian display strings (Bendahara / Tata Usaha / Kehadiran)
 * that render directly in the peran filter chips + row subtitle.
 */
export type StaffAbilityRoleTag = 'Bendahara' | 'Tata Usaha' | 'Kehadiran' | string;

export interface AdminStaffEngagementRow {
  user_id: string;
  name: string;
  photo_url: string | null;
  level: number;
  streak_days: number;
  points_7d: number;
  last_active_at: string | null;
  status: TeacherRowStatus;
  sparkline: number[];
  ability_role_tag: StaffAbilityRoleTag;
}

export interface AdminStaffIndexPayload {
  data: AdminStaffEngagementRow[];
  meta: {
    highlight: AdminStaffHighlightPayload;
    kpi: AdminStaffSummaryPayload;
    weekly_activity: WeeklyActivityPoint[];
  };
}

export const TeacherProgressService = {
  async getHighlight(): Promise<HighlightPayload> {
    const res = await api.get('/teacher/gamification/highlight');
    return (res.data?.data ?? res.data) as HighlightPayload;
  },

  async getMe(): Promise<PersonalPayload> {
    const res = await api.get('/teacher/gamification/me');
    return (res.data?.data ?? res.data) as PersonalPayload;
  },

  async getLeaderboard(params: {
    period?: 'week' | 'month';
    cohort?: Cohort;
  } = {}): Promise<LeaderboardResponse> {
    const res = await api.get('/teacher/gamification/leaderboard', { params });
    // Response envelope on backend controllers is { data: [...], meta: {...} }
    // — pass through as-is because callers want both.
    return res.data as LeaderboardResponse;
  },

  async updateSetting(payload: SettingUpdatePayload): Promise<SettingUpdatePayload> {
    const res = await api.patch('/teacher/gamification/setting', payload);
    return (res.data?.data ?? res.data) as SettingUpdatePayload;
  },

  // ─── Admin ─────────────────────────────────────────────

  async getAdminHighlight(): Promise<AdminHighlightPayload> {
    const res = await api.get('/admin/teacher-engagement/highlight');
    return (res.data?.data ?? res.data) as AdminHighlightPayload;
  },

  async getAdminSummary(): Promise<AdminSummaryPayload> {
    const res = await api.get('/admin/teacher-engagement/summary');
    return (res.data?.data ?? res.data) as AdminSummaryPayload;
  },

  async getAdminIndex(): Promise<AdminIndexPayload> {
    const res = await api.get('/admin/teacher-engagement');
    return res.data as AdminIndexPayload;
  },

  async sendReminders(teacherIds: string[]): Promise<SendRemindersResponse> {
    const res = await api.post('/admin/teacher-engagement/send-reminders', {
      teacher_ids: teacherIds,
    });
    return (res.data?.data ?? res.data) as SendRemindersResponse;
  },

  // ─── Admin · Staff variant ─────────────────────────────

  async getAdminStaffHighlight(): Promise<AdminStaffHighlightPayload> {
    const res = await api.get('/admin/staff-engagement/highlight');
    return (res.data?.data ?? res.data) as AdminStaffHighlightPayload;
  },

  async getAdminStaffSummary(): Promise<AdminStaffSummaryPayload> {
    const res = await api.get('/admin/staff-engagement/summary');
    return (res.data?.data ?? res.data) as AdminStaffSummaryPayload;
  },

  async getAdminStaffIndex(): Promise<AdminStaffIndexPayload> {
    const res = await api.get('/admin/staff-engagement');
    return res.data as AdminStaffIndexPayload;
  },

  async sendStaffReminders(userIds: string[]): Promise<SendRemindersResponse> {
    const res = await api.post('/admin/staff-engagement/send-reminders', {
      user_ids: userIds,
    });
    return (res.data?.data ?? res.data) as SendRemindersResponse;
  },
};

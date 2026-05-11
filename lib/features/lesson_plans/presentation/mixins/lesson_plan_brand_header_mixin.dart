// Brand-migrated header for the teacher RPP list screen.
//
// Replaces the legacy `LessonPlanHeader` with `BrandPageHeader` +
// 4-cell KPI overlay (Pekan ini · Bulan ini · Pending · AI),
// `RoleToggleChipRow` for wali/mengajar (when applicable), and a
// `BrandFilterChipStrip` showing Format · Status · Kelas affordances.
//
// Frame A from `_design/teacher_rpp_mockup.html`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';

mixin LessonPlanBrandHeaderMixin on ConsumerState<LessonPlanScreen> {
  // ── Abstract bridges to the screen state ──

  /// Active formats — read from LessonPlanFilterMixin's selectedFormats.
  Set<LessonPlanFormat> get selectedFormats;

  /// Active status — read from LessonPlanFilterMixin's selectedStatusFilter.
  String? get selectedStatusFilter;

  /// Method axis (`ai` / `manual` / null).
  String? get selectedMethod;

  /// Total active filter count (used for the badge on the tune icon).
  int get totalActiveFilterCount {
    var n = 0;
    if (selectedStatusFilter != null) n++;
    if (selectedFormats.isNotEmpty) n++;
    if (selectedMethod != null) n++;
    return n;
  }

  /// The list the screen renders. Used to compute the AI count cell.
  List<dynamic> get lessonPlanList;

  /// The summary blob the screen loaded from `/rpp/summary`. May be
  /// null until first load completes.
  List<Map<String, dynamic>>? get summaryData;

  /// Server-computed KPI aggregates from `/rpp/summary` —
  /// `{weekly, monthly, open, ai, approved, rejected, total}`. Null
  /// while the summary call is in flight or on cold cache; the KPI
  /// card falls back to a tally over `lessonPlanList` in that case.
  Map<String, int>? get kpiData;

  /// Open the filter sheet (provided by LessonPlanFilterMixin).
  void showFilterSheet();

  // ── Brand header ──

  Widget buildBrandHeader(LanguageProvider lp) {
    return BrandPageHeader(
      role: 'guru',
      title: lp.getTranslatedText({
        'en': 'Lesson Plans',
        'id': 'Rencana Pembelajaran',
      }),
      subtitle: lp.getTranslatedText({
        'en': 'Academic · RPP',
        'id': 'Akademik · RPP',
      }),
      isRealtimeFresh: true,
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: showFilterSheet,
          badgeCount: totalActiveFilterCount > 0
              ? totalActiveFilterCount
              : null,
          badgeBorderColor: ColorUtils.brandDarkBlue,
        ),
      ],
      bottomSlot: BrandFilterChipStrip(chips: _buildFilterChips(lp)),
    );
  }

  // The wali-kelas / Mengajar selector was intentionally removed from
  // RPP. RPPs are written per teaching assignment (teacher + subject +
  // class), so the homeroom dimension adds no extra rows — the chip
  // would only ever be a no-op shortcut. Class scoping is already
  // covered by the "+ Kelas" filter chip in the bottom slot.

  /// Three filter chips matching Frame A — Format, Status, Kelas.
  /// Each chip opens the same filter sheet; the chip's value updates
  /// live as the teacher applies filters.
  List<BrandFilterChip> _buildFilterChips(LanguageProvider lp) {
    void tap() => showFilterSheet();

    String? formatValue;
    if (selectedFormats.length == 1) {
      formatValue = selectedFormats.first.shortLabel;
    } else if (selectedFormats.length > 1) {
      formatValue = '${selectedFormats.length} format';
    }

    return [
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Format', 'id': 'Format'}),
        value: formatValue,
        onTap: tap,
      ),
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Status', 'id': 'Status'}),
        value: _localizedStatus(selectedStatusFilter, lp),
        onTap: tap,
      ),
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Method', 'id': 'Metode'}),
        value: _localizedMethod(selectedMethod, lp),
        onTap: tap,
      ),
    ];
  }

  String? _localizedStatus(String? raw, LanguageProvider lp) {
    if (raw == null) return null;
    switch (raw) {
      case 'Pending':
        return lp.getTranslatedText({'en': 'Pending', 'id': 'Menunggu'});
      case 'Approved':
        return lp.getTranslatedText({'en': 'Approved', 'id': 'Disetujui'});
      case 'Rejected':
        return lp.getTranslatedText({'en': 'Rejected', 'id': 'Ditolak'});
      case 'Draft':
        return 'Draf';
      default:
        return raw;
    }
  }

  String? _localizedMethod(String? raw, LanguageProvider lp) {
    if (raw == null) return null;
    return raw == 'ai'
        ? lp.getTranslatedText({'en': 'AI', 'id': 'AI'})
        : lp.getTranslatedText({'en': 'Manual', 'id': 'Manual'});
  }

  // ── KPI card ──

  /// 4-cell overlap KPI card per Frame A: Pekan ini · Bulan ini ·
  /// Belum · AI. Counts come from the server-computed `kpiData` block
  /// when loaded — accurate across the entire dataset, not just the
  /// visible page. Falls back to a client-side tally over the loaded
  /// list during cold cache so the card never blanks out.
  ///
  /// "Belum" replaces the legacy "Pending" cell because teachers were
  /// confused by the label — it counted only `status='Pending'`, missed
  /// `draft` rows. The new cell counts everything that's not yet
  /// approved or rejected (draft + pending + submitted) and is
  /// labelled "BELUM" to match what teachers actually want to see —
  /// "RPPs not yet finalized".
  Widget buildBrandKpiCard(LanguageProvider lp) {
    final stats = _resolveKpiStats();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Row(
          children: [
            _kpiCell(
              label: lp.getTranslatedText({
                'en': 'This week',
                'id': 'Pekan ini',
              }),
              value: '${stats.weekly}',
              color: ColorUtils.success600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({
                'en': 'This month',
                'id': 'Bulan ini',
              }),
              value: '${stats.monthly}',
              color: ColorUtils.info600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({'en': 'Open', 'id': 'Belum'}),
              value: '${stats.open}',
              color: ColorUtils.warning600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: 'AI',
              value: '${stats.aiCount}',
              color: ColorUtils.violet700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(width: 1, height: 28, color: ColorUtils.slate100);
  }

  /// Resolve KPI counts. Prefers server-computed `kpiData` (global,
  /// accurate, doesn't shift on scroll). Falls back to a client-side
  /// tally over the loaded list during cold cache so the card always
  /// has something to show.
  _KpiStats _resolveKpiStats() {
    final server = kpiData;
    if (server != null && server.isNotEmpty) {
      return _KpiStats(
        weekly: server['weekly'] ?? 0,
        monthly: server['monthly'] ?? 0,
        open: server['open'] ?? 0,
        aiCount: server['ai'] ?? 0,
      );
    }

    // Cold-cache fallback — tally over the loaded page.
    var aiCount = 0;
    var open = 0;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    var weekly = 0;
    var monthly = 0;

    for (final row in lessonPlanList) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);

      // AI detection — broader than the legacy single-key check.
      // Mirrors the dispatcher's heuristic so the cold-cache count
      // doesn't disagree with whatever the server reports once the
      // summary call resolves.
      if (_isAiRow(m)) aiCount++;

      // Open = not yet finalized (draft + pending + submitted).
      // "Pending" alone misses drafts, which is what the user
      // complained about.
      final status = (m['status'] ?? '').toString().toLowerCase();
      if (status == 'draft' ||
          status == 'pending' ||
          status == 'submitted' ||
          status.isEmpty) {
        open++;
      }

      final created = m['created_at'];
      DateTime? createdAt;
      if (created is String && created.isNotEmpty) {
        createdAt = DateTime.tryParse(created);
      }
      if (createdAt != null) {
        if (createdAt.isAfter(weekAgo)) weekly++;
        if (!createdAt.isBefore(monthStart)) monthly++;
      }
    }

    return _KpiStats(
      weekly: weekly,
      monthly: monthly,
      open: open,
      aiCount: aiCount,
    );
  }

  /// Best-effort AI detection across whatever the row's payload shape
  /// happens to carry. Matches the lesson-plan dispatcher's logic.
  bool _isAiRow(Map<String, dynamic> m) {
    bool truthy(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s.isNotEmpty && s != 'false' && s != '0' && s != 'null';
      }
      return false;
    }

    // 1) The new authoritative flag.
    if (truthy(m['ai_generated']) || truthy(m['is_ai_generated'])) {
      return true;
    }
    // 2) AI-only relation pointers / metadata.
    const aiOnlyKeys = [
      'ai_model_used',
      'ai_tokens_used',
      'lesson_plan_ai_id',
      'chapter_id',
      'sub_chapter_id',
    ];
    for (final k in aiOnlyKeys) {
      if (truthy(m[k])) return true;
    }
    // 3) Last resort — any K13 legacy text column has content
    // (those slots only got written by the AI generator).
    const legacyKeys = [
      'core_competence',
      'basic_competence',
      'indicator',
      'learning_objective',
      'main_material',
      'learning_method',
      'media_tools',
      'learning_source',
      'learning_activities',
      'assessment',
    ];
    for (final k in legacyKeys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return true;
    }
    return false;
  }
}

class _KpiStats {
  final int weekly;
  final int monthly;
  final int open;
  final int aiCount;
  const _KpiStats({
    required this.weekly,
    required this.monthly,
    required this.open,
    required this.aiCount,
  });
}

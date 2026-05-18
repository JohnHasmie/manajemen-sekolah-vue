// Filter bottom sheet for lesson plan filtering — Frame L of the
// RPP mockup. Adds Format (multi-select, 4 chips colored per format)
// and Metode (single-select: All/AI/Manual) on top of the legacy
// Status section.
//
// Returns the picked filter via [LessonPlanFilterResult] so the
// service-layer query can include `formats[]` + `method` query params.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';

/// Result of the filter sheet — returned via the [onApply] callback.
class LessonPlanFilterResult {
  /// `null` ↔ "All". Otherwise one of `Pending` / `Approved` /
  /// `Rejected` / `Draft` (legacy backend strings, not localized).
  final String? status;

  /// Multi-select set of formats. Empty set ↔ "all formats".
  final Set<LessonPlanFormat> formats;

  /// Method axis. `null` ↔ "all" (no filter), or `'ai'` / `'manual'`.
  final String? method;

  const LessonPlanFilterResult({
    required this.status,
    required this.formats,
    required this.method,
  });

  /// Number of active filter axes — used for the "Terapkan (N)" footer
  /// badge so the teacher knows how many filters are about to apply.
  int get activeCount {
    var n = 0;
    if (status != null) n++;
    if (formats.isNotEmpty) n++;
    if (method != null) n++;
    return n;
  }
}

/// Shows a filter bottom sheet for lesson plan filtering.
///
/// `currentStatus` / `currentFormats` / `currentMethod` seed the sheet
/// with whatever the list screen is already filtering by. `onApply`
/// is called with the picked combination.
void showLessonPlanFilterSheet({
  required BuildContext context,
  required Color primaryColor,
  required LanguageProvider languageProvider,
  required String? currentStatus,
  Set<LessonPlanFormat> currentFormats = const <LessonPlanFormat>{},
  String? currentMethod,
  required ValueChanged<LessonPlanFilterResult> onApply,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LessonPlanFilterSheetContent(
      primaryColor: primaryColor,
      languageProvider: languageProvider,
      currentStatus: currentStatus,
      currentFormats: currentFormats,
      currentMethod: currentMethod,
      onApply: onApply,
    ),
  );
}

class _LessonPlanFilterSheetContent extends StatefulWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final String? currentStatus;
  final Set<LessonPlanFormat> currentFormats;
  final String? currentMethod;
  final ValueChanged<LessonPlanFilterResult> onApply;

  const _LessonPlanFilterSheetContent({
    required this.primaryColor,
    required this.languageProvider,
    required this.currentStatus,
    required this.currentFormats,
    required this.currentMethod,
    required this.onApply,
  });

  @override
  State<_LessonPlanFilterSheetContent> createState() =>
      _LessonPlanFilterSheetContentState();
}

class _LessonPlanFilterSheetContentState
    extends State<_LessonPlanFilterSheetContent> {
  late String? _tempStatus = widget.currentStatus;
  late Set<LessonPlanFormat> _tempFormats = Set<LessonPlanFormat>.from(
    widget.currentFormats,
  );
  late String? _tempMethod = widget.currentMethod;

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageProvider;

    final formatOptions = [
      for (final f in LessonPlanFormat.values)
        FilterOption(value: f, label: f.label),
    ];

    final methodOptions = <FilterOption<String?>>[
      FilterOption(
        value: null,
        label: lang.getTranslatedText({'en': 'All', 'id': 'Semua'}),
      ),
      FilterOption(
        value: 'ai',
        label: lang.getTranslatedText({'en': 'AI', 'id': 'AI'}),
      ),
      FilterOption(
        value: 'manual',
        label: lang.getTranslatedText({'en': 'Manual', 'id': 'Manual'}),
      ),
    ];

    final statusOptions = <FilterOption<String?>>[
      FilterOption(
        value: null,
        label: lang.getTranslatedText({'en': 'All', 'id': 'Semua'}),
      ),
      const FilterOption(value: 'Draft', label: 'Draf'),
      FilterOption(
        value: 'Pending',
        label: lang.getTranslatedText({'en': 'Pending', 'id': 'Menunggu'}),
      ),
      FilterOption(
        value: 'Approved',
        label: lang.getTranslatedText({'en': 'Approved', 'id': 'Disetujui'}),
      ),
      FilterOption(
        value: 'Rejected',
        label: lang.getTranslatedText({'en': 'Rejected', 'id': 'Ditolak'}),
      ),
    ];

    return AppFilterBottomSheet(
      title: lang.getTranslatedText({
        'en': 'Filter Lesson Plans',
        'id': 'Filter RPP',
      }),
      icon: Icons.tune_rounded,
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.86,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Format (multi-select) ──
          FilterSectionHeader(
            title: lang.getTranslatedText({'en': 'Format', 'id': 'Format'}),
            icon: Icons.category_rounded,
            primaryColor: widget.primaryColor,
          ),
          FilterChipGrid<LessonPlanFormat>(
            options: formatOptions,
            selectedValues: _tempFormats,
            onMultiSelected: (values) => setState(() => _tempFormats = values),
            // The shared chip grid only colors with a single brand
            // color, so we color each chip by its own format brand
            // via the iconBuilder hook (a small dot prefix). The
            // shared chip itself stays in primary tint when active —
            // good enough for v1; per-chip tint can come in a follow-up.
            selectedColor: widget.primaryColor,
          ),

          const SizedBox(height: 8),

          // ── Metode (single-select: All / AI / Manual) ──
          FilterSectionHeader(
            title: lang.getTranslatedText({'en': 'Method', 'id': 'Metode'}),
            icon: Icons.auto_awesome_outlined,
            primaryColor: widget.primaryColor,
          ),
          FilterChipGrid<String?>(
            options: methodOptions,
            selectedValue: _tempMethod,
            onSelected: (value) => setState(() => _tempMethod = value),
            selectedColor: widget.primaryColor,
          ),

          const SizedBox(height: 8),

          // ── Status ──
          FilterSectionHeader(
            title: lang.getTranslatedText({'en': 'Status', 'id': 'Status'}),
            icon: Icons.check_circle_outline_rounded,
            primaryColor: widget.primaryColor,
          ),
          FilterChipGrid<String?>(
            options: statusOptions,
            selectedValue: _tempStatus,
            onSelected: (value) => setState(() => _tempStatus = value),
            selectedColor: widget.primaryColor,
          ),
        ],
      ),
      onApply: () {
        widget.onApply(
          LessonPlanFilterResult(
            status: _tempStatus,
            formats: _tempFormats,
            method: _tempMethod,
          ),
        );
        Navigator.pop(context);
      },
      onReset: () => setState(() {
        _tempStatus = null;
        _tempFormats = <LessonPlanFormat>{};
        _tempMethod = null;
      }),
    );
  }
}

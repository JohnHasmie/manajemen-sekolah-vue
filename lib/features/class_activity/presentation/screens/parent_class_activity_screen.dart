// Parent view of class activities — Phase 3 brand-aligned redesign.
//
// Composition:
//   • BrandPageHeader (role 'wali') with kicker subtitle, filter
//     icon, BrandRealtimePill, ChildSelectorChipRow, and a
//     BrandFilterChipStrip in the bottomSlot for the Jenis filter
//     (Tugas / Materi).
//   • Body wrapped in RefreshIndicator → mixin-built activity list.
//
// Filtering is implemented as a state-level passthrough: the screen
// stores activities in `_allActivities` and exposes them via the
// `activityList` getter that applies `_typeFilter` on read. The data
// mixin still writes to `activityList` as before — the setter just
// updates `_allActivities` so cache + API roundtrips stay unaware
// of the filter, and the list builder mixin sees the filtered view.
//
// Sibling switching is in-place — tapping a different chip just
// resets the activity list, updates `selectedStudentId`, and
// re-runs `loadActivities` (no Navigator round-trip).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_data_loading_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_list_builder_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_read_tracking_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_tour_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Parent's read-only view of class activities with read tracking.
class ParentClassActivityScreen extends ConsumerStatefulWidget {
  final String? academicYearId;

  const ParentClassActivityScreen({super.key, this.academicYearId});

  @override
  ParentClassActivityScreenState createState() =>
      ParentClassActivityScreenState();
}

class ParentClassActivityScreenState
    extends ConsumerState<ParentClassActivityScreen>
    with
        ParentActivityDataLoadingMixin,
        ParentActivityReadTrackingMixin,
        ParentActivityTourMixin,
        ParentActivityUIBuilderMixin,
        ParentActivityListBuilderMixin {
  // ---- State -----------------------------------------------------------
  /// Unfiltered list owned by the data layer. The `activityList`
  /// getter below applies `_typeFilter` on read so the list builder
  /// mixin sees only the filtered subset, while the data load and
  /// cache layers keep working on the full list unchanged.
  List<dynamic> _allActivities = [];
  final List<dynamic> studentList = [];
  String? selectedStudentId;
  final String parentName = '';
  bool isLoading = true;
  bool hasFreshData = false;

  /// Active type filter. `null` = no filter, `'tugas'` = assignments
  /// only, `'materi'` = materials only.
  String? _typeFilter;

  /// Filter-aware view of `_allActivities`. The data mixin reads/writes
  /// this name; the setter routes back to `_allActivities` so the
  /// cache stays aligned with the API.
  List<dynamic> get activityList {
    if (_typeFilter == null) return _allActivities;
    return _allActivities
        .where((a) => (a as Map)['jenis'] == _typeFilter)
        .toList(growable: false);
  }

  set activityList(List<dynamic> value) {
    _allActivities = value;
  }

  final GlobalKey studentSelectorKey = GlobalKey();
  final GlobalKey activityListKey = GlobalKey();

  // Visibility Tracking
  final Set<String> processedIds = {};
  final Set<String> pendingReadIds = {};
  Timer? markReadDebounce;

  // Drives the realtime pill — bumped after every successful refresh.
  DateTime _lastSync = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    markReadDebounce?.cancel();
    if (pendingReadIds.isNotEmpty) {
      flushMarkReadSilently(List.from(pendingReadIds));
      pendingReadIds.clear();
    }
    super.dispose();
  }

  String get studentsCacheKey =>
      'parent_activity_students_'
      '${widget.academicYearId ?? 'default'}';

  String buildActivitiesCacheKey() {
    return 'parent_activity_list_${selectedStudentId}_'
        '${widget.academicYearId ?? 'default'}';
  }

  // ---- Build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: RefreshIndicator(
        color: ColorUtils.brandAzureDeep,
        onRefresh: () async {
          await forceRefresh();
          if (mounted) setState(() => _lastSync = DateTime.now());
        },
        // Single outer ListView so the gradient hero scrolls with
        // the activity list — matches the dashboard / Kehadiran
        // hero idiom (not pinned).
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(lang),
            KeyedSubtree(
              key: activityListKey,
              child: buildActivityList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lang) {
    final children = _buildChildSummaries();
    return BrandPageHeader(
      role: 'wali',
      subtitle: lang.getTranslatedText({
        'en': 'Academic · Child',
        'id': 'Akademik · Anak',
      }),
      title: lang.getTranslatedText({
        'en': 'Class Activity',
        'id': 'Aktivitas Kelas',
      }),
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => _showFilterSheet(lang),
          badgeCount: _typeFilter != null ? 1 : null,
          badgeBorderColor: ColorUtils.brandAzureDeep,
        ),
      ],
      realtimeIndicator: BrandRealtimePill(
        isFresh: !isLoading,
        lastSync: _lastSync,
      ),
      childSelector: children.length < 2
          ? null
          : ChildSelectorChipRow(
              key: studentSelectorKey,
              children: children,
              selectedChildId: selectedStudentId ?? children.first.id,
              onSelected: (id) {
                setState(() {
                  selectedStudentId = id;
                  _allActivities = [];
                  hasFreshData = false;
                });
                loadActivities();
              },
              accentColor: ColorUtils.brandAzureDeep,
            ),
      bottomSlot: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: lang.getTranslatedText({
              'en': 'Type',
              'id': 'Jenis',
            }),
            value: _typeChipValue(lang),
            onTap: () => _showFilterSheet(lang),
            width: 172,
          ),
        ],
      ),
    );
  }

  String? _typeChipValue(LanguageProvider lang) {
    if (_typeFilter == null) return null;
    return _typeFilter == 'tugas'
        ? lang.getTranslatedText({'en': 'Assignment', 'id': 'Tugas'})
        : lang.getTranslatedText({'en': 'Material', 'id': 'Materi'});
  }

  void _showFilterSheet(LanguageProvider lang) {
    final primaryColor = ColorUtils.brandAzureDeep;
    String? tempType = _typeFilter;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSS) {
          return AppFilterBottomSheet(
            title: lang.getTranslatedText({
              'en': 'Filter Activity',
              'id': 'Filter Aktivitas',
            }),
            primaryColor: primaryColor,
            maxHeightFactor: 0.6,
            onApply: () {
              Navigator.pop(ctx);
              setState(() => _typeFilter = tempType);
            },
            onReset: () => setSS(() => tempType = null),
            content: TeacherFilterContent(
              sections: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: lang.getTranslatedText({
                        'en': 'Type',
                        'id': 'Jenis',
                      }),
                      icon: Icons.category_outlined,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: [
                        FilterOption<String>(
                          value: 'tugas',
                          label: lang.getTranslatedText({
                            'en': 'Assignment',
                            'id': 'Tugas',
                          }),
                        ),
                        FilterOption<String>(
                          value: 'materi',
                          label: lang.getTranslatedText({
                            'en': 'Material',
                            'id': 'Materi',
                          }),
                        ),
                      ],
                      selectedValue: tempType,
                      onSelected: (val) => setSS(() {
                        tempType = val == tempType ? null : val;
                      }),
                      selectedColor: primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<ChildSummary> _buildChildSummaries() {
    return studentList.map<ChildSummary>((raw) {
      final model = Student.fromJson(raw as Map<String, dynamic>);
      return ChildSummary(
        id: model.id,
        shortName: model.name.isEmpty ? '?' : model.name,
        klass: model.className.isEmpty
            ? '-'
            : 'Kelas ${model.className}',
      );
    }).toList();
  }
}

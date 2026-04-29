// Parent report card list screen — Phase 3 brand-aligned redesign.
//
// Displays the parent's children with their report card
// availability per semester. Tapping a student navigates to the
// detail screen.
//
// The data mixin (load + cache + force refresh) is unchanged. The
// presentation overrides the generic UI mixin's `buildHeader()` and
// `buildFilterSection()` so the screen renders the canonical Phase-3
// stack: BrandPageHeader (role 'wali') + BrandFilterChipStrip in the
// bottomSlot for the Semester chip + RefreshIndicator-wrapped list.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/mixins/report_card_data_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/mixins/report_card_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/parent_report_card_filter_mixin.dart';
import 'package:manajemensekolah/core/shell/shell_controller.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Parent's report card list -- shows children with semester selector.
///
/// Props: optional [academicYearId].
/// Navigates to [ParentReportCardDetailScreen] on student tap.
class ParentReportCardScreen extends ConsumerStatefulWidget {
  final String? academicYearId;
  const ParentReportCardScreen({super.key, this.academicYearId});

  @override
  ConsumerState createState() => _ParentReportCardScreenState();
}

/// State for [ParentReportCardScreen].
///
/// Like a Vue component with
/// `data() { return { isLoading, studentsData, selectedTermId } }`.
/// Auto-resolves the current semester and loads student raport data.
class _ParentReportCardScreenState extends ConsumerState<ParentReportCardScreen>
    with ReportCardDataMixin<ParentReportCardScreen>, ReportCardUIBuilderMixin<ParentReportCardScreen>, ParentReportCardFilterMixin {
  @override
  bool isLoading = true;
  @override
  String errorMessage = '';
  @override
  List<dynamic> studentsData = [];
  @override
  Map<String, dynamic> parentData = {};
  @override
  String selectedTermId = '1';

  @override
  String? get academicYearId => widget.academicYearId;

  // Sibling selector state — mirrors the pattern from parent attendance.
  List<Student> _siblings = const [];
  String? _selectedChildId;

  DateTime _lastSync = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadData();
    _loadSiblings();
  }

  @override
  dynamic getAcademicYearProvider() => ref.read(academicYearRiverpod);

  Future<void> _loadSiblings() async {
    try {
      final raw = PreferencesService().getString('user');
      final userData = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(json.decode(raw) as Map);
      final email = (userData['email'] ?? '').toString();
      final userId = (userData['id'] ?? '').toString();
      if (email.isEmpty && userId.isEmpty) return;

      final allStudents = await getIt<ApiStudentService>().getStudent(
        userId: userId.isNotEmpty ? userId : null,
        guardianEmail: email.isNotEmpty ? email : null,
      );
      if (!mounted) return;
      setState(() {
        _siblings = allStudents
            .map((m) => Student.fromJson(m as Map<String, dynamic>))
            .toList(growable: false);
        // Auto-select first child if none selected yet.
        _selectedChildId ??=
            _siblings.isNotEmpty ? _siblings.first.id : null;
      });
    } catch (_) {}
  }

  void _switchChild(String newId) {
    if (newId == _selectedChildId) return;
    setState(() => _selectedChildId = newId);
  }

  /// Effective child id — falls back to first sibling or first in data.
  String? get _effectiveChildId {
    if (_selectedChildId != null) return _selectedChildId;
    if (_siblings.isNotEmpty) return _siblings.first.id;
    return null;
  }

  /// Filter studentsData to show only the selected child's raport.
  List<dynamic> get _filteredStudents {
    final childId = _effectiveChildId;
    if (childId == null || studentsData.isEmpty) return studentsData;
    return studentsData.where((s) {
      final student = (s as Map)['student'] as Map?;
      if (student == null) return true;
      final id = (student['id'] ?? student['student_id'])?.toString();
      return id == childId;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildBrandHeader(lang),
          Expanded(
            child: RefreshIndicator(
              color: ColorUtils.brandAzureDeep,
              onRefresh: () async {
                await forceRefresh();
                await _loadSiblings();
                if (mounted) setState(() => _lastSync = DateTime.now());
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  buildContentArea(filteredData: _filteredStudents),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(LanguageProvider lang) {
    final semesterLabel = selectedTermId == '2'
        ? lang.getTranslatedText({'en': 'Genap', 'id': 'Genap'})
        : lang.getTranslatedText({'en': 'Ganjil', 'id': 'Ganjil'});

    final children = _siblings
        .map((s) => ChildSummary(
              id: s.id,
              shortName: s.name.isEmpty ? '?' : s.name,
              klass: s.className.isEmpty ? '-' : 'Kelas ${s.className}',
            ))
        .toList(growable: false);

    final effectiveChildId = _effectiveChildId ??
        (children.isNotEmpty ? children.first.id : '');

    return BrandPageHeader(
      role: 'wali',
      showBackButton: true,
      onBackPressed: () => AppNavigator.pop(context),
      subtitle: lang.getTranslatedText({
        'en': 'Academic · Child',
        'id': 'Akademik · Anak',
      }),
      title: lang.getTranslatedText({
        'en': 'Report Card',
        'id': 'E-Raport',
      }),
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: showFilterSheet,
        ),
      ],
      realtimeIndicator: BrandRealtimePill(
        isFresh: !isLoading,
        lastSync: _lastSync,
      ),
      childSelector: children.length < 2
          ? null
          : ChildSelectorChipRow(
              children: children,
              selectedChildId: effectiveChildId,
              onSelected: _switchChild,
              accentColor: ColorUtils.brandAzureDeep,
            ),
      bottomSlot: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: lang.getTranslatedText({
              'en': 'Semester',
              'id': 'Semester',
            }),
            value: semesterLabel,
            onTap: showFilterSheet,
            width: 172,
          ),
        ],
      ),
    );
  }
}

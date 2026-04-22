// Parent report card list screen -- shows children and their
// raport status.
// Like `pages/parent/Raport/Index.vue` in a Vue app.
//
// Displays the parent's children with their report card
// availability per semester. Tapping a student navigates to the
// detail screen. Auto-detects current semester based on school
// calendar. In Laravel terms: `RaportController@parentIndex`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/mixins/report_card_data_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/mixins/report_card_ui_builder_mixin.dart';

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
    with ReportCardDataMixin, ReportCardUIBuilderMixin {
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

  /// Like Vue's `mounted()` -- loads report card data on screen init.
  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  dynamic getAcademicYearProvider() => ref.read(academicYearRiverpod);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          buildHeader(),
          buildFilterSection(),
          Expanded(child: buildContentArea()),
        ],
      ),
    );
  }
}

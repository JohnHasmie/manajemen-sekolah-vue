// Teacher · Rekap Nilai overview — brand-migrated.
//
// Replaces the legacy TeacherPageHeader + matrix/list view-toggle
// scaffold with `BrandPageLayout` (gradient header + KPI overlap card +
// scrollable body). Per UX request, the matrix view + view-toggle have
// been retired; the overview always renders as the dense list (Frame B
// from `_design/teacher_grade_recap_mockup.html`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_brand_body_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_brand_header_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_data_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_dialog_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_filter_mixin.dart';

/// Flat overview for Rekap Nilai. Tap a row → opens the recap matrix
/// (currently still hosted in a draggable sheet via
/// `GradeRecapDialogMixin.openRecapTable`; promotion to a full-screen
/// route is tracked under [Brand 4.3]).
class GradeRecapOverviewPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  const GradeRecapOverviewPage({super.key, required this.teacher});

  @override
  ConsumerState<GradeRecapOverviewPage> createState() =>
      _GradeRecapOverviewPageState();
}

class _GradeRecapOverviewPageState extends ConsumerState<GradeRecapOverviewPage>
    with
        GradeRecapDataMixin,
        GradeRecapFilterMixin,
        GradeRecapDialogMixin,
        GradeRecapBrandHeaderMixin,
        GradeRecapBrandBodyMixin {
  @override
  late List<dynamic> groupedData;
  @override
  late bool isLoading;
  @override
  late bool isHomeroomView;
  @override
  late TextEditingController searchController;
  @override
  late String? filterClassId;
  @override
  late String? filterClassName;
  @override
  late String? filterSubjectId;
  @override
  late String? filterSubjectName;

  @override
  Map<String, dynamic> get teacherData => widget.teacher;

  @override
  void initState() {
    super.initState();
    groupedData = [];
    isLoading = true;
    isHomeroomView = false;
    searchController = TextEditingController();
    filterClassId = null;
    filterClassName = null;
    filterSubjectId = null;
    filterSubjectName = null;
    searchController.addListener(() {
      if (mounted) setState(() {});
    });
    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  @override
  int get activeFilterCount =>
      (filterClassId != null ? 1 : 0) + (filterSubjectId != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'guru',
        onRefresh: refresh,
        header: buildBrandHeader(lp),
        kpiCard: buildBrandKpiCard(lp),
        bodyChildren: [buildBrandBody(lp)],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_data_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_header_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_filter_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_dialog_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_content_mixin.dart';

/// Flat overview for Rekap Nilai — matching Nilai/Mengajar
/// pattern. Tap a subject → opens GradeRecapPage as a dialog.
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
        GradeRecapHeaderMixin,
        GradeRecapFilterMixin,
        GradeRecapDialogMixin,
        GradeRecapContentMixin {
  @override
  late List<dynamic> groupedData;
  @override
  late bool isLoading;
  @override
  late bool isHomeroomView;
  @override
  late bool isListView;
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
    isListView = false;
    searchController = TextEditingController();
    filterClassId = null;
    filterClassName = null;
    filterSubjectId = null;
    filterSubjectName = null;
    _loadViewModePref();
    loadViewPref();
    loadData();
  }

  Future<void> _loadViewModePref() async {
    try {
      final cached = await LocalCacheService.load('rekap_nilai_view_mode');
      if (cached is Map && mounted) {
        setState(() {
          isListView = cached['is_list_view'] == true;
        });
      }
    } catch (_) {}
  }

  @override
  void toggleViewMode() {
    setState(() => isListView = !isListView);
    LocalCacheService.save('rekap_nilai_view_mode', {
      'is_list_view': isListView,
    });
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
      body: Column(
        children: [
          buildHeader(lp),
          Expanded(child: buildContent(lp)),
        ],
      ),
    );
  }
}

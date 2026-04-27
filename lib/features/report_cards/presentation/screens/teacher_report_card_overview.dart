import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/header_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/filter_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/filter_dialog_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/card_view_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/table_view_mixin.dart';

class ReportCardOverviewPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;

  const ReportCardOverviewPage({super.key, required this.teacher});

  @override
  ConsumerState<ReportCardOverviewPage> createState() =>
      _ReportCardOverviewPageState();
}

class _ReportCardOverviewPageState extends ConsumerState<ReportCardOverviewPage>
    with
        HeaderMixin,
        FilterMixin,
        FilterDialogMixin,
        CardViewMixin,
        TableViewMixin {
  List<dynamic> _classData = [];
  bool _isLoading = true;
  bool _isTableView = false;
  String? _filterStatus;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  String get _teacherId => Teacher.fromJson(widget.teacher).id;

  @override
  String? get filterStatus => _filterStatus;
  @override
  set filterStatus(String? value) => _filterStatus = value;

  @override
  TextEditingController get searchController => _searchController;
  @override
  bool get isTableView => _isTableView;

  @override
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    final cached = await LocalCacheService.load('raport_overview_view');
    if (cached != null && mounted) {
      setState(() => _isTableView = cached['isTableView'] == true);
    }
  }

  void _saveViewPreference() {
    LocalCacheService.save('raport_overview_view', {
      'isTableView': _isTableView,
    });
  }

  String get _raportCacheKey {
    final ayId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'raport_overview_${_teacherId}_$ayId';
  }

  Future<void> _loadData({bool useCache = true}) async {
    try {
      // Cache-first: show cached data immediately
      if (useCache && _classData.isEmpty) {
        try {
          final cached = await LocalCacheService.load(
            _raportCacheKey,
            ttl: const Duration(hours: 1),
          );
          if (cached is List && cached.isNotEmpty && mounted) {
            setState(() {
              _classData = cached;
              _isLoading = false;
            });
          }
        } catch (_) {}
      }

      if (_classData.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final data = await ApiReportCardService.getTeacherRaportSummary(
        teacherId: _teacherId,
        academicYearId: ayId,
      );
      if (mounted) {
        setState(() {
          _classData = data;
          _isLoading = false;
          _errorMessage = null;
        });
        await LocalCacheService.save(_raportCacheKey, data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  @override
  void openClassReport(dynamic classItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.95,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: ReportCardScreen(
            teacher: widget.teacher.map(
              (k, v) => MapEntry(k, v?.toString() ?? ''),
            ),
            initialClassId: classItem['class_id']?.toString(),
          ),
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget buildViewToggleButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _isTableView = !_isTableView);
        _saveViewPreference();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _isTableView ? Icons.view_agenda_rounded : Icons.table_chart_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  @override
  void buildFilterButtonOnTap() {
    showFilterDialog(ref.watch(languageRiverpod));
  }

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          buildHeader(lp),
          Expanded(child: buildContentArea(lp)),
        ],
      ),
    );
  }

  Widget buildContentArea(LanguageProvider lp) {
    if (_isLoading) {
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      );
    }
    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: () => _loadData(),
        role: 'guru',
      );
    }
    final filteredData = getFilteredData(_classData, _searchController.text);
    return buildContentView(filteredData, _classData, lp);
  }

  Widget buildContentView(
    List<dynamic> filteredData,
    List<dynamic> classData,
    LanguageProvider lp,
  ) {
    if (classData.isEmpty) {
      return buildEmptyClassState(lp);
    }
    if (filteredData.isEmpty) {
      return buildNoResultsState();
    }
    return AppRefreshIndicator(
      onRefresh: _loadData,
      role: 'guru',
      child: _isTableView
          ? buildTableView(filteredData)
          : buildCardView(filteredData, classData),
    );
  }

  Widget buildEmptyClassState(LanguageProvider lp) {
    return EmptyState(
      icon: Icons.assignment_outlined,
      title: lp.getTranslatedText({
        'en': 'No Homeroom Class',
        'id': 'Bukan Wali Kelas',
      }),
      subtitle: lp.getTranslatedText({
        'en': 'Report cards are managed by homeroom teachers',
        'id': 'Raport dikelola oleh wali kelas',
      }),
    );
  }

  Widget buildNoResultsState() {
    return const EmptyState(
      icon: Icons.search_off,
      title: 'Tidak Ditemukan',
      subtitle: 'Tidak ada kelas yang cocok dengan filter',
    );
  }
}

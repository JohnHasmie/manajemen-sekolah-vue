// RPP (Rencana Pelaksanaan Pembelajaran / Lesson Plan) list screen.
// Like `pages/teacher/LessonPlan/Index.vue` in a Vue app.
//
// Displays a list of RPPs with search, filter by status (draft/final),
// CRUD operations, AI generation, and Word/PDF download.
// The [LessonPlanFormDialog] has been extracted to a separate file.
// In Laravel terms: `LessonPlanController@index`, `@store`, `@update`, `@destroy`.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_detail_screen.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/generate_lesson_plan_form_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';

/// RPP (lesson plan) list screen with CRUD, search, filter, and AI generation.
///
/// Props (like Vue props): [teacherId], [teacherName].
/// Contains the main list view and navigation to detail/AI screens.
class LessonPlanScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;

  const LessonPlanScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  LessonPlanScreenState createState() => LessonPlanScreenState();
}

/// State for [LessonPlanScreen].
///
/// Like a Vue page component with `data() { return { rppList, isLoading, ... } }`.
/// Manages the RPP list, search, status filter, and CRUD operations.
class LessonPlanScreenState extends ConsumerState<LessonPlanScreen> {
  List<dynamic> _lessonPlanList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String? _selectedStatusFilter;
  bool _hasActiveFilter = false;

  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _addRppKey = GlobalKey();

  /// Like Vue's `mounted()` -- loads RPP list on screen init.
  @override
  void initState() {
    super.initState();
    _loadLessonPlans();
  }

  /// Like Vue's `beforeUnmount()` -- disposes search controller.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _selectedStatusFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _hasActiveFilter = false;
    });
  }

  String _buildFilterSummary(LanguageProvider languageProvider) {
    final List<String> filters = [];

    if (_selectedStatusFilter != null) {
      filters.add(
        '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $_selectedStatusFilter',
      );
    }

    return filters.join(' • ');
  }

  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    // Temporary state for bottom sheet
    String? tempSelectedStatus = _selectedStatusFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Header (Pattern #11 gradient)
                Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Filter',
                                  'id': 'Filter',
                                }),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedStatus = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Reset',
                                'id': 'Reset',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Filter
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                              color: ColorUtils.slate700,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Status',
                                'id': 'Status',
                              }),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: ColorUtils.slate900,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'All',
                                'id': 'Semua',
                              }),
                              value: null,
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = null;
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Menunggu',
                              value: 'Pending',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Pending';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Disetujui',
                              value: 'Approved',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Approved';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Ditolak',
                              value: 'Rejected',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Rejected';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.slate900.withValues(alpha: 0.05),
                        offset: Offset(0, -2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                              style: TextStyle(color: ColorUtils.slate600),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatusFilter = tempSelectedStatus;
                              });
                              _checkActiveFilter();
                              AppNavigator.pop(context);
                              _loadLessonPlans();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Apply Filter',
                                'id': 'Terapkan Filter',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: _getPrimaryColor().withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate600,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate300,
      ),
    );
  }

  String? _getAcademicYearId() {
    final provider = ref.read(academicYearRiverpod);
    return (provider.selectedAcademicYear?['id'] ??
            provider.activeAcademicYear?['id'])
        ?.toString();
  }

  String _buildLessonPlanCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    return 'rpp_list_${widget.teacherId}_$academicYearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('rpp_');
    _loadLessonPlans(useCache: false);
  }

  /// Fetches RPP list from API with cache-first strategy.
  /// Like `axios.get('/api/rpp')` in Vue with localStorage caching.
  Future<void> _loadLessonPlans({bool useCache = true}) async {
    final isFilteredOrSearched =
        _searchController.text.isNotEmpty || _selectedStatusFilter != null;
    final lessonPlanCacheKey = _buildLessonPlanCacheKey();

    // Step 1: Try cache → return early (only for unfiltered default view)
    if (useCache && !isFilteredOrSearched) {
      final cached = await LocalCacheService.load(lessonPlanCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _lessonPlanList = List<dynamic>.from(cached);
            _isLoading = false;
            _errorMessage = null;
          });
          _checkAndShowTour();
        }
        AppLogger.debug(
          'lesson_plan',
          'LessonPlanScreen: Data from cache (${cached.length})',
        );
        return;
      }
    }

    // Step 2: Show loading & fetch from API
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final academicYearId = _getAcademicYearId();

      final lessonPlanData = await LessonPlanService.getLessonPlans(
        teacherId: widget.teacherId,
        search: _searchController.text,
        status: _selectedStatusFilter,
        academicYearId: academicYearId,
      );

      if (mounted) {
        setState(() {
          _lessonPlanList = lessonPlanData;
          _isLoading = false;
          _hasActiveFilter = _selectedStatusFilter != null;
        });
      }

      // Save to cache only for unfiltered default view
      if (!isFilteredOrSearched) {
        await LocalCacheService.save(lessonPlanCacheKey, lessonPlanData);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Load RPP error: $e');
      if (mounted && _lessonPlanList.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    }
  }

  /// Opens the RPP creation form dialog.
  /// Like clicking a "Add New" button that opens a Vue modal/dialog.
  void _addLessonPlan() {
    final languageProvider = ref.read(languageRiverpod);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: ColorUtils.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Choose Action',
                'id': 'Pilih Aksi',
              }),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate900,
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppNavigator.pop(context);
                      _showLessonPlanFormDialog();
                    },
                    child: Container(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getPrimaryColor().withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 32,
                            color: _getPrimaryColor(),
                          ),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Upload Manual',
                              'id': 'Upload Manual',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getPrimaryColor(),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppNavigator.pop(context);
                      _showGenerateLessonPlanFormDialog();
                    },
                    child: Container(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: ColorUtils.success600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ColorUtils.success600.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 32,
                            color: ColorUtils.success600,
                          ),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Generate AI',
                              'id': 'Generate AI',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.success600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showLessonPlanFormDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: LessonPlanFormDialog(
          teacherId: widget.teacherId,
          onSaved: _loadLessonPlans,
        ),
      ),
    );
  }

  void _showGenerateLessonPlanFormDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GenerateLessonPlanFormDialog(
          teacherId: widget.teacherId,
          onSaved: _forceRefresh,
        ),
      ),
    );
  }

  void _editLessonPlan(Map<String, dynamic> lessonPlan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: LessonPlanFormDialog(
          teacherId: widget.teacherId,
          onSaved: _loadLessonPlans,
          lessonPlanData: lessonPlan,
        ),
      ),
    );
  }

  /// Deletes an RPP after confirmation dialog.
  /// Like `axios.delete('/api/rpp/{id}')` in Vue with a confirm modal.
  Future<void> _deleteLessonPlan(Map<String, dynamic> lessonPlan) async {
    final languageProvider = ref.read(languageRiverpod);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Confirm Delete',
            'id': 'Konfirmasi Hapus',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'Are you sure you want to delete RPP "${lessonPlan['judul']}"?',
            'id':
                'Apakah Anda yakin ingin menghapus RPP "${lessonPlan['judul']}"?',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          ElevatedButton(
            onPressed: () => AppNavigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.error600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Delete',
                'id': 'Hapus',
              }),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await LessonPlanService.deleteLessonPlan(lessonPlan['id']);
        await LocalCacheService.clearStartingWith('rpp_');
        _loadLessonPlans(useCache: false);
        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            languageProvider.getTranslatedText({
              'en': 'RPP deleted successfully',
              'id': 'RPP berhasil dihapus',
            }),
          );
        }
      } catch (e) {
        AppLogger.error('lesson_plan', 'Delete RPP error: $e');
        if (mounted) {
          SnackBarUtils.showError(
            context,
            '${languageProvider.getTranslatedText({'en': 'Failed to delete RPP: ', 'id': 'Gagal menghapus RPP: '})}${ErrorUtils.getFriendlyMessage(e)}',
          );
        }
      }
    }
  }

  Future<void> _viewLessonPlanDetail(Map<String, dynamic> lessonPlan) async {
    final id = lessonPlan['id']?.toString();
    if (id == null || id.isEmpty) {
      SnackBarUtils.showError(
        context,
        ErrorUtils.getFriendlyMessage(Exception('RPP ID tidak tersedia')),
      );
      return;
    }

    try {
      final fullLessonPlan = await LessonPlanService.getLessonPlanById(id);
      AppNavigator.push(context, RPPDetailPage(lessonPlanData: fullLessonPlan));
    } catch (e) {
      AppLogger.error('lesson_plan', 'Fetch RPP detail error: $e');
      SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Approved':
        return ColorUtils.success600;
      case 'Menunggu':
      case 'Pending':
        return ColorUtils.warning600;
      case 'Ditolak':
      case 'Rejected':
        return ColorUtils.error600;
      case 'Draft':
      case 'draft':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return 'Disetujui';
      case 'Pending':
      case 'Menunggu':
        return 'Menunggu';
      case 'Draft':
      case 'draft':
        return 'Draft';
      case 'Rejected':
      case 'Ditolak':
        return 'Ditolak';
      default:
        return status ?? '-';
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    Color? tagColor,
  }) {
    final color = tagColor ?? ColorUtils.slate500;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildLessonPlanCard(Map<String, dynamic> lessonPlan, int index) {
    final accentColor = ColorUtils.getColorForIndex(index);
    final statusColor = _getStatusColor(lessonPlan['status'] ?? '');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewLessonPlanDetail(lessonPlan),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon + title/subject + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lessonPlan['judul'] ?? 'No Title',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Text(
                            lessonPlan['mata_pelajaran_nama'] ?? 'No Subject',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusLabel(lessonPlan['status']),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),
                // Info tags: class
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildInfoTag(
                      icon: Icons.class_,
                      label: lessonPlan['kelas_nama'] ?? 'No Class',
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildCircleActionButton(
                      icon: Icons.visibility_outlined,
                      color: _getPrimaryColor(),
                      onPressed: () => _viewLessonPlanDetail(lessonPlan),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _buildCircleActionButton(
                      icon: Icons.edit_outlined,
                      color: ColorUtils.warning600,
                      onPressed: () => _editLessonPlan(lessonPlan),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _buildCircleActionButton(
                      icon: Icons.delete_outlined,
                      color: ColorUtils.error600,
                      onPressed: () => _deleteLessonPlan(lessonPlan),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 36,
              color: ColorUtils.slate400,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          Text(
            languageProvider.getTranslatedText({
              'en': 'No RPP created yet',
              'id': 'Belum ada RPP dibuat',
            }),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate700,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            languageProvider.getTranslatedText({
              'en': 'Click the "+" button to create your first RPP.',
              'id': 'Klik tombol "+" untuk membuat RPP pertama Anda.',
            }),
            style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: ColorUtils.error600,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Error',
                'id': 'Terjadi Kesalahan',
              }),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage ?? '',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _loadLessonPlans,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'Retry',
                  'id': 'Coba Lagi',
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    final filteredLessonPlans = _lessonPlanList;

    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: _getCardGradient(),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'RPP List',
                              'id': 'Daftar RPP',
                            }),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'View and manage your RPP documents',
                              'id': 'Lihat dan kelola dokumen RPP Anda',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'refresh') _forceRefresh();
                      },
                      icon: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'refresh',
                          child: Row(
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 20,
                                color: ColorUtils.info600,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Text(AppLocalizations.updateData.tr),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),

                // Search Bar with Filter Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: ColorUtils.slate800),
                                decoration: InputDecoration(
                                  hintText: languageProvider.getTranslatedText({
                                    'en': 'Search RPP...',
                                    'id': 'Cari RPP...',
                                  }),
                                  hintStyle: TextStyle(
                                    color: ColorUtils.slate400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: ColorUtils.slate400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) {
                                  _loadLessonPlans();
                                },
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(right: 4),
                              child: IconButton(
                                icon: Icon(
                                  Icons.search,
                                  color: _getPrimaryColor(),
                                ),
                                onPressed: _loadLessonPlans,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // Filter Button
                    Container(
                      key: _filterKey,
                      decoration: BoxDecoration(
                        color: _hasActiveFilter
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            onPressed: _showFilterSheet,
                            icon: Icon(
                              Icons.tune,
                              color: _hasActiveFilter
                                  ? _getPrimaryColor()
                                  : Colors.white,
                            ),
                            tooltip: languageProvider.getTranslatedText({
                              'en': 'Filter',
                              'id': 'Filter',
                            }),
                          ),
                          if (_hasActiveFilter)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: ColorUtils.error600,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 8,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Filter Chips
                if (_hasActiveFilter) ...[
                  SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _buildFilterSummary(languageProvider),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    GestureDetector(
                                      onTap: _clearAllFilters,
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                : _errorMessage != null
                ? _buildErrorState()
                : filteredLessonPlans.isEmpty
                ? _buildEmptyState(languageProvider)
                : RefreshIndicator(
                    onRefresh: _loadLessonPlans,
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        top: 16,
                        bottom: 16,
                        left: 5,
                        right: 5,
                      ),
                      itemCount: filteredLessonPlans.length,
                      itemBuilder: (context, index) {
                        final lessonPlan = filteredLessonPlans[index];
                        return _buildLessonPlanCard(lessonPlan, index);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: _addRppKey,
        onPressed: _addLessonPlan,
        backgroundColor: _getPrimaryColor(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      // Cache-only: tour status pre-fetched from dashboard
      final tourCacheKey = CacheKeyBuilder.tourStatus('rpp_screen', 'guru');
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error checking tour status: $e');
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'rpp_screen_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('rpp_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'rpp_screen_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('rpp_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "FilterRPP",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Filter RPP',
                      'id': 'Filter RPP Cerdas',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Use this to filter your RPP by status or class.',
                        'id':
                            'Temukan Rencana Pelaksanaan Pembelajaran dengan mudah. Filter berdasarkan Mata Pelajaran, Kelas, atau Status.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "AddRPP",
        keyTarget: _addRppKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Add New RPP',
                      'id': 'Tambah & Generate RPP',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Tap here to add a new RPP, either manually or via AI.',
                        'id':
                            'Klik ikon ini untuk membuat RPP baru. Anda dapat menggunakan fitur AI untuk men-generate otomatis atau mengunggah RPP manual.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}

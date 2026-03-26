// RPP (Rencana Pelaksanaan Pembelajaran / Lesson Plan) list screen.
// Like `pages/teacher/LessonPlan/Index.vue` in a Vue app.
//
// Displays a list of RPPs with search, filter by status (draft/final),
// CRUD operations, AI generation, and Word/PDF download. Also contains
// the [RppFormDialog] for creating/editing RPPs.
// In Laravel terms: `LessonPlanController@index`, `@store`, `@update`, `@destroy`.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/features/lesson_plans/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/screens/lesson_plan_detail_screen.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// RPP (lesson plan) list screen with CRUD, search, filter, and AI generation.
///
/// Props (like Vue props): [teacherId], [teacherName].
/// Contains the main list view and navigation to detail/AI screens.
class RppScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;

  const RppScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  RppScreenState createState() => RppScreenState();
}

/// State for [RppScreen].
///
/// Like a Vue page component with `data() { return { rppList, isLoading, ... } }`.
/// Manages the RPP list, search, status filter, and CRUD operations.
class RppScreenState extends ConsumerState<RppScreen> {
  List<dynamic> _rppList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String? _selectedStatusFilter;
  bool _hasActiveFilter = false;

  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _addRppKey = GlobalKey();
  String? _tourId;

  /// Like Vue's `mounted()` -- loads RPP list on screen init.
  @override
  void initState() {
    super.initState();
    _loadRpp();
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
    List<String> filters = [];

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
                    padding: EdgeInsets.all(20),
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
                            SizedBox(width: 8),
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
                        SizedBox(height: 12),
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
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatusFilter = tempSelectedStatus;
                              });
                              _checkActiveFilter();
                              AppNavigator.pop(context);
                              _loadRpp();
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
    return (provider.selectedAcademicYear?['id'] ?? provider.activeAcademicYear?['id'])?.toString();
  }

  String _buildRppCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    return 'rpp_list_${widget.teacherId}_$academicYearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('rpp_');
    _loadRpp(useCache: false);
  }

  /// Fetches RPP list from API with cache-first strategy.
  /// Like `axios.get('/api/rpp')` in Vue with localStorage caching.
  Future<void> _loadRpp({bool useCache = true}) async {
    final isFilteredOrSearched = _searchController.text.isNotEmpty || _selectedStatusFilter != null;
    final rppCacheKey = _buildRppCacheKey();

    // Step 1: Try cache → return early (only for unfiltered default view)
    if (useCache && !isFilteredOrSearched) {
      final cached = await LocalCacheService.load(rppCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _rppList = List<dynamic>.from(cached);
            _isLoading = false;
            _errorMessage = null;
          });
          _checkAndShowTour();
        }
        AppLogger.debug('lesson_plan', 'RppScreen: Data from cache (${cached.length})');
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

      final rppData = await ApiService.getLessonPlans(
        teacherId: widget.teacherId,
        search: _searchController.text,
        status: _selectedStatusFilter,
        academicYearId: academicYearId,
      );

      if (mounted) {
        setState(() {
          _rppList = rppData;
          _isLoading = false;
          _hasActiveFilter = _selectedStatusFilter != null;
        });
      }

      // Save to cache only for unfiltered default view
      if (!isFilteredOrSearched) {
        await LocalCacheService.save(rppCacheKey, rppData);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Load RPP error: $e');
      if (mounted && _rppList.isEmpty) {
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
  void _tambahRpp() {
    final languageProvider = ref.read(languageRiverpod);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
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
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppNavigator.pop(context);
                      _showRppFormDialog();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
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
                          SizedBox(height: 12),
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
                SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppNavigator.pop(context);
                      _showGenerateRppFormDialog();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
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
                          SizedBox(height: 12),
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
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRppFormDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RppFormDialog(teacherId: widget.teacherId, onSaved: _loadRpp),
      ),
    );
  }

  void _showGenerateRppFormDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GenerateRppFormDialog(
          teacherId: widget.teacherId,
          onSaved: _forceRefresh,
        ),
      ),
    );
  }

  void _editRpp(Map<String, dynamic> rpp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RppFormDialog(
          teacherId: widget.teacherId,
          onSaved: _loadRpp,
          rppData: rpp,
        ),
      ),
    );
  }

  /// Deletes an RPP after confirmation dialog.
  /// Like `axios.delete('/api/rpp/{id}')` in Vue with a confirm modal.
  Future<void> _deleteRpp(Map<String, dynamic> rpp) async {
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
            'en': 'Are you sure you want to delete RPP "${rpp['judul']}"?',
            'id': 'Apakah Anda yakin ingin menghapus RPP "${rpp['judul']}"?',
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
        await ApiService.deleteLessonPlan(rpp['id']);
        await LocalCacheService.clearStartingWith('rpp_');
        _loadRpp(useCache: false);
        if (mounted) {
                    SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
                  'en': 'RPP deleted successfully',
                  'id': 'RPP berhasil dihapus',
                }));
        }
      } catch (e) {
        AppLogger.error('lesson_plan', 'Delete RPP error: $e');
        if (mounted) {
                    SnackBarUtils.showError(context, '${languageProvider.getTranslatedText({'en': 'Failed to delete RPP: ', 'id': 'Gagal menghapus RPP: '})}${ErrorUtils.getFriendlyMessage(e)}');
        }
      }
    }
  }

  Future<void> _lihatDetailRpp(Map<String, dynamic> rpp) async {
    final id = rpp['id']?.toString();
    if (id == null || id.isEmpty) {
            SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(Exception('RPP ID tidak tersedia')));
      return;
    }

    try {
      final fullRpp = await ApiService.getLessonPlanById(id);
      AppNavigator.push(context, RPPDetailPage(rppData: fullRpp));
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
          SizedBox(width: 4),
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

  Widget _buildRppCard(Map<String, dynamic> rpp, int index) {
    final accentColor = ColorUtils.getColorForIndex(index);
    final statusColor = _getStatusColor(rpp['status'] ?? '');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _lihatDetailRpp(rpp),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
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
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rpp['judul'] ?? 'No Title',
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
                            rpp['mata_pelajaran_nama'] ?? 'No Subject',
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
                    SizedBox(width: 8),
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
                        _getStatusLabel(rpp['status']),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),
                // Info tags: class
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildInfoTag(
                      icon: Icons.class_,
                      label: rpp['kelas_nama'] ?? 'No Class',
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildCircleActionButton(
                      icon: Icons.visibility_outlined,
                      color: _getPrimaryColor(),
                      onPressed: () => _lihatDetailRpp(rpp),
                    ),
                    SizedBox(width: 8),
                    _buildCircleActionButton(
                      icon: Icons.edit_outlined,
                      color: ColorUtils.warning600,
                      onPressed: () => _editRpp(rpp),
                    ),
                    SizedBox(width: 8),
                    _buildCircleActionButton(
                      icon: Icons.delete_outlined,
                      color: ColorUtils.error600,
                      onPressed: () => _deleteRpp(rpp),
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
          SizedBox(height: 20),
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
          SizedBox(height: 8),
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
        padding: EdgeInsets.all(24),
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
            SizedBox(height: 20),
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
            SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadRpp,
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
    final filteredRpp = _rppList;

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Header dengan gradient
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
                    SizedBox(width: 12),
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
                        child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                      ),
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'refresh',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                              SizedBox(width: 8),
                              Text('Perbarui Data'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),

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
                                  _loadRpp();
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
                                onPressed: _loadRpp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
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
                                padding: EdgeInsets.all(4),
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
                  SizedBox(height: 12),
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
                                    SizedBox(width: 8),
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
                : filteredRpp.isEmpty
                ? _buildEmptyState(languageProvider)
                : RefreshIndicator(
                    onRefresh: _loadRpp,
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        top: 16,
                        bottom: 16,
                        left: 5,
                        right: 5,
                      ),
                      itemCount: filteredRpp.length,
                      itemBuilder: (context, index) {
                        final rpp = filteredRpp[index];
                        return _buildRppCard(rpp, index);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: _addRppKey,
        onPressed: _tambahRpp,
        backgroundColor: _getPrimaryColor(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      // Cache-only: tour status pre-fetched from dashboard
      const tourCacheKey = 'tour_rpp_screen_guru';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
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
    List<TargetFocus> targets = _createTourTargets();
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
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_rpp_screen_guru', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_rpp_screen_guru', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
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

/// Dialog form for creating or editing an RPP (lesson plan).
///
/// Like a Vue `<RppFormModal>` component. When [rppData] is null, it creates
/// a new RPP; when provided, it edits the existing one.
/// Props: [teacherId], [onSaved] callback, optional [rppData] for editing.
class RppFormDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final VoidCallback onSaved;
  final Map<String, dynamic>? rppData;

  const RppFormDialog({
    super.key,
    required this.teacherId,
    required this.onSaved,
    this.rppData,
  });

  @override
  ConsumerState<RppFormDialog> createState() => _RppFormDialogState();
}

class _RppFormDialogState extends ConsumerState<RppFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _tahunAjaranController = TextEditingController();

  String? _selectedMataPelajaranId;
  String? _selectedClassId;
  String? _selectedSemester = 'Ganjil';
  String? _selectedFileName;
  File? _selectedFile;
  bool _isUploading = false;

  List<dynamic> _mataPelajaranList = [];
  List<dynamic> _kelasList = [];

  @override
  void initState() {
    super.initState();
    _loadMataPelajaranByGuru();

    // Jika mode edit, isi field dengan data RPP
    if (widget.rppData != null) {
      _judulController.text =
          widget.rppData!['judul'] ?? widget.rppData!['title'] ?? '';
      _tahunAjaranController.text =
          widget.rppData!['academic_year'] ??
          widget.rppData!['tahun_ajaran'] ??
          '';
      _selectedMataPelajaranId =
          (widget.rppData!['subject_id'] ??
                  widget.rppData!['mata_pelajaran_id'])
              ?.toString();
      _selectedClassId =
          (widget.rppData!['class_id'] ?? widget.rppData!['kelas_id'])
              ?.toString();
      _selectedSemester = widget.rppData!['semester'] ?? 'Ganjil';
      _selectedFileName = widget.rppData!['file_path'];

      if (_selectedMataPelajaranId != null) {
        _loadKelasByMataPelajaran(_selectedMataPelajaranId!);
      }
    } else {
      // Mode tambah baru: set default tahun ajaran
      _tahunAjaranController.text = DateTime.now().year.toString();
    }
  }

  Future<void> _loadMataPelajaranByGuru() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/guru/${widget.teacherId}/mata-pelajaran',
      );
      setState(() {
        // Backend returns {success: true, data: [...], pagination: {...}}
        if (result is Map && result['data'] is List) {
          _mataPelajaranList = result['data'];
        } else if (result is List) {
          _mataPelajaranList = result;
        } else {
          _mataPelajaranList = [];
        }
      });
      if (kDebugMode) {
        AppLogger.info('lesson_plan', 'Loaded ${_mataPelajaranList.length} mata pelajaran');
        if (_mataPelajaranList.isNotEmpty) {
          AppLogger.debug('lesson_plan', 'DEBUG SUBJECT ITEM: ${_mataPelajaranList.first}');
        }
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error loading mata pelajaran by guru: $e');
      _loadAllMataPelajaran();
    }
  }

  Future<void> _loadAllMataPelajaran() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        // Backend might return {success: true, data: [...]} or direct array
        if (result is Map && result['data'] is List) {
          _mataPelajaranList = result['data'];
        } else if (result is List) {
          _mataPelajaranList = result;
        } else {
          _mataPelajaranList = [];
        }
      });
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error loading all mata pelajaran: $e');
    }
  }

  Future<void> _loadKelasByMataPelajaran(String subjectId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$subjectId',
      );
      setState(() {
        // Backend might return {success: true, data: [...]} or direct array
        if (result is Map && result['data'] is List) {
          _kelasList = result['data'];
        } else if (result is List) {
          _kelasList = result;
        } else {
          _kelasList = [];
        }
      });
      if (kDebugMode) {
        AppLogger.info('lesson_plan', 'Loaded ${_kelasList.length} kelas for mata pelajaran $subjectId',);
        if (_kelasList.isNotEmpty) {
          AppLogger.debug('lesson_plan', 'DEBUG CLASS ITEM: ${_kelasList.first}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('lesson_plan', 'Error loading kelas by mata pelajaran: $e');
        setState(() {
          _kelasList = [];
        });
      }
    }
  }

  void _showFilePickerDialog() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        PlatformFile file = result.files.first;

        // Pastikan file benar-benar ada
        File selectedFile = File(file.path!);
        bool fileExists = await selectedFile.exists();

        AppLogger.debug('lesson_plan', 'File picked: ${file.name}');
        AppLogger.debug('lesson_plan', 'File path: ${file.path}');
        AppLogger.debug('lesson_plan', 'File exists: $fileExists');
        AppLogger.debug('lesson_plan', 'File size: ${file.size} bytes');

        if (fileExists) {
          setState(() {
            _selectedFileName = file.name;
            _selectedFile = selectedFile;
          });
        }
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error picking file: $e');
    }
  }

  Future<void> _viewCurrentFile() async {
    final filePath = widget.rppData?['file_path'];
    if (filePath != null) {
      // Use the helper function defined at the bottom of the file
      await _downloadAndOpenFile(context, filePath);
    }
  }

  // Helper to download and open file
  Future<void> _downloadAndOpenFile(
    BuildContext context,
    String filePath,
  ) async {
    try {
      // Construct full URL properly
      // If ApiService.baseUrl is "https://edu-api.kamillabs.com/api"
      // Static files are usually at "https://edu-api.kamillabs.com/uploads/..."
      // We stripping the '/api' suffix to get the root.
      final rootUrl = ApiService.baseUrl.replaceFirst('/api', '');

      // Ensure filePath doesn't double slash and is properly combined
      String cleanPath = filePath;
      if (!cleanPath.startsWith('/')) {
        cleanPath = '/$cleanPath';
      }

      final fullUrl = '$rootUrl$cleanPath';

      AppLogger.debug('lesson_plan', 'Downloading file from: $fullUrl');

      final languageProvider = ref.read(languageRiverpod);
            SnackBarUtils.showInfo(context, languageProvider.getTranslatedText({
              'en': 'Downloading file...',
              'id': 'Mengunduh file...',
            }));

      final dio = Dio();
      final response = await dio.get<List<int>>(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final dir = await getTemporaryDirectory();
      // Extract filename
      final fileName = cleanPath.split('/').last;
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(response.data ?? []);

      AppLogger.info('lesson_plan', 'File saved to: ${file.path}');

      await OpenFile.open(file.path);
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error opening file: $e');

      String message = e.toString().replaceFirst('Exception: ', '');

            SnackBarUtils.showError(context, message);
    }
  }

  // File Upload Logic Removed - Using simplified version

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      String? filePath;

      // Debug: Cek apakah file ada
      AppLogger.debug('lesson_plan', 'File selected: $_selectedFile');
      AppLogger.debug('lesson_plan', 'File name: $_selectedFileName');

      if (_selectedFile != null) {
        try {
          AppLogger.debug('lesson_plan', 'Starting file upload...');
          final uploadResult = await ApiService.uploadLessonPlanFile(_selectedFile!);
          AppLogger.debug('lesson_plan', 'Upload result: $uploadResult');

          filePath = uploadResult['file_path'];
          AppLogger.info('lesson_plan', 'File uploaded successfully: $filePath');
        } catch (uploadError) {
          AppLogger.error('lesson_plan', 'Error during file upload: $uploadError');
          // Tetap lanjut tanpa file jika upload gagal
          filePath = null;
        }
      } else {
        AppLogger.debug('lesson_plan', 'No file selected for upload');
      }

      // Debug data yang akan dikirim
      AppLogger.debug('lesson_plan', 'Submitting RPP data:');
      AppLogger.debug('lesson_plan', '- Guru ID: ${widget.teacherId}');
      AppLogger.debug('lesson_plan', '- Mata Pelajaran ID: $_selectedMataPelajaranId');
      AppLogger.debug('lesson_plan', '- Kelas ID: $_selectedClassId');
      AppLogger.debug('lesson_plan', '- Judul: ${_judulController.text}');
      AppLogger.debug('lesson_plan', '- File Path: $filePath');

      final rppData = {
        'subject_id': _selectedMataPelajaranId,
        'class_id': _selectedClassId,
        'title': _judulController.text,
        'semester': _selectedSemester,
        'academic_year': _tahunAjaranController.text,
        'file_path': filePath ?? _selectedFileName,
      };

      // Submit data RPP (mode edit atau tambah)
      if (widget.rppData != null) {
        // Mode edit
        await ApiService.updateRPP(widget.rppData!['id'], rppData);
        AppLogger.info('lesson_plan', 'RPP updated successfully');
      } else {
        // Mode tambah baru
        rppData['teacher_id'] = widget.teacherId;
        await ApiService.createLessonPlan(rppData);
        AppLogger.info('lesson_plan', 'RPP created successfully');
      }

      if (!mounted) return;
      AppNavigator.pop(context);
      widget.onSaved();

      final languageProvider = ref.read(languageRiverpod);
            SnackBarUtils.showInfo(context, widget.rppData != null
                ? languageProvider.getTranslatedText({
                    'en': 'RPP updated successfully',
                    'id': 'RPP berhasil diupdate',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'RPP created successfully',
                    'id': 'RPP berhasil dibuat',
                  }));
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error creating RPP: $e');
            SnackBarUtils.showInfo(context, '${languageProvider.getTranslatedText({'en': 'Error', 'id': 'Terjadi Kesalahan'})}: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    VoidCallback? onTap,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextFormField(
        controller: controller,
        onTap: onTap,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required dynamic value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? Function(dynamic)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<dynamic>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final primaryColor = _getPrimaryColor();
    final isEditMode = widget.rppData != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (Pattern #10 gradient)
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: ColorUtils.heroGradient(primaryColor: primaryColor),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        isEditMode ? Icons.edit_note : Icons.add_task,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditMode
                                ? languageProvider.getTranslatedText({
                                    'en': 'Edit RPP',
                                    'id': 'Edit RPP',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Add New RPP',
                                    'id': 'Tambah RPP Baru',
                                  }),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            isEditMode
                                ? languageProvider.getTranslatedText({
                                    'en': 'Update RPP details',
                                    'id': 'Perbarui detail RPP',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Create a new RPP document',
                                    'id': 'Buat dokumen RPP baru',
                                  }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogTextField(
                      controller: _judulController,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Title', 'id': 'Judul'})} *',
                      icon: Icons.title_rounded,
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Enter RPP title',
                        'id': 'Masukkan judul RPP',
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.getTranslatedText({
                            'en': 'Title is required',
                            'id': 'Judul wajib diisi',
                          });
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedMataPelajaranId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})} *',
                      icon: Icons.book_outlined,
                      items: _mataPelajaranList.map((mp) {
                        return DropdownMenuItem(
                          value: mp['id'],
                          child: Text(
                            mp['name'] ??
                                mp['nama'] ??
                                mp['subject_name'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMataPelajaranId = value.toString();
                          _selectedClassId = null;
                        });
                        _loadKelasByMataPelajaran(value.toString());
                      },
                      validator: (value) {
                        if (value == null) {
                          return languageProvider.getTranslatedText({
                            'en': 'Subject is required',
                            'id': 'Mata pelajaran wajib diisi',
                          });
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedClassId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})} *',
                      icon: Icons.class_outlined,
                      items: _kelasList.map((kelas) {
                        return DropdownMenuItem(
                          value: kelas['id'],
                          child: Text(
                            kelas['name'] ??
                                kelas['nama'] ??
                                kelas['class_name'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedClassId = value.toString();
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return languageProvider.getTranslatedText({
                            'en': 'Class name is required',
                            'id': 'Nama kelas wajib diisi',
                          });
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedSemester,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Semester', 'id': 'Semester'})} *',
                      icon: Icons.calendar_view_month_rounded,
                      items: ['Ganjil', 'Genap'].map((semester) {
                        return DropdownMenuItem(
                          value: semester,
                          child: Text(semester),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSemester = value;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: _tahunAjaranController,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Academic Year', 'id': 'Tahun Ajaran'})} *',
                      icon: Icons.calendar_today_rounded,
                      hintText: '2024/2025',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.getTranslatedText({
                            'en': 'Academic year is required',
                            'id': 'Tahun ajaran wajib diisi',
                          });
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // File upload section
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'File Attachment',
                        'id': 'Lampiran File',
                      }),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        border: Border.all(color: ColorUtils.slate200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _selectedFileName != null
                                  ? ColorUtils.info600.withValues(alpha: 0.1)
                                  : ColorUtils.slate100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _selectedFileName != null
                                  ? Icons.description_rounded
                                  : Icons.upload_file_rounded,
                              color: _selectedFileName != null
                                  ? ColorUtils.info600
                                  : ColorUtils.slate400,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFileName ??
                                      languageProvider.getTranslatedText({
                                        'en': 'No file selected',
                                        'id': 'Belum ada file dipilih',
                                      }),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedFileName != null
                                        ? ColorUtils.slate800
                                        : ColorUtils.slate400,
                                    fontWeight: _selectedFileName != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedFileName == null)
                                  Text(
                                    'PDF, DOC, DOCX',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ColorUtils.slate400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isEditMode &&
                              widget.rppData!['file_path'] != null)
                            GestureDetector(
                              onTap: _viewCurrentFile,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: ColorUtils.info600.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ColorUtils.info600.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: ColorUtils.info600,
                                ),
                              ),
                            ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showFilePickerDialog,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Choose',
                                  'id': 'Pilih',
                                }),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer Buttons (Enhanced Pattern)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading
                          ? null
                          : () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shadowColor: primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isUploading
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEditMode
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Update',
                                      'id': 'Perbarui',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Save',
                                      'id': 'Simpan',
                                    }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
  }
}

class GenerateRppFormDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final VoidCallback onSaved;

  const GenerateRppFormDialog({
    super.key,
    required this.teacherId,
    required this.onSaved,
  });

  @override
  ConsumerState<GenerateRppFormDialog> createState() => _GenerateRppFormDialogState();
}

class _GenerateRppFormDialogState extends ConsumerState<GenerateRppFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _tahunAjaranController = TextEditingController();

  String? _selectedMataPelajaranId;
  String? _selectedClassId;
  String? _selectedBabId;
  String? _selectedSubBabId;
  String? _selectedSemester = 'Ganjil';
  bool _isAutoGenerating = false;
  String _generationStatus = '';

  List<dynamic> _mataPelajaranList = [];
  List<dynamic> _kelasList = [];
  List<dynamic> _babList = [];
  List<dynamic> _subBabList = [];

  @override
  void initState() {
    super.initState();
    _loadMataPelajaranByGuru();
    _tahunAjaranController.text = DateTime.now().year.toString();
  }

  Future<void> _loadMataPelajaranByGuru() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/guru/${widget.teacherId}/mata-pelajaran',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          _mataPelajaranList = result['data'];
        } else if (result is List) {
          _mataPelajaranList = result;
        } else {
          _mataPelajaranList = [];
        }
      });
    } catch (e) {
      _loadAllMataPelajaran();
    }
  }

  Future<void> _loadAllMataPelajaran() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        if (result is Map && result['data'] is List) {
          _mataPelajaranList = result['data'];
        } else if (result is List) {
          _mataPelajaranList = result;
        } else {
          _mataPelajaranList = [];
        }
      });
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error loading all mata pelajaran: $e');
    }
  }

  Future<void> _loadKelasByMataPelajaran(String subjectId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$subjectId',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          _kelasList = result['data'];
        } else if (result is List) {
          _kelasList = result;
        } else {
          _kelasList = [];
        }
      });
    } catch (e) {
      setState(() {
        _kelasList = [];
      });
    }
  }

  Future<void> _loadBabByMataPelajaran(String subjectId) async {
    try {
      final result = await getIt<ApiSubjectService>().getBabMateri(subjectId: subjectId);
      setState(() {
        _babList = result;
      });
    } catch (e) {
      setState(() {
        _babList = [];
      });
    }
  }

  Future<void> _loadSubBabByBab(String babId) async {
    try {
      final result = await getIt<ApiSubjectService>().getSubBabMateri(babId: babId);
      setState(() {
        _subBabList = result;
      });
    } catch (e) {
      setState(() {
        _subBabList = [];
      });
    }
  }

  // Helper untuk membersihkan HTML tag menjadi teks biasa
  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (html.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  Future<void> _submitForm() async {
    AppLogger.debug('lesson_plan', '_submitForm called');
    if (!_formKey.currentState!.validate()) {
      AppLogger.error('lesson_plan', 'Validation failed');
            SnackBarUtils.showWarning(context, 'Mohon lengkapi semua field yang wajib diisi');
      return;
    }

    AppLogger.info('lesson_plan', 'Validation passed, starting API call');
    setState(() {
      _isAutoGenerating = true;
      _generationStatus = 'Sedang menghubungi AI KamillLabs...';
    });

    try {
      final prefs = PreferencesService();
      final token = prefs.getString('token');
      final userJson = prefs.getString('user');
      String? schoolId;

      if (userJson != null) {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString();
      }

      if (kDebugMode) {
        AppLogger.debug('lesson_plan', 'Current ApiService.baseUrl: ${ApiService.baseUrl}');
        AppLogger.debug('lesson_plan', 'Using Token: ${token != null ? "Available" : "NULL"}');
        if (token != null && token.length > 5) {
          AppLogger.debug('lesson_plan', 'Token Prefix: ${token.substring(0, 5)}...');
        }
        AppLogger.debug('lesson_plan', 'Using School ID: ${schoolId ?? "NULL"} (Removed from AI request headers)',);
      }

      final requestBody = {
        'title': _judulController.text,
        'subject_id': _selectedMataPelajaranId,
        'class_id': _selectedClassId,
        'chapter_id': _selectedBabId,
        'sub_chapter_id': _selectedSubBabId,
        'semester': _selectedSemester,
        'academic_year': _tahunAjaranController.text,
        'teacher_id': widget.teacherId,
      };

      AppLogger.debug('lesson_plan', '🌐 Sending POST request to KamillLabs...');
      AppLogger.debug('lesson_plan', 'Payload: ${json.encode(requestBody)}');

      // Panggilan API asli ke KamillLabs Edu AI via Dio
      final aiDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        validateStatus: (_) => true, // Don't throw on non-2xx
      ));

      final response = await aiDio.post(
        'https://edu-ai-api.kamillabs.com/api/lesson-plans/generate',
        data: requestBody,
      );

      AppLogger.debug('lesson_plan', '📥 Response Status: ${response.statusCode}');

      // Dio auto-decodes JSON, so response.data is already a Map
      final resultBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 202) {
        // Async Mode - navigate to result screen with polling
        AppLogger.debug('lesson_plan', 'Full 202 Response: ${response.data}');

        // Try multiple field names for poll_url and job_id
        final pollUrl =
            (resultBody['poll_url'] ??
                    resultBody['polling_url'] ??
                    resultBody['status_url'])
                as String?;
        final jobId =
            (resultBody['job_id'] ??
                    resultBody['jobId'] ??
                    resultBody['id'] ??
                    resultBody['data']?['id'] ??
                    resultBody['data']?['job_id'])
                as String?;

        AppLogger.debug('lesson_plan', '⏳ Job Queued: $jobId | Polling at: $pollUrl');

        // Build metadata for the result screen
        final pollingMetadata = await _buildPollingMetadata();

        if (!mounted) return;

        AppNavigator.pushReplacement(context, RppAiResultScreen(
              teacherId: widget.teacherId,
              onSaved: widget.onSaved,
              pollUrl: pollUrl,
              jobId: jobId,
              token: token,
              pollingMetadata: pollingMetadata,
            ));
        return;
      }

      if (response.statusCode == 429) {
        AppLogger.warning('lesson_plan', 'Rate limit reached');
        final message =
            resultBody['message'] ??
            'Batas pembuatan RPP AI harian/bulanan telah tercapai.';
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: Icon(
                Icons.timer_off_rounded,
                color: ColorUtils.warning600,
                size: 48,
              ),
              title: Text(
                'Batas Tercapai',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () => AppNavigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.warning600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text('Mengerti'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        AppLogger.error('lesson_plan', 'API Error Body: ${response.data}');
        final message = resultBody['message'] ?? 'Gagal generate RPP';
        throw Exception(message);
      }

      final rppResponse = resultBody['data'] ?? resultBody;

      await _processAndNavigate(rppResponse);
    } catch (e) {
      AppLogger.error('lesson_plan', '🚨 _submitForm error: $e');
      if (mounted) {
                SnackBarUtils.showInfo(context, '${AppLocalizations.error.tr}: $e');
      }
    } finally {
      AppLogger.debug('lesson_plan', '🏁 _submitForm finished (isAutoGenerating: false)');
      if (mounted) {
        setState(() {
          _isAutoGenerating = false;
          _generationStatus = '';
        });
      }
    }
  }

  Future<Map<String, dynamic>> _buildPollingMetadata() async {
    final userData = await TokenService().getUserData();
    final schoolObj = userData?['school'] as Map<String, dynamic>?;
    final schoolNameStr = schoolObj != null
        ? (schoolObj['school_name'] ?? schoolObj['nama_sekolah'] ?? 'SD/MI')
        : (userData?['school_name'] ?? userData?['nama_sekolah'] ?? 'SD/MI');

    final selectedSubject = _mataPelajaranList.firstWhere(
      (m) => m['id'].toString() == _selectedMataPelajaranId,
      orElse: () => {'name': 'Mata Pelajaran'},
    );
    final mataPelajaranNama =
        selectedSubject['name'] ?? selectedSubject['nama'] ?? 'Mata Pelajaran';

    final selectedClass = _kelasList.firstWhere(
      (k) => k['id'].toString() == _selectedClassId,
      orElse: () => {'name': 'Kelas'},
    );
    final kelasNama = selectedClass['name'] ?? selectedClass['nama'] ?? 'Kelas';

    final babMap = _selectedBabId != null
        ? _babList.firstWhere(
            (b) => b['id'].toString() == _selectedBabId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final babName = babMap.isNotEmpty
        ? (babMap['judul_bab'] ?? babMap['title'] ?? babMap['judul'] ?? '')
        : '';

    final subBabMap = _selectedSubBabId != null
        ? _subBabList.firstWhere(
            (s) => s['id'].toString() == _selectedSubBabId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final subBabName = subBabMap.isNotEmpty
        ? (subBabMap['judul_sub_bab'] ??
              subBabMap['title'] ??
              subBabMap['judul'] ??
              '')
        : '';

    return {
      'title': _judulController.text,
      'mata_pelajaran_id': _selectedMataPelajaranId,
      'mata_pelajaran_nama': mataPelajaranNama,
      'satuan_pendidikan': schoolNameStr,
      'bab_nama': babName,
      'sub_bab_nama': subBabName,
      'kelas_semester': '$kelasNama / ${_selectedSemester ?? 'Ganjil'}',
      'alokasi_waktu': _tahunAjaranController.text,
    };
  }

  Future<void> _processAndNavigate(dynamic rppResponse) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final languageProvider = ref.read(languageRiverpod);

    final userData = await TokenService().getUserData();
    final schoolObj = userData?['school'] as Map<String, dynamic>?;
    final schoolNameStr = schoolObj != null
        ? (schoolObj['school_name'] ?? schoolObj['nama_sekolah'] ?? 'SD/MI')
        : (userData?['school_name'] ?? userData?['nama_sekolah'] ?? 'SD/MI');

    final selectedSubject = _mataPelajaranList.firstWhere(
      (m) => m['id'].toString() == _selectedMataPelajaranId,
      orElse: () => {'name': 'Mata Pelajaran'},
    );
    final mataPelajaranNama =
        rppResponse['mata_pelajaran_nama'] ??
        selectedSubject['name'] ??
        selectedSubject['nama'] ??
        'Mata Pelajaran';

    final selectedClass = _kelasList.firstWhere(
      (k) => k['id'].toString() == _selectedClassId,
      orElse: () => {'name': 'Kelas'},
    );
    final kelasNama =
        rppResponse['kelas_nama'] ??
        selectedClass['name'] ??
        selectedClass['nama'] ??
        'Kelas';

    final babMap = _selectedBabId != null
        ? _babList.firstWhere(
            (b) => b['id'].toString() == _selectedBabId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final babName = babMap.isNotEmpty
        ? (babMap['judul_bab'] ??
              babMap['title'] ??
              babMap['judul'] ??
              'Tanpa Nama')
        : '';

    final subBabMap = _selectedSubBabId != null
        ? _subBabList.firstWhere(
            (s) => s['id'].toString() == _selectedSubBabId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final subBabName = subBabMap.isNotEmpty
        ? (subBabMap['judul_sub_bab'] ??
              subBabMap['title'] ??
              subBabMap['judul'] ??
              'Tanpa Nama')
        : '';

    final mappedRppData = {
      'id': null,
      'judul': rppResponse['title'] ?? _judulController.text,
      'mata_pelajaran_id': _selectedMataPelajaranId,
      'mata_pelajaran_nama': mataPelajaranNama,
      'satuan_pendidikan': schoolNameStr,
      'bab_nama': babName,
      'sub_bab_nama': subBabName,
      'kelas_semester':
          '$kelasNama / ${rppResponse['semester'] ?? _selectedSemester}',
      'tema': rppResponse['title'],
      'sub_tema': '',
      'pembelajaran_ke': '',
      'alokasi_waktu': _tahunAjaranController.text,
      'waktu_pendahuluan': '15',
      'waktu_inti': '140',
      'waktu_penutup': '15',
      'kompetensi_inti': _stripHtml(
        rppResponse['core_competence'] as String? ?? '',
      ),
      'kompetensi_dasar': _stripHtml(
        rppResponse['basic_competence'] as String? ?? '',
      ),
      'tujuan_pembelajaran': _stripHtml(
        rppResponse['learning_objective'] as String? ?? '',
      ),
      'kegiatan_pendahuluan':
          '• Melakukan Pembukaan dengan Salam dan Membaca Doa\n• Mengaitkan Materi Sebelumnya dengan Materi yang akan dipelajari',
      'kegiatan_inti': _stripHtml(
        rppResponse['learning_activities'] as String? ?? '',
      ),
      'kegiatan_penutup':
          '• Siswa membuat resume dengan bimbingan guru\n• Guru memeriksa pekerjaan siswa\n• Pemberian hadiah/pujian untuk pekerjaan yang benar',
      'penilaian': _stripHtml(rppResponse['assessment'] as String? ?? ''),
      'is_ai_generated': true,
    };

    if (!mounted) return;
    AppNavigator.pushReplacement(context, RppAiResultScreen(
          rppData: mappedRppData,
          teacherId: widget.teacherId,
          onSaved: () {
            widget.onSaved();
          },
        ));

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          languageProvider.getTranslatedText({
            'en': 'RPP successfully AI-generated.',
            'id': 'RPP berhasil di-generate AI.',
          }),
        ),
        backgroundColor: ColorUtils.success600,
      ),
    );
  }

  Color _getPrimaryColor() => ColorUtils.success600;

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required dynamic value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? Function(dynamic)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<dynamic>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final primaryColor = _getPrimaryColor();

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Generate RPP with AI',
                              'id': 'Generate RPP dengan AI',
                            }),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            languageProvider.getTranslatedText({
                              'en':
                                  'Create interactive RPP documents automatically',
                              'id': 'Buat dokumen RPP secara otomatis',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogTextField(
                      controller: _judulController,
                      label: '${AppLocalizations.title.tr} *',
                      icon: Icons.title_rounded,
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Enter RPP title',
                        'id': 'Masukkan judul RPP',
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.titleRequired.tr;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedMataPelajaranId,
                      label: '${AppLocalizations.subject.tr} *',
                      icon: Icons.book_outlined,
                      items: _mataPelajaranList.map((mp) {
                        return DropdownMenuItem(
                          value: mp['id'],
                          child: Text(
                            mp['name'] ??
                                mp['nama'] ??
                                mp['subject_name'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMataPelajaranId = value.toString();
                          _selectedClassId = null;
                          _selectedBabId = null;
                          _selectedSubBabId = null;
                          _babList = [];
                          _subBabList = [];
                        });
                        _loadKelasByMataPelajaran(value.toString());
                        _loadBabByMataPelajaran(value.toString());
                      },
                      validator: (value) {
                        if (value == null) {
                          return AppLocalizations.subjectRequired.tr;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedClassId,
                            label: '${AppLocalizations.class_.tr} *',
                            icon: Icons.class_outlined,
                            items: _kelasList.map((kelas) {
                              return DropdownMenuItem(
                                value: kelas['id'],
                                child: Text(
                                  kelas['name'] ??
                                      kelas['nama'] ??
                                      kelas['class_name'] ??
                                      'Tanpa Nama',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClassId = value.toString();
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return AppLocalizations.classNameRequired.tr;
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedSemester,
                            label: '${AppLocalizations.semester.tr} *',
                            icon: Icons.calendar_view_month_rounded,
                            items: ['Ganjil', 'Genap'].map((semester) {
                              return DropdownMenuItem(
                                value: semester,
                                child: Text(semester),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSemester = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedBabId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Chapter', 'id': 'Bab'})} *',
                      icon: Icons.bookmark_border_rounded,
                      items: _babList.map((bab) {
                        return DropdownMenuItem(
                          value: bab['id'],
                          child: Text(
                            bab['judul_bab'] ??
                                bab['title'] ??
                                bab['judul'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBabId = value.toString();
                          _selectedSubBabId = null;
                          _subBabList = [];
                        });
                        _loadSubBabByBab(value.toString());
                      },
                      validator: (value) {
                        if (value == null) {
                          return languageProvider.getTranslatedText({
                            'en': 'Chapter is required',
                            'id': 'Bab harus dipilih',
                          });
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedSubBabId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Sub Chapter', 'id': 'Sub Bab'})} (Opsional)',
                      icon: Icons.bookmark_add_outlined,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'None',
                              'id': 'Tidak ada',
                            }),
                            style: TextStyle(color: ColorUtils.slate400),
                          ),
                        ),
                        ..._subBabList.map((subBab) {
                          return DropdownMenuItem(
                            value: subBab['id'],
                            child: Text(
                              subBab['judul_sub_bab'] ??
                                  subBab['title'] ??
                                  subBab['judul'] ??
                                  'Tanpa Nama',
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSubBabId = value?.toString();
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: _tahunAjaranController,
                      label: '${AppLocalizations.academicYear.tr} *',
                      icon: Icons.calendar_today_rounded,
                      hintText: '2024/2025',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.academicYearRequired.tr;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer Buttons
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isAutoGenerating
                          ? null
                          : () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        AppLocalizations.cancel.tr,
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAutoGenerating ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shadowColor: primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isAutoGenerating
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_generationStatus.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    _generationStatus,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Text(
                              languageProvider.getTranslatedText({
                                'en': 'Generate',
                                'id': 'Generate',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
  }
}

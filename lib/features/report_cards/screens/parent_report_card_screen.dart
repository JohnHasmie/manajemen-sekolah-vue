// Parent report card list screen -- shows children and their raport status.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
// Like `pages/parent/Raport/Index.vue` in a Vue app.
//
// Displays the parent's children with their report card availability
// per semester. Tapping a student navigates to the detail screen.
// Auto-detects current semester based on school calendar.
// In Laravel terms: `RaportController@parentIndex`.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/screens/parent_report_card_detail_screen.dart';
import 'package:manajemensekolah/features/schedule/services/schedule_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Parent's report card list -- shows children with semester selector.
///
/// Props: optional [academicYearId].
/// Navigates to [ParentRaportDetailScreen] on student tap.
class ParentRaportScreen extends ConsumerStatefulWidget {
  final String? academicYearId;
  const ParentRaportScreen({super.key, this.academicYearId});

  @override
  ConsumerState createState() => _ParentRaportScreenState();
}

/// State for [ParentRaportScreen].
///
/// Like a Vue component with `data() { return { isLoading, studentsData, selectedSemesterId } }`.
/// Auto-resolves the current semester and loads student raport data.
class _ParentRaportScreenState extends ConsumerState<ParentRaportScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _studentsData = [];
  Map<String, dynamic> _parentData = {};

  // We can select semester (1 for Ganjil, 2 for Genap)
  String _selectedSemesterId = '1';

  /// Like Vue's `mounted()` -- loads report card data on screen init.
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _buildCacheKey() {
    final yearId =
        widget.academicYearId ??
        ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ??
        'unknown';
    return 'parent_raport_${yearId}_$_selectedSemesterId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('parent_raport_');
    await LocalCacheService.clearStartingWith('school_day_data');
    _loadData(useCache: false);
  }

  Future<void> _resolveSemester() async {
    // Use shared school_day_data cache (24h TTL) instead of direct API call
    final cached = await LocalCacheService.load('school_day_data', ttl: const Duration(hours: 24));
    Map<String, dynamic>? dateBasedSemester;

    if (cached != null && cached is Map<String, dynamic>) {
      dateBasedSemester = cached;
    } else {
      dateBasedSemester = await getIt<ApiScheduleService>().getDateBasedSemester();
      // Non-blocking save
      LocalCacheService.save('school_day_data', dateBasedSemester);
    }

    if (dateBasedSemester.containsKey('semester') &&
        dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
      _selectedSemesterId = '2';
    }
  }

  /// Loads parent data and fetches raport for each child.
  /// Resolves current semester automatically, then fetches from cache or API.
  Future<void> _loadData({bool useCache = true}) async {
    // Load parent data
    if (_parentData.isEmpty || _parentData['id'] == null) {
      final prefs = PreferencesService();
      _parentData = json.decode(prefs.getString('user') ?? '{}');
    }

    // Resolve semester
    await _resolveSemester();

    // Step 1: Try cache — return early on hit
    if (useCache) {
      final cacheKey = _buildCacheKey();
      final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 3));
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _studentsData = List<dynamic>.from(cached);
          _isLoading = false;
          _errorMessage = '';
        });
        return;
      }
    }

    // Step 2: Show skeleton only if list is empty
    if (_studentsData.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    // Step 3: Fetch fresh from API
    try {
      if (_parentData.isEmpty || _parentData['id'] == null) {
        throw Exception(
          "Sesi wali murid tidak ditemukan. Silakan login kembali.",
        );
      }

      await _fetchParentRaports();
    } catch (e) {
      if (!mounted) return;
      // Only show error if no cached data
      if (_studentsData.isEmpty) {
        setState(() => _errorMessage = ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchParentRaports() async {
    final yearId =
        widget.academicYearId ??
        ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();

    if (yearId == null) throw Exception("Tahun ajaran belum dipilih.");

    final response = await dioClient.get(
      '/parent/raports',
      queryParameters: {
        'academic_year_id': yearId,
        'semester_id': _selectedSemesterId,
      },
    );

    // Dio auto-decodes JSON and throws on non-2xx (handled by ErrorInterceptor)
    final jsonResponse = response.data;
    if (jsonResponse is Map<String, dynamic> && jsonResponse['success'] == true) {
      final freshData = jsonResponse['data'] ?? [];
      if (!mounted) return;

      // Save to cache (non-blocking)
      LocalCacheService.save(_buildCacheKey(), freshData);

      setState(() {
        _studentsData = freshData;
      });
    } else {
      throw Exception(
        jsonResponse is Map ? (jsonResponse['message'] ?? 'Gagal memuat e-raport.') : 'Gagal memuat e-raport.',
      );
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(_parentData['role'] ?? 'wali');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header - Pattern #7 gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: _getCardGradient(),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
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
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'E-Raport',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lihat raport akademik siswa',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'refresh') _forceRefresh();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                          const SizedBox(width: AppSpacing.sm),
                          const Text('Perbarui Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Filter section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Semester:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedSemesterId,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('Ganjil')),
                      DropdownMenuItem(value: '2', child: Text('Genap')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSemesterId = val);
                        _loadData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const SkeletonListLoading()
                : _errorMessage.isNotEmpty && _studentsData.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 48,
                            color: Colors.orange[300],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _studentsData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Belum ada E-Raport yang dipublikasikan\npada semester ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: _studentsData.length,
                      itemBuilder: (context, index) {
                        final student = _studentsData[index];
                        final reportCard = student['raport'];

                        // Parent only sees published raports
                        if (reportCard == null || reportCard['status'] != 'published') {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              AppNavigator.push(context, ParentRaportDetailScreen(
                                        reportCardData: reportCard,
                                        studentName:
                                            student['student']['name'] ??
                                            'Siswa',
                                        userRole: 'wali',
                                        studentData: student['student'],
                                      ));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: ColorUtils.corporateBlue600
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      (student['student']['name'] ?? '?')[0]
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: ColorUtils.corporateBlue600,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student['student']['name'] ??
                                              'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          'NIS: ${student['student']['nis'] ?? '-'}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

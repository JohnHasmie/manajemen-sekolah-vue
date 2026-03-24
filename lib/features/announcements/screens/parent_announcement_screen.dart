// School announcements screen for parents (wali murid).
// Like `pages/parent/Announcements.vue` in a Vue app.
//
// Displays a list of school announcements with read/unread tracking.
// Automatically marks announcements as read when they become visible
// (using a debounced visibility tracking pattern -- similar to an
// Intersection Observer in Vue). Supports search, file attachments,
// and detail view in a bottom sheet.
// In Laravel terms: `AnnouncementController@index` with read tracking.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// School announcements list with automatic read tracking.
///
/// A StatefulWidget with no constructor params -- reads user data from
/// SharedPreferences. Implements a debounced "mark as read" pattern
/// similar to how Gmail marks emails as read when scrolled past.
class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  AnnouncementScreenState createState() => AnnouncementScreenState();
}

/// State for [AnnouncementScreen].
///
/// Like a Vue page component with `data() { return {...} }`. Key state:
/// - [_announcementList] -- list of announcements from API
/// - [_processedIds] / [_pendingReadIds] -- visibility tracking sets
/// - [_markReadDebounce] -- timer for batched "mark as read" API calls
///
/// The visibility tracking pattern: when an item becomes visible, its ID is
/// queued. After 1 second of no new items, all queued IDs are sent to the
/// API in one batch. Like a Vue Intersection Observer + debounced API call.
class AnnouncementScreenState extends State<AnnouncementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _announcementList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _userRole = 'wali'; // Default role

  // Visibility Tracking
  final Set<String> _processedIds = {}; // IDs we've already handled/queued
  final Set<String> _pendingReadIds = {}; // IDs waitng to be sent to API
  Timer? _markReadDebounce;

  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();
  String? _tourId;

  @override
  void dispose() {
    _markReadDebounce?.cancel(); // Cancel visibility debounce
    if (_pendingReadIds.isNotEmpty) {
      _flushMarkReadSilently(List.from(_pendingReadIds));
      _pendingReadIds.clear();
    }
    super.dispose();
  }

  Future<void> _flushMarkReadSilently(List<String> ids) async {
    try {
      await ApiService.markAnnouncementRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error silent auto-marking read: $e");
    }
  }

  void _onItemVisible(Map<String, dynamic> announcement) {
    final id = announcement['id'].toString();
    final isRead =
        announcement['is_read'] == null ||
        announcement['is_read'] == true ||
        announcement['is_read'] == 1 ||
        announcement['is_read'] == '1';

    if (!isRead && !_processedIds.contains(id)) {
      _processedIds.add(id);
      _pendingReadIds.add(id);
      _scheduleMarkRead();
    }
  }

  void _scheduleMarkRead() {
    if (_markReadDebounce?.isActive ?? false) return;

    _markReadDebounce = Timer(const Duration(seconds: 1), () {
      if (_pendingReadIds.isNotEmpty) {
        final idsToMark = _pendingReadIds.toList();
        _pendingReadIds.clear(); // Clear pending first to avoid duplicates
        _flushMarkRead(idsToMark);
      }
    });
  }

  Future<void> _flushMarkRead(List<String> ids) async {
    try {
      if (kDebugMode) {
        print('📨 Auto-marking ${ids.length} visible announcements as read...');
      }

      // Optimistic Update (update local list UI immediately)
      setState(() {
        for (var item in _announcementList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await ApiService.markAnnouncementRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error auto-marking read: $e");
    }
  }

  /// Like Vue's `mounted()` -- loads user role and announcement data.
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  static const String _announcementCacheKey = 'announcement_list';

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('announcement_');
    _loadData(useCache: false);
  }

  /// Loads announcements from API with cache-first strategy.
  /// Like `axios.get('/api/announcements')` in Vue.
  Future<void> _loadData({bool useCache = true}) async {
    // Load user role from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    if (userData != null) {
      final user = json.decode(userData);
      if (mounted) {
        setState(() {
          _userRole = user['role'] ?? 'wali';
        });
      }
    }

    // Step 1: Try cache → return early
    if (useCache) {
      final cached = await LocalCacheService.load(_announcementCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _announcementList = List<dynamic>.from(cached);
            _isLoading = false;
            _errorMessage = null;
          });
          _checkAndShowTour();
        }
        if (kDebugMode) print('📦 AnnouncementScreen: Data from cache (${cached.length})');
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
      final response = await _apiService.get('/announcement/user/current');

      List<dynamic> announcementList = [];
      if (response is Map<String, dynamic> && response['data'] != null) {
        announcementList = response['data'] is List ? response['data'] : [];
      } else if (response is List) {
        announcementList = response;
      }

      if (mounted) {
        setState(() {
          _announcementList = announcementList;
          _isLoading = false;
        });
      }

      // Save to cache
      await LocalCacheService.save(_announcementCacheKey, announcementList);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading announcements: $e');
      }
      if (mounted && _announcementList.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    }
  }

  List<dynamic> get _filteredAnnouncement {
    if (_searchController.text.isEmpty) {
      return _announcementList;
    }

    final searchLower = _searchController.text.toLowerCase();
    return _announcementList.where((p) {
      final title = p['title']?.toString().toLowerCase() ?? '';
      final content = p['content']?.toString().toLowerCase() ?? '';
      final creatorName = p['pembuat_nama']?.toString().toLowerCase() ?? '';
      return title.contains(searchLower) ||
          content.contains(searchLower) ||
          creatorName.contains(searchLower);
    }).toList();
  }

  Color _getPrimaryColor() {
    // Use ColorUtils with dynamic role from user data
    final color = ColorUtils.getRoleColor(_userRole);
    if (kDebugMode) {
      print('🎨 User role: $_userRole, Color: $color');
    }
    return color;
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _getTargetText(
    Map<String, dynamic> announcementData,
    LanguageProvider languageProvider,
  ) {
    final roleTarget = (announcementData['role_target'] ?? 'all')
        .toString()
        .toLowerCase()
        .trim();
    final className = announcementData['kelas_nama'];

    // Handle both 'all' (English) and 'semua' (Indonesian) from backend
    if ((roleTarget == 'all' || roleTarget == 'semua' || roleTarget == '') &&
        className == null) {
      return languageProvider.getTranslatedText({
        'en': 'All Users',
        'id': 'Semua Pengguna',
      });
    } else if (className != null) {
      return '$className (${roleTarget.toUpperCase()})';
    } else {
      return roleTarget.toUpperCase();
    }
  }

  // Pattern #8 info tag chip
  Widget _buildInfoTag(IconData icon, String text, {Color? tagColor}) {
    final c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor != null
              ? tagColor.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDetail(Map<String, dynamic> announcementData) {
    final languageProvider = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.announcement,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            announcementData['title'] ?? 'No Title',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _formatDate(announcementData['created_at']),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Priority badge
                    if ([
                      'penting',
                      'important',
                    ].contains(announcementData['priority']))
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtils.warning600.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ColorUtils.warning600.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning,
                              size: 14,
                              color: ColorUtils.warning600,
                            ),
                            SizedBox(width: 6),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Important Announcement',
                                'id': 'Pengumuman Penting',
                              }),
                              style: TextStyle(
                                color: ColorUtils.warning600,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16),

                    // Content text
                    Text(
                      announcementData['content'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: ColorUtils.slate800,
                      ),
                    ),

                    SizedBox(height: 20),

                    // Attachment Section
                    if (announcementData['file_path'] != null) ...[
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Attachment',
                          'id': 'Lampiran',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate600,
                        ),
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _openFile(
                          _getFileUrl(announcementData['file_path']),
                          announcementData['file_name'] ?? 'attachment',
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: ColorUtils.slate200,
                                  ),
                                ),
                                child: Icon(
                                  Icons.attach_file,
                                  color: _getPrimaryColor(),
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      announcementData['file_name'] ??
                                          languageProvider.getTranslatedText({
                                            'en': 'Download File',
                                            'id': 'Unduh File',
                                          }),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtils.slate800,
                                      ),
                                    ),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Tap to open',
                                        'id': 'Ketuk untuk membuka',
                                      }),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ColorUtils.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.download_rounded,
                                color: ColorUtils.slate400,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],

                    // Metadata
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.person,
                            label: languageProvider.getTranslatedText({
                              'en': 'Created by',
                              'id': 'Dibuat oleh',
                            }),
                            value:
                                announcementData['pembuat_nama'] ?? 'Unknown',
                          ),
                          SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.people,
                            label: languageProvider.getTranslatedText({
                              'en': 'Target Role',
                              'id': 'Role Target',
                            }),
                            value: _getTargetText(
                              announcementData,
                              languageProvider,
                            ),
                          ),
                          if (announcementData['start_date'] != null)
                            SizedBox(height: 8),
                          if (announcementData['start_date'] != null)
                            _buildDetailRow(
                              icon: Icons.calendar_today,
                              label: languageProvider.getTranslatedText({
                                'en': 'Start Date',
                                'id': 'Tanggal Mulai',
                              }),
                              value: _formatDate(
                                announcementData['start_date'],
                              ),
                            ),
                          if (announcementData['end_date'] != null)
                            SizedBox(height: 8),
                          if (announcementData['end_date'] != null)
                            _buildDetailRow(
                              icon: Icons.event_busy,
                              label: languageProvider.getTranslatedText({
                                'en': 'End Date',
                                'id': 'Tanggal Berakhir',
                              }),
                              value: _formatDate(announcementData['end_date']),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Close',
                            'id': 'Tutup',
                          }),
                          style: TextStyle(color: Colors.white),
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
    );
  }

  String _getFileUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = ApiService.baseUrl.replaceAll('/api', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$base/storage/$cleanPath';
  }

  Future<void> _openFile(String url, String fileName) async {
    try {
      if (kDebugMode) {
        print('Downloading file from: $url');
      }

      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.data!);

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: ColorUtils.error600,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _getPrimaryColor()),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Pattern #8: Material > InkWell > Container with corporateShadow
  Widget _buildAnnouncementCard(
    Map<String, dynamic> announcementData,
    int index,
  ) {
    final languageProvider = context.read<LanguageProvider>();
    final primaryColor = _getPrimaryColor();
    final isUnread =
        announcementData['is_read'] != null &&
        announcementData['is_read'] != true &&
        announcementData['is_read'] != 1 &&
        announcementData['is_read'] != '1';
    final isImportant = [
      'penting',
      'important',
    ].contains(announcementData['priority']);
    final accentColor = isImportant ? ColorUtils.warning600 : primaryColor;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAnnouncementDetail(announcementData),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: colored icon container (Pattern #8 avatar)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isImportant
                        ? Icons.campaign_rounded
                        : Icons.announcement_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),

                // Middle: title + preview + info chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        announcementData['title'] ?? 'No Title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3),
                      // Content preview
                      Text(
                        announcementData['content'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      // Info chips row
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _buildInfoTag(
                            Icons.access_time_outlined,
                            _formatDate(announcementData['created_at']),
                          ),
                          _buildInfoTag(
                            Icons.person_outline,
                            announcementData['pembuat_nama'] ?? 'Unknown',
                          ),
                          _buildInfoTag(
                            Icons.people_outline,
                            _getTargetText(announcementData, languageProvider),
                          ),
                          if (isImportant)
                            _buildInfoTag(
                              Icons.warning_amber_rounded,
                              languageProvider.getTranslatedText({
                                'en': 'Important',
                                'id': 'Penting',
                              }),
                              tagColor: ColorUtils.warning600,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),

                // Right: unread dot
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: ColorUtils.error600,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
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
                          onTap: () => Navigator.pop(context),
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
                                  'en': 'Announcements',
                                  'id': 'Pengumuman',
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
                                  'en': 'View school announcements',
                                  'id': 'Lihat pengumuman sekolah',
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

                    // Search Bar
                    Container(
                      key: _searchKey,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: ColorUtils.slate900),
                              decoration: InputDecoration(
                                hintText: languageProvider.getTranslatedText({
                                  'en': 'Search announcements...',
                                  'id': 'Cari pengumuman...',
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
                                setState(() {});
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
                              onPressed: () {
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? SkeletonListLoading(
                        itemCount: 6,
                        infoTagCount: 3,
                        baseColor: _getPrimaryColor().withValues(alpha: 0.15),
                        highlightColor: _getPrimaryColor().withValues(
                          alpha: 0.05,
                        ),
                      )
                    : _errorMessage != null
                    ? ErrorScreen(
                        errorMessage: _errorMessage!,
                        onRetry: _loadData,
                      )
                    : _filteredAnnouncement.isEmpty
                    ? EmptyState(
                        icon: Icons.announcement_outlined,
                        title: languageProvider.getTranslatedText({
                          'en': 'No Announcements',
                          'id': 'Tidak Ada Pengumuman',
                        }),
                        subtitle: languageProvider.getTranslatedText({
                          'en': _searchController.text.isNotEmpty
                              ? 'No announcements found for your search'
                              : 'There are no announcements available at the moment',
                          'id': _searchController.text.isNotEmpty
                              ? 'Tidak ada pengumuman yang sesuai dengan pencarian'
                              : 'Tidak ada pengumuman yang tersedia saat ini',
                        }),
                        buttonText: languageProvider.getTranslatedText({
                          'en': 'Refresh',
                          'id': 'Muat Ulang',
                        }),
                        onPressed: _loadData,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: _getPrimaryColor(),
                        backgroundColor: Colors.white,
                        child: ListView.builder(
                          key: _listKey,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: _filteredAnnouncement.length,
                          itemBuilder: (context, index) {
                            return Builder(
                              builder: (context) {
                                // Trigger visibility logic when built
                                _onItemVisible(_filteredAnnouncement[index]);
                                return _buildAnnouncementCard(
                                  _filteredAnnouncement[index],
                                  index,
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      // Check cache first (24h TTL)
      final tourCacheKey = 'tour_announcement_screen_$_userRole';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
          if (mounted) _showTour();
        }
        return;
      }

      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'walimurid',
        name: 'announcement_screen_tour',
      );

      // Cache the result
      await LocalCacheService.save(tourCacheKey, status);

      if (status['should_show'] == true && status['tour'] != null) {
        _tourId = status['tour']['id'];

        if (!mounted) return;
        _showTour();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking tour status: $e');
    }
  }

  void _showTour() {
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = context.read<LanguageProvider>();

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
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_announcement_screen_$_userRole', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_announcement_screen_$_userRole', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = context.read<LanguageProvider>();

    targets.add(
      TargetFocus(
        identify: "SearchBar",
        keyTarget: _searchKey,
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
                      'en': 'Search Announcements',
                      'id': 'Pencarian Pengumuman',
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
                            'Quickly find specific announcements by typing keywords here.',
                        'id':
                            'Temukan pengumuman spesifik dengan cepat dengan mengetikkan kata kunci di sini.',
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

    // Only add list tour if there are items
    if (_filteredAnnouncement.isNotEmpty) {
      targets.add(
        TargetFocus(
          identify: "AnnouncementList",
          keyTarget: _listKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 12,
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
                        'en': 'Important Updates',
                        'id': 'Pembaruan Penting',
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
                              'Tap any announcement card to read the full details and download attachments if available.',
                          'id':
                              'Ketuk kartu pengumuman mana saja untuk membaca detail lengkap dan mengunduh lampiran jika tersedia. Pengumuman yang belum dibaca akan memiliki titik merah.',
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
    }

    return targets;
  }
}

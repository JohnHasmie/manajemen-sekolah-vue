import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  AnnouncementScreenState createState() => AnnouncementScreenState();
}

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

  @override
  void dispose() {
    // Assuming _searchDebounce might be defined elsewhere if needed
    // _searchDebounce?.cancel();
    _markReadDebounce?.cancel(); // Cancel visibility debounce
    super.dispose();
  }

  void _onItemVisible(Map<String, dynamic> announcement) {
    final id = announcement['id'].toString();
    final isRead =
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
      // On error, maybe remove from _processedIds to retry?
      // For now, silent fail is safer to avoid endless retry loops.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load user role from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user');
      if (userData != null) {
        final user = json.decode(userData);
        _userRole = user['role'] ?? 'wali';
      }

      if (kDebugMode) {
        print('🔄 Memuat data pengumuman untuk role: $_userRole');
      }
      final response = await _apiService.get('/announcement/user/current');

      if (kDebugMode) {
        print('✅ Response dari API:');
        print('Type: ${response.runtimeType}');
        print('Data: $response');
      }

      // Handle response structure: {success, data, pagination}
      List<dynamic> announcementList = [];
      if (response is Map<String, dynamic> && response['data'] != null) {
        announcementList = response['data'] is List ? response['data'] : [];
      } else if (response is List) {
        // Fallback for direct list response
        announcementList = response;
      }

      setState(() {
        _announcementList = announcementList;
        _isLoading = false;
      });

      if (kDebugMode) {
        print(
          '📊 Data berhasil dimuat: ${_announcementList.length} pengumuman',
        );
      }

      // Removed: Eagerly marking all as read. Now handled by visibility check.
      // if (_announcementList.isNotEmpty) {
      //   _markAnnouncementsAsRead(_announcementList);
      // }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading announcements: $e');
      }
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.getFriendlyMessage(e);
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
      colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
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
                    if (announcementData['priority'] == 'important' ||
                        announcementData['priority'] == 'penting')
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, size: 14, color: Colors.orange),
                            SizedBox(width: 6),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Important Announcement',
                                'id': 'Pengumuman Penting',
                              }),
                              style: TextStyle(
                                color: Colors.orange,
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
                        color: Colors.grey.shade800,
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
                          color: Colors.grey.shade600,
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
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
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
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Tap to open',
                                        'id': 'Ketuk untuk membuka',
                                      }),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.download_rounded,
                                color: Colors.grey.shade400,
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
                        color: Colors.grey.shade50,
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
                child: SafeArea(
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

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        final result = await OpenFile.open(file.path);

        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open file: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(
    Map<String, dynamic> announcementData,
    int index,
  ) {
    final languageProvider = context.read<LanguageProvider>();

    return GestureDetector(
      onTap: () {
        _showAnnouncementDetail(announcementData);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAnnouncementDetail(announcementData),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, // Background putih
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Strip berwarna di pinggir kiri - menyesuaikan role
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: _getPrimaryColor(), // Warna sesuai role user
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // Background pattern effect (Indicator)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            (announcementData['is_read'] == true ||
                                announcementData['is_read'] == 1 ||
                                announcementData['is_read'] == '1')
                            ? Colors
                                  .transparent // Read: Completely hidden
                            : Colors.red.withValues(
                                alpha: 0.1,
                              ), // Unread: Red tint
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color:
                                (announcementData['is_read'] == true ||
                                    announcementData['is_read'] == 1 ||
                                    announcementData['is_read'] == '1')
                                ? Colors.transparent
                                : Colors.red, // Unread: Red Dot
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Priority badge
                  if (announcementData['priority'] == 'important' ||
                      announcementData['priority'] == 'penting')
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'IMPORTANT',
                                'id': 'PENTING',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header dengan judul
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    announcementData['title'] ?? 'No Title',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    _formatDate(announcementData['created_at']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Konten preview
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.description,
                                color: _getPrimaryColor(),
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Content',
                                      'id': 'Konten',
                                    }),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    announcementData['content'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Informasi pembuat
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.person,
                                color: _getPrimaryColor(),
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Created by',
                                      'id': 'Dibuat oleh',
                                    }),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    announcementData['pembuat_nama'] ??
                                        'Unknown',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Target informasi
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.people,
                                color: _getPrimaryColor(),
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Target Audience',
                                      'id': 'Target Pengguna',
                                    }),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    _getTargetText(
                                      announcementData,
                                      languageProvider,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header - menggunakan gradient sesuai role
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
                      ],
                    ),
                    SizedBox(height: 16),

                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: languageProvider.getTranslatedText({
                                  'en': 'Search announcements...',
                                  'id': 'Cari pengumuman...',
                                }),
                                hintStyle: TextStyle(color: Colors.grey),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey,
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
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading announcements...',
                          'id': 'Memuat pengumuman...',
                        }),
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
                        color: _getPrimaryColor(), // Warna sesuai role
                        backgroundColor: Colors.white,
                        child: ListView.builder(
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
}

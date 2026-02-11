import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/components/filter_sheet.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class PresenceParentPage extends StatefulWidget {
  final Map<String, dynamic> parent;
  final String studentId; // ID siswa yang merupakan anak dari wali murid
  final String? academicYearId;

  const PresenceParentPage({
    super.key,
    required this.parent,
    required this.studentId,
    this.academicYearId,
  });

  @override
  PresenceParentPageState createState() => PresenceParentPageState();
}

class PresenceParentPageState extends State<PresenceParentPage> {
  List<dynamic> _absensiData = [];
  Siswa? _student;
  bool _isLoading = true;
  String? _selectedMonthFilter;
  String? _selectedSemesterFilter;
  bool _hasActiveFilter = false;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _monthlySummary = {
    'hadir': 0,
    'terlambat': 0,
    'izin': 0,
    'sakit': 0,
    'alpha': 0,
  };

  // Visibility Tracking
  final Set<String> _processedIds = {}; // IDs we've already handled/queued
  final Set<String> _pendingReadIds = {}; // IDs waiting to be sent to API
  Timer? _markReadDebounce;

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
      await ApiService.markPresenceAsRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error silent auto-marking read: $e");
    }
  }

  void _onItemVisible(Map<String, dynamic> absen) {
    final id = absen['id'].toString();
    final isRead =
        absen['is_read'] == true ||
        absen['is_read'] == 1 ||
        absen['is_read'] == '1';

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
        print('📨 Auto-marking ${ids.length} visible presence as read...');
      }

      // Optimistic Update (update local list UI immediately)
      setState(() {
        for (var item in _absensiData) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await ApiService.markPresenceAsRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error auto-marking read: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load data siswa
      final userId = widget.parent['id']?.toString();
      final guardianEmail = widget.parent['email']?.toString();

      final studentData = await ApiStudentService.getStudent(
        userId: userId,
        guardianEmail: guardianEmail,
      );
      final student = studentData
          .map((s) => Siswa.fromJson(s))
          .firstWhere((s) => s.id == widget.studentId);

      // Load data absensi
      final absensiData = await ApiService.getAbsensi(
        studentId: widget.studentId,
        academicYearId: widget.academicYearId,
      );

      setState(() {
        _student = student;
        _absensiData = absensiData;
        _calculateMonthlySummary();
        _isLoading = false;
      });

      // Mark notifications as read
      ApiService.markAttendanceRead(studentId: widget.studentId);

      if (kDebugMode) {
        print(
          'Loaded ${_absensiData.length} absensi records for student ${_student?.name}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading parent presence data: $e');
      }
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateMonthlySummary() {
    // Reset summary
    _monthlySummary.updateAll((key, value) => 0);

    for (var absen in _absensiData) {
      final date = _parseLocalDate(absen['tanggal']);

      // Apply same filter logic for summary
      if (_selectedMonthFilter != null) {
        if (date.month.toString() != _selectedMonthFilter) continue;
      }

      if (_selectedSemesterFilter != null) {
        final month = date.month;
        final semester = (month >= 7) ? '1' : '2';
        if (semester != _selectedSemesterFilter) continue;
      }

      final status = _normalizeStatus(absen['status']);
      _monthlySummary[status] = (_monthlySummary[status] ?? 0) + 1;
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedMonthFilter != null ||
          _selectedSemesterFilter != null ||
          _searchController.text.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedMonthFilter = null;
      _selectedSemesterFilter = null;
      _searchController.clear();
      _hasActiveFilter = false;
    });
  }

  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        primaryColor: _getPrimaryColor(),
        config: FilterConfig(
          sections: [
            FilterSection(
              key: 'month',
              title: languageProvider.getTranslatedText({
                'en': 'Month',
                'id': 'Bulan',
              }),
              options:
                  [
                    {'en': 'January', 'id': 'Januari', 'val': '1'},
                    {'en': 'February', 'id': 'Februari', 'val': '2'},
                    {'en': 'March', 'id': 'Maret', 'val': '3'},
                    {'en': 'April', 'id': 'April', 'val': '4'},
                    {'en': 'May', 'id': 'Mei', 'val': '5'},
                    {'en': 'June', 'id': 'Juni', 'val': '6'},
                    {'en': 'July', 'id': 'Juli', 'val': '7'},
                    {'en': 'August', 'id': 'Agustus', 'val': '8'},
                    {'en': 'September', 'id': 'September', 'val': '9'},
                    {'en': 'October', 'id': 'Oktober', 'val': '10'},
                    {'en': 'November', 'id': 'November', 'val': '11'},
                    {'en': 'December', 'id': 'Desember', 'val': '12'},
                  ].map((m) {
                    return FilterOption(
                      label: languageProvider.getTranslatedText({
                        'en': m['en']!,
                        'id': m['id']!,
                      }),
                      value: m['val']!,
                    );
                  }).toList(),
              multiSelect: false,
            ),
            FilterSection(
              key: 'semester',
              title: languageProvider.getTranslatedText({
                'en': 'Semester',
                'id': 'Semester',
              }),
              options:
                  [
                    {'en': 'Semester 1', 'id': 'Semester 1', 'val': '1'},
                    {'en': 'Semester 2', 'id': 'Semester 2', 'val': '2'},
                  ].map((s) {
                    return FilterOption(
                      label: languageProvider.getTranslatedText({
                        'en': s['en']!,
                        'id': s['id']!,
                      }),
                      value: s['val']!,
                    );
                  }).toList(),
              multiSelect: false,
            ),
          ],
        ),
        initialFilters: {
          'month': _selectedMonthFilter,
          'semester': _selectedSemesterFilter,
        },
        onApplyFilters: (filters) {
          setState(() {
            _selectedMonthFilter = filters['month'];
            _selectedSemesterFilter = filters['semester'];
            _checkActiveFilter();
          });
        },
      ),
    );
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedMonthFilter != null) {
      final months = [
        {'en': 'January', 'id': 'Januari', 'val': '1'},
        {'en': 'February', 'id': 'Februari', 'val': '2'},
        {'en': 'March', 'id': 'Maret', 'val': '3'},
        {'en': 'April', 'id': 'April', 'val': '4'},
        {'en': 'May', 'id': 'Mei', 'val': '5'},
        {'en': 'June', 'id': 'Juni', 'val': '6'},
        {'en': 'July', 'id': 'Juli', 'val': '7'},
        {'en': 'August', 'id': 'Agustus', 'val': '8'},
        {'en': 'September', 'id': 'September', 'val': '9'},
        {'en': 'October', 'id': 'Oktober', 'val': '10'},
        {'en': 'November', 'id': 'November', 'val': '11'},
        {'en': 'December', 'id': 'Desember', 'val': '12'},
      ];
      final month = months.firstWhere((m) => m['val'] == _selectedMonthFilter);
      final label = languageProvider.getTranslatedText({
        'en': month['en']!,
        'id': month['id']!,
      });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Month', 'id': 'Bulan'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedMonthFilter = null;
            _checkActiveFilter();
          });
        },
      });
    }

    if (_selectedSemesterFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Semester', 'id': 'Semester'})}: $_selectedSemesterFilter',
        'onRemove': () {
          setState(() {
            _selectedSemesterFilter = null;
            _checkActiveFilter();
          });
        },
      });
    }

    if (_searchController.text.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Search', 'id': 'Cari'})}: ${_searchController.text}',
        'onRemove': () {
          setState(() {
            _searchController.clear();
            _checkActiveFilter();
          });
        },
      });
    }

    return filterChips;
  }

  Widget _buildMonthlySummary() {
    final totalDays = _monthlySummary.values.reduce((a, b) => a + b);
    final presentaseAbsensi = totalDays > 0
        ? ((_monthlySummary['hadir']! + _monthlySummary['terlambat']!) /
                  totalDays *
                  100)
              .round()
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header dengan bulan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _hasActiveFilter
                    ? languageProvider.getTranslatedText({
                        'en': 'Filtered Recap',
                        'id': 'Rekap Terfilter',
                      })
                    : languageProvider.getTranslatedText({
                        'en': 'Yearly Recap',
                        'id': 'Rekap Tahunan',
                      }),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Persentase kehadiran
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$presentaseAbsensi%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.attendanceRate.tr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Detail status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                AppLocalizations.present.tr,
                _monthlySummary['hadir']!,
                Colors.green,
              ),
              _buildStatItem(
                AppLocalizations.late.tr,
                _monthlySummary['terlambat']!,
                Colors.orange,
              ),
              _buildStatItem(
                AppLocalizations.permission.tr,
                _monthlySummary['izin']!,
                Colors.blue,
              ),
              _buildStatItem(
                AppLocalizations.sick.tr,
                _monthlySummary['sakit']!,
                Colors.purple,
              ),
              _buildStatItem(
                AppLocalizations.alpha.tr,
                _monthlySummary['alpha']!,
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAbsensiList() {
    final filteredAbsensi =
        _absensiData.where((absen) {
          final date = _parseLocalDate(absen['tanggal']);

          // Month Filter
          if (_selectedMonthFilter != null) {
            if (date.month.toString() != _selectedMonthFilter) {
              return false;
            }
          }

          // Semester Filter (1: July-Dec, 2: Jan-June)
          if (_selectedSemesterFilter != null) {
            final month = date.month;
            final semester = (month >= 7) ? '1' : '2';
            if (semester != _selectedSemesterFilter) {
              return false;
            }
          }

          // Search Filter
          if (_searchController.text.isNotEmpty) {
            final query = _searchController.text.toLowerCase();
            final subject = (absen['mata_pelajaran_nama'] ?? '')
                .toString()
                .toLowerCase();
            final status = (absen['status'] ?? '').toString().toLowerCase();
            if (!subject.contains(query) && !status.contains(query)) {
              return false;
            }
          }

          return true;
        }).toList()..sort((a, b) {
          final dateA = a['tanggal']?.toString() ?? '';
          final dateB = b['tanggal']?.toString() ?? '';
          return dateB.compareTo(dateA);
        });

    if (filteredAbsensi.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.noPresenceData.tr,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            if (_hasActiveFilter) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'No attendance records found for this year',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredAbsensi.length,
      itemBuilder: (context, index) {
        final absen = filteredAbsensi[index];
        return Builder(
          builder: (context) {
            _onItemVisible(absen);
            return _buildAbsensiItem(absen);
          },
        );
      },
    );
  }

  Widget _buildAbsensiItem(Map<String, dynamic> absen) {
    final status = _normalizeStatus(absen['status']);
    final date = _parseLocalDate(absen['tanggal']);
    final subjectName =
        absen['mata_pelajaran_nama'] ?? AppLocalizations.subject.tr;
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getTranslatedStatus(status);
    final String day = DateFormat(
      'EEEE',
      context.watch<LanguageProvider>().currentLanguage == 'id'
          ? 'id_ID'
          : 'en_US',
    ).format(date);

    final isRead =
        absen['is_read'] == true ||
        absen['is_read'] == 1 ||
        absen['is_read'] == '1';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: isRead ? Colors.white : Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: isRead ? 0.3 : 0.4),
                  blurRadius: 5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Strip berwarna di pinggir kiri
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor(),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),

                // Background pattern effect
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Status badge positioned
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Indikator unread (red dot)
                if (!isRead)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Tanggal
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _getPrimaryColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('dd').format(date),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _getPrimaryColor(),
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MMM',
                                context
                                            .watch<LanguageProvider>()
                                            .currentLanguage ==
                                        'id'
                                    ? 'id_ID'
                                    : 'en_US',
                              ).format(date),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getPrimaryColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Detail absensi
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subjectName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if ((absen['lesson_hour_name'] != null &&
                                      absen['lesson_hour_name']
                                          .toString()
                                          .isNotEmpty) ||
                                  (absen['jam_pelajaran_nama'] != null &&
                                      absen['jam_pelajaran_nama']
                                          .toString()
                                          .isNotEmpty) ||
                                  (absen['lesson_hour'] != null &&
                                      absen['lesson_hour']['name'] !=
                                          null)) ...[
                                const SizedBox(height: 2),
                                Text(
                                  (absen['lesson_hour_name'] ??
                                          absen['jam_pelajaran_nama'] ??
                                          (absen['lesson_hour'] != null
                                              ? absen['lesson_hour']['name']
                                              : ''))
                                      .toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'dd MMMM yyyy',
                                  context
                                              .watch<LanguageProvider>()
                                              .currentLanguage ==
                                          'id'
                                      ? 'id_ID'
                                      : 'en_US',
                                ).format(date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'izin':
        return Colors.blue;
      case 'sakit':
        return Colors.orange;
      case 'alpha':
        return Colors.red;
      case 'terlambat':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  String _getTranslatedStatus(String? status) {
    if (status == null) return '-';
    // Normalize status just in case
    String s = status.trim();
    if (s.toLowerCase() == 'hadir') return AppLocalizations.present.tr;
    if (s.toLowerCase() == 'telat' || s.toLowerCase() == 'terlambat')
      return AppLocalizations.late.tr;
    if (s.toLowerCase() == 'izin') return AppLocalizations.permission.tr;
    if (s.toLowerCase() == 'sakit') return AppLocalizations.sick.tr;
    if (s.toLowerCase() == 'alpha') return AppLocalizations.alpha.tr;
    return status;
  }

  String _normalizeStatus(dynamic rawStatus) {
    String status = (rawStatus ?? 'alpha').toString().toLowerCase();

    // Map English/Mixed to standard keys
    if (status == 'present') return 'hadir';
    if (status == 'permission') return 'izin';
    if (status == 'excused') return 'izin'; // excused = izin
    if (status == 'sick') return 'sakit';
    if (status == 'late') return 'terlambat';
    if (status == 'absent') return 'alpha';

    // Map capitalized Indonesian to lowercase
    if (status == 'hadir') return 'hadir';
    if (status == 'izin') return 'izin';
    if (status == 'sakit') return 'sakit';
    if (status == 'terlambat') return 'terlambat';
    if (status == 'alpha') return 'alpha';
    if (status == 'alpa') return 'alpha';

    // Default fallback if it matches one of our keys
    if (_monthlySummary.containsKey(status)) return status;

    return 'alpha'; // Default to alpha for unknown status (safer than hadir)
  }

  // Helper function to parse date string as local date (not UTC)
  DateTime _parseLocalDate(dynamic dateValue) {
    // Gunakan AppDateUtils untuk parsing yang konsisten dan benar
    return AppDateUtils.parseApiDate(dateValue) ?? DateTime.now();
  }

  Color _getPrimaryColor() {
    return Color(0xFF9333EA); // Warna purple untuk wali murid
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.7)],
    );
  }

  Widget _buildHeader() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              Text(
                AppLocalizations.childPresence.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 48), // Spacer to balance back button
            ],
          ),
          const SizedBox(height: 24),

          // Search and Filter Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _checkActiveFilter();
                      _calculateMonthlySummary();
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search subject or status...',
                        'id': 'Cari mapel atau status...',
                      }),
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _showFilterSheet,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: _hasActiveFilter
                        ? Colors.white
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.filter_list,
                    color: _hasActiveFilter ? _getPrimaryColor() : Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // Filter Chips
          if (_hasActiveFilter) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._buildFilterChips(languageProvider).map((chip) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          chip['label'],
                          style: TextStyle(
                            color: _getPrimaryColor(),
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        onDeleted: chip['onRemove'],
                        deleteIcon: Icon(
                          Icons.close,
                          size: 14,
                          color: _getPrimaryColor(),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }),
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Clear All',
                        'id': 'Hapus Semua',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Memuat data absensi...'),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info siswa
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.blue[700],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _student?.name ??
                                        AppLocalizations.studentName.tr,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'NIS: ${_student?.nis ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Kelas: ${_student?.className ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Summary bulanan
                      _buildMonthlySummary(),

                      // Daftar absensi
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Riwayat Absensi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Expanded(child: _buildAbsensiList()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

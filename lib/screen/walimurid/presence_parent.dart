import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  DateTime _selectedMonth = DateTime.now();
  final Map<String, int> _monthlySummary = {
    'hadir': 0,
    'terlambat': 0,
    'izin': 0,
    'sakit': 0,
    'alpha': 0,
  };

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

      // Find the most recent month with data
      DateTime? latestMonth;
      if (absensiData.isNotEmpty) {
        // Parse all dates and find the most recent one
        for (var absen in absensiData) {
          final absenDate = _parseLocalDate(absen['tanggal']);
          if (latestMonth == null || absenDate.isAfter(latestMonth)) {
            latestMonth = absenDate;
          }
        }

        // Set selected month to the month of the most recent attendance record
        if (latestMonth != null) {
          _selectedMonth = DateTime(latestMonth.year, latestMonth.month, 1);
          if (kDebugMode) {
            print(
              '🎯 Auto-selected month with latest data: ${_selectedMonth.month}/${_selectedMonth.year}',
            );
          }
        }
      }

      setState(() {
        _student = student;
        _absensiData = absensiData;
        _calculateMonthlySummary();
        _isLoading = false;
      });

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

    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    if (kDebugMode) {
      print(
        '📅 Selected month: ${_selectedMonth.month}/${_selectedMonth.year}',
      );
      print('📅 Month range: $monthStart to $monthEnd');
      print('📊 Total absensi records: ${_absensiData.length}');
    }

    int matchCount = 0;
    for (var absen in _absensiData) {
      final absenDate = _parseLocalDate(absen['tanggal']);
      final matches =
          absenDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          absenDate.isBefore(monthEnd.add(const Duration(days: 1)));

      if (kDebugMode) {
        print(
          '  📌 Record date: ${absen['tanggal']} -> parsed: $absenDate -> matches: $matches',
        );
      }

      if (matches) {
        matchCount++;
        final status = _normalizeStatus(absen['status']);
        _monthlySummary[status] = (_monthlySummary[status] ?? 0) + 1;
      }
    }
    if (kDebugMode) {
      print('✅ Records matching current month: $matchCount');
      print('📈 Summary: $_monthlySummary');
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
        _calculateMonthlySummary();
      });
    }
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
                AppLocalizations.monthlyRecap.tr,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => _selectMonth(context),
                child: Text(
                  DateFormat(
                    'MMMM yyyy',
                    context.watch<LanguageProvider>().currentLanguage == 'id'
                        ? 'id_ID'
                        : 'en_US',
                  ).format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
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
    final monthAbsensi =
        _absensiData.where((absen) {
          final absenDate = _parseLocalDate(absen['tanggal']);
          final monthStart = DateTime(
            _selectedMonth.year,
            _selectedMonth.month,
            1,
          );
          final monthEnd = DateTime(
            _selectedMonth.year,
            _selectedMonth.month + 1,
            0,
          );
          return absenDate.isAfter(
                monthStart.subtract(const Duration(days: 1)),
              ) &&
              absenDate.isBefore(monthEnd.add(const Duration(days: 1)));
        }).toList()..sort((a, b) {
          final dateA = a['tanggal']?.toString() ?? '';
          final dateB = b['tanggal']?.toString() ?? '';
          return dateB.compareTo(dateA);
        });

    if (monthAbsensi.isEmpty) {
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
            const SizedBox(height: 8),
            Text(
              '${AppLocalizations.forMonth.tr} ${DateFormat('MMMM yyyy', context.watch<LanguageProvider>().currentLanguage == 'id' ? 'id_ID' : 'en_US').format(_selectedMonth)}',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: monthAbsensi.length,
      itemBuilder: (context, index) {
        final absen = monthAbsensi[index];
        return _buildAbsensiItem(absen);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
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
    return Container(
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
            color: _getPrimaryColor().withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.childPresence.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text(
                          _student?.name ?? AppLocalizations.studentName.tr,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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

// parent_class_activity.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_class_activity_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentClassActivityScreen extends StatefulWidget {
  final String? academicYearId;

  const ParentClassActivityScreen({super.key, this.academicYearId});

  @override
  ParentClassActivityScreenState createState() =>
      ParentClassActivityScreenState();
}

class ParentClassActivityScreenState extends State<ParentClassActivityScreen> {
  List<dynamic> _activityList = [];
  List<dynamic> _studentList = [];
  String? _selectedStudentId;
  String _parentName = '';
  bool _isLoading = true;

  final Map<String, Color> _dayColorMap = {
    'Senin': Color(0xFF6366F1),
    'Selasa': Color(0xFF10B981),
    'Rabu': Color(0xFFF59E0B),
    'Kamis': Color(0xFFEF4444),
    'Jumat': Color(0xFF8B5CF6),
    'Sabtu': Color(0xFF06B6D4),
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('user') ?? '{}');

      setState(() {
        _parentName =
            userData['name']?.toString() ?? 'Wali Murid'; // Fix: Use 'name'
      });

      await _loadStudentsForParent();
    } catch (e) {
      setState(() => _isLoading = false);
      if (kDebugMode) {
        print('Error load user data: $e');
      }
    }
  }

  Future<void> _loadStudentsForParent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final userId = userData['id']?.toString() ?? '';
      final guardianEmail = userData['email']?.toString();

      // Dapatkan siswa yang difilter server-side berdasarkan userId parent
      final allStudents = await ApiStudentService.getStudent(
        academicYearId: widget.academicYearId,
        userId: userId, // Filter server-side
        guardianEmail: guardianEmail,
      );

      // Filter siswa berdasarkan berbagai kemungkinan relasi
      // Filter siswa berdasarkan berbagai kemungkinan relasi
      final filteredStudents = allStudents.where((student) {
        return student['guardian_email'] == userData['email'] ||
            student['guardian_name'] ==
                userData['name'] || // Fix: userData['name']
            student['user_id'].toString() ==
                userId || // Match user_id (Student.user_id)
            student['parent_id'].toString() == userId || // Legacy check
            student['wali_id'].toString() == userId || // Legacy check
            (userData['student_id'] != null &&
                student['id'] == userData['student_id']) ||
            (userData['siswa_id'] != null &&
                student['id'] == userData['siswa_id']);
      }).toList();

      if (kDebugMode) {
        print('DEBUG: User Data: $userData');
      }

      setState(() {
        _studentList = filteredStudents;
      });

      // Jika hanya ada 1 siswa, langsung pilih dan load aktivitasnya
      if (_studentList.isNotEmpty) {
        if (_studentList.length == 1) {
          _selectedStudentId = _studentList[0]['id'];
          await _loadActivities();
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (kDebugMode) {
        print('Error load students for parent: $e');
      }
    }
  }

  Future<void> _loadActivities() async {
    if (_selectedStudentId == null) return;

    try {
      setState(() => _isLoading = true);

      final selectedStudent = _studentList.firstWhere(
        (s) => s['id'] == _selectedStudentId,
        orElse: () => {},
      );

      final classId =
          selectedStudent['class_id'] ?? selectedStudent['class']?['id'];

      if (selectedStudent.isNotEmpty && classId != null) {
        final activities = await ApiClassActivityService.getKegiatanByKelas(
          classId,
          siswaId: _selectedStudentId,
          academicYearId: widget.academicYearId,
        );

        setState(() {
          _activityList = activities;
          _isLoading = false;
        });
      } else {
        setState(() {
          _activityList = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (kDebugMode) {
        print('Error load activities: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat aktivitas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStudentSelector() {
    if (_studentList.isEmpty) {
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tidak ada data siswa/anak yang terhubung dengan akun ini',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Pilih Anak:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                value: _selectedStudentId,
                isExpanded: true,
                underline: SizedBox(), // Hapus garis bawah default
                items: _studentList.map((student) {
                  return DropdownMenuItem<String>(
                    value: student['id'],
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            student['name'] ?? 'Nama tidak tersedia',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Kelas: ${student['kelas_nama'] ?? student['class']?['name'] ?? '-'} • NIS: ${student['student_number'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStudentId = value;
                  });
                  _loadActivities();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActivityDetail(Map<String, dynamic> activity) {
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
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activity['jenis'] == 'tugas'
                            ? Icons.assignment
                            : Icons.menu_book,
                        size: 30,
                        color: _getPrimaryColor(),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      activity['title'] ??
                          activity['judul'] ??
                          'Judul Kegiatan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${activity['subject_name'] ?? activity['mata_pelajaran_nama'] ?? '-'} • ${activity['class_name'] ?? activity['kelas_nama'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
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
                    _buildDetailItem(
                      icon: Icons.person,
                      label: 'Guru Pengajar',
                      value:
                          activity['teacher_name'] ??
                          activity['guru_nama'] ??
                          'Tidak Diketahui',
                    ),
                    _buildDetailItem(
                      icon: Icons.calendar_today,
                      label: 'Hari',
                      value: activity['day'] ?? activity['hari'] ?? '-',
                    ),
                    _buildDetailItem(
                      icon: Icons.date_range,
                      label: 'Tanggal',
                      value: _formatDate(
                        activity['date'] ?? activity['tanggal'],
                      ),
                    ),
                    if (activity['jenis'] == 'tugas')
                      _buildDetailItem(
                        icon: Icons.access_time,
                        label: 'Batas Waktu',
                        value: _formatDate(
                          activity['deadline'] ?? activity['batas_waktu'],
                        ),
                      ),

                    if (activity['deskripsi'] != null &&
                        activity['deskripsi'].toString().isNotEmpty &&
                        activity['deskripsi'] != 'null') ...[
                      SizedBox(height: 16),
                      Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          activity['deskripsi'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],

                    if (activity['judul_bab'] != null ||
                        activity['judul_sub_bab'] != null) ...[
                      SizedBox(height: 16),
                      Text(
                        'Informasi Bab',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (activity['judul_bab'] != null)
                        _buildDetailItem(
                          icon: Icons.menu_book,
                          label: 'Bab',
                          value: activity['judul_bab'],
                        ),
                      if (activity['judul_sub_bab'] != null)
                        _buildDetailItem(
                          icon: Icons.bookmark,
                          label: 'Sub Bab (Utama)',
                          value: activity['judul_sub_bab'],
                        ),
                      if (activity['additional_material'] != null &&
                          activity['additional_material'] is List &&
                          (activity['additional_material'] as List)
                              .isNotEmpty) ...[
                        SizedBox(height: 8),
                        ...(activity['additional_material'] as List)
                            .map<Widget>((item) {
                              return _buildDetailItem(
                                icon: Icons.bookmark_add,
                                label: 'Sub Bab (Tambahan)',
                                value: item['sub_chapter_title'] ?? 'Unknown',
                              );
                            }),
                      ],
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPrimaryColor(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Tutup', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getPrimaryColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _getPrimaryColor()),
          ),
          SizedBox(width: 12),
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
      ),
    );
  }

  Widget _buildActivityList() {
    if (_selectedStudentId == null) {
      return _buildEmptyState(
        'Pilih anak terlebih dahulu untuk melihat aktivitas',
      );
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_activityList.isEmpty) {
      return _buildEmptyState('Belum ada aktivitas untuk anak ini');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _activityList.length,
      itemBuilder: (context, index) {
        final activity = _activityList[index];
        final day =
            activity['day']?.toString() ??
            activity['hari']?.toString() ??
            'Unknown';
        final cardColor = _getDayColor(day);
        final isAssignment = activity['jenis'] == 'tugas';
        final isSpecificTarget = activity['target'] == 'khusus';
        final isForThisStudent = activity['untuk_siswa_ini'] == true;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showActivityDetail(activity),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 5,
                      offset: Offset(0, 4),
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
                          borderRadius: BorderRadius.only(
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

                    // Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isAssignment ? Colors.orange : Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAssignment ? 'TUGAS' : 'MATERI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isSpecificTarget && isForThisStudent) ...[
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'KHUSUS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Activity Header
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getPrimaryColor(),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isAssignment
                                      ? Icons.assignment
                                      : Icons.menu_book,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity['judul'] ?? 'Judul Kegiatan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${activity['mata_pelajaran_nama']} • ${activity['kelas_nama']}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${activity['hari']} • ${_formatDate(activity['tanggal'])}',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 8),

                          // Activity Details
                          if (activity['deskripsi'] != null &&
                              activity['deskripsi'].isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                activity['deskripsi'],
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                          if (activity['judul_bab'] != null) ...[
                            SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${activity['judul_bab']}${activity['judul_sub_bab'] != null ? ' • ${activity['judul_sub_bab']}' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (activity['additional_material'] != null &&
                                      activity['additional_material'] is List &&
                                      (activity['additional_material'] as List)
                                          .isNotEmpty) ...[
                                    SizedBox(height: 4),
                                    ...(activity['additional_material'] as List)
                                        .map<Widget>((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.add_circle_outline,
                                                  size: 14,
                                                  color: Colors.blue,
                                                ),
                                                SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    item['sub_chapter_title'] ??
                                                        'Unknown',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSpecificTarget
                                      ? Colors.purple.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSpecificTarget
                                        ? Colors.purple
                                        : Colors.green,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSpecificTarget
                                          ? Icons.person
                                          : Icons.group,
                                      size: 12,
                                      color: isSpecificTarget
                                          ? Colors.purple
                                          : Colors.green,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      isSpecificTarget
                                          ? 'Khusus Siswa'
                                          : 'Semua Siswa',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSpecificTarget
                                            ? Colors.purple
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Spacer(),
                              if (isAssignment &&
                                  activity['batas_waktu'] != null)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.red.shade300,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    'Batas: ${_formatDate(activity['batas_waktu'])}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
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
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 80, color: Colors.grey.shade300),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
          ),
          SizedBox(height: 16),
          Text(
            'Memuat aktivitas...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  Color _getDayColor(String day) {
    return _dayColorMap[day] ?? Color(0xFF6B7280);
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
                      'Aktivitas Kelas Anak',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pantau aktivitas anak Anda',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadActivities,
                tooltip: 'Refresh',
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.family_restroom, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _parentName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${_studentList.length} Anak',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),

          // Student Selector
          _buildStudentSelector(),

          // Activities List
          Expanded(child: _buildActivityList()),
        ],
      ),
    );
  }
}

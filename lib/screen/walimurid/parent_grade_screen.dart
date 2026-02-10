import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentGradeScreen extends StatefulWidget {
  final String? academicYearId;

  const ParentGradeScreen({super.key, this.academicYearId});

  @override
  ParentGradeScreenState createState() => ParentGradeScreenState();
}

class ParentGradeScreenState extends State<ParentGradeScreen> {
  List<dynamic> _gradeList = [];
  List<dynamic> _studentList = [];
  String? _selectedStudentId;
  String _parentName = '';
  bool _isLoading = true;

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
      await ApiService.markGradeAsRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error silent auto-marking read: $e");
    }
  }

  void _onItemVisible(Map<String, dynamic> grade) {
    final id = grade['id'].toString();
    final isRead =
        grade['is_read'] == true ||
        grade['is_read'] == 1 ||
        grade['is_read'] == '1';

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
        print('📨 Auto-marking ${ids.length} visible grades as read...');
      }

      // Optimistic Update (update local list UI immediately)
      setState(() {
        for (var item in _gradeList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await ApiService.markGradeAsRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error auto-marking read: $e");
    }
  }

  final Map<String, Color> _gradeTypeColorMap = {
    'tugas': Color(0xFF6366F1),
    'uh': Color(0xFF10B981),
    'uts': Color(0xFFF59E0B),
    'uas': Color(0xFFEF4444),
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
        _parentName = userData['name']?.toString() ?? 'Wali Murid';
      });

      await _loadStudentsForParent();
    } catch (e) {
      if (kDebugMode) {
        print('Error load user data: $e');
      }
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
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
        userId: userId,
        guardianEmail: guardianEmail,
      );

      // Filter siswa berdasarkan berbagai kemungkinan relasi (sama seperti parent_class_activity)
      final filteredStudents = allStudents.where((student) {
        return student['guardian_email'] == userData['email'] ||
            student['guardian_name'] == userData['name'] ||
            student['user_id'].toString() == userId ||
            student['parent_id'].toString() == userId ||
            student['wali_id'].toString() == userId ||
            (userData['student_id'] != null &&
                student['id'] == userData['student_id']) ||
            (userData['siswa_id'] != null &&
                student['id'] == userData['siswa_id']);
      }).toList();

      setState(() {
        _studentList = filteredStudents;
      });

      // Jika hanya ada 1 siswa, langsung pilih dan load nilai
      if (_studentList.isNotEmpty) {
        if (_studentList.length == 1) {
          _selectedStudentId = _studentList[0]['id'];
          await _loadGrades();
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error load students for parent grade: $e');
      }
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _loadGrades() async {
    if (_selectedStudentId == null) return;

    try {
      setState(() => _isLoading = true);

      final grades = await ApiService.getNilai(
        siswaId: _selectedStudentId,
        academicYearId: widget.academicYearId,
      );

      setState(() {
        _gradeList = grades;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error load grades: $e');
      }
      setState(() => _isLoading = false);
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
                AppLocalizations.noChildrenLinked.tr,
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
              AppLocalizations.selectChild.tr,
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
                            student['name'] ??
                                AppLocalizations.nameNotAvailable.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${AppLocalizations.classString.tr}: ${student['kelas_nama'] ?? student['class']?['name'] ?? '-'} • NIS: ${student['student_number'] ?? '-'}',
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
                  _loadGrades();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGradeDetail(Map<String, dynamic> grade) {
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
                      child: Center(
                        child: Text(
                          grade['score']?.toString() ?? '0',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getPrimaryColor(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      grade['subject_name'] ??
                          grade['mata_pelajaran'] ??
                          AppLocalizations.subject.tr,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    if (grade['title'] != null &&
                        grade['title'].toString().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          grade['title'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.95),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(height: 4),
                    Text(
                      grade['type']?.toString().toUpperCase() ??
                          AppLocalizations.grades.tr.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
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
                      label: AppLocalizations.teacher.tr,
                      value:
                          grade['teacher_name'] ?? AppLocalizations.unknown.tr,
                    ),
                    _buildDetailItem(
                      icon: Icons.calendar_today,
                      label: AppLocalizations.assessmentDate.tr,
                      value: _formatDate(grade['date']),
                    ),
                    if (grade['notes'] != null &&
                        grade['notes'].toString().isNotEmpty &&
                        grade['notes'] != 'null') ...[
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.teacherNotes.tr,
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
                          grade['notes'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
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
                    child: Text(
                      AppLocalizations.close.tr,
                      style: TextStyle(color: Colors.white),
                    ),
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

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = AppDateUtils.parseApiDate(date);
      if (dt == null) return date.toString();
      // Use intl package if available, or simple string formatting
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(_getPrimaryColor()),
      ),
    );
  }

  Widget _buildGradeList() {
    if (_selectedStudentId == null) {
      return _buildEmptyState(AppLocalizations.selectChildToViewGrades.tr);
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_gradeList.isEmpty) {
      return _buildEmptyState(AppLocalizations.noGradesData.tr);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _gradeList.length,
      itemBuilder: (context, index) {
        final grade = _gradeList[index];
        final type = grade['type']?.toString().toLowerCase() ?? 'tugas';
        final typeColor = _gradeTypeColorMap[type] ?? Colors.blue;
        final score = double.tryParse(grade['score']?.toString() ?? '0') ?? 0;
        final assessmentTitle = grade['title']?.toString();
        final isRead =
            grade['is_read'] == true ||
            grade['is_read'] == 1 ||
            grade['is_read'] == '1';

        return Builder(
          builder: (context) {
            _onItemVisible(grade);
            return Container(
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showGradeDetail(grade),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.white
                          : Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(
                            alpha: isRead ? 0.3 : 0.4,
                          ),
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
                              color: typeColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                          ),
                        ),

                        // Badge Score
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            width: 54, // Diperlebar agar muat 100.0
                            height: 48,
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: typeColor.withOpacity(0.3),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                score.toStringAsFixed(0) == score.toString()
                                    ? score.toStringAsFixed(0)
                                    : score.toString(),
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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
                                        color: Colors.red.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            16,
                            70,
                            16,
                          ), // Right padding ditambah
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  type.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                grade['subject_name'] ??
                                    grade['mata_pelajaran'] ??
                                    AppLocalizations.subject.tr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (assessmentTitle != null &&
                                  assessmentTitle.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Text(
                                  assessmentTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _formatDate(grade['date']),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
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
      },
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
                      AppLocalizations.childAcademicGrades.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppLocalizations.monitorChildGrades.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
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
      backgroundColor: Color(0xFFF8F9FA), // Slate 50 equivalent
      body: Column(
        children: [
          _buildHeader(),
          _buildStudentSelector(),
          Expanded(child: _buildGradeList()),
        ],
      ),
    );
  }
}

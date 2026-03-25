// Teacher detail view screen - shows full profile info for a single teacher.
//
// Like `pages/admin/teachers/{id}.vue` - a detail/show page that displays
// all teacher information (personal data, subjects taught, classes, schedule).
//
// In Laravel terms, this calls `GET /api/teachers/{id}` (TeacherController@show).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Teacher detail screen - displays full profile for a single teacher.
///
/// Takes a [teacher] map (basic data) and fetches full details from API.
/// Like a Vue route page with `props: true` receiving the teacher object.
class TeacherDetailScreen extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  TeacherDetailScreenState createState() => TeacherDetailScreenState();
}

/// Mutable state for [TeacherDetailScreen].
///
/// Key state (like Vue `data()`):
/// - [_teacherDetail] - full teacher data from API (null until loaded)
/// - [_subjects] - all subjects for reference/mapping
/// - [_isLoading] / [_errorMessage] - loading and error states
class TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final ApiTeacherService apiTeacherService = ApiTeacherService();
  final ApiClassService apiClassService = getIt<ApiClassService>();
  final ApiSubjectService apiSubjectService = ApiSubjectService();

  Map<String, dynamic>? _teacherDetail;
  List<dynamic> _subjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  /// Like Vue's `mounted()` - fetches full teacher details from the API.
  @override
  void initState() {
    super.initState();
    _loadTeacherDetail();
  }

  /// Fetches full teacher details by ID, including subjects and classes.
  /// Like calling `GET /api/teachers/{id}?academic_year_id=...` in Vue.
  Future<void> _loadTeacherDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      String? academicYearId;
      if (mounted) {
        try {
          final academicYearProvider = Provider.of<AcademicYearProvider>(
            context,
            listen: false,
          );
          academicYearId = academicYearProvider.selectedAcademicYear?['id']
              ?.toString();
        } catch (e) {
          // provider might not be available or other error
        }
      }

      // Backend already returns everything including subjects and classes
      final teacherDetail = await apiTeacherService.getTeacherById(
        widget.teacher['id'],
        academicYearId: academicYearId,
      );

      // Fetch all classes and subjects for mapping
      final subjects = await apiSubjectService.getSubject();

      setState(() {
        _teacherDetail = teacherDetail;
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('teacher', e);
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.getFriendlyMessage(e);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat detail guru: ${ErrorUtils.getFriendlyMessage(e)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(
    String label,
    dynamic value, {
    bool isMultiline = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              _getIconForLabel(label),
              size: 18,
              color: ColorUtils.corporateBlue600,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 3),
                if (value is List<String>)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: value.map((item) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ColorUtils.corporateBlue600.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: ColorUtils.corporateBlue600.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.corporateBlue600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text(
                    value.toString().isNotEmpty ? value.toString() : 'Tidak ada',
                    style: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.slate800,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: isMultiline ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: ColorUtils.corporateBlue600, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.corporateBlue600),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Nama':
        return Icons.person;
      case 'NIP':
        return Icons.badge;
      case 'Email':
        return Icons.email;
      case 'Kelas':
        return Icons.school;
      case 'Mata Pelajaran':
        return Icons.menu_book;
      case 'Role':
        return Icons.work;
      case 'Status Wali Kelas':
        return Icons.groups;
      case 'ID':
        return Icons.fingerprint;
      case 'Tanggal Dibuat':
        return Icons.calendar_today;
      case 'Terakhir Diupdate':
        return Icons.update;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = _teacherDetail ?? widget.teacher;

    // Helper to get names from direct objects or IDs
    List<String> getNames(
      dynamic objects,
      dynamic ids,
      List<dynamic> sourceList,
    ) {
      if (objects != null && objects is List && objects.isNotEmpty) {
        return objects
            .map((item) => item['name']?.toString() ?? 'Unknown')
            .toList();
      }
      if (ids == null) return [];
      List<String> idList = [];
      if (ids is List) {
        idList = ids.map((e) => e.toString()).toList();
      } else if (ids is String && ids.isNotEmpty) {
        idList = ids.split(',').map((e) => e.trim()).toList();
      }
      return idList.map((id) {
        final item = sourceList.firstWhere(
          (element) => element['id'].toString() == id,
          orElse: () => {'name': 'Unknown'},
        );
        return item['name']?.toString() ?? 'Unknown';
      }).toList();
    }

    // Use widget.teacher as fallback for IDs if _teacherDetail doesn't have them
    final effectiveTeacher = _teacherDetail ?? widget.teacher;

    final displaySubjectNames = getNames(
      effectiveTeacher['subjects'],
      effectiveTeacher['subject_ids'] ?? widget.teacher['subject_ids'],
      _subjects,
    );

    // 1. Get Teaching Classes from Schedules
    List<String> teachingClassNames = [];
    if (effectiveTeacher['teaching_schedules'] != null &&
        effectiveTeacher['teaching_schedules'] is List) {
      final schedules = effectiveTeacher['teaching_schedules'] as List;
      final uniqueClassNames = <String>{};
      for (var schedule in schedules) {
        if (schedule['class'] != null && schedule['class']['name'] != null) {
          uniqueClassNames.add(schedule['class']['name'].toString());
        }
      }
      teachingClassNames = uniqueClassNames.toList()..sort();
    } else {
      // Fallback to legacy 'classes' if schedules empty (though user asked for schedules)
      // actually user explicitly asked "pada kelas itu mengambil list kelasnya dari table teaching_schedules"
      // so we prioritizing schedules.
      // If schedules specific logic returns empty, valid result is empty.
    }

    // Determine Homeroom Status
    String homeroomStatus = '-';
    // 1. Check homeroomClasses (plural) from new backend
    if (effectiveTeacher['homeroom_classes'] != null &&
        effectiveTeacher['homeroom_classes'] is List &&
        (effectiveTeacher['homeroom_classes'] as List).isNotEmpty) {
      final classes = effectiveTeacher['homeroom_classes'] as List;
      final names = classes
          .where((c) => c['name'] != null)
          .map((c) => c['name'].toString())
          .toList();

      if (names.isNotEmpty) {
        homeroomStatus = 'Ya, Kelas ${names.join(", ")}';
      }
    }
    // 2. Fallback to legacy single 'homeroom_class' object
    else if (effectiveTeacher['homeroom_class'] != null) {
      if (effectiveTeacher['homeroom_class'] is Map) {
        homeroomStatus =
            'Ya, Kelas ${effectiveTeacher['homeroom_class']['name']}';
      }
    }

    final nameStr = teacher['name'] ?? '';
    final nameHash = nameStr.codeUnits.fold(0, (sum, c) => sum + c);
    final avatarColor = ColorUtils.getColorForIndex(nameHash);
    final initial = nameStr.isNotEmpty ? nameStr[0].toUpperCase() : '?';
    final nip = teacher['employee_number'] ?? '';

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // --- Gradient Header (Pattern #7) ---
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.corporateBlue600,
                  ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
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
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Guru',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        nameStr.isNotEmpty ? nameStr : 'Informasi lengkap guru',
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _loadTeacherDetail,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // --- Body (conditional) ---
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.corporateBlue600),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Memuat detail guru...',
                          style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: ColorUtils.error600.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(color: ColorUtils.error600.withValues(alpha: 0.2)),
                            ),
                            child: Icon(Icons.error_outline_rounded, size: 36, color: ColorUtils.error600),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Terjadi kesalahan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate800),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: ColorUtils.slate600, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loadTeacherDetail,
                            icon: Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                            label: Text('Coba Lagi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Profile Header Card ---
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                ColorUtils.corporateBlue600,
                                ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: ColorUtils.corporateShadow(elevation: 2.0),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: avatarColor,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: Offset(0, 4))],
                                ),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                nameStr,
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (nip.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.badge_outlined, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('NIP: $nip', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                                      ]),
                                    ),
                                  if (homeroomStatus != '-') ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.groups_outlined, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Wali Kelas', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                                      ]),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // --- Personal Information Card ---
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ColorUtils.slate200),
                            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(Icons.person_rounded, 'Informasi Pribadi'),
                              _buildInfoRow('Nama', teacher['name']),
                              _buildInfoRow('NIP', teacher['employee_number'] ?? 'Tidak ada'),
                              _buildInfoRow('Email', teacher['user']?['email'] ?? teacher['email']),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),

                        // --- Teaching Information Card ---
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ColorUtils.slate200),
                            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(Icons.school_rounded, 'Informasi Mengajar'),
                              _buildInfoRow(
                                'Kelas',
                                teachingClassNames.isNotEmpty ? teachingClassNames : 'Belum dijadwalkan',
                                isMultiline: true,
                              ),
                              _buildInfoRow(
                                'Mata Pelajaran',
                                displaySubjectNames.isNotEmpty ? displaySubjectNames : 'Belum ditugaskan',
                                isMultiline: true,
                              ),
                              _buildInfoRow('Role', teacher['role']?.toUpperCase() ?? 'GURU'),
                              _buildInfoRow('Status Wali Kelas', homeroomStatus),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // --- Back Button ---
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back_rounded, size: 18, color: ColorUtils.slate700),
                            label: Text(
                              'Kembali ke Daftar Guru',
                              style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

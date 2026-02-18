// admin_class_activity.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/services/api_class_activity_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/excel_class_activity_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class AdminClassActivityScreen extends StatefulWidget {
  const AdminClassActivityScreen({super.key});

  @override
  AdminClassActivityScreenState createState() =>
      AdminClassActivityScreenState();
}

class AdminClassActivityScreenState extends State<AdminClassActivityScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _teacherList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _activityList = [];
  bool _isLoading = true;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  bool _showTeacherList = true;
  bool _showSubjectList = false;
  String? _errorMessage;

  // Search
  final TextEditingController _searchController = TextEditingController();

  // Animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final apiTeacherService = ApiTeacherService();
      final teachers = await apiTeacherService.getTeacher();

      setState(() {
        _teacherList = teachers;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
        _showErrorSnackBar('Gagal memuat data guru: $_errorMessage');
      }
    }
  }

  // Method untuk export data
  Future<void> exportActivities() async {
    if (_activityList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada data kegiatan untuk diexport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ExcelClassActivityService.exportClassActivitiesToExcel(
        activities: _activityList,
        context: context,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting activities: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubjectsByTeacher(
    String teacherId,
    String teacherName,
  ) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedTeacherId = teacherId;
        _selectedTeacherName = teacherName;
        _showTeacherList = false;
        _showSubjectList = true;
      });

      final academicYearId = context
          .read<AcademicYearProvider>()
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await ApiTeacherService.getSubjectsByTeacherPaginated(
        teacherId: teacherId,
        academicYearId: academicYearId,
      );

      setState(() {
        _subjectList = response['data'] ?? [];
        _isLoading = false;
      });

      _animationController.forward(from: 0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
        _showErrorSnackBar('Gagal memuat data mata pelajaran: $_errorMessage');
      }
    }
  }

  Future<void> _loadActivitiesBySubject(
    String subjectId,
    String subjectName,
  ) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedSubjectId = subjectId;
        _selectedSubjectName = subjectName;
        _showSubjectList = false;
      });

      final academicYearId = context
          .read<AcademicYearProvider>()
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await ApiClassActivityService.getClassActivityPaginated(
        guruId: _selectedTeacherId,
        mataPelajaranId: subjectId,
        academicYearId: academicYearId,
      );

      setState(() {
        _activityList = response['data'] ?? [];
        _isLoading = false;
      });

      _animationController.forward(from: 0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
        _showErrorSnackBar('Gagal memuat data kegiatan: $_errorMessage');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ColorUtils.error600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _backToTeacherList() {
    setState(() {
      _showTeacherList = true;
      _showSubjectList = false;
      _selectedTeacherId = null;
      _selectedTeacherName = null;
      _selectedSubjectId = null;
      _selectedSubjectName = null;
      _searchController.clear();
    });
    _animationController.forward(from: 0);
  }

  void _backToSubjectList() {
    setState(() {
      _showTeacherList = false;
      _showSubjectList = true;
      _selectedSubjectId = null;
      _selectedSubjectName = null;
      _searchController.clear();
    });
    _animationController.forward(from: 0);
  }

  List<dynamic> _getFilteredTeachers() {
    final searchTerm = _searchController.text.toLowerCase();
    return _teacherList.where((teacher) {
      final teacherName = teacher['name']?.toString().toLowerCase() ?? '';
      final teacherEmail = teacher['email']?.toString().toLowerCase() ?? '';
      final teacherSubject =
          teacher['subject_name']?.toString().toLowerCase() ?? '';

      return searchTerm.isEmpty ||
          teacherName.contains(searchTerm) ||
          teacherEmail.contains(searchTerm) ||
          teacherSubject.contains(searchTerm);
    }).toList();
  }

  List<dynamic> _getFilteredSubjects() {
    final searchTerm = _searchController.text.toLowerCase();
    return _subjectList.where((subject) {
      final name = subject['name']?.toString().toLowerCase() ?? '';
      return searchTerm.isEmpty || name.contains(searchTerm);
    }).toList();
  }

  List<dynamic> _getFilteredActivities() {
    final searchTerm = _searchController.text.toLowerCase();
    return _activityList.where((activity) {
      final title = activity['title']?.toString().toLowerCase() ?? '';
      final subject = activity['subject_name']?.toString().toLowerCase() ?? '';
      final className = activity['class_name']?.toString().toLowerCase() ?? '';
      final description =
          activity['description']?.toString().toLowerCase() ?? '';

      return searchTerm.isEmpty ||
          title.contains(searchTerm) ||
          subject.contains(searchTerm) ||
          className.contains(searchTerm) ||
          description.contains(searchTerm);
    }).toList();
  }

  // ─── Pattern #8: Teacher Card ──────────────────────────────────────────────
  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index) {
    final teacherName = teacher['name']?.toString() ?? 'Nama tidak tersedia';
    final teacherEmail = teacher['email']?.toString() ?? '';
    final teacherNip = teacher['nip']?.toString() ?? '';
    final avatarColor = ColorUtils.getColorForIndex(index);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay > 1 ? 1 : delay, 1.0, curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                _loadSubjectsByTeacher(teacher['id'].toString(), teacherName),
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
                children: [
                  // CircleAvatar with first letter
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: avatarColor.withValues(alpha: 0.15),
                    child: Text(
                      teacherName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: avatarColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Teacher info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacherName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (teacherEmail.isNotEmpty || teacherNip.isNotEmpty) ...[
                          SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              if (teacherEmail.isNotEmpty)
                                _buildInfoTag(
                                  Icons.email_outlined,
                                  teacherEmail,
                                ),
                              if (teacherNip.isNotEmpty)
                                _buildInfoTag(
                                  Icons.badge_outlined,
                                  'NIP: $teacherNip',
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // Chevron
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: ColorUtils.slate500,
                      size: 18,
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

  // ─── Pattern #8: Subject Card ──────────────────────────────────────────────
  Widget _buildSubjectCard(Map<String, dynamic> subject, int index) {
    final subjectName = subject['name']?.toString() ?? 'Mata Pelajaran';
    final subjectColor = ColorUtils.getColorForIndex(index);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay > 1 ? 1 : delay, 1.0, curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                _loadActivitiesBySubject(subject['id'].toString(), subjectName),
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
                children: [
                  // Colored icon container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: subjectColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: subjectColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: subjectColor,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Subject name + hint
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subjectName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ketuk untuk melihat kegiatan',
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: ColorUtils.slate500,
                      size: 18,
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

  // ─── Pattern #8: Activity Card ─────────────────────────────────────────────
  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    final isAssignment = activity['type'] == 'assignment';
    final isSpecificTarget = activity['target'] == 'specific';
    final accentColor =
        isAssignment ? ColorUtils.corporateBlue600 : ColorUtils.success600;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay > 1 ? 1 : delay, 1.0, curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showActivityDetail(activity),
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
                  // Icon container (tugas vs materi)
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
                      isAssignment
                          ? Icons.assignment_outlined
                          : Icons.menu_book_outlined,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'] ?? 'Judul Kegiatan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3),
                        Text(
                          '${activity['subject_name'] ?? '-'} • ${activity['class_name'] ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            _buildInfoTag(
                              Icons.calendar_today_outlined,
                              '${activity['day'] ?? '-'} • ${_formatDate(activity['date'])}',
                            ),
                            _buildInfoTag(
                              isAssignment
                                  ? Icons.assignment_outlined
                                  : Icons.menu_book_outlined,
                              isAssignment ? 'Tugas' : 'Materi',
                              tagColor: accentColor,
                            ),
                            _buildInfoTag(
                              isSpecificTarget
                                  ? Icons.person_outline
                                  : Icons.group_outlined,
                              isSpecificTarget ? 'Khusus' : 'Semua',
                              tagColor: isSpecificTarget
                                  ? ColorUtils.corporateBlue600
                                  : ColorUtils.success600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: ColorUtils.slate500,
                      size: 18,
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

  // ─── Reusable info chip (Pattern #8) ──────────────────────────────────────
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

  // ─── Pattern #10: Activity Detail Dialog ──────────────────────────────────
  void _showActivityDetail(Map<String, dynamic> activity) {
    final languageProvider = context.read<LanguageProvider>();
    final isAssignment = activity['jenis'] == 'tugas';
    final isSpecificTarget = activity['target'] == 'khusus';
    final primaryColor = _getPrimaryColor();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient header (Pattern #10)
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
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAssignment ? Icons.assignment : Icons.menu_book,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['judul'] ?? 'Judul Kegiatan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Text(
                            '${activity['mata_pelajaran_nama'] ?? ''} • ${activity['kelas_nama'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
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
                      value: activity['guru_nama'] ?? 'Tidak Diketahui',
                    ),
                    _buildDetailItem(
                      icon: Icons.calendar_today,
                      label: 'Hari',
                      value: activity['hari'] ?? '-',
                    ),
                    _buildDetailItem(
                      icon: Icons.date_range,
                      label: 'Tanggal',
                      value: _formatDate(activity['tanggal']),
                    ),
                    if (isAssignment)
                      _buildDetailItem(
                        icon: Icons.access_time,
                        label: 'Batas Waktu',
                        value: _formatDate(activity['batas_waktu']),
                      ),
                    _buildDetailItem(
                      icon: Icons.category,
                      label: 'Jenis Kegiatan',
                      value: isAssignment ? 'Tugas' : 'Materi',
                    ),
                    _buildDetailItem(
                      icon: Icons.group,
                      label: 'Target Siswa',
                      value:
                          isSpecificTarget ? 'Khusus Siswa' : 'Semua Siswa',
                    ),

                    if (activity['deskripsi'] != null &&
                        activity['deskripsi'].isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ColorUtils.slate50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ColorUtils.slate200),
                        ),
                        child: Text(
                          activity['deskripsi'],
                          style: TextStyle(
                            fontSize: 14,
                            color: ColorUtils.slate700,
                            height: 1.5,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate700,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (activity['judul_bab'] != null)
                        _buildDetailItem(
                          icon: Icons.menu_book,
                          label: 'Bab',
                          value: activity['judul_bab']!,
                        ),
                      if (activity['judul_sub_bab'] != null)
                        _buildDetailItem(
                          icon: Icons.bookmark,
                          label: 'Sub Bab (Utama)',
                          value: activity['judul_sub_bab']!,
                        ),
                      if (activity['additional_material'] != null &&
                          activity['additional_material'] is List &&
                          (activity['additional_material'] as List)
                              .isNotEmpty) ...[
                        SizedBox(height: 4),
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

                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Close',
                                'id': 'Tutup',
                              }),
                              style: TextStyle(
                                color: ColorUtils.slate700,
                                fontWeight: FontWeight.w600,
                              ),
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
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getPrimaryColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: _getPrimaryColor()),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return LoadingScreen(
            message: _showTeacherList
                ? languageProvider.getTranslatedText({
                    'en': 'Loading teacher data...',
                    'id': 'Memuat data guru...',
                  })
                : (_showSubjectList
                      ? languageProvider.getTranslatedText({
                          'en': 'Loading subjects...',
                          'id': 'Memuat mata pelajaran...',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Loading activities...',
                          'id': 'Memuat kegiatan...',
                        })),
          );
        }

        if (_errorMessage != null) {
          return ErrorScreen(
            errorMessage: _errorMessage!,
            onRetry: _showTeacherList
                ? _loadTeachers
                : (_showSubjectList
                      ? () => _loadSubjectsByTeacher(
                          _selectedTeacherId!,
                          _selectedTeacherName!,
                        )
                      : () => _loadActivitiesBySubject(
                          _selectedSubjectId!,
                          _selectedSubjectName!,
                        )),
          );
        }

        final filteredItems = _showTeacherList
            ? _getFilteredTeachers()
            : (_showSubjectList
                  ? _getFilteredSubjects()
                  : _getFilteredActivities());

        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: Column(
            children: [
              // ─── Pattern #7 Gradient Header ──────────────────────────────
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
                        // Back button (40x40 semi-transparent)
                        GestureDetector(
                          onTap: _showTeacherList
                              ? () => Navigator.pop(context)
                              : (_showSubjectList
                                    ? _backToTeacherList
                                    : _backToSubjectList),
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
                        // Title + subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _showTeacherList
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Class Activities',
                                        'id': 'Kegiatan Kelas',
                                      })
                                    : (_showSubjectList
                                          ? languageProvider.getTranslatedText({
                                              'en':
                                                  'Subjects - $_selectedTeacherName',
                                              'id':
                                                  'Mata Pelajaran - $_selectedTeacherName',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en':
                                                  'Activities - $_selectedSubjectName',
                                              'id':
                                                  'Kegiatan - $_selectedSubjectName',
                                            })),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                _showTeacherList
                                    ? languageProvider.getTranslatedText({
                                        'en': 'View all teacher activities',
                                        'id': 'Lihat semua kegiatan guru',
                                      })
                                    : (_showSubjectList
                                          ? languageProvider.getTranslatedText({
                                              'en':
                                                  'Select subject to view activities',
                                              'id':
                                                  'Pilih mata pelajaran untuk melihat kegiatan',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en':
                                                  'Viewing activities for $_selectedSubjectName',
                                              'id':
                                                  'Melihat kegiatan untuk $_selectedSubjectName',
                                            })),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Icon badge
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _showTeacherList
                                ? Icons.people
                                : (_showSubjectList
                                      ? Icons.menu_book
                                      : Icons.assignment),
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
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: ColorUtils.slate800),
                              decoration: InputDecoration(
                                hintText: _showTeacherList
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Search teachers...',
                                        'id': 'Cari guru...',
                                      })
                                    : (_showSubjectList
                                          ? languageProvider.getTranslatedText({
                                              'en': 'Search subjects...',
                                              'id': 'Cari mata pelajaran...',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en': 'Search activities...',
                                              'id': 'Cari kegiatan...',
                                            })),
                                hintStyle:
                                    TextStyle(color: ColorUtils.slate400),
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
                              onSubmitted: (_) => setState(() {}),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(right: 4),
                            child: IconButton(
                              icon: Icon(
                                Icons.search,
                                color: _getPrimaryColor(),
                              ),
                              onPressed: () => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Content ─────────────────────────────────────────────────
              Expanded(
                child: filteredItems.isEmpty
                    ? EmptyState(
                        title: _showTeacherList
                            ? languageProvider.getTranslatedText({
                                'en': 'No teachers',
                                'id': 'Tidak ada guru',
                              })
                            : (_showSubjectList
                                  ? languageProvider.getTranslatedText({
                                      'en': 'No subjects',
                                      'id': 'Tidak ada mata pelajaran',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'No activities',
                                      'id': 'Tidak ada kegiatan',
                                    })),
                        subtitle: _searchController.text.isEmpty
                            ? _showTeacherList
                                  ? languageProvider.getTranslatedText({
                                      'en': 'No teacher data available',
                                      'id': 'Data guru tidak tersedia',
                                    })
                                  : (_showSubjectList
                                        ? languageProvider.getTranslatedText({
                                            'en':
                                                'Teacher $_selectedTeacherName has no subjects',
                                            'id':
                                                'Guru $_selectedTeacherName tidak memiliki mata pelajaran',
                                          })
                                        : languageProvider.getTranslatedText({
                                            'en':
                                                'Subject $_selectedSubjectName has no class activities',
                                            'id':
                                                'Mata pelajaran $_selectedSubjectName belum memiliki kegiatan kelas',
                                          }))
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: _showTeacherList
                            ? Icons.people_outline
                            : (_showSubjectList
                                  ? Icons.menu_book
                                  : Icons.event_note),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _showTeacherList
                              ? _buildTeacherCard(item, index)
                              : (_showSubjectList
                                    ? _buildSubjectCard(item, index)
                                    : _buildActivityCard(item, index));
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

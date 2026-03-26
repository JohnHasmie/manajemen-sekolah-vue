// Student detail view screen - shows full profile info for a single student.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
//
// Like `pages/admin/students/{id}.vue` - a detail/show page that displays
// all student information (personal data, class, guardian, etc.).
//
// In Laravel terms, this calls `GET /api/students/{id}` (StudentController@show).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Student detail screen - displays full profile for a single student.
///
/// Takes a [student] map (basic data) and fetches full details from API.
/// Optionally accepts [onEdit] callback to trigger refresh in parent screen.
/// Like a Vue route page with `props: true` receiving the student object.
class StudentDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback? onEdit;

  const StudentDetailScreen({
    super.key,
    required this.student,
    this.onEdit,
  });

  @override
  StudentDetailScreenState createState() => StudentDetailScreenState();
}

/// Mutable state for [StudentDetailScreen].
///
/// Key state (like Vue `data()`):
/// - [_studentDetail] - full student data from API (null until loaded)
/// - [_isLoading] / [_errorMessage] - loading and error states
class StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  Map<String, dynamic>? _studentDetail;
  bool _isLoading = true;
  String? _errorMessage;

  /// Like Vue's `mounted()` - fetches full student details from the API.
  @override
  void initState() {
    super.initState();
    _loadStudentDetail();
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Fetches full student details by ID from the API.
  /// Like calling `GET /api/students/{id}` in a Vue method.
  Future<void> _loadStudentDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final studentDetail = await getIt<ApiStudentService>().getStudentById(
        widget.student['id'].toString(),
      );

      if (!mounted) return;
      setState(() {
        _studentDetail = studentDetail is Map<String, dynamic>
            ? studentDetail
            : null;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('student', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.getFriendlyMessage(e);
      });
            SnackBarUtils.showError(context, 'Gagal memuat detail siswa: ${ErrorUtils.getFriendlyMessage(e)}');
    }
  }

  String _getGenderText(String? gender, LanguageProvider languageProvider) {
    switch (gender) {
      case 'M':
      case 'L':
        return languageProvider.getTranslatedText({
          'en': 'Male',
          'id': 'Laki-laki',
        });
      case 'F':
      case 'P':
        return languageProvider.getTranslatedText({
          'en': 'Female',
          'id': 'Perempuan',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
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
              color: _getPrimaryColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getPrimaryColor().withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              icon ?? _getIconForLabel(label),
              size: 18,
              color: _getPrimaryColor(),
            ),
          ),
          SizedBox(width: AppSpacing.md),
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
                Text(
                  value.isNotEmpty ? value : 'Tidak ada',
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
          left: BorderSide(color: _getPrimaryColor(), width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _getPrimaryColor()),
          SizedBox(width: AppSpacing.sm),
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
      case 'Kelas':
      case 'Class':
        return Icons.school;
      case 'Jenis Kelamin':
      case 'Gender':
        return Icons.transgender;
      case 'Tanggal Lahir':
      case 'Birth Date':
        return Icons.cake;
      case 'Alamat':
      case 'Address':
        return Icons.location_on;
      case 'Nama Wali':
      case 'Parent Name':
        return Icons.person;
      case 'No. Telepon':
      case 'Phone Number':
        return Icons.phone;
      case 'Email Wali':
      case 'Parent Email':
        return Icons.email;
      case 'NIS':
        return Icons.badge;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    final student = _studentDetail ?? widget.student;
    final classes = student['classes'] as List<dynamic>? ?? [];

    final nameStr = student['name'] ?? '';
    final nameHash = nameStr.codeUnits.fold(0, (sum, c) => sum + c);
    final avatarColor = ColorUtils.getColorForIndex(nameHash);
    final initial = nameStr.isNotEmpty ? nameStr[0].toUpperCase() : '?';
    final className = student['class']?['name'] ?? '';
    final nis = student['student_number'] ?? '';

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
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
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
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Student Detail',
                          'id': 'Detail Siswa',
                        }),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        nameStr.isNotEmpty
                            ? nameStr
                            : languageProvider.getTranslatedText({
                                'en': 'Complete student information',
                                'id': 'Informasi lengkap siswa',
                              }),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _loadStudentDetail,
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
                if (widget.onEdit != null) ...[
                  SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: () {
                      AppNavigator.pop(context);
                      widget.onEdit?.call();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
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
                            color: _getPrimaryColor().withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_getPrimaryColor()),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: AppSpacing.lg),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Loading student detail...',
                            'id': 'Memuat detail siswa...',
                          }),
                          style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: ColorUtils.error600.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ColorUtils.error600.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  size: 36,
                                  color: ColorUtils.error600,
                                ),
                              ),
                              SizedBox(height: AppSpacing.lg),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'An error occurred',
                                  'id': 'Terjadi kesalahan',
                                }),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ColorUtils.slate800,
                                ),
                              ),
                              SizedBox(height: AppSpacing.sm),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: ColorUtils.slate600,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: AppSpacing.xl),
                              ElevatedButton.icon(
                                onPressed: _loadStudentDetail,
                                icon: Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                                label: Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Try Again',
                                    'id': 'Coba Lagi',
                                  }),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getPrimaryColor(),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  elevation: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(AppSpacing.lg),
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
                                    _getPrimaryColor(),
                                    _getPrimaryColor().withValues(alpha: 0.8),
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
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: AppSpacing.md),
                                  Text(
                                    nameStr.isNotEmpty ? nameStr : 'No Name',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (nis.toString().isNotEmpty)
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.badge_outlined, size: 12, color: Colors.white),
                                              SizedBox(width: AppSpacing.xs),
                                              Text(
                                                'NIS: $nis',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (className.isNotEmpty) ...[
                                        SizedBox(width: AppSpacing.sm),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.school_outlined, size: 12, color: Colors.white),
                                              SizedBox(width: AppSpacing.xs),
                                              Text(
                                                className,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppSpacing.lg),

                            // --- Personal Information Card ---
                            Container(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ColorUtils.slate200),
                                boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(
                                    Icons.person_rounded,
                                    languageProvider.getTranslatedText({
                                      'en': 'Personal Information',
                                      'id': 'Informasi Pribadi',
                                    }),
                                  ),
                                  _buildInfoRow(
                                    'NIS',
                                    student['student_number']?.toString() ?? '-',
                                    icon: Icons.badge,
                                  ),
                                  _buildInfoRow(
                                    languageProvider.getTranslatedText({
                                      'en': 'Class',
                                      'id': 'Kelas',
                                    }),
                                    student['class']?['name'] ?? 'No Class',
                                    icon: Icons.school,
                                  ),
                                  _buildInfoRow(
                                    languageProvider.getTranslatedText({
                                      'en': 'Gender',
                                      'id': 'Jenis Kelamin',
                                    }),
                                    _getGenderText(student['gender'], languageProvider),
                                    icon: Icons.transgender,
                                  ),
                                  _buildInfoRow(
                                    languageProvider.getTranslatedText({
                                      'en': 'Birth Date',
                                      'id': 'Tanggal Lahir',
                                    }),
                                    _formatDate(student['date_of_birth']),
                                    icon: Icons.cake,
                                  ),
                                  _buildInfoRow(
                                    languageProvider.getTranslatedText({
                                      'en': 'Address',
                                      'id': 'Alamat',
                                    }),
                                    student['address'] ?? 'No Address',
                                    icon: Icons.location_on,
                                    isMultiline: true,
                                  ),
                                ],
                              ),
                            ),

                            // --- Class History Card ---
                            if (classes.isNotEmpty) ...[
                              SizedBox(height: AppSpacing.md),
                              Container(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: ColorUtils.slate200),
                                  boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      Icons.history_rounded,
                                      languageProvider.getTranslatedText({
                                        'en': 'Class History',
                                        'id': 'Riwayat Kelas',
                                      }),
                                    ),
                                    ...classes.map<Widget>((classItem) {
                                      final year =
                                          classItem['academic_year']?['year'] ??
                                              'Unknown Year';
                                      return _buildInfoRow(
                                        year,
                                        classItem['name'] ?? 'Unknown Class',
                                        icon: Icons.history,
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: AppSpacing.md),

                            // --- Parent Information Card ---
                            Container(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ColorUtils.slate200),
                                boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(
                                    Icons.family_restroom_rounded,
                                    languageProvider.getTranslatedText({
                                      'en': 'Parent Information',
                                      'id': 'Informasi Wali',
                                    }),
                                  ),
                                  _buildInfoRow(
                                    languageProvider.getTranslatedText({
                                      'en': 'Parent Name',
                                      'id': 'Nama Wali',
                                    }),
                                    student['guardian_name'] ?? 'No Parent Name',
                                    icon: Icons.person,
                                  ),
                                  _buildInfoRow(
                                    languageProvider.getTranslatedText({
                                      'en': 'Phone Number',
                                      'id': 'No. Telepon',
                                    }),
                                    student['phone_number'] ?? 'No Phone',
                                    icon: Icons.phone,
                                  ),
                                  _buildInfoRow(
                                    languageProvider.getTranslatedText({
                                      'en': 'Parent Email',
                                      'id': 'Email Wali',
                                    }),
                                    student['parent_email'] ??
                                        student['guardian_email'] ??
                                        'No Email',
                                    icon: Icons.email,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppSpacing.xxl),

                            // --- Back Button ---
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => AppNavigator.pop(context),
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 18,
                                  color: ColorUtils.slate700,
                                ),
                                label: Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Back to Student List',
                                    'id': 'Kembali ke Daftar Siswa',
                                  }),
                                  style: TextStyle(
                                    color: ColorUtils.slate700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 13),
                                  side: BorderSide(color: ColorUtils.slate300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// Dialog form for creating/editing a lesson plan (RPP).
// Extracted from teacher_lesson_plan_screen.dart to reduce file size.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Dialog form for creating or editing an RPP (lesson plan).
///
/// Like a Vue `<RppFormModal>` component. When [lessonPlanData] is null, it creates
/// a new RPP; when provided, it edits the existing one.
/// Props: [teacherId], [onSaved] callback, optional [lessonPlanData] for editing.
class LessonPlanFormDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final VoidCallback onSaved;
  final Map<String, dynamic>? lessonPlanData;

  const LessonPlanFormDialog({
    super.key,
    required this.teacherId,
    required this.onSaved,
    this.lessonPlanData,
  });

  @override
  ConsumerState<LessonPlanFormDialog> createState() =>
      _LessonPlanFormDialogState();
}

class _LessonPlanFormDialogState extends ConsumerState<LessonPlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _academicYearController = TextEditingController();

  String? _selectedSubjectId;
  String? _selectedClassId;
  String? _selectedTerm = 'Ganjil';
  String? _selectedFileName;
  File? _selectedFile;
  bool _isUploading = false;

  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];

  @override
  void initState() {
    super.initState();
    _loadSubjectsByTeacher();

    // If in edit mode, fill fields with RPP data
    if (widget.lessonPlanData != null) {
      _titleController.text =
          widget.lessonPlanData!['judul'] ??
          widget.lessonPlanData!['title'] ??
          '';
      _academicYearController.text =
          widget.lessonPlanData!['academic_year'] ??
          widget.lessonPlanData!['tahun_ajaran'] ??
          '';
      _selectedSubjectId =
          (widget.lessonPlanData!['subject_id'] ??
                  widget.lessonPlanData!['mata_pelajaran_id'])
              ?.toString();
      _selectedClassId =
          (widget.lessonPlanData!['class_id'] ??
                  widget.lessonPlanData!['kelas_id'])
              ?.toString();
      _selectedTerm = widget.lessonPlanData!['semester'] ?? 'Ganjil';
      _selectedFileName = widget.lessonPlanData!['file_path'];

      if (_selectedSubjectId != null) {
        _loadClassesBySubject(_selectedSubjectId!);
      }
    } else {
      // New add mode: set default academic year
      _academicYearController.text = DateTime.now().year.toString();
    }
  }

  Future<void> _loadSubjectsByTeacher() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/guru/${widget.teacherId}/mata-pelajaran',
      );
      setState(() {
        // Backend returns {success: true, data: [...], pagination: {...}}
        if (result is Map && result['data'] is List) {
          _subjectList = result['data'];
        } else if (result is List) {
          _subjectList = result;
        } else {
          _subjectList = [];
        }
      });
      if (kDebugMode) {
        AppLogger.info(
          'lesson_plan',
          'Loaded ${_subjectList.length} mata pelajaran',
        );
        if (_subjectList.isNotEmpty) {
          AppLogger.debug(
            'lesson_plan',
            'DEBUG SUBJECT ITEM: ${_subjectList.first}',
          );
        }
      }
    } catch (e) {
      AppLogger.error(
        'lesson_plan',
        'Error loading mata pelajaran by guru: $e',
      );
      _loadAllSubjects();
    }
  }

  Future<void> _loadAllSubjects() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        // Backend might return {success: true, data: [...]} or direct array
        if (result is Map && result['data'] is List) {
          _subjectList = result['data'];
        } else if (result is List) {
          _subjectList = result;
        } else {
          _subjectList = [];
        }
      });
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error loading all mata pelajaran: $e');
    }
  }

  Future<void> _loadClassesBySubject(String subjectId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$subjectId',
      );
      setState(() {
        // Backend might return {success: true, data: [...]} or direct array
        if (result is Map && result['data'] is List) {
          _classList = result['data'];
        } else if (result is List) {
          _classList = result;
        } else {
          _classList = [];
        }
      });
      if (kDebugMode) {
        AppLogger.info(
          'lesson_plan',
          'Loaded ${_classList.length} kelas for mata pelajaran $subjectId',
        );
        if (_classList.isNotEmpty) {
          AppLogger.debug(
            'lesson_plan',
            'DEBUG CLASS ITEM: ${_classList.first}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'lesson_plan',
          'Error loading kelas by mata pelajaran: $e',
        );
        setState(() {
          _classList = [];
        });
      }
    }
  }

  void _showFilePickerDialog() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final PlatformFile file = result.files.first;

        // Make sure the file actually exists
        final File selectedFile = File(file.path!);
        final bool fileExists = await selectedFile.exists();

        AppLogger.debug('lesson_plan', 'File picked: ${file.name}');
        AppLogger.debug('lesson_plan', 'File path: ${file.path}');
        AppLogger.debug('lesson_plan', 'File exists: $fileExists');
        AppLogger.debug('lesson_plan', 'File size: ${file.size} bytes');

        if (fileExists) {
          setState(() {
            _selectedFileName = file.name;
            _selectedFile = selectedFile;
          });
        }
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error picking file: $e');
    }
  }

  Future<void> _viewCurrentFile() async {
    final filePath = widget.lessonPlanData?['file_path'];
    if (filePath != null) {
      // Use the helper function defined at the bottom of the file
      await _downloadAndOpenFile(context, filePath);
    }
  }

  // Helper to download and open file
  Future<void> _downloadAndOpenFile(
    BuildContext context,
    String filePath,
  ) async {
    try {
      // Construct full URL properly
      // If ApiService.baseUrl is "https://edu-api.kamillabs.com/api"
      // Static files are usually at "https://edu-api.kamillabs.com/uploads/..."
      // We stripping the '/api' suffix to get the root.
      final rootUrl = ApiService.baseUrl.replaceFirst('/api', '');

      // Ensure filePath doesn't double slash and is properly combined
      String cleanPath = filePath;
      if (!cleanPath.startsWith('/')) {
        cleanPath = '/$cleanPath';
      }

      final fullUrl = '$rootUrl$cleanPath';

      AppLogger.debug('lesson_plan', 'Downloading file from: $fullUrl');

      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showInfo(
        context,
        languageProvider.getTranslatedText({
          'en': 'Downloading file...',
          'id': 'Mengunduh file...',
        }),
      );

      final dio = Dio();
      final response = await dio.get<List<int>>(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final dir = await getTemporaryDirectory();
      // Extract filename
      final fileName = cleanPath.split('/').last;
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(response.data ?? []);

      AppLogger.info('lesson_plan', 'File saved to: ${file.path}');

      await OpenFile.open(file.path);
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error opening file: $e');

      final String message = e.toString().replaceFirst('Exception: ', '');

      if (context.mounted) {
        SnackBarUtils.showError(context, message);
      }
    }
  }

  // File Upload Logic Removed - Using simplified version

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      String? filePath;

      // Debug: Check if file exists
      AppLogger.debug('lesson_plan', 'File selected: $_selectedFile');
      AppLogger.debug('lesson_plan', 'File name: $_selectedFileName');

      if (_selectedFile != null) {
        try {
          AppLogger.debug('lesson_plan', 'Starting file upload...');
          final uploadResult = await LessonPlanService.uploadLessonPlanFile(
            _selectedFile!,
          );
          AppLogger.debug('lesson_plan', 'Upload result: $uploadResult');

          filePath = uploadResult['file_path'];
          AppLogger.info(
            'lesson_plan',
            'File uploaded successfully: $filePath',
          );
        } catch (uploadError) {
          AppLogger.error(
            'lesson_plan',
            'Error during file upload: $uploadError',
          );
          // Continue without file if upload fails
          filePath = null;
        }
      } else {
        AppLogger.debug('lesson_plan', 'No file selected for upload');
      }

      // Debug data to be submitted
      AppLogger.debug('lesson_plan', 'Submitting RPP data:');
      AppLogger.debug('lesson_plan', '- Guru ID: ${widget.teacherId}');
      AppLogger.debug(
        'lesson_plan',
        '- Mata Pelajaran ID: $_selectedSubjectId',
      );
      AppLogger.debug('lesson_plan', '- Kelas ID: $_selectedClassId');
      AppLogger.debug('lesson_plan', '- Judul: ${_titleController.text}');
      AppLogger.debug('lesson_plan', '- File Path: $filePath');

      final lessonPlanData = {
        'subject_id': _selectedSubjectId,
        'class_id': _selectedClassId,
        'title': _titleController.text,
        'semester': _selectedTerm,
        'academic_year': _academicYearController.text,
        'file_path': filePath ?? _selectedFileName,
      };

      // Submit RPP data (edit or add mode)
      if (widget.lessonPlanData != null) {
        // Edit mode
        await LessonPlanService.updateLessonPlan(
          widget.lessonPlanData!['id'],
          lessonPlanData,
        );
        AppLogger.info('lesson_plan', 'RPP updated successfully');
      } else {
        // New add mode
        lessonPlanData['teacher_id'] = widget.teacherId;
        await LessonPlanService.createLessonPlan(lessonPlanData);
        AppLogger.info('lesson_plan', 'RPP created successfully');
      }

      if (!mounted) return;
      AppNavigator.pop(context);
      widget.onSaved();

      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showInfo(
        context,
        widget.lessonPlanData != null
            ? languageProvider.getTranslatedText({
                'en': 'RPP updated successfully',
                'id': 'RPP berhasil diupdate',
              })
            : languageProvider.getTranslatedText({
                'en': 'RPP created successfully',
                'id': 'RPP berhasil dibuat',
              }),
      );
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error creating RPP: $e');
      SnackBarUtils.showInfo(
        context,
        '${languageProvider.getTranslatedText({'en': 'Error', 'id': 'Terjadi Kesalahan'})}: $e',
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    VoidCallback? onTap,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextFormField(
        controller: controller,
        onTap: onTap,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required dynamic value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? Function(dynamic)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<dynamic>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final primaryColor = _getPrimaryColor();
    final isEditMode = widget.lessonPlanData != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (Pattern #10 gradient)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: ColorUtils.heroGradient(primaryColor: primaryColor),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        isEditMode ? Icons.edit_note : Icons.add_task,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditMode
                                ? languageProvider.getTranslatedText({
                                    'en': 'Edit RPP',
                                    'id': 'Edit RPP',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Add New RPP',
                                    'id': 'Tambah RPP Baru',
                                  }),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditMode
                                ? languageProvider.getTranslatedText({
                                    'en': 'Update RPP details',
                                    'id': 'Perbarui detail RPP',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Create a new RPP document',
                                    'id': 'Buat dokumen RPP baru',
                                  }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogTextField(
                      controller: _titleController,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Title', 'id': 'Judul'})} *',
                      icon: Icons.title_rounded,
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Enter RPP title',
                        'id': 'Masukkan judul RPP',
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.getTranslatedText({
                            'en': 'Title is required',
                            'id': 'Judul wajib diisi',
                          });
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDialogDropdown(
                      value: _selectedSubjectId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})} *',
                      icon: Icons.book_outlined,
                      items: _subjectList.map((mp) {
                        return DropdownMenuItem(
                          value: mp['id'],
                          child: Text(
                            mp['name'] ??
                                mp['nama'] ??
                                mp['subject_name'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSubjectId = value.toString();
                          _selectedClassId = null;
                        });
                        _loadClassesBySubject(value.toString());
                      },
                      validator: (value) {
                        if (value == null) {
                          return languageProvider.getTranslatedText({
                            'en': 'Subject is required',
                            'id': 'Mata pelajaran wajib diisi',
                          });
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDialogDropdown(
                      value: _selectedClassId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})} *',
                      icon: Icons.class_outlined,
                      items: _classList.map((classItem) {
                        return DropdownMenuItem(
                          value: classItem['id'],
                          child: Text(
                            classItem['name'] ??
                                classItem['nama'] ??
                                classItem['class_name'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedClassId = value.toString();
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return languageProvider.getTranslatedText({
                            'en': 'Class name is required',
                            'id': 'Nama kelas wajib diisi',
                          });
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDialogDropdown(
                      value: _selectedTerm,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Semester', 'id': 'Semester'})} *',
                      icon: Icons.calendar_view_month_rounded,
                      items: ['Ganjil', 'Genap'].map((semester) {
                        return DropdownMenuItem(
                          value: semester,
                          child: Text(semester),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTerm = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDialogTextField(
                      controller: _academicYearController,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Academic Year', 'id': 'Tahun Ajaran'})} *',
                      icon: Icons.calendar_today_rounded,
                      hintText: '2024/2025',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.getTranslatedText({
                            'en': 'Academic year is required',
                            'id': 'Tahun ajaran wajib diisi',
                          });
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // File upload section
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'File Attachment',
                        'id': 'Lampiran File',
                      }),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        border: Border.all(color: ColorUtils.slate200),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _selectedFileName != null
                                  ? ColorUtils.info600.withValues(alpha: 0.1)
                                  : ColorUtils.slate100,
                              borderRadius: const BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Icon(
                              _selectedFileName != null
                                  ? Icons.description_rounded
                                  : Icons.upload_file_rounded,
                              color: _selectedFileName != null
                                  ? ColorUtils.info600
                                  : ColorUtils.slate400,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFileName ??
                                      languageProvider.getTranslatedText({
                                        'en': 'No file selected',
                                        'id': 'Belum ada file dipilih',
                                      }),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedFileName != null
                                        ? ColorUtils.slate800
                                        : ColorUtils.slate400,
                                    fontWeight: _selectedFileName != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedFileName == null)
                                  Text(
                                    'PDF, DOC, DOCX',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ColorUtils.slate400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isEditMode &&
                              widget.lessonPlanData!['file_path'] != null)
                            GestureDetector(
                              onTap: _viewCurrentFile,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: ColorUtils.info600.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                  border: Border.all(
                                    color: ColorUtils.info600.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: ColorUtils.info600,
                                ),
                              ),
                            ),
                          const SizedBox(width: AppSpacing.sm),
                          GestureDetector(
                            onTap: _showFilePickerDialog,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Choose',
                                  'id': 'Pilih',
                                }),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
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

          // Footer Buttons (Enhanced Pattern)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading
                          ? null
                          : () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shadowColor: primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isUploading
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEditMode
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Update',
                                      'id': 'Perbarui',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Save',
                                      'id': 'Simpan',
                                    }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

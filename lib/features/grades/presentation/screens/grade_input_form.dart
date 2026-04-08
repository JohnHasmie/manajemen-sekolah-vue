// Individual grade input form dialog.
// Like a Vue modal component for editing a single student's grade.
//
// This form is shown when a teacher taps on a grade cell to edit it.
// In Laravel terms, this is GradeController@update for a single grade record.
//
// Extracted from teacher_grade_input_screen.dart.
// Contains:
// - [GradeInputForm] -- individual grade input/edit dialog
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

// Form Input Nilai Individual
class GradeInputForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Student student;
  final String gradeType;
  final Map<String, dynamic>? existingGrade;
  final dynamic assessmentId; // Added assessmentId
  final DateTime? initialDate;
  final String? initialTitle;

  const GradeInputForm({
    super.key,
    required this.teacher,
    required this.subject,
    required this.student,
    required this.gradeType,
    this.existingGrade,
    this.assessmentId, // Added assessmentId
    this.initialDate,
    this.initialTitle,
  });

  @override
  GradeInputFormState createState() => GradeInputFormState();
}

class GradeInputFormState extends ConsumerState<GradeInputForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  bool get _isReadOnly {
    return ref.read(academicYearRiverpod).isReadOnly;
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill data if editing
    if (widget.existingGrade != null) {
      _scoreController.text = (widget.existingGrade!['score'] ?? widget.existingGrade!['nilai'] ?? '').toString();
      _deskripsiController.text =
          widget.existingGrade!['deskripsi']?.toString() ?? '';
      _titleController.text = widget.existingGrade!['title']?.toString() ?? '';

      if (widget.existingGrade!['tanggal'] != null) {
        _selectedDate = DateTime.parse(widget.existingGrade!['tanggal']);
      }
    } else {
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
      }
      if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
        _titleController.text = widget.initialTitle!;
      } else {
        // Prefill with "Nilai [Type]" as requested
        final label = _getGradeTypeLabel(widget.gradeType, ref.read(languageRiverpod));
        _titleController.text = 'Nilai $label';
      }
    }
    
    // Also handle case where existing grade has no title
    if (widget.existingGrade != null && _titleController.text.isEmpty) {
      final label = _getGradeTypeLabel(widget.gradeType, ref.read(languageRiverpod));
      _titleController.text = 'Nilai $label';
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _deskripsiController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showModernDatePicker(
      context: context,
      initialDate: _selectedDate,
      title: 'Pilih Tanggal Nilai',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitGrade() async {
    if (_isReadOnly) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Cannot submit grades for inactive academic year',
          'id':
              'Tidak dapat menyimpan nilai untuk tahun ajaran yang tidak aktif',
        }),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final data = {
          'student_id': widget.student.id,
          'student_class_id':
              widget.student.studentClassId, // Added for completeness
          'teacher_id': widget.teacher['id'],
          'subject_id': widget.subject['id'],
          'type': widget.gradeType,
          'assessment_id':
              widget.assessmentId ??
              widget
                  .existingGrade?['assessment_id'], // Priority on assessmentId
          'score': int.parse(_scoreController.text),
          'notes': _deskripsiController.text,
          'title': _titleController.text.isNotEmpty
              ? _titleController.text
              : null,
          'date':
              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        };

        if (widget.existingGrade != null) {
          // Update existing grade
          await ApiService().put(
            '/grades/${widget.existingGrade!['id']}',
            data,
          );
        } else {
          // Tambah nilai baru
          await ApiService().post('/grades', data);
        }

        if (!mounted) return;
        SnackBarUtils.showSuccess(
          context,
          ref.read(languageRiverpod).getTranslatedText({
            'en': widget.existingGrade != null
                ? 'Grade successfully updated'
                : 'Grade successfully saved',
            'id': widget.existingGrade != null
                ? 'Nilai berhasil diupdate'
                : 'Nilai berhasil disimpan',
          }),
        );

        AppNavigator.pop(context);
      } catch (e) {
        AppLogger.error('grades', e);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  String _getGradeTypeLabel(String type, LanguageProvider languageProvider) {
    switch (type) {
      case 'uh':
        return languageProvider.getTranslatedText({
          'en': 'Daily/Quiz',
          'id': 'UH/Ulangan',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      case 'pts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm Exam',
          'id': 'PTS',
        });
      case 'pas':
        return languageProvider.getTranslatedText({
          'en': 'Final Exam',
          'id': 'PAS',
        });
      default:
        return type.toUpperCase();
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(icon, size: 18, color: ColorUtils.corporateBlue600),
          ),
          const SizedBox(width: AppSpacing.md),
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
                  ),
                ),
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Pattern #7 Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
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
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Input Grade',
                          'id': 'Input Nilai',
                        }),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.student.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Info card - Pattern #10 detail items style
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                        border: Border.all(color: ColorUtils.slate200),
                        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailItem(
                            Icons.person_outline,
                            languageProvider.getTranslatedText({
                              'en': 'Student',
                              'id': 'Siswa',
                            }),
                            widget.student.name,
                          ),
                          _buildDetailItem(
                            Icons.badge_outlined,
                            languageProvider.getTranslatedText({
                              'en': 'NIS',
                              'id': 'NIS',
                            }),
                            widget.student.studentNumber,
                          ),
                          _buildDetailItem(
                            Icons.menu_book_outlined,
                            languageProvider.getTranslatedText({
                              'en': 'Subject',
                              'id': 'Mata Pelajaran',
                            }),
                            widget.subject['nama'] ??
                                widget.subject['name'] ??
                                '-',
                          ),
                          _buildDetailItem(
                            Icons.assignment_outlined,
                            languageProvider.getTranslatedText({
                              'en': 'Type',
                              'id': 'Jenis',
                            }),
                            _getGradeTypeLabel(
                              widget.gradeType,
                              languageProvider,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Input Title - Pattern #9 styled field
                    Container(
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: TextFormField(
                        controller: _titleController,
                        style: TextStyle(color: ColorUtils.slate900),
                        decoration: InputDecoration(
                          labelText: languageProvider.getTranslatedText({
                            'en': 'Assessment Title (Optional)',
                            'id': 'Judul Penilaian (Opsional)',
                          }),
                          labelStyle: TextStyle(color: ColorUtils.slate500),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.title,
                            color: _getPrimaryColor(),
                          ),
                          helperText: languageProvider.getTranslatedText({
                            'en': 'E.g., Quiz 1, Project A',
                            'id': 'Contoh: Kuis 1, Proyek A',
                          }),
                          helperStyle: TextStyle(
                            color: ColorUtils.slate400,
                            fontSize: 11,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: _getPrimaryColor(),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Input Nilai - Pattern #9 styled field
                    Container(
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: TextFormField(
                        controller: _scoreController,
                        style: TextStyle(color: ColorUtils.slate900),
                        decoration: InputDecoration(
                          labelText: languageProvider.getTranslatedText({
                            'en': 'Grade',
                            'id': 'Nilai',
                          }),
                          labelStyle: TextStyle(color: ColorUtils.slate500),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.score,
                            color: _getPrimaryColor(),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: _getPrimaryColor(),
                              width: 1.5,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageProvider.getTranslatedText({
                              'en': 'Please enter grade',
                              'id': 'Masukkan nilai',
                            });
                          }
                          if (int.tryParse(value) == null) {
                            return languageProvider.getTranslatedText({
                              'en': 'Please enter valid integer',
                              'id': 'Masukkan angka bulat yang valid',
                            });
                          }
                          final gradeValue = int.parse(value);
                          if (gradeValue < 0 || gradeValue > 100) {
                            return languageProvider.getTranslatedText({
                              'en': 'Grade must be between 0-100',
                              'id': 'Nilai harus antara 0-100',
                            });
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Input Deskripsi - Pattern #9 styled field
                    Container(
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: TextFormField(
                        controller: _deskripsiController,
                        style: TextStyle(color: ColorUtils.slate900),
                        decoration: InputDecoration(
                          labelText: languageProvider.getTranslatedText({
                            'en': 'Description',
                            'id': 'Deskripsi',
                          }),
                          labelStyle: TextStyle(color: ColorUtils.slate500),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.description,
                            color: _getPrimaryColor(),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: _getPrimaryColor(),
                              width: 1.5,
                            ),
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Date picker - Pattern #9 field container style
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: _getPrimaryColor(),
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Date:',
                              'id': 'Tanggal:',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: ColorUtils.slate600,
                            ),
                          ),
                          Spacer(),
                          TextButton(
                            onPressed: () => _selectDate(context),
                            child: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: TextStyle(
                                fontSize: 15,
                                color: _getPrimaryColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitGrade,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          disabledBackgroundColor: _getPrimaryColor()
                              .withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.existingGrade != null
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Update Grade',
                                        'id': 'Update Nilai',
                                      })
                                    : languageProvider.getTranslatedText({
                                        'en': 'Save Grade',
                                        'id': 'Simpan Nilai',
                                      }),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

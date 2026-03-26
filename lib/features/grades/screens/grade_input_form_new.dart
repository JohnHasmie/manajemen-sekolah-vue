// New grade input form for multiple students.
// Like a Vue modal component for bulk-entering grades for a class.
//
// This form is shown when a teacher creates a new assessment and
// enters grades for all students at once.
// In Laravel terms, this is GradeController@store for batch grade creation.
//
// Extracted from teacher_grade_input_screen.dart.
// Contains:
// - [GradeInputFormNew] -- bulk grade input form for multiple students
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

// Form Input Nilai Baru untuk Multiple Siswa
class GradeInputFormNew extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final List<Student> siswaList;

  const GradeInputFormNew({
    super.key,
    required this.teacher,
    required this.subject,
    required this.siswaList,
  });

  @override
  GradeInputFormNewState createState() => GradeInputFormNewState();
}

class GradeInputFormNewState extends ConsumerState<GradeInputFormNew> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();

  bool get _isReadOnly {
    return ref.read(academicYearRiverpod).isReadOnly;
  }

  // Variabel untuk state
  String? _selectedJenisNilai;
  final List<String> _jenisNilaiList = [
    'uh',
    'tugas',
    'uts',
    'uas',
    'pts',
    'pas',
  ];

  // Map untuk menyimpan nilai per siswa
  final Map<String, Map<String, dynamic>> _nilaiSiswaMap = {};

  // Text controllers untuk tabel input
  final Map<String, TextEditingController> _tableControllers = {};
  final Map<String, FocusNode> _tableFocusNodes = {};

  // State untuk tracking apakah jenis nilai dan tanggal sudah di-set
  bool _isConfigurationSet = false;
  String? _confirmedJenisNilai;
  DateTime? _confirmedDate;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize map dengan nilai default untuk setiap siswa
    for (var siswa in widget.siswaList) {
      _nilaiSiswaMap[siswa.id] = {'nilai': '', 'deskripsi': ''};
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _tableControllers.values) {
      controller.dispose();
    }
    for (var node in _tableFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitNilai() async {
    final languageProvider = ref.read(languageRiverpod);

    if (_formKey.currentState!.validate()) {
      if (_selectedJenisNilai == null) {
                SnackBarUtils.showWarning(context, languageProvider.getTranslatedText({
                'en': 'Please select grade type first',
                'id': 'Pilih jenis nilai terlebih dahulu',
              }));
        return;
      }

      // Cek apakah ada setidaknya satu siswa yang memiliki nilai
      bool hasData = false;
      for (var siswa in widget.siswaList) {
        final nilaiData = _nilaiSiswaMap[siswa.id];
        if (nilaiData?['nilai']?.isNotEmpty == true) {
          hasData = true;
          break;
        }
      }

      if (!hasData) {
                SnackBarUtils.showWarning(context, languageProvider.getTranslatedText({
                'en': 'Enter grade for at least one student',
                'id': 'Masukkan nilai untuk setidaknya satu siswa',
              }));
        return;
      }

      try {
        int successCount = 0;

        for (var siswa in widget.siswaList) {
          final nilaiData = _nilaiSiswaMap[siswa.id];
          final nilai = nilaiData?['nilai']?.toString().trim();

          // Skip jika tidak ada nilai yang diinput
          if (nilai == null || nilai.isEmpty) {
            continue;
          }

          // Perbaikan: Kirim Student Class ID jika ada, fallback ke ID siswa (untuk kompatibilitas)
          final studentIdToSend = siswa.studentClassId ?? siswa.id;

          // ... (inside _submitNilai)
          final data = {
            'student_id': siswa.id, // For legacy/history
            'student_class_id':
                studentIdToSend, // New field required by backend
            'teacher_id': widget.teacher['id'],
            'subject_id': widget.subject['id'],
            'type': _selectedJenisNilai,
            'score': int.parse(nilaiData!['nilai']),
            'notes': nilaiData['deskripsi'] ?? '',
            'date':
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
            'title': _titleController.text.isNotEmpty
                ? _titleController.text
                : null,
          };

          // Tambah nilai baru
          await ApiService().post('/grades', data);
          successCount++;
        }

        if (!mounted) return;
                SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
                'en': '$successCount grades successfully saved',
                'id': '$successCount nilai berhasil disimpan',
              }));

        AppNavigator.pop(context);
      } catch (e) {
        AppLogger.error('grades', e);
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } else {
      // Validation failed - show error message
            SnackBarUtils.showError(context, languageProvider.getTranslatedText({
              'en':
                  'Please check your input. Grades must be integers between 0-100.',
              'id':
                  'Periksa input Anda. Nilai harus berupa angka bulat antara 0-100.',
            }));
    }
  }

  String _getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
    switch (jenis) {
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
        return jenis.toUpperCase();
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  Widget _buildInputTable(LanguageProvider languageProvider) {
    // Calculate width
    double tableWidth = 150.0; // Name column
    tableWidth += 100.0; // Nilai column
    tableWidth += 200.0; // Deskripsi column

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? MediaQuery.of(context).size.width
              : tableWidth,
          child: Column(
            children: [
              // Header (Sticky-like appearance)
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.05),
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 150,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Name',
                          'id': 'Nama',
                        }),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      width: 100,
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Grade',
                          'id': 'Nilai',
                        }),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Description',
                            'id': 'Deskripsi',
                          }),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Rows - scrollable
              ...widget.siswaList.map((siswa) {
                final nilaiKey = "${siswa.id}_nilai";
                final deskripsiKey = "${siswa.id}_deskripsi";

                // Initialize controllers if not exists
                if (!_tableControllers.containsKey(nilaiKey)) {
                  _tableControllers[nilaiKey] = TextEditingController();
                  _tableFocusNodes[nilaiKey] = FocusNode();
                }
                if (!_tableControllers.containsKey(deskripsiKey)) {
                  _tableControllers[deskripsiKey] = TextEditingController();
                  _tableFocusNodes[deskripsiKey] = FocusNode();
                }

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: ColorUtils.slate200),
                    ),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      // Name
                      Container(
                        width: 150,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              siswa.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              siswa.studentNumber,
                              style: TextStyle(
                                fontSize: 10,
                                color: ColorUtils.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Nilai Input
                      Container(
                        width: 100,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: ColorUtils.slate200),
                            right: BorderSide(color: ColorUtils.slate200),
                          ),
                        ),
                        child: TextFormField(
                          controller: _tableControllers[nilaiKey],
                          focusNode: _tableFocusNodes[nilaiKey],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ColorUtils.slate900),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '-',
                            hintStyle: TextStyle(color: ColorUtils.slate400),
                            errorStyle: TextStyle(fontSize: 10),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (int.tryParse(value) == null) {
                                return languageProvider.getTranslatedText({
                                  'en': 'Integer only',
                                  'id': 'Hanya angka bulat',
                                });
                              }
                              final numValue = int.parse(value);
                              if (numValue < 0 || numValue > 100) {
                                return languageProvider.getTranslatedText({
                                  'en': '0-100',
                                  'id': '0-100',
                                });
                              }
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _nilaiSiswaMap[siswa.id]?['nilai'] = value;
                            });
                          },
                        ),
                      ),
                      // Deskripsi Input
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: TextFormField(
                            controller: _tableControllers[deskripsiKey],
                            focusNode: _tableFocusNodes[deskripsiKey],
                            style: TextStyle(color: ColorUtils.slate900),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: languageProvider.getTranslatedText({
                                'en': 'Add description...',
                                'id': 'Tambah deskripsi...',
                              }),
                              hintStyle: TextStyle(
                                color: ColorUtils.slate400,
                                fontSize: 12,
                              ),
                            ),
                            onChanged: (value) {
                              _nilaiSiswaMap[siswa.id]?['deskripsi'] = value;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Build header for add mode after configured (similar to edit mode)
  Widget _buildAddHeader(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.all(16),
      color: ColorUtils.warning600.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Jenis Nilai with edit icon
          GestureDetector(
            onTap: () {
              setState(() {
                _isConfigurationSet = false;
              });
            },
            child: Row(
              children: [
                Text(
                  _getJenisNilaiLabel(
                    _confirmedJenisNilai ?? '',
                    languageProvider,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ColorUtils.warning600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.edit, size: 16, color: ColorUtils.warning600),
              ],
            ),
          ),
          // Right side: Date in Indonesian format
          Text(
            _formatDateIndonesian(_confirmedDate!),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: ColorUtils.slate700,
            ),
          ),
        ],
      ),
    );
  }

  // Format date to Indonesian format (e.g., "05 Januari 2025")
  String _formatDateIndonesian(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString();

    return '$day $month $year';
  }

  // Build configuration panel (selection stage)
  Widget _buildConfigurationPanel(LanguageProvider languageProvider) {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: ColorUtils.slate200, width: 1),
          ),
        ),
        child: Column(
          children: [
            // Subject Info
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: _getPrimaryColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject['nama'] ??
                              widget.subject['name'] ??
                              '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        if (widget.subject['code'] != null ||
                            widget.subject['kode'] != null)
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'Code', 'id': 'Kode'})}: ${widget.subject['code'] ?? widget.subject['kode']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Pilih Jenis Nilai - Pattern #9 style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedJenisNilai,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.assignment_outlined,
                    color: _getPrimaryColor(),
                  ),
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Select grade type',
                    'id': 'Pilih jenis nilai',
                  }),
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(color: ColorUtils.slate900),
                items: _jenisNilaiList.map((String jenis) {
                  return DropdownMenuItem<String>(
                    value: jenis,
                    child: Text(_getJenisNilaiLabel(jenis, languageProvider)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedJenisNilai = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return languageProvider.getTranslatedText({
                      'en': 'Please select grade type',
                      'id': 'Pilih jenis nilai terlebih dahulu',
                    });
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            // Pilih Tanggal - Pattern #9 style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _getPrimaryColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
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
                  const Spacer(),
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
            const SizedBox(height: 12),
            // Title field - Pattern #9 style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: TextFormField(
                controller: _titleController,
                style: TextStyle(color: ColorUtils.slate900),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.title, color: _getPrimaryColor()),
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Assessment Title (Optional)',
                    'id': 'Judul Penilaian (Opsional)',
                  }),
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                  helperText: languageProvider.getTranslatedText({
                    'en': 'E.g., Quiz 1, Chapter 5 Test',
                    'id': 'Contoh: Kuis 1, Ulangan Bab 5',
                  }),
                  helperStyle: TextStyle(
                    color: ColorUtils.slate400,
                    fontSize: 11,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Set button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_selectedJenisNilai != null && !_isReadOnly)
                    ? () {
                        setState(() {
                          _isConfigurationSet = true;
                          _confirmedJenisNilai = _selectedJenisNilai;
                          _confirmedDate = _selectedDate;
                        });
                      }
                    : null,
                icon: Icon(Icons.check),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Set',
                    'id': 'Tetapkan',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: ColorUtils.slate200,
                  disabledForegroundColor: ColorUtils.slate500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
        final siswaWithNilaiCount = widget.siswaList.where((siswa) {
          final nilaiData = _nilaiSiswaMap[siswa.id];
          return nilaiData?['nilai']?.isNotEmpty == true;
        }).length;

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
                              'en': 'New Grade Input',
                              'id': 'Input Nilai Baru',
                            }),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.subject['nama'] ??
                                widget.subject['name'] ??
                                '',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Conditional header based on state
                      if (!_isConfigurationSet)
                        _buildConfigurationPanel(languageProvider)
                      else
                        _buildAddHeader(languageProvider),

                      // Student List Section - only show after configuration is set
                      if (_isConfigurationSet) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Student List',
                                  'id': 'Daftar Siswa',
                                }),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: ColorUtils.slate700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: siswaWithNilaiCount > 0
                                      ? ColorUtils.success600.withValues(
                                          alpha: 0.08,
                                        )
                                      : ColorUtils.slate100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: siswaWithNilaiCount > 0
                                        ? ColorUtils.success600.withValues(
                                            alpha: 0.3,
                                          )
                                        : ColorUtils.slate200,
                                  ),
                                ),
                                child: Text(
                                  '$siswaWithNilaiCount/${widget.siswaList.length} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                                  style: TextStyle(
                                    color: siswaWithNilaiCount > 0
                                        ? ColorUtils.success600
                                        : ColorUtils.slate500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en':
                                  'Edit grade and description for each student',
                              'id':
                                  'Edit nilai dan deskripsi untuk setiap siswa',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _buildInputTable(languageProvider)),
                      ] else ...[
                        const Expanded(
                          child: EmptyState(
                            title: 'Select grade type and date',
                            subtitle:
                                'Please select grade type and date first then click Set',
                            icon: Icons.assignment,
                          ),
                        ),
                      ],

                      // Finish button - only show after configuration is set
                      if (_isConfigurationSet) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: ColorUtils.slate200),
                            ),
                          ),
                          child: SafeArea(
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitNilai,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getPrimaryColor(),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Finish',
                                    'id': 'Selesai',
                                  }),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }
}

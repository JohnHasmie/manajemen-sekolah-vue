import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/walimurid/parent_raport_detail_screen.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_raport_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/excel_raport_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class AdminRaportScreen extends StatefulWidget {
  const AdminRaportScreen({super.key});

  @override
  State<AdminRaportScreen> createState() => _AdminRaportScreenState();
}

class _AdminRaportScreenState extends State<AdminRaportScreen> {
  late LanguageProvider _languageProvider;

  bool _isLoading = true;
  bool _isLoadingStudents = false;
  bool _isExporting = false;
  bool _isPublishing = false;
  String _errorMessage = '';

  List<dynamic> _classes = [];
  Map<String, dynamic>? _selectedClass;
  List<dynamic> _students = [];

  @override
  void initState() {
    super.initState();
    _languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final classesResponse = await ApiClassService.getClassPaginated(
        limit: 100,
        academicYearId: academicYearId,
      );

      if (mounted) {
        setState(() {
          _classes = classesResponse['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedClass == null) return;

    setState(() {
      _isLoadingStudents = true;
      _errorMessage = '';
    });

    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      if (academicYearId == null) throw Exception("Tahun ajaran tidak valid.");

      final studentsData = await ApiRaportService.getRaports(
        classId: _selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
      );

      if (mounted) {
        setState(() {
          _students = studentsData;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingStudents = false;
        });
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_selectedClass == null) return;

    setState(() => _isExporting = true);
    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      if (academicYearId == null) throw Exception("Tahun ajaran tidak valid.");

      await ExcelRaportService.exportRaportToExcel(
        classId: _selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        className: _selectedClass!['name'] ?? 'Kelas',
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _publishRaports() async {
    if (_selectedClass == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Raport ke Wali Murid?'),
        content: const Text(
          'Tindakan ini akan mempublikasikan raport dengan status "Final" dan secara otomatis mengirimkan notifikasi ke wali murid terkait. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.corporateBlue600,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, Kirim',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPublishing = true);
    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      final headers = await ApiService.getHeaders();
      final url = Uri.parse('${ApiService.baseUrl}/raports/publish');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'class_id': _selectedClass!['id'],
          'academic_year_id': academicYearId,
          'semester_id': semesterId,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Raport berhasil dipublikasi dan dikirim ke wali murid!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadStudents(); // Reload status
        }
      } else {
        throw Exception('Gagal mengirim raport: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  Future<void> _viewRaportDetail(Map<String, dynamic> student) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      Map<String, dynamic>? detail = await ApiRaportService.getRaportDetail(
        studentClassId: student['student_class_id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
      );

      if (detail == null) {
        final initialData = await ApiRaportService.getInitialData(
          studentClassId: student['student_class_id'].toString(),
          academicYearId: academicYearId,
          semesterId: semesterId,
        );

        if (initialData != null) {
          final att = initialData['attendance'] ?? {};

          detail = {
            'student_class_id': student['student_class_id'],
            'academic_year_id': academicYearId,
            'semester_id': semesterId,
            'status': 'draft',

            // Populate defaults from initial data
            'sick': att['sick'] ?? 0,
            'permit': att['permit'] ?? 0,
            'absent': att['absent'] ?? 0,

            // Empty defaults for editable fields
            'spiritual_predicate': null,
            'spiritual_description': null,
            'social_predicate': null,
            'social_description': null,
            'notes': null,
            'promotion_decision': null,

            // Map initial subjects
            'raport_subjects':
                (initialData['grades'] as List?)?.map((g) {
                  return {
                    'subject_id': g['subject_id'],
                    'knowledge_score': g['knowledge_score']?.toString(),
                    'knowledge_predicate': g['knowledge_predicate'],
                    'knowledge_description': g['knowledge_description'],
                    'skill_score': null,
                    'skill_predicate': null,
                    'skill_description': null,
                    'subject': {
                      'id': g['subject_id'],
                      'name': g['subject_name'],
                    },
                  };
                }).toList() ??
                [],

            'extracurriculars': [],
            'achievements': [],
          };
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (detail != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParentRaportDetailScreen(
              raportData: detail!,
              studentName: student['student_name'] ?? 'Unknown',
              userRole: 'admin',
              studentData: {
                'nis': student['student_number'] ?? '-',
                'nisn':
                    '-', // Admin API list doesnt fetch NISN by default, fallback
              },
            ),
          ),
        );
      } else {
        throw Exception("Data raport tidak ditemukan.");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _downloadStudentPdf(Map<String, dynamic> student) async {
    final status = student['raport_status'] ?? 'draft';
    if (status == 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Raport Draft belum bisa dicetak.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menyiapkan PDF untuk ${student['student_name']}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      await ExcelRaportService.exportSingleRaportPdf(
        studentClassId: student['student_class_id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        studentName: student['student_name'] ?? 'Unknown',
        context: context,
      );
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty && _classes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_errorMessage'),
              TextButton(
                onPressed: _loadInitialData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header with Gradient
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manajemen Raport',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unduh dan publikasikan raport kelas',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar:
          _selectedClass != null && !_isLoadingStudents && _students.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.download,
                                color: Colors.white,
                                size: 18,
                              ),
                        label: const Text(
                          'Export Excel',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isExporting ? null : _exportToExcel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isPublishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 18,
                              ),
                        label: const Text(
                          'Kirim ke Wali',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.corporateBlue600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isPublishing ? null : _publishRaports,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Class Selection
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Kelas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: _selectedClass,
                    hint: const Text('Pilih Kelas'),
                    items: _classes.map((cls) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: cls,
                        child: Text(cls['name']?.toString() ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClass = value;
                        _students = [];
                      });
                      _loadStudents();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Students List
        Expanded(
          child: _isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : _selectedClass == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Silakan pilih kelas terlebih dahulu',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : _students.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada data siswa',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final status = student['raport_status'] ?? 'draft';

                    Color statusColor;
                    String statusText;
                    IconData statusIcon;

                    if (status == 'published') {
                      statusColor = Colors.green;
                      statusText = 'Terkirim';
                      statusIcon = Icons.check_circle;
                    } else if (status == 'final') {
                      statusColor = Colors.blue;
                      statusText = 'Final';
                      statusIcon = Icons.save;
                    } else {
                      statusColor = Colors.orange;
                      statusText = 'Draft';
                      statusIcon = Icons.edit_note;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _viewRaportDetail(student),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _getPrimaryColor().withOpacity(
                                  0.1,
                                ),
                                child: Text(
                                  (student['student_name'] ?? '?')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: _getPrimaryColor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['student_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'NIS: ${student['student_number'] ?? '-'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 14,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                                onPressed: () => _downloadStudentPdf(student),
                                tooltip: 'Cetak PDF',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

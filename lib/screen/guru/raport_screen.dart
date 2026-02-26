import 'package:flutter/material.dart';
import 'package:manajemensekolah/screen/guru/raport_detail_screen.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_raport_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

import '../../providers/academic_year_provider.dart';

class RaportScreen extends StatefulWidget {
  final Map<String, String> teacher;

  const RaportScreen({super.key, required this.teacher});

  @override
  RaportScreenState createState() => RaportScreenState();
}

class RaportScreenState extends State<RaportScreen> {
  final LanguageProvider _languageProvider = LanguageProvider();

  bool _isLoading = true;
  bool _isLoadingStudents = false;
  String _errorMessage = '';

  List<dynamic> _classes = [];
  Map<String, dynamic>? _selectedClass;

  List<dynamic> _students = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final academicYearId = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      ).selectedAcademicYear?['id']?.toString();

      // Only fetching classes where the teacher is a homeroom teacher (if the API supports it, otherwise filtering locally or relying on backend constraint)
      final classesResponse = await ApiClassService.getClassPaginated(
        waliclassId: widget.teacher['id'],
        academicYearId: academicYearId,
        limit: 100,
      );

      final uniqueClassesMap = <String, dynamic>{};
      if (classesResponse['data'] != null) {
        for (var classData in classesResponse['data']) {
          if (classData != null && classData['id'] != null) {
            uniqueClassesMap[classData['id'].toString()] = classData;
          }
        }
      }

      setState(() {
        _classes = uniqueClassesMap.values.toList();
        if (_classes.isNotEmpty) {
          _selectedClass = _classes.first;
          _loadStudentsForClass();
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentsForClass() async {
    if (_selectedClass == null) return;

    setState(() {
      _isLoadingStudents = true;
    });

    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();
      final semester = '1';

      if (academicYearId == null) {
        setState(() {
          _errorMessage = "Tahun ajaran tidak valid.";
          _isLoadingStudents = false;
          _isLoading = false;
        });
        return;
      }

      // Fetch students and their raport status
      final response = await ApiRaportService.getRaports(
        classId: _selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semester,
      );

      setState(() {
        _students = response;
        _isLoadingStudents = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingStudents = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _languageProvider.getTranslatedText({
            'en': 'Report Cards (Raport)',
            'id': 'Raport Siswa',
          }),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: ColorUtils.slate800,
        elevation: 0,
        iconTheme: IconThemeData(color: ColorUtils.slate800),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                'Terjadi kesalahan:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.corporateBlue600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildClassSelector(),
        Expanded(
          child: _isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : _buildStudentList(),
        ),
      ],
    );
  }

  Widget _buildClassSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.class_outlined,
              color: ColorUtils.corporateBlue600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _languageProvider.getTranslatedText({
                    'en': 'Select Class',
                    'id': 'Pilih Kelas',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_classes.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: _selectedClass,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedClass = newValue;
                            _loadStudentsForClass();
                          });
                        }
                      },
                      items: _classes.map((cls) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: cls,
                          child: Text(cls['name'] ?? 'Unknown Class'),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Text(
                    _languageProvider.getTranslatedText({
                      'en': 'No classes available',
                      'id': 'Tidak ada kelas',
                    }),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data siswa',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final bool hasRaport = student['has_raport'] ?? false;
        final String status = student['raport_status'] ?? 'Belum ada';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RaportDetailScreen(
                    studentClassId: student['student_class_id'].toString(),
                    studentName: student['student_name'] ?? 'Siswa',
                    className: _selectedClass?['name'] ?? '',
                  ),
                ),
              ).then((_) => _loadStudentsForClass());
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: ColorUtils.corporateBlue50,
                    child: Text(
                      (student['student_name'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        color: ColorUtils.corporateBlue600,
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
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NIS: ${student['student_number'] ?? '-'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(hasRaport, status),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool hasRaport, String status) {
    Color bgColor;
    Color textColor;
    String label;

    if (!hasRaport) {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      label = 'Belum Isi';
    } else if (status.toLowerCase() == 'draft') {
      bgColor = Colors.orange.shade50;
      textColor = ColorUtils.warning600;
      label = 'Draft';
    } else {
      bgColor = Colors.green.shade50;
      textColor = ColorUtils.success600;
      label = 'Selesai';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

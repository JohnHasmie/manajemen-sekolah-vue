import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

import 'learning_recommendation_result_screen.dart';

class LearningRecommendationStudentScreen extends StatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> classData;

  const LearningRecommendationStudentScreen({
    super.key,
    required this.teacher,
    required this.classData,
  });

  @override
  State<LearningRecommendationStudentScreen> createState() =>
      _LearningRecommendationStudentScreenState();
}

class _LearningRecommendationStudentScreenState
    extends State<LearningRecommendationStudentScreen> {
  bool _isLoading = true;
  List<dynamic> _students = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final students = await ApiClassService.getStudentsByClassId(
        widget.classData['id'].toString(),
      );
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header
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
                  offset: const Offset(0, 2),
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
                      Text(
                        widget.classData['name'] ??
                            widget.classData['nama'] ??
                            'Daftar Siswa',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih siswa untuk melihat rekomendasi belajar',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _isLoading
                ? const SkeletonListLoading()
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _students.isEmpty
                ? const Center(child: Text('Tidak ada data siswa'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: ColorUtils.corporateShadow(),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ColorUtils.slate50,
                            child: Text(
                              (student['nama'] ?? student['name'] ?? '?')[0]
                                  .toUpperCase(),
                              style: TextStyle(
                                color: ColorUtils.slate600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            student['nama'] ??
                                student['name'] ??
                                'Siswa Tanpa Nama',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate800,
                            ),
                          ),
                          subtitle: Text(
                            'NIS: ${student['nis'] ?? student['nisn'] ?? '-'}',
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: ColorUtils.slate400,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    LearningRecommendationResultScreen(
                                      teacher: widget.teacher,
                                      student: student,
                                      classData: widget.classData,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

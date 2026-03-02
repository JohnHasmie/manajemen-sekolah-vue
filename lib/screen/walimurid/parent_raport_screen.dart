import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/walimurid/parent_raport_detail_screen.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentRaportScreen extends StatefulWidget {
  final String? academicYearId;
  const ParentRaportScreen({super.key, this.academicYearId});

  @override
  State<ParentRaportScreen> createState() => _ParentRaportScreenState();
}

class _ParentRaportScreenState extends State<ParentRaportScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _studentsData = [];
  Map<String, dynamic> _parentData = {};

  // We can select semester (1 for Ganjil, 2 for Genap)
  String _selectedSemesterId = '1';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _parentData = json.decode(prefs.getString('user') ?? '{}');

      if (_parentData.isEmpty || _parentData['id'] == null) {
        throw Exception(
          "Sesi wali murid tidak ditemukan. Silakan login kembali.",
        );
      }

      final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        _selectedSemesterId = '2';
      }

      await _fetchParentRaports();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchParentRaports() async {
    final yearId =
        widget.academicYearId ??
        Provider.of<AcademicYearProvider>(
          context,
          listen: false,
        ).selectedAcademicYear?['id']?.toString();

    if (yearId == null) throw Exception("Tahun ajaran belum dipilih.");

    final headers = await ApiService.getHeaders();
    final url = Uri.parse(
      '${ApiService.baseUrl}/parent/raports?academic_year_id=$yearId&semester_id=$_selectedSemesterId',
    );

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success']) {
        setState(() {
          _studentsData = jsonResponse['data'] ?? [];
        });
      } else {
        throw Exception(jsonResponse['message'] ?? 'Gagal memuat e-raport.');
      }
    } else {
      setState(() {
        _studentsData = [];
      });
      String errorMsg =
          'Gagal mengambil data dari server (Status: ${response.statusCode}).';
      try {
        final errJson = jsonDecode(response.body);
        errorMsg = errJson['message'] ?? errJson['error'] ?? errorMsg;
      } catch (e) {
        // use default errorMsg
      }
      throw Exception(errorMsg);
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(_parentData['role'] ?? 'wali');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header - Pattern #7 gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: _getCardGradient(),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'E-Raport',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lihat raport akademik siswa',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          // Filter section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Semester:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedSemesterId,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('Ganjil')),
                      DropdownMenuItem(value: '2', child: Text('Genap')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSemesterId = val);
                        _loadData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty && _studentsData.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 48,
                            color: Colors.orange[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _studentsData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada E-Raport yang dipublikasikan\npada semester ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _studentsData.length,
                      itemBuilder: (context, index) {
                        final student = _studentsData[index];
                        final raport = student['raport'];

                        // Parent only sees published raports
                        if (raport == null || raport['status'] != 'published') {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ParentRaportDetailScreen(
                                        raportData: raport,
                                        studentName:
                                            student['student']['name'] ??
                                            'Siswa',
                                        studentData: student['student'],
                                      ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: ColorUtils.corporateBlue600
                                        .withOpacity(0.1),
                                    child: Text(
                                      (student['student']['name'] ?? '?')[0]
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: ColorUtils.corporateBlue600,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student['student']['name'] ??
                                              'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'NIS: ${student['student']['nis'] ?? '-'}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
          ),
        ],
      ),
    );
  }
}

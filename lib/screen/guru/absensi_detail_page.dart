// screen/guru/absensi_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';

class AbsensiDetailPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final String subjectId;
  final String subjectName;
  final DateTime date;

  const AbsensiDetailPage({
    super.key,
    required this.teacher,
    required this.subjectId,
    required this.subjectName,
    required this.date,
  });

  @override
  State<AbsensiDetailPage> createState() => _AbsensiDetailPageState();
}

class _AbsensiDetailPageState extends State<AbsensiDetailPage> {
  List<dynamic> _absensiData = [];
  List<Siswa> _studentList = [];
  List<Siswa> _filteredStudentList = [];
  final Map<String, String> _absensiStatus = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterSiswa);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSiswa() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudentList = List.from(_studentList);
      } else {
        _filteredStudentList = _studentList
            .where((siswa) =>
                siswa.name.toLowerCase().contains(query) ||
                siswa.nis.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      // Load siswa dan absensi data
      final [studentData, absensiData] = await Future.wait([
        ApiStudentService.getStudent(),
        ApiService.getAbsensi(
          teacherId: widget.teacher['id'],
          subjectId: widget.subjectId,
          date: DateFormat('yyyy-MM-dd').format(widget.date),
        ),
      ]);

      setState(() {
        _studentList = studentData.map((s) => Siswa.fromJson(s)).toList();
        _filteredStudentList = List.from(_studentList);
        _absensiData = absensiData;

        // Map status absensi
        for (var absen in _absensiData) {
          _absensiStatus[absen['siswa_id']] = absen['status'];
        }

        // Set default untuk siswa yang belum ada data
        for (var student in _studentList) {
          _absensiStatus[student.id] ??= 'hadir';
        }

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading absensi detail: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStudentItem(Siswa student) {
    final status = _absensiStatus[student.id] ?? 'hadir';
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getStatusText(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAvatarColor(student.name),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('NIS: ${student.nis}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: DropdownButton<String>(
            value: status,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: 'hadir',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Hadir'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'terlambat',
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.purple, size: 16),
                    SizedBox(width: 4),
                    Text('Terlambat'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'izin',
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 4),
                    Text('Izin'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'sakit',
                child: Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.orange, size: 16),
                    SizedBox(width: 4),
                    Text('Sakit'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'alpha',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text('Alpha'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _absensiStatus[student.id] = value!;
              });
            },
          ),
        ),
      ),
    );
  }

  Future<void> _updateAbsensi() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      int successCount = 0;

      for (var student in _studentList) {
        final status = _absensiStatus[student.id]!;
        
        await ApiService.tambahAbsensi({
          'siswa_id': student.id,
          'guru_id': widget.teacher['id'],
          'mata_pelajaran_id': widget.subjectId,
          'tanggal': DateFormat('yyyy-MM-dd').format(widget.date),
          'status': status,
          'keterangan': '',
        });

        successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil update $successCount absensi'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Helper functions
  Color _getStatusColor(String status) {
    switch (status) {
      case 'izin': return Colors.blue;
      case 'sakit': return Colors.orange;
      case 'alpha': return Colors.red;
      case 'terlambat': return Colors.purple;
      default: return Colors.green;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'izin': return 'Izin';
      case 'sakit': return 'Sakit';
      case 'alpha': return 'Alpha';
      case 'terlambat': return 'Terlambat';
      default: return 'Hadir';
    }
  }

  Color _getAvatarColor(String nama) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.indigo];
    final index = nama.isNotEmpty ? nama.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Absensi - ${widget.subjectName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.subjectName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(widget.date),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Cari siswa...',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Student Count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Siswa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '${_filteredStudentList.length} siswa',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Student List
                Expanded(
                  child: _filteredStudentList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada siswa ditemukan',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredStudentList.length,
                          itemBuilder: (context, index) => _buildStudentItem(_filteredStudentList[index]),
                        ),
                ),
                // Update Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _updateAbsensi,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.update),
                    label: Text(_isSubmitting ? 'Mengupdate...' : 'Update Absensi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
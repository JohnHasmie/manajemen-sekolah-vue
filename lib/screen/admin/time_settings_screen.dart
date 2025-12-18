import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_settings_services.dart';

class TimeSettingsScreen extends StatefulWidget {
  const TimeSettingsScreen({super.key});

  @override
  State<TimeSettingsScreen> createState() => _TimeSettingsScreenState();
}

class _TimeSettingsScreenState extends State<TimeSettingsScreen> {
  List<dynamic> _days = [];
  Map<String, List<dynamic>> _sessionsByDay =
      {}; // dayId (String) -> List of sessions
  bool _isLoadingTime = true;
  final Color primaryColor = Color(0xFF4361EE);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingTime = true);
    try {
      final futures = await Future.wait([
        ApiScheduleService.getHari(),
        ApiSettingsService.getLessonHourSettings(),
      ]);

      final allSessions = futures[1];
      final Map<String, List<dynamic>> grouped = {};

      for (var session in allSessions) {
        final dayId = session['day_id'].toString(); // Ensure String
        if (!grouped.containsKey(dayId)) {
          grouped[dayId] = [];
        }
        grouped[dayId]!.add(session);
      }

      setState(() {
        _days = futures[0];
        _sessionsByDay = grouped;
        _isLoadingTime = false;
      });
    } catch (e) {
      print('Error loading settings data: $e');
      if (mounted) {
        setState(() => _isLoadingTime = false);
      }
    }
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 28, color: Colors.grey[800]),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openDaySettings(dynamic day) {
    final dayId = day['id'].toString();
    final sessions = _sessionsByDay[dayId] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DaySessionManagementSheet(
        day: day,
        sessions: sessions,
        onSave: () {
          _loadInitialData(); // Refresh all data
        },
      ),
    );
  }

  Widget _buildDayCard(dynamic day) {
    final dayId = day['id'].toString();
    final sessions = _sessionsByDay[dayId] ?? [];

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openDaySettings(day),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day['name'] ?? day['nama'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${sessions.length} Jam Pelajaran',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Pengaturan Waktu',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _isLoadingTime
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    'Jam Aktif Harian',
                    'Pilih hari untuk mengatur jam pelajaran.',
                    Icons.calendar_today_outlined,
                  ),
                  SizedBox(height: 24),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _days.length,
                    itemBuilder: (context, index) {
                      final day = _days[index];
                      return _buildDayCard(day);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class DaySessionManagementSheet extends StatefulWidget {
  final dynamic day;
  final List<dynamic> sessions;
  final VoidCallback onSave;

  const DaySessionManagementSheet({
    super.key,
    required this.day,
    required this.sessions,
    required this.onSave,
  });

  @override
  State<DaySessionManagementSheet> createState() =>
      _DaySessionManagementSheetState();
}

class _DaySessionManagementSheetState extends State<DaySessionManagementSheet> {
  final Color primaryColor = Color(0xFF4361EE);
  late List<dynamic> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = widget.sessions;
  }

  Future<void> _refreshSessions() async {
    try {
      final allSettings = await ApiSettingsService.getLessonHourSettings();
      final dayId = widget.day['id'].toString();
      final updated = allSettings
          .where((s) => s['day_id'].toString() == dayId)
          .toList();

      updated.sort(
        (a, b) => (a['hour_number'] as int).compareTo(b['hour_number'] as int),
      );

      if (mounted) {
        setState(() {
          _sessions = updated;
        });
      }
      widget.onSave(); // Sync parent
    } catch (e) {
      print('Error refreshing sessions: $e');
    }
  }

  void _showAddEditSessionDialog({Map<String, dynamic>? session}) {
    final bool isEdit = session != null;
    final TextEditingController hourController = TextEditingController(
      text: isEdit ? session['hour_number'].toString() : '',
    );

    TimeOfDay startTime = TimeOfDay(hour: 7, minute: 0);
    TimeOfDay endTime = TimeOfDay(hour: 7, minute: 45);

    if (isEdit) {
      try {
        final startParts = session['start_time'].toString().split(':');
        final endParts = session['end_time'].toString().split(':');
        startTime = TimeOfDay(
          hour: int.parse(startParts[0]),
          minute: int.parse(startParts[1]),
        );
        endTime = TimeOfDay(
          hour: int.parse(endParts[0]),
          minute: int.parse(endParts[1]),
        );
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickTime(bool isStart) async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: isStart ? startTime : endTime,
              );
              if (picked != null) {
                setState(() {
                  if (isStart)
                    startTime = picked;
                  else
                    endTime = picked;
                });
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Sesi' : 'Tambah Sesi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hourController,
                    decoration: InputDecoration(labelText: 'Jam Ke-'),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => pickTime(true),
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: 'Mulai'),
                            child: Text(startTime.format(context)),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => pickTime(false),
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: 'Selesai'),
                            child: Text(endTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (hourController.text.isEmpty) return;

                    final startStr =
                        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                    final endStr =
                        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';
                    final hourNum = int.tryParse(hourController.text) ?? 0;

                    try {
                      if (isEdit) {
                        await ApiSettingsService.updateLessonSession(
                          id: session['id'].toString(),
                          startTime: startStr,
                          endTime: endStr,
                          hourNumber: hourNum,
                        );
                      } else {
                        await ApiSettingsService.createLessonSession(
                          dayId: widget.day['id'].toString(),
                          hourNumber: hourNum,
                          startTime: startStr,
                          endTime: endStr,
                        );
                      }
                      Navigator.pop(context); // Close dialog
                      await _refreshSessions(); // Refresh list without closing sheet
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                    }
                  },
                  child: Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSession(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Jam Pelajaran?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus jam pelajaran ini? Data yang dihapus tidak dapat dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Batal
            child: Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // Hapus
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiSettingsService.deleteLessonSession(id);
      await _refreshSessions();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Jadwal ${widget.day['name'] ?? widget.day['nama']}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          Divider(),
          Expanded(
            child: _sessions.isEmpty
                ? Center(child: Text('Belum ada jadwal'))
                : ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: Text(
                            '${session['hour_number']}',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                        title: Text(
                          '${session['start_time']} - ${session['end_time']}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showAddEditSessionDialog(session: session),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteSession(session['id'].toString()),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditSessionDialog(),
              icon: Icon(Icons.add),
              label: Text('Tambah Jam Pelajaran'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
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

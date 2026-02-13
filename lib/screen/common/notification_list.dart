import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/screen/walimurid/announcement_screen.dart';
import 'package:manajemensekolah/screen/walimurid/parent_billing.dart';
import 'package:manajemensekolah/screen/walimurid/parent_class_activity.dart';
import 'package:manajemensekolah/services/api_notification_service.dart';

class NotificationListScreen extends StatefulWidget {
  final String role; // 'guru', 'admin', 'wali'

  const NotificationListScreen({super.key, required this.role});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final ApiNotificationService _apiService = ApiNotificationService();
  List<dynamic> _notifications = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final notifs = await _apiService.getNotifications(role: widget.role);
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error loading notifications: $e');
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _apiService.markAsRead(id);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['is_read'] = true; // Local update
          // Or 1 if API returns 1/0
          _notifications[index]['is_read'] = 1;
        }
      });
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _apiService.deleteNotification(id);
      setState(() {
        _notifications.removeWhere((n) => n['id'] == id);
      });
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _apiService.markAllRead();
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
          n['is_read'] = 1;
        }
      });
    } catch (e) {
      print('Error marking all read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Notifikasi & Jadwal',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all),
            tooltip: 'Tandai semua dibaca',
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  Text(
                    'Notifikasi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  if (_notifications.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 32.0),
                        child: Text(
                          'Tidak ada notifikasi',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._notifications.map((n) => _buildNotificationTile(n)),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notif) {
    bool isRead = false;
    if (notif['is_read'] is bool)
      isRead = notif['is_read'];
    else if (notif['is_read'] is int)
      isRead = notif['is_read'] == 1;

    final type = notif['type'] ?? 'general';

    return Dismissible(
      key: Key(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(notif['id']);
      },
      child: InkWell(
        onTap: () {
          if (!isRead) _markAsRead(notif['id']);
          _handleTap(notif);
        },
        child: Container(
          color: isRead ? Colors.transparent : Colors.blue.withOpacity(0.05),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: isRead
                      ? Colors.grey[200]
                      : _getColor(type).withOpacity(0.2),
                  child: Icon(
                    _getIcon(type),
                    color: isRead ? Colors.grey : _getColor(type),
                  ),
                ),
                title: Text(
                  notif['title'] ?? '-',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(notif['body'] ?? '-'),
                    SizedBox(height: 4),
                    Text(
                      _formatDate(notif['created_at']),
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor(String type) {
    switch (type) {
      case 'bill':
      case 'tagihan':
        return Colors.green;
      case 'announcement':
      case 'pengumuman':
        return Colors.blue;
      case 'class_activity':
      case 'activity':
        return Colors.orange;
      case 'reminder_teaching':
        return Colors.purple;
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'bill':
      case 'tagihan':
        return Icons.payment;
      case 'announcement':
      case 'pengumuman':
        return Icons.campaign;
      case 'class_activity':
      case 'activity':
        return Icons.assignment;
      case 'reminder_teaching':
        return Icons.class_;
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return Icons.grade;
      default:
        return Icons.notifications;
    }
  }

  void _handleTap(Map<String, dynamic> notif) {
    final type = notif['type'];

    if (widget.role == 'wali' || widget.role == 'parent') {
      if (type == 'bill') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ParentBillingScreen()),
        );
      } else if (type == 'class_activity') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ParentClassActivityScreen()),
        );
      }
    } else if (widget.role == 'guru' || widget.role == 'teacher') {
      if (type == 'class_activity') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClassActifityScreen()),
        );
      }
    }

    if (type == 'announcement' || type == 'pengumuman') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnnouncementScreen()),
      );
    } else if (type == 'grade' || type == 'nilai' || type == 'exam_score') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(notif['title'] ?? 'Info'),
          content: SingleChildScrollView(child: Text(notif['body'] ?? '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Tutup'),
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
